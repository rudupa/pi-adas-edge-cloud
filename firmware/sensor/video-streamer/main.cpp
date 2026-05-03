/*
 * firmware/sensor/video-streamer/main.cpp
 *
 * Lightweight C++ H.264 video streamer — fallback for environments where
 * GStreamer is unavailable or too resource-intensive.
 *
 * Uses libcamera to capture frames from the CSI camera, then packages them
 * into minimal RTP/H.264 packets and sends them to the gateway over UDP.
 *
 * Build:
 *   g++ -std=c++17 -O2 main.cpp -o video-streamer \
 *       $(pkg-config --cflags --libs libcamera) -lpthread
 *
 * Usage:
 *   ./video-streamer [gateway_ip] [gateway_port]
 */

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <thread>
#include <vector>

#include <libcamera/libcamera.h>

/* ── RTP helpers ──────────────────────────────────────────────────────────── */

static constexpr uint8_t  RTP_VERSION     = 2;
static constexpr uint8_t  RTP_PAYLOAD_H264 = 96;   // dynamic PT agreed with receiver
static constexpr uint16_t RTP_MTU          = 1400;  // leave headroom for UDP/IP headers

struct RtpHeader {
    uint8_t  vpxcc;   // V=2, P=0, X=0, CC=0
    uint8_t  mpt;     // M bit + payload type
    uint16_t seq;
    uint32_t timestamp;
    uint32_t ssrc;
};

static void rtp_send(int sock, const sockaddr_in &dst,
                     const uint8_t *nal, size_t nal_len,
                     uint16_t &seq, uint32_t ts, uint32_t ssrc)
{
    /* Single-NAL-unit packets (RFC 6184 §5.6) for NALs ≤ MTU,
     * Fragmentation Units (FU-A, §5.8) for larger NALs. */
    if (nal_len == 0) return;

    const size_t max_payload = RTP_MTU - sizeof(RtpHeader);

    if (nal_len <= max_payload) {
        /* Single NAL unit packet */
        std::vector<uint8_t> pkt(sizeof(RtpHeader) + nal_len);

        auto *hdr      = reinterpret_cast<RtpHeader *>(pkt.data());
        hdr->vpxcc     = (RTP_VERSION << 6);
        hdr->mpt       = 0x80 | RTP_PAYLOAD_H264; // marker bit set on last fragment
        hdr->seq       = htons(seq++);
        hdr->timestamp = htonl(ts);
        hdr->ssrc      = htonl(ssrc);

        std::memcpy(pkt.data() + sizeof(RtpHeader), nal, nal_len);
        sendto(sock, pkt.data(), pkt.size(), 0,
               reinterpret_cast<const sockaddr *>(&dst), sizeof(dst));
        return;
    }

    /* FU-A fragmentation */
    const uint8_t nal_hdr   = nal[0];
    const uint8_t nal_type  = nal_hdr & 0x1F;
    const uint8_t nal_nri   = nal_hdr & 0x60;

    const uint8_t fu_indicator = (nal_nri) | 28; // FU-A type = 28
    size_t offset = 1; // skip original NAL header
    bool first = true;

    while (offset < nal_len) {
        size_t chunk = std::min(nal_len - offset, max_payload - 2);
        bool   last  = (offset + chunk >= nal_len);

        uint8_t fu_header = nal_type;
        if (first) fu_header |= 0x80; // start bit
        if (last)  fu_header |= 0x40; // end bit

        std::vector<uint8_t> pkt(sizeof(RtpHeader) + 2 + chunk);
        auto *hdr      = reinterpret_cast<RtpHeader *>(pkt.data());
        hdr->vpxcc     = (RTP_VERSION << 6);
        hdr->mpt       = (last ? 0x80 : 0x00) | RTP_PAYLOAD_H264;
        hdr->seq       = htons(seq++);
        hdr->timestamp = htonl(ts);
        hdr->ssrc      = htonl(ssrc);

        pkt[sizeof(RtpHeader)]     = fu_indicator;
        pkt[sizeof(RtpHeader) + 1] = fu_header;
        std::memcpy(pkt.data() + sizeof(RtpHeader) + 2, nal + offset, chunk);

        sendto(sock, pkt.data(), pkt.size(), 0,
               reinterpret_cast<const sockaddr *>(&dst), sizeof(dst));

        offset += chunk;
        first   = false;
    }
}

/* ── Main ─────────────────────────────────────────────────────────────────── */

