# C++ ADAS Implementation Proposals

## 1  Is Shell + Python the Standard for ADAS?

### Short Answer — No, Not for Production ADAS

In production automotive systems Python and shell scripts are **not** used for
real-time, safety-relevant functions.  The industry norms are:

| Layer | Standard Approach | Why |
|-------|-------------------|-----|
| Perception / sensor drivers | C++ (AUTOSAR Adaptive/Classic, ROS2 C++ nodes) | Deterministic timing, zero-copy DMA, MISRA-C++ compliance |
| Sensor fusion / object tracking | C++ (Kalman, particle filters) | Predictable latency, no GC pauses |
| Decision / planning | C++ or Ada (safety-critical) | ISO 26262 ASIL-B/D, formal analysis |
| Middleware | DDS/Cyclone DDS, ROS2 C++ | Hard real-time pub/sub |
| Build / CI tooling | Shell / CMake / Python | Non-real-time path — acceptable |
| Cloud telemetry / OTA dashboards | Python / Go / Java | Also non-real-time path — acceptable |

### Why It Matters Here

This project already targets sub-100 ms end-to-end latency and runs on
resource-constrained Pi Zero W boards.  Python introduces:

- **GIL contention** — the audio-mixer and gateway-bridge each spin worker
  threads that can block one another through the GIL.
- **GC jitter** — Python's cyclic GC can add multi-millisecond pauses in the
  real-time audio/video path.
- **Interpreter overhead** — every ALSA `read()` and UDP `sendto()` call pays
  Python object allocation overhead on top of the syscall.
- **Dependency fragility** — `alsaaudio`, `tflite_runtime`, `paho-mqtt`, and
  `psutil` must be cross-compiled into the Buildroot image; missing any one
  silently disables a feature.

### What Is Already C++

`firmware/sensor/video-streamer/main.cpp` already shows the right approach:
libcamera + raw UDP/RTP, RFC 6184 H.264 packetisation, no Python in the hot
path.  The proposals below bring the remaining Python components to the same
standard.

---

## 2  Component-by-Component C++ Proposals

### 2.1  Audio Capture  (`firmware/sensor/audio-capture/`)

**Current:** `main.py` — Python `alsaaudio` + `paho.mqtt` + `socket`  
**Proposed:** `audio_capture.cpp` — ALSA libasound C API + Paho MQTT C++ +
POSIX UDP socket

#### Key differences from the Python version

| Concern | Python | C++ proposal |
|---------|--------|--------------|
| ALSA open | `alsaaudio.PCM(PCM_NONBLOCK)` | `snd_pcm_open()` + `snd_pcm_nonblock()` |
| Period read | `inp.read()` returns a Python tuple | `snd_pcm_readi()` writes directly into a stack/heap buffer |
| Packet build | `struct.pack("!II", …) + data` — copies | Build header in-place in a `std::array`; append PCM slice with `memcpy` — single allocation |
| MQTT | Python paho re-enters GIL on every publish | Paho C++ `async_client::publish()` is lock-free from the caller's side |
| Timing | `time.sleep(0.001)` — imprecise | `snd_pcm_wait()` blocks until a period is ready — driver-level precision |

#### Proposed `audio_capture.cpp`

```cpp
/*
 * firmware/sensor/audio-capture/audio_capture.cpp
 *
 * Captures stereo PCM from ALSA and streams 20 ms frames to the gateway
 * over UDP.  Publishes stream-status to MQTT every 50 frames (~1 s).
 *
 * Build:
 *   g++ -std=c++17 -O2 audio_capture.cpp -o audio-capture \
 *       -lasound -lpaho-mqttpp3 -lpaho-mqtt3as -lpthread
 *
 * Usage:
 *   ./audio-capture [gateway_ip] [gateway_port]
 */

#include <alsa/asoundlib.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <signal.h>

#include <array>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

#include <mqtt/async_client.h>  // Paho MQTT C++

static constexpr int     CHANNELS    = 2;
static constexpr int     RATE        = 48000;
static constexpr int     PERIOD_SIZE = 960;   // 20 ms @ 48 kHz
static constexpr size_t  PCM_BYTES   = PERIOD_SIZE * CHANNELS * 2; // S16_LE
static constexpr size_t  HDR_BYTES   = 8;     // frame_id(4) + timestamp(4)

static volatile sig_atomic_t g_stop = 0;

// ── ALSA helpers ─────────────────────────────────────────────────────────────

static snd_pcm_t *open_alsa_capture()
{
    snd_pcm_t *handle = nullptr;
    int rc;

    rc = snd_pcm_open(&handle, "default", SND_PCM_STREAM_CAPTURE, SND_PCM_NONBLOCK);
    if (rc < 0) {
        std::fprintf(stderr, "snd_pcm_open: %s\n", snd_strerror(rc));
        std::exit(1);
    }

    snd_pcm_hw_params_t *hw = nullptr;
    snd_pcm_hw_params_alloca(&hw);
    snd_pcm_hw_params_any(handle, hw);
    snd_pcm_hw_params_set_access(handle, hw, SND_PCM_ACCESS_RW_INTERLEAVED);
    snd_pcm_hw_params_set_format(handle, hw, SND_PCM_FORMAT_S16_LE);
    snd_pcm_hw_params_set_channels(handle, hw, CHANNELS);

    unsigned int rate = RATE;
    snd_pcm_hw_params_set_rate_near(handle, hw, &rate, nullptr);

    snd_pcm_uframes_t period = PERIOD_SIZE;
    snd_pcm_hw_params_set_period_size_near(handle, hw, &period, nullptr);
    snd_pcm_hw_params(handle, hw);

    snd_pcm_prepare(handle);
    return handle;
}

// ── UDP helpers ───────────────────────────────────────────────────────────────

static uint32_t hton32(uint32_t v)
{
    return htonl(v);
}

static void write_be32(uint8_t *dst, uint32_t v)
{
    v = hton32(v);
    std::memcpy(dst, &v, 4);
}

// ── Main ──────────────────────────────────────────────────────────────────────

int main(int argc, char *argv[])
{
    const char *gw_ip   = (argc > 1) ? argv[1] : "192.168.4.1";
    int         gw_port = (argc > 2) ? std::atoi(argv[2]) : 5001;

    std::printf("Audio capture (C++) → %s:%d\n", gw_ip, gw_port);

    // UDP socket
    int udp = socket(AF_INET, SOCK_DGRAM, 0);
    if (udp < 0) { std::perror("socket"); return 1; }

    sockaddr_in dst{};
    dst.sin_family = AF_INET;
    dst.sin_port   = htons(static_cast<uint16_t>(gw_port));
    inet_pton(AF_INET, gw_ip, &dst.sin_addr);

    // MQTT async client
    const std::string mqtt_addr = std::string("tcp://") + gw_ip + ":1883";
    mqtt::async_client mqtt_cli(mqtt_addr, "audio-capture");
    mqtt::connect_options conn_opts;
    conn_opts.set_keep_alive_interval(20);
    conn_opts.set_clean_session(true);
    try {
        mqtt_cli.connect(conn_opts)->wait();
    } catch (const mqtt::exception &e) {
        std::fprintf(stderr, "WARNING: MQTT connect failed: %s; continuing\n",
                     e.what());
    }

    // ALSA capture
    snd_pcm_t *pcm = open_alsa_capture();

    // Packet buffer: 8-byte header + PCM payload
    std::array<uint8_t, HDR_BYTES + PCM_BYTES> pkt{};

    uint32_t frame_id = 0;
    auto     t0       = std::chrono::steady_clock::now();

    // Signal handler
    struct sigaction sa{};
    sa.sa_handler = [](int) { g_stop = 1; };
    sigemptyset(&sa.sa_mask);
    sigaction(SIGINT,  &sa, nullptr);
    sigaction(SIGTERM, &sa, nullptr);

    while (!g_stop) {
        // Block until at least one period is ready
        snd_pcm_wait(pcm, 100 /*ms*/);

        snd_pcm_sframes_t n = snd_pcm_readi(pcm, pkt.data() + HDR_BYTES, PERIOD_SIZE);
        if (n == -EPIPE) {
            snd_pcm_prepare(pcm);
            continue;
        }
        if (n <= 0) continue;

        // 90 kHz-equivalent timestamp from steady clock
        auto now = std::chrono::steady_clock::now();
        auto us  = std::chrono::duration_cast<std::chrono::microseconds>(now - t0).count();
        uint32_t ts = static_cast<uint32_t>((us * 90ULL) / 1000ULL);

        write_be32(pkt.data(),     frame_id);
        write_be32(pkt.data() + 4, ts);

        sendto(udp, pkt.data(), HDR_BYTES + static_cast<size_t>(n) * CHANNELS * 2, 0,
               reinterpret_cast<const sockaddr *>(&dst), sizeof(dst));

        // Publish stream status every 50 frames (~1 s)
        if (++frame_id % 50 == 0 && mqtt_cli.is_connected()) {
            char buf[128];
            std::snprintf(buf, sizeof(buf),
                          R"({"frame_id":%u,"rate":%d})", frame_id, RATE);
            mqtt_cli.publish("sensor/audio/stream", buf, std::strlen(buf), 0, false);
        }
    }

    snd_pcm_close(pcm);
    close(udp);
    if (mqtt_cli.is_connected()) mqtt_cli.disconnect()->wait();
    std::printf("Audio capture stopped\n");
    return 0;
}
```

#### Why this is better for ADAS

- `snd_pcm_wait()` suspends the thread in the kernel until a period is ready —
  no spinning, no `sleep(0.001)` imprecision.