int main(int argc, char *argv[])
{
    const char *gateway_ip   = (argc > 1) ? argv[1] : "192.168.4.1";
    int         gateway_port = (argc > 2) ? std::atoi(argv[2]) : 5000;

    std::printf("Video Streamer (C++ / libcamera): target %s:%d\n",
                gateway_ip, gateway_port);

    /* ── UDP socket setup ── */
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        std::perror("socket");
        return 1;
    }

    sockaddr_in dst{};
    dst.sin_family      = AF_INET;
    dst.sin_port        = htons(static_cast<uint16_t>(gateway_port));
    inet_pton(AF_INET, gateway_ip, &dst.sin_addr);

    /* ── libcamera setup ── */
    auto &mgr = libcamera::CameraManager::instance();
    if (mgr.start()) {
        std::fprintf(stderr, "Failed to start CameraManager\n");
        close(sock);
        return 1;
    }

    auto cameras = mgr.cameras();
    if (cameras.empty()) {
        std::fprintf(stderr, "No cameras found\n");
        mgr.stop();
        close(sock);
        return 1;
    }

    auto camera = cameras[0];
    if (camera->acquire()) {
        std::fprintf(stderr, "Failed to acquire camera\n");
        mgr.stop();
        close(sock);
        return 1;
    }

    auto config = camera->generateConfiguration(
        {libcamera::StreamRole::VideoRecording});
    if (!config) {
        std::fprintf(stderr, "Failed to generate camera configuration\n");
        camera->release();
        mgr.stop();
        close(sock);
        return 1;
    }

    libcamera::StreamConfiguration &stream_cfg = config->at(0);
    stream_cfg.pixelFormat = libcamera::formats::H264;
    stream_cfg.size        = {640, 480};

    if (config->validate() == libcamera::CameraConfiguration::Invalid) {
        std::fprintf(stderr, "Camera configuration invalid\n");
        camera->release();
        mgr.stop();
        close(sock);
        return 1;
    }

    camera->configure(config.get());

    /* ── Frame callback (runs on libcamera's internal thread) ── */
    uint16_t rtp_seq  = 0;
    uint32_t rtp_ssrc = 0xDEADBEEF;
    std::atomic<bool> running{true};

    /* 90 kHz RTP clock for video */
    auto epoch = std::chrono::steady_clock::now();
    auto rtp_timestamp = [&]() -> uint32_t {
        auto now = std::chrono::steady_clock::now();
        auto us  = std::chrono::duration_cast<std::chrono::microseconds>(
                       now - epoch).count();
        return static_cast<uint32_t>((us * 90) / 1000); // 90 kHz
    };

    camera->requestCompleted.connect(
        [&](libcamera::Request *request) {
            if (!running) return;
            if (request->status() == libcamera::Request::RequestCancelled)
                return;

            for (auto &[stream, buf] : request->buffers()) {
                const libcamera::FrameMetadata &meta = buf->metadata();
                if (meta.status != libcamera::FrameMetadata::FrameSuccess)
                    continue;

                /* Map the DMA buffer and send each plane as RTP NAL units */
                auto mem = buf->planes();
                for (size_t i = 0; i < meta.planes().size(); ++i) {
                    const uint8_t *data = static_cast<const uint8_t *>(
                        mem[i].mem());
                    size_t len = meta.planes()[i].bytesused;
                    rtp_send(sock, dst, data, len,
                             rtp_seq, rtp_timestamp(), rtp_ssrc);
                }
            }

            /* Re-queue the request for continuous capture */
            request->reuse(libcamera::Request::ReuseBuffers);
            camera->queueRequest(request);
        });

    /* ── Allocate buffers and start capture ── */
    libcamera::FrameBufferAllocator allocator(camera);
    libcamera::Stream *stream = stream_cfg.stream();
    if (allocator.allocate(stream) < 0) {
        std::fprintf(stderr, "Failed to allocate frame buffers\n");
        camera->release();
        mgr.stop();
        close(sock);
        return 1;
    }

    std::vector<std::unique_ptr<libcamera::Request>> requests;
    for (auto &buf : allocator.buffers(stream)) {
        auto req = camera->createRequest();
        if (!req) {
            std::fprintf(stderr, "Failed to create request\n");
            continue;
        }
        req->addBuffer(stream, buf.get());
        requests.push_back(std::move(req));
    }

    camera->start();
    for (auto &req : requests)
        camera->queueRequest(req.get());

    std::printf("Streaming H.264 640×480 @ 30fps → %s:%d\n",
                gateway_ip, gateway_port);

    /* ── Run until interrupted ── */
    struct sigaction sa{};
    sa.sa_handler = [](int) { /* caught below via atomic */ };
    sigaction(SIGINT,  &sa, nullptr);
    sigaction(SIGTERM, &sa, nullptr);

    pause(); // sleep until a signal is received

    running = false;
    camera->stop();
    allocator.free(stream);
    camera->release();
    mgr.stop();
    close(sock);

    std::printf("Video streamer stopped\n");
    return 0;
}