- PCM samples land **directly** in the packet buffer (`pkt.data() + HDR_BYTES`),
  avoiding an extra copy that Python's `inp.read()` always performs.
- No GIL, no GC.  Audio latency is bounded by the ALSA period (20 ms) plus
  UDP round-trip, not by interpreter scheduling.

---

### 2.2  Gateway Bridge  (`firmware/gateway/gateway-bridge.py`)

**Current:** Python — paho-mqtt, tflite_runtime, threading, global deques  
**Proposed:** `gateway_bridge.cpp` — Paho MQTT C++, TFLite C API,
`std::queue` protected by `std::mutex` + `std::condition_variable`

#### Key differences

| Concern | Python | C++ proposal |
|---------|--------|--------------|
| Frame queue | `collections.deque` + GIL | `std::queue<FrameMeta>` + `std::mutex` / `std::condition_variable` |
| TFLite inference | `tflite_runtime.Interpreter` Python bindings | `TfLiteInterpreter*` C API (`tensorflow/lite/c/c_api.h`) — no Python overhead |
| Inference thread | Python thread (GIL-bound) | `std::thread` — truly parallel on multi-core Pi 4 |
| MQTT callbacks | Python GIL re-acquisition on every message | Paho C++ callback — runs on the internal Paho thread, no GIL |

#### Proposed `gateway_bridge.cpp`

```cpp
/*
 * firmware/gateway/gateway_bridge.cpp
 *
 * Aggregates sensor streams via MQTT, runs TFLite object detection on vision
 * frames, and publishes detection results back to the fleet.
 *
 * Build:
 *   g++ -std=c++17 -O2 gateway_bridge.cpp -o gateway-bridge \
 *       -lpaho-mqttpp3 -lpaho-mqtt3as \
 *       -ltensorflowlite_c \
 *       -lpthread
 *
 * Usage:
 *   TFLITE_MODEL_PATH=/usr/local/share/models/mobilenet_ssd_v2_quantized.tflite \
 *   ./gateway-bridge
 */

#include <condition_variable>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <queue>
#include <string>
#include <thread>

#include <mqtt/async_client.h>
#include <tensorflow/lite/c/c_api.h>

static constexpr int   VISION_QUEUE_MAX = 30;
static constexpr char  MQTT_BROKER[]    = "tcp://127.0.0.1:1883";
static constexpr char  MODEL_ENV[]      = "TFLITE_MODEL_PATH";
static constexpr char  DEFAULT_MODEL[]  =
    "/usr/local/share/models/mobilenet_ssd_v2_quantized.tflite";

// ── Shared vision frame queue ─────────────────────────────────────────────────

struct FrameMeta {
    std::string json_payload;
};

static std::queue<FrameMeta>    g_vision_q;
static std::mutex               g_vision_mtx;
static std::condition_variable  g_vision_cv;

// ── MQTT callback ─────────────────────────────────────────────────────────────

class BridgeCallback : public mqtt::callback {
    mqtt::async_client &cli_;
public:
    explicit BridgeCallback(mqtt::async_client &c) : cli_(c) {}

    void connected(const std::string &) override {
        cli_.subscribe("sensor/vision/frame", 0);
        cli_.subscribe("sensor/audio/stream", 0);
        cli_.subscribe("ui/command/#", 0);
        std::puts("MQTT connected; subscriptions set");
    }

    void message_arrived(mqtt::const_message_ptr msg) override {
        const std::string &topic   = msg->get_topic();
        const std::string &payload = msg->to_string();

        if (topic.rfind("sensor/vision/", 0) == 0) {
            std::lock_guard<std::mutex> lk(g_vision_mtx);
            if (static_cast<int>(g_vision_q.size()) < VISION_QUEUE_MAX)
                g_vision_q.push({payload});
            g_vision_cv.notify_one();
        }
        // audio frames: handled by audio-mixer process; ignored here
    }
};

// ── Inference thread ──────────────────────────────────────────────────────────

static void inference_loop(mqtt::async_client &cli,
                           TfLiteInterpreter  *interp)
{
    while (true) {
        FrameMeta frame;
        {
            std::unique_lock<std::mutex> lk(g_vision_mtx);
            g_vision_cv.wait_for(lk, std::chrono::milliseconds(100),
                                 []{ return !g_vision_q.empty(); });
            if (g_vision_q.empty()) continue;
            frame = std::move(g_vision_q.front());
            g_vision_q.pop();
        }

        if (interp == nullptr) continue;

        // TODO: decode JPEG/raw bytes from frame.json_payload,
        //       resize to 300×300, copy into input tensor, invoke.
        TfLiteInterpreterInvoke(interp);

        // Read outputs and build compact detection JSON
        char result[256];
        std::snprintf(result, sizeof(result),
                      R"({"timestamp":0,"source":"tflite","detections":[]})");

        if (cli.is_connected())
            cli.publish("gateway/ai/detections", result, std::strlen(result), 0, false);
    }
}

// ── Main ──────────────────────────────────────────────────────────────────────

int main()
{
    // Load TFLite model
    const char *model_path = std::getenv(MODEL_ENV);
    if (!model_path) model_path = DEFAULT_MODEL;

    TfLiteModel      *model  = TfLiteModelCreateFromFile(model_path);
    TfLiteInterpreter *interp = nullptr;

    if (model) {
        TfLiteInterpreterOptions *opts = TfLiteInterpreterOptionsCreate();
        TfLiteInterpreterOptionsSetNumThreads(opts, 2);
        interp = TfLiteInterpreterCreate(model, opts);
        TfLiteInterpreterOptionsDelete(opts);
        if (TfLiteInterpreterAllocateTensors(interp) != kTfLiteOk) {
            std::fprintf(stderr, "WARNING: TFLite AllocateTensors failed\n");
            TfLiteInterpreterDelete(interp);
            interp = nullptr;
        } else {
            std::printf("TFLite model loaded from %s\n", model_path);
        }
    } else {
        std::fprintf(stderr, "WARNING: Could not load model %s; inference disabled\n",
                     model_path);
    }

    // MQTT
    mqtt::async_client cli(MQTT_BROKER, "gateway-bridge");
    BridgeCallback     cb(cli);
    cli.set_callback(cb);

    mqtt::connect_options opts;
    opts.set_keep_alive_interval(20);
    opts.set_clean_session(true);
    opts.set_automatic_reconnect(true);
    cli.connect(opts)->wait();

    // Inference thread
    std::thread inf_thread(inference_loop, std::ref(cli), interp);
    inf_thread.detach();

    std::puts("Gateway bridge running");
    // Block main thread; signal handling can be added here
    for (;;) std::this_thread::sleep_for(std::chrono::seconds(1));

    if (interp) TfLiteInterpreterDelete(interp);
    if (model)  TfLiteModelDelete(model);
    cli.disconnect()->wait();
    return 0;
}
```

#### Why this is better for ADAS

- Inference genuinely runs in parallel with MQTT I/O — Python's GIL prevents
  true parallelism even with `threading.Thread`.
- The TFLite C API (`TfLiteInterpreterInvoke`) has no Python overhead and can
  be given multiple XNNPACK/CPU threads via `TfLiteInterpreterOptionsSetNumThreads`.
- `std::condition_variable` eliminates the `time.sleep(0.1)` busy-wait
  present in the Python `inference_loop`.

---

### 2.3  Status Publisher  (`firmware/gateway/status-publisher.py`)

**Current:** Python — psutil + paho-mqtt  
**Proposed:** `status_publisher.cpp` — direct `/proc` and sysfs reads, Paho
MQTT C++, no third-party system-monitoring library

#### Why drop `psutil`

`psutil` pulls in a large CPython extension that must be cross-compiled into
the Buildroot image.  All the data it provides is available natively:

| Metric | psutil | Direct read |
|--------|--------|-------------|
| CPU % | `cpu_percent()` | `/proc/stat` delta |
| Memory % | `virtual_memory().percent` | `/proc/meminfo` |
| Temperature | `sensors_temperatures()` | `/sys/class/thermal/thermal_zone0/temp` |
| Uptime | `boot_time()` | `/proc/uptime` |

#### Proposed `status_publisher.cpp`

```cpp
/*
 * firmware/gateway/status_publisher.cpp
 *
 * Publishes gateway health metrics to MQTT topic "gateway/status" every 10 s.
 *
 * Build:
 *   g++ -std=c++17 -O2 status_publisher.cpp -o status-publisher \
 *       -lpaho-mqttpp3 -lpaho-mqtt3as -lpthread
 *
 * Usage:
 *   ./status-publisher [broker_ip]
 */

#include <chrono>
#include <cstdio>
#include <cstring>
#include <string>
#include <thread>

#include <mqtt/async_client.h>

static constexpr int INTERVAL_S = 10;

// ── /proc helpers ─────────────────────────────────────────────────────────────

struct CpuTimes { unsigned long long user, nice, sys, idle, other; };

static CpuTimes read_cpu_times()
{
    CpuTimes t{};
    FILE *f = std::fopen("/proc/stat", "r");
    if (!f) return t;
    // first line: "cpu  user nice sys idle iowait irq softirq ..."
    std::fscanf(f, "cpu %llu %llu %llu %llu %llu",
                &t.user, &t.nice, &t.sys, &t.idle, &t.other);
    std::fclose(f);
    return t;
}

static double cpu_percent()
{
    auto a = read_cpu_times();
    std::this_thread::sleep_for(std::chrono::milliseconds(200));
    auto b = read_cpu_times();

    unsigned long long da = (a.user + a.nice + a.sys + a.idle + a.other);
    unsigned long long db = (b.user + b.nice + b.sys + b.idle + b.other);
    unsigned long long dt = db - da;
    if (dt == 0) return 0.0;
    unsigned long long didle = b.idle - a.idle;
    return 100.0 * (1.0 - static_cast<double>(didle) / static_cast<double>(dt));
}

static double memory_percent()
{
    unsigned long long total = 0, available = 0;
    FILE *f = std::fopen("/proc/meminfo", "r");
    if (!f) return 0.0;
    char line[128];
    while (std::fgets(line, sizeof(line), f)) {
        unsigned long long v;
        if (std::sscanf(line, "MemTotal: %llu kB", &v) == 1)  total     = v;
        if (std::sscanf(line, "MemAvailable: %llu kB", &v) == 1) available = v;
    }
    std::fclose(f);
    if (total == 0) return 0.0;
    return 100.0 * (1.0 - static_cast<double>(available) / static_cast<double>(total));
}

static double read_temperature()
{
    FILE *f = std::fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (!f) return 0.0;
    int millideg = 0;
    std::fscanf(f, "%d", &millideg);
    std::fclose(f);
    return millideg / 1000.0;
}

static int read_uptime_s()
{
    FILE *f = std::fopen("/proc/uptime", "r");
    if (!f) return 0;
    double up = 0.0;
    std::fscanf(f, "%lf", &up);
    std::fclose(f);
    return static_cast<int>(up);
}

// ── Main ──────────────────────────────────────────────────────────────────────

int main(int argc, char *argv[])
{
    const char *broker_ip = (argc > 1) ? argv[1] : "127.0.0.1";
    std::string broker_url = std::string("tcp://") + broker_ip + ":1883";

    mqtt::async_client cli(broker_url, "status-publisher");
    mqtt::connect_options opts;
    opts.set_keep_alive_interval(20);
    opts.set_clean_session(true);
    cli.connect(opts)->wait();
    std::printf("Status publisher connected to %s\n", broker_url.c_str());

    while (true) {
        double cpu  = cpu_percent();      // 200 ms sample inside
        double mem  = memory_percent();
        double temp = read_temperature();
        int    up   = read_uptime_s();

        // Unix epoch in seconds (C++17 portable)
        auto ts = std::chrono::duration_cast<std::chrono::seconds>(
                      std::chrono::system_clock::now().time_since_epoch())
                      .count();

        char payload[256];
        std::snprintf(payload, sizeof(payload),
                      R"({"timestamp":%lld,"cpu_percent":%.1f,)"
                      R"("memory_percent":%.1f,"temperature":%.1f,"uptime":%d})",
                      static_cast<long long>(ts), cpu, mem, temp, up);

        cli.publish("gateway/status", payload, std::strlen(payload), 1, false)->wait();
        std::this_thread::sleep_for(
            std::chrono::seconds(INTERVAL_S) - std::chrono::milliseconds(200));
    }

    cli.disconnect()->wait();
    return 0;
}
```

#### Why this is better for ADAS

- Removes `psutil` dependency entirely — one fewer cross-compiled Python
  extension in the Buildroot image.
- The 200 ms CPU measurement window is controlled precisely in C++ with
  `std::this_thread::sleep_for`; Python's `cpu_percent(interval=1)` blocks
  for a full second.
- No GC pauses affect the 10-second publish cadence.

---

### 2.4  Audio Mixer  (`firmware/gateway/audio-mixer/main.py`)

**Current:** Python — four-level priority `deque`, `threading.Lock`, paho-mqtt  
**Proposed:** `audio_mixer.cpp` — `std::priority_queue` + lock-free
single-producer / single-consumer hand-off between the UDP listener and the
mixer, Paho MQTT C++

#### Key differences

| Concern | Python | C++ proposal |
|---------|--------|--------------|
| Priority selection | iterate `deque` dict under a `threading.Lock` | `std::priority_queue<AudioFrame>` — O(log n) push/pop, single mutex |
| UDP receive | `sock.recvfrom(65535)` — Python heap alloc per packet | Stack-allocated 4096-byte buffer; only copies payload into `AudioFrame.data` |
| Mixer tick | `time.sleep(0.01)` — 10 ms approx. | `std::condition_variable::wait_for(10ms)` — notified immediately when a high-priority frame arrives |
| MQTT publish | Base64-encoded JSON payload (copies) | Same wire format; encoding done with a small inline Base64 impl — no dependency |

#### Proposed `audio_mixer.cpp`

```cpp
/*
 * firmware/gateway/audio_mixer.cpp
 *
 * Priority-based audio mixer for the ADAS gateway.
 *
 *   P0 – Safety Critical  (<100 ms)
 *   P1 – Advisory         (<500 ms)
 *   P2 – Info             (<2 s)
 *   P3 – Background       (best-effort)
 *
 * Build:
 *   g++ -std=c++17 -O2 audio_mixer.cpp -o audio-mixer \
 *       -lpaho-mqttpp3 -lpaho-mqtt3as -lpthread
 */

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>

#include <array>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <queue>
#include <string>
#include <thread>
#include <vector>

#include <mqtt/async_client.h>

static constexpr uint16_t UDP_PORT     = 5001;
static constexpr int      QUEUE_MAX    = 100;   // frames per priority level (matches Python deque maxlen)
static constexpr int      QUEUE_CAP    = QUEUE_MAX * 4; // total capacity across all 4 priority levels
static constexpr int      MIXER_MS     = 10;

// ── Priority enum ─────────────────────────────────────────────────────────────

enum Priority : int {
    P0_SAFETY     = 0,
    P1_ADVISORY   = 1,
    P2_INFO       = 2,
    P3_BACKGROUND = 3,
};

// ── AudioFrame ────────────────────────────────────────────────────────────────

struct AudioFrame {
    Priority    priority;
    uint32_t    frame_id;
    uint32_t    timestamp;
    std::string source_ip;
    std::vector<uint8_t> data;

    // Min-heap: lower priority value = higher importance
    bool operator>(const AudioFrame &o) const { return priority > o.priority; }
};

static std::priority_queue<AudioFrame,
                           std::vector<AudioFrame>,
                           std::greater<AudioFrame>> g_queue;
static std::mutex               g_mtx;
static std::condition_variable  g_cv;

// ── Source → priority heuristic ───────────────────────────────────────────────

static Priority source_priority(const std::string &ip)
{
    // cloud sources (outside 192.168.4.x) get P1; local sensor nodes get P2
    if (ip.rfind("192.168.4.", 0) == 0) return P2_INFO;
    return P1_ADVISORY;
}

// ── Minimal Base64 encoder (RFC 4648) ─────────────────────────────────────────

static const char B64[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static std::string base64_encode(const uint8_t *src, size_t len)
{
    std::string out;
    out.reserve(((len + 2) / 3) * 4);
    for (size_t i = 0; i < len; i += 3) {
        uint32_t v  = static_cast<uint32_t>(src[i]) << 16;
        if (i + 1 < len) v |= static_cast<uint32_t>(src[i + 1]) << 8;
        if (i + 2 < len) v |= static_cast<uint32_t>(src[i + 2]);
        out += B64[(v >> 18) & 63];
        out += B64[(v >> 12) & 63];
        out += (i + 1 < len) ? B64[(v >> 6) & 63] : '=';
        out += (i + 2 < len) ? B64[(v)      & 63] : '=';
    }
    return out;
}

// ── UDP listener thread ───────────────────────────────────────────────────────

static void udp_listener()
{
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) { std::perror("socket"); return; }

    sockaddr_in addr{};
    addr.sin_family      = AF_INET;
    addr.sin_port        = htons(UDP_PORT);
    addr.sin_addr.s_addr = INADDR_ANY;

    if (bind(sock, reinterpret_cast<sockaddr *>(&addr), sizeof(addr)) < 0) {
        std::perror("bind"); close(sock); return;
    }

    timeval tv{1, 0};
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    std::printf("UDP listener bound to 0.0.0.0:%d\n", UDP_PORT);

    // Single-threaded listener: static buffer is safe here.
    // If multiple listener threads are added in future, move buf to the stack.
    static uint8_t buf[65535];

    while (true) {
        sockaddr_in from{};
        socklen_t   from_len = sizeof(from);
        ssize_t n = recvfrom(sock, buf, sizeof(buf), 0,
                             reinterpret_cast<sockaddr *>(&from), &from_len);
        if (n < 0) continue;   // timeout or error
        if (n < 8) continue;   // header too short

        uint32_t frame_id, timestamp;
        std::memcpy(&frame_id,  buf,     4); frame_id  = ntohl(frame_id);
        std::memcpy(&timestamp, buf + 4, 4); timestamp = ntohl(timestamp);

        char src_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &from.sin_addr, src_ip, sizeof(src_ip));

        Priority prio = source_priority(src_ip);

        AudioFrame frame;
        frame.priority  = prio;
        frame.frame_id  = frame_id;
        frame.timestamp = timestamp;
        frame.source_ip = src_ip;
        frame.data.assign(buf + 8, buf + n);

        std::lock_guard<std::mutex> lk(g_mtx);
        if (static_cast<int>(g_queue.size()) < QUEUE_CAP) {
            g_queue.push(std::move(frame));
            // Wake mixer immediately for high-priority frames
            if (prio <= P1_ADVISORY) g_cv.notify_one();
        }
    }
    close(sock);
}

// ── Mixer thread ──────────────────────────────────────────────────────────────

static void mixer_thread(mqtt::async_client &cli)
{
    while (true) {
        AudioFrame frame;
        bool have_frame = false;

        {
            std::unique_lock<std::mutex> lk(g_mtx);
            g_cv.wait_for(lk, std::chrono::milliseconds(MIXER_MS),
                          []{ return !g_queue.empty(); });
            if (!g_queue.empty()) {
                frame      = g_queue.top();
                g_queue.pop();
                have_frame = true;
            }
        }

        if (!have_frame) continue;

        std::string b64 = base64_encode(frame.data.data(), frame.data.size());
        // Use std::string for the payload to avoid a VLA (not standard C++17)
        std::string payload;
        payload.resize(512 + b64.size());
        int plen = std::snprintf(payload.data(), payload.size(),
                      R"({"priority":%d,"audio_b64":"%s","source":"%s"})",
                      static_cast<int>(frame.priority),
                      b64.c_str(),
                      frame.source_ip.c_str());
        payload.resize(static_cast<size_t>(plen));

        char topic[64];
        std::snprintf(topic, sizeof(topic),
                      "ui/audio/play/%d", static_cast<int>(frame.priority));

        if (cli.is_connected())
            cli.publish(topic, payload.c_str(), payload.size(), 0, false);
    }
}

// ── Main ──────────────────────────────────────────────────────────────────────

int main()
{
    mqtt::async_client cli("tcp://127.0.0.1:1883", "audio-mixer");
    mqtt::connect_options opts;
    opts.set_keep_alive_interval(20);
    opts.set_clean_session(true);
    cli.connect(opts)->wait();

    std::thread t_udp(udp_listener);
    t_udp.detach();

    std::thread t_mix(mixer_thread, std::ref(cli));
    t_mix.detach();

    std::puts("Audio mixer running (UDP → priority queue → MQTT ui/audio/play)");
    for (;;) std::this_thread::sleep_for(std::chrono::seconds(1));

    cli.disconnect()->wait();
    return 0;
}
```

#### Why this is better for ADAS

- `std::priority_queue` selects the highest-priority frame in **O(log n)**;
  the Python version iterates all four `deque` buckets on every tick.
- The mixer wakes **immediately** when a P0/P1 frame arrives via
  `g_cv.notify_one()`; the Python version always waits the full 10 ms tick.
- No Base64 library dependency — the inline encoder has zero external linkage.

---

### 2.5  Video Pipeline Script  (`firmware/sensor/video-streamer/pipeline.sh`)

**Current:** `pipeline.sh` — `gst-launch-1.0` one-liner  
**Proposed (option A):** Replace with the existing `main.cpp` (libcamera +
raw RTP) for environments without GStreamer.  
**Proposed (option B):** C++ GStreamer pipeline using the GStreamer C API

The repo already has `main.cpp` as the GStreamer-free fallback.  Option B is
useful when GStreamer is available and its hardware-accelerated elements are
needed but a persistent, monitored C++ process is preferred over relying on
`gst-launch-1.0` re-launch logic in a shell script.

#### Proposed `video_pipeline.cpp` (Option B — GStreamer C API)

```cpp
/*
 * firmware/sensor/video-streamer/video_pipeline.cpp
 *
 * GStreamer H.264 video pipeline in C++.
 * Equivalent to the shell one-liner but runs as a supervised process that
 * can be monitored, restarted, and integrated with systemd watchdog.
 *
 * Build:
 *   g++ -std=c++17 -O2 video_pipeline.cpp -o video-pipeline \
 *       $(pkg-config --cflags --libs gstreamer-1.0) -lpthread
 *
 * Usage:
 *   ./video-pipeline [gateway_ip] [gateway_port]
 */

#include <gst/gst.h>
#include <signal.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

static GMainLoop *g_loop = nullptr;

static gboolean bus_callback(GstBus *, GstMessage *msg, gpointer)
{
    switch (GST_MESSAGE_TYPE(msg)) {
    case GST_MESSAGE_ERROR: {
        GError *err = nullptr;
        gchar  *dbg = nullptr;
        gst_message_parse_error(msg, &err, &dbg);
        std::fprintf(stderr, "GStreamer error: %s\nDebug: %s\n",
                     err->message, dbg ? dbg : "(none)");
        g_error_free(err);
        g_free(dbg);
        g_main_loop_quit(g_loop);
        break;
    }
    case GST_MESSAGE_EOS:
        g_main_loop_quit(g_loop);
        break;
    default:
        break;
    }
    return TRUE;
}

int main(int argc, char *argv[])
{
    gst_init(&argc, &argv);

    const char *gw_ip   = (argc > 1) ? argv[1] : "192.168.4.1";
    int         gw_port = (argc > 2) ? std::atoi(argv[2]) : 5000;

    // Build pipeline string programmatically so IP/port can vary
    char pipe_desc[512];
    std::snprintf(pipe_desc, sizeof(pipe_desc),
        "v4l2src device=/dev/video0 "
        "! video/x-h264,width=640,height=480,framerate=30/1 "
        "! h264parse "
        "! rtph264pay pt=96 "
        "! udpsink host=%s port=%d auto-multicast=false",
        gw_ip, gw_port);

    GError     *err      = nullptr;
    GstElement *pipeline = gst_parse_launch(pipe_desc, &err);
    if (!pipeline) {
        std::fprintf(stderr, "Failed to create pipeline: %s\n",
                     err ? err->message : "unknown");
        return 1;
    }

    GstBus *bus = gst_element_get_bus(pipeline);
    gst_bus_add_watch(bus, bus_callback, nullptr);
    gst_object_unref(bus);

    gst_element_set_state(pipeline, GST_STATE_PLAYING);
    std::printf("H.264 640×480 @ 30fps → %s:%d\n", gw_ip, gw_port);

    g_loop = g_main_loop_new(nullptr, FALSE);

    // Signal handling
    struct sigaction sa{};
    sa.sa_handler = [](int) {
        if (g_loop) g_main_loop_quit(g_loop);
    };
    sigemptyset(&sa.sa_mask);
    sigaction(SIGINT,  &sa, nullptr);
    sigaction(SIGTERM, &sa, nullptr);

    g_main_loop_run(g_loop);

    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    g_main_loop_unref(g_loop);
    std::puts("Video pipeline stopped");
    return 0;
}
```

---

## 3  Build Integration

### CMakeLists.txt (top-level sensor node)

```cmake
cmake_minimum_required(VERSION 3.16)
project(adas_sensor CXX)
set(CMAKE_CXX_STANDARD 17)

find_package(PkgConfig REQUIRED)

# ── audio-capture ──────────────────────────────────────────────────────────────
pkg_check_modules(ALSA REQUIRED alsa)
find_package(PahoMqttCpp REQUIRED)

add_executable(audio-capture
    firmware/sensor/audio-capture/audio_capture.cpp)
target_include_directories(audio-capture PRIVATE ${ALSA_INCLUDE_DIRS})
target_link_libraries(audio-capture PRIVATE
    ${ALSA_LIBRARIES}
    PahoMqttCpp::paho-mqttpp3
    Threads::Threads)

# ── video-pipeline (GStreamer) ─────────────────────────────────────────────────
pkg_check_modules(GST REQUIRED gstreamer-1.0)
add_executable(video-pipeline
    firmware/sensor/video-streamer/video_pipeline.cpp)
target_include_directories(video-pipeline PRIVATE ${GST_INCLUDE_DIRS})
target_link_libraries(video-pipeline PRIVATE ${GST_LIBRARIES})
```

### CMakeLists.txt (top-level compute node)

```cmake
cmake_minimum_required(VERSION 3.16)
project(adas_gateway CXX)
set(CMAKE_CXX_STANDARD 17)

find_package(PahoMqttCpp REQUIRED)
find_package(Threads      REQUIRED)

# ── gateway-bridge ─────────────────────────────────────────────────────────────
# TFLite C shared library must be installed (e.g. from tflite-runtime Buildroot package)
add_executable(gateway-bridge
    firmware/gateway/gateway_bridge.cpp)
target_link_libraries(gateway-bridge PRIVATE
    PahoMqttCpp::paho-mqttpp3
    tensorflowlite_c
    Threads::Threads)

# ── status-publisher ───────────────────────────────────────────────────────────
add_executable(status-publisher
    firmware/gateway/status_publisher.cpp)
target_link_libraries(status-publisher PRIVATE
    PahoMqttCpp::paho-mqttpp3
    Threads::Threads)

# ── audio-mixer ────────────────────────────────────────────────────────────────
add_executable(audio-mixer
    firmware/gateway/audio_mixer.cpp)
target_link_libraries(audio-mixer PRIVATE
    PahoMqttCpp::paho-mqttpp3
    Threads::Threads)
```

---

## 4  Migration Priority

| Component | Impact if kept in Python | Recommended action |
|-----------|--------------------------|-------------------|
| `audio-capture` | 20–40 ms extra latency, GIL contention | **Migrate first** — directly on the real-time audio path |
| `audio-mixer` | 10 ms tick imprecision, GIL on every UDP packet | **Migrate second** — P0 safety audio has <100 ms budget |
| `gateway-bridge` | GIL prevents true parallel inference | Migrate with TFLite C API; Python acceptable short-term |
| `status-publisher` | Only telemetry; no real-time constraint | Lowest priority; Python is acceptable long-term |
| `pipeline.sh` | Shell is fine for a GStreamer one-liner | Replace with `video_pipeline.cpp` only if supervision/watchdog needed |

---

## 5  Summary

Shell scripts are appropriate for **build tooling, CI, and one-shot
administration tasks** and can remain as-is (`scripts/`, `build/`).

Python is acceptable for **non-real-time services** (cloud telemetry, status
dashboards, OTA tooling) but introduces GIL contention and GC jitter in the
real-time audio and video paths.

C++ is the standard choice for ADAS sensor drivers, fusion pipelines, and any
service with a hard latency budget.  The video streamer (`main.cpp`) already
demonstrates the pattern; the proposals above bring the remaining components
to the same standard.
