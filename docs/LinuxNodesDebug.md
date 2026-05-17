# Linux Kernel, Middleware & Apps Debug Cheatsheet for AV Compute Nodes

## Table of Contents

- [Linux Kernel, Middleware \& Apps Debug Cheatsheet for AV Compute Nodes](#linux-kernel-middleware--apps-debug-cheatsheet-for-av-compute-nodes)
  - [Table of Contents](#table-of-contents)
  - [1. Kernel Debugging \& System Analysis](#1-kernel-debugging--system-analysis)
    - [Kernel Logging \& Messages](#kernel-logging--messages)
    - [Kernel Tracing \& Profiling](#kernel-tracing--profiling)
    - [Process \& Thread Analysis](#process--thread-analysis)
    - [Memory Debugging](#memory-debugging)
    - [CPU \& Scheduler Analysis](#cpu--scheduler-analysis)
  - [2. I/O \& Storage Debugging](#2-io--storage-debugging)
    - [Disk I/O Analysis](#disk-io-analysis)
    - [Disk Performance](#disk-performance)
  - [3. Network Debugging](#3-network-debugging)
    - [Network Monitoring](#network-monitoring)
    - [Connection \& Socket Analysis](#connection--socket-analysis)
    - [Network Performance](#network-performance)
  - [4. Middleware Debugging (ROS/AUTOSAR)](#4-middleware-debugging-rosautosar)
    - [ROS (Robot Operating System)](#ros-robot-operating-system)
    - [Message Queue \& Communication](#message-queue--communication)
    - [Service \& RPC Debugging](#service--rpc-debugging)
  - [5. Application Debugging](#5-application-debugging)
    - [GDB - GNU Debugger](#gdb---gnu-debugger)
    - [Core Dumps](#core-dumps)
    - [Runtime Analysis](#runtime-analysis)
    - [Profiling](#profiling)
  - [6. Real-Time System Debugging](#6-real-time-system-debugging)
    - [Real-Time Priority \& Latency](#real-time-priority--latency)
    - [CPU Isolation \& Irq Affinity](#cpu-isolation--irq-affinity)
  - [7. System Calls \& Kernel Tracing](#7-system-calls--kernel-tracing)
    - [Syscall Tracing](#syscall-tracing)
    - [Context Switches](#context-switches)
  - [8. Common Debug Commands Cheatsheet](#8-common-debug-commands-cheatsheet)
    - [Monitoring \& Top-like Tools](#monitoring--top-like-tools)
    - [Finding Bottlenecks](#finding-bottlenecks)
    - [Files \& Directories](#files--directories)
    - [Boot \& Crash Analysis](#boot--crash-analysis)
  - [9. AV-Specific Debug Scenarios](#9-av-specific-debug-scenarios)
    - [Timing \& Deadline Monitoring](#timing--deadline-monitoring)
    - [Camera/Sensor Data Pipeline](#camerasensor-data-pipeline)
    - [CAN/Vehicle Network Bus](#canvehicle-network-bus)
  - [10. Quick Reference: Essential Tools Installation](#10-quick-reference-essential-tools-installation)
  - [11. Debug Workflow Examples](#11-debug-workflow-examples)
    - [Issue: High Latency Spikes](#issue-high-latency-spikes)
    - [Issue: Memory Leak](#issue-memory-leak)
    - [Issue: Thread Deadlock](#issue-thread-deadlock)
  - [Notes](#notes)

---

## 1. Kernel Debugging & System Analysis

### Kernel Logging & Messages
```bash
# View kernel logs
dmesg                                    # Display kernel ring buffer
dmesg -T                                 # Show timestamps in readable format
dmesg | tail -50                         # Last 50 kernel messages
journalctl -k                            # View kernel messages via journald
journalctl -k -f                         # Follow kernel messages in real-time
journalctl -k --since "30 min ago"       # Kernel logs from last 30 minutes

# Monitor kernel logs live
tail -f /var/log/kern.log                # Watch kernel log file continuously
```

### Kernel Tracing & Profiling
```bash
# Trace system calls
strace -p <PID>                          # Trace system calls of running process
strace -c command                        # Count and profile system calls
strace -e openat,read,write ./app        # Trace specific syscalls
strace -f command                        # Trace child processes

# Performance tracing (perf)
perf record -p <PID>                     # Record CPU performance events
perf report                              # View recorded performance data
perf stat command                        # Show performance statistics
perf list                                # List available tracing events
perf trace -p <PID>                      # Trace all syscalls (replaces strace)

# eBPF tracing (modern approach)
bpftrace -l                              # List available probes
bpftrace -e 'kprobe:sys_openat { printf("%s\n", comm); }'  # Trace kernel function
```

### Process & Thread Analysis
```bash
# Process information
ps aux                                   # List all processes
ps -eLf                                  # Show threads with NLWP (number of threads)
ps -p <PID> -L                           # List threads of specific process
pstree -p <PID>                          # Show process tree with PIDs

# Task statistics
cat /proc/<PID>/stat                     # Detailed process statistics
cat /proc/<PID>/status                   # Human-readable process info
cat /proc/<PID>/maps                     # Memory mapping of process
cat /proc/<PID>/cmdline                  # Command line of process

# Real-time process priority
ps -eo pid,cls,pri,rtprio,comm           # Show scheduling class & priority
chrt -p <PID>                            # Get scheduling parameters
chrt -p -f 99 <PID>                      # Set FIFO realtime priority
```

### Memory Debugging
```bash
# Memory usage
free -h                                  # Memory summary with human-readable output
cat /proc/meminfo                        # Detailed memory statistics
top -p <PID>                             # Monitor specific process memory
ps -eo pid,vsz,rss,comm                  # Virtual & resident memory per process

# Memory leaks & corruption
valgrind --leak-check=full ./app         # Full memory leak detection
valgrind --tool=memcheck ./app           # Check for memory errors
valgrind --tool=helgrind ./app           # Detect race conditions

# Page faults & swapping
watch -n 1 "cat /proc/<PID>/stat | awk '{print \"Major faults:\"$10,\"Minor faults:\"$11}'"
```

### CPU & Scheduler Analysis
```bash
# CPU affinity & binding
taskset -p <PID>                         # Show CPU affinity of process
taskset -cp 0,1,2 <PID>                  # Bind process to CPUs 0,1,2
taskset -c 0 command                     # Run command on CPU 0

# Scheduling information
cat /proc/sched_debug                    # Kernel scheduler debug info
cat /proc/<PID>/task/*/sched             # Per-thread scheduling stats

# Load average & CPU usage
uptime                                   # System load average
mpstat -P ALL 1                          # Per-CPU statistics (interval 1s)
iostat -x 1                              # CPU & I/O statistics
```

---

## 2. I/O & Storage Debugging

### Disk I/O Analysis
```bash
# I/O monitoring
iotop -b -n 1                            # Top I/O consumers
iostat -x 1 5                            # Extended I/O stats (5 intervals)
blktrace -d /dev/sda -o - | blkparse -i - # Block I/O tracing
pidstat -d 1                             # I/O statistics per process

# File descriptor analysis
lsof -p <PID>                            # Open files of process
cat /proc/<PID>/fd                       # List file descriptors
ls -la /proc/<PID>/fd                    # Show actual file descriptor files

# Filesystem operations
strace -e openat,read,write,close -p <PID>  # Trace filesystem operations
```

### Disk Performance
```bash
# Filesystem usage
df -h                                    # Disk space per filesystem
du -sh *                                 # Directory sizes
fio --name=test --size=1G --rw=read     # Flexible I/O benchmark

# Latency monitoring
latency-histogram /dev/sda               # I/O latency distribution (needs blktrace)
```

---

## 3. Network Debugging

### Network Monitoring
```bash
# Interface statistics
ip -s link show                          # Interface statistics with packets/bytes
ethtool -S eth0                          # Extended driver statistics
cat /proc/net/dev                        # Network device stats

# Real-time traffic
tcpdump -i eth0 -n                       # Capture packets on interface
tcpdump -i eth0 -nn 'tcp.flags.syn==1'   # Capture SYN packets
tcpdump -i eth0 -w dump.pcap             # Write to file for analysis
Wireshark                                # GUI packet analyzer (remote via X11/SSH)

# Packet statistics
netstat -s                               # Network statistics
ss -s                                    # Socket statistics (modern replacement)
ip route show                            # Routing table
ip neighbor show                         # ARP cache
```

### Connection & Socket Analysis
```bash
# Active connections
netstat -tulpn                           # All TCP/UDP connections with PIDs
ss -tulpn                                # Modern socket statistics
ss -p | grep :port                       # Find process on port
lsof -i :port                            # Show process listening on port

# Per-process network stats
cat /proc/<PID>/net/tcp                  # TCP connections of process
nstat -n                                 # Continuous network statistics
iftop -i eth0                            # Real-time bandwidth per connection
```

### Network Performance
```bash
# Latency & throughput
ping -c 10 host                          # Test reachability & latency
iperf3 -c server -t 60                   # Throughput testing
mtr host                                 # Combine traceroute & ping
traceroute host                          # Trace packet path

# MTU & TCP window
ip link show | grep mtu                  # Check MTU size
ss -i                                    # TCP info including CWND
```

---

## 4. Middleware Debugging (ROS/AUTOSAR)

### ROS (Robot Operating System)
```bash
# ROS nodes & topics
rosnode list                             # List active nodes
rostopic list                            # List topics
rostopic echo /topic_name                # Print topic messages
rosparam list                            # List parameters
rosparam get /param                      # Get parameter value

# Debugging
rosbag record -a                         # Record all topics
rosbag play bag_file.bag                 # Replay recorded data
rqt                                      # ROS visualization GUI (requires X11)
roslaunch file.launch --screen           # Launch with console output

# ROS logs
cat ~/.ros/log/latest/roslaunch.log      # Launch logs
rosclean purge                           # Clear old logs
```

### Message Queue & Communication
```bash
# Message passing (MQ)
ipcs -q                                  # List message queues
ipcs -m                                  # List shared memory
ipcs -s                                  # List semaphores
ipcrm -q <MSQID>                         # Remove message queue

# IPC debugging
pmap -x <PID>                            # Detailed memory map including shared segments
cat /proc/<PID>/smaps                    # Detailed memory maps with sizes
```

### Service & RPC Debugging
```bash
# Service discovery
netstat -tulpn | grep -E '(LISTEN|ESTABLISHED)'
ss -x                                    # Unix socket connections
journalctl -u servicename -f             # Follow service logs
systemctl status servicename             # Service status
systemctl journal -u servicename -n 100  # Last 100 service log lines
```

---

## 5. Application Debugging

### GDB - GNU Debugger
```bash
# Basic debugging
gdb ./app                                # Launch debugger
gdb --args ./app arg1 arg2               # Debug with arguments
gdb --pid <PID>                          # Attach to running process
gdb core.dump                            # Debug core dump

# GDB commands
(gdb) run                                # Start program
(gdb) break main                         # Set breakpoint
(gdb) continue                           # Continue execution
(gdb) step                               # Step into function
(gdb) next                               # Execute next line
(gdb) print var                          # Print variable value
(gdb) backtrace                          # Print stack trace
(gdb) info threads                       # List threads
(gdb) thread 2                           # Switch to thread 2
(gdb) frame 0                            # Show frame info
```

### Core Dumps
```bash
# Enable core dumps
ulimit -c unlimited                      # Allow unlimited core dump size
ulimit -a                                # Show all limits

# Generate & analyze core dumps
gdb -ex "bt full" -ex "quit" app core.dump  # Quick backtrace from core
gdb -ex "thread apply all bt full" -ex "quit" app core.dump  # All threads

# Core dump location
cat /proc/sys/kernel/core_pattern       # Core dump filename pattern
```

### Runtime Analysis
```bash
# Memory sanitizers (compile with flags)
# CFLAGS="-fsanitize=address" gcc app.c  # Address sanitizer
# CFLAGS="-fsanitize=thread" gcc app.c   # Thread sanitizer
# CFLAGS="-fsanitize=undefined" gcc app.c # Undefined behavior sanitizer

# Run with sanitizers
ASAN_OPTIONS=verbosity=2 ./app           # AddressSanitizer options
TSAN_OPTIONS=verbosity=2 ./app           # ThreadSanitizer options
```

### Profiling
```bash
# CPU profiling
perf record -p <PID> -F 99 -- sleep 10  # Profile for 10 seconds at 99 Hz
perf report -i perf.data                 # View results
google-pprof binary perf.data            # Alternative profiling view

# Memory profiling
heaptrack ./app                          # Memory allocation tracking
heaptrack_print heaptrack.app.*.gz       # View heaptrack results
```

---

## 6. Real-Time System Debugging

### Real-Time Priority & Latency
```bash
# Check if system is RT-enabled
uname -r                                 # Check kernel version for PREEMPT_RT
grep PREEMPT /boot/config-$(uname -r)    # Check kernel config

# Real-time processes
ps -eo pid,cls,pri,rtprio,comm --sort=rtprio
chrt -p <PID>                            # Show scheduling of process
chrt -f -p 99 <PID>                      # Set FIFO priority 99

# Latency measurement
cyclictest -p 99 -n -l 10000             # Measure latency (needs RT kernel)
hwlatdetect --duration=10 --threshold=10 # Measure hardware latency
rt-tests                                 # Real-time testing suite
```

### CPU Isolation & Irq Affinity
```bash
# Check IRQ affinity
cat /proc/irq/*/smp_affinity_list        # Which CPUs handle each IRQ
echo 1 > /proc/irq/35/smp_affinity       # Bind IRQ to CPU 1

# Isolate CPUs from kernel scheduler
cat /proc/cmdline | grep isolcpus        # Check isolated CPUs
# Add to bootline: isolcpus=2,3           # Isolate CPUs 2 & 3
# Use taskset to run on isolated CPUs
```

---

## 7. System Calls & Kernel Tracing

### Syscall Tracing
```bash
# Detailed syscall tracing
strace -e trace=open,openat,read,write -p <PID>  # Trace file operations
strace -e trace=network -p <PID>         # Network syscalls only
strace -c -p <PID>                       # Count syscalls
strace -s 256 command                    # Longer string output
strace -T command                        # Show time spent in syscalls

# Kernel functions (ftrace/eBPF)
echo "function_tracer" > /sys/kernel/debug/tracing/current_tracer
echo "sched_*" > /sys/kernel/debug/tracing/set_ftrace_filter
cat /sys/kernel/debug/tracing/trace_pipe # View trace output
```

### Context Switches
```bash
# Monitor context switches
cat /proc/sched_debug | grep switches    # Context switch counts
pidstat -w 1 1                           # Context switches per process
```

---

## 8. Common Debug Commands Cheatsheet

### Monitoring & Top-like Tools
```bash
# Process monitoring
top                                      # Interactive CPU/memory monitor
htop                                     # Enhanced top with colors
atop -a                                  # Process accounting top
iotop                                    # I/O monitor
nethogs                                  # Network I/O per process

# System-wide monitoring
vmstat 1 5                               # Virtual memory stats (5 samples, 1s interval)
iostat -x 1 5                            # I/O stats
pidstat 1 5                              # Process stats
dstat -tcms 1                            # Combined stats (CPU, Mem, Net, Disk)
```

### Finding Bottlenecks
```bash
# What's using resources?
ps aux --sort=-%cpu | head                  # Top CPU consumers
ps aux --sort=-%mem | head                  # Top memory consumers
lsof | wc -l                               # Total open file descriptors
who                                        # Logged-in users
w                                          # Logged-in users + their processes

# System load
uptime                                     # Load average
cat /proc/loadavg                          # Load average (detailed)
```

### Files & Directories
```bash
# File system health
fsck -n /dev/sda1                        # Check filesystem (dry-run)
tune2fs -l /dev/sda1                     # Filesystem parameters
stat filename                            # Detailed file info
lsattr -R /path                          # File attributes

# Find problematic files
lsof -r 1 | grep -v COMMAND              # Continuously update open files
fuser /mnt/fs                            # Processes using mount point
find /tmp -type f -atime +30             # Files not accessed in 30 days
```

### Boot & Crash Analysis
```bash
# Boot messages
journalctl -b                            # Current boot logs
journalctl -b -1                         # Previous boot logs
journalctl -b --no-pager -n 100          # Last 100 boot messages

# Crash dumps
ls -la /var/crash/                       # Crash dumps location
apport-cli                               # Interactive crash analysis
```

---

## 9. AV-Specific Debug Scenarios

### Timing & Deadline Monitoring
```bash
# Monitor deadline tasks (scheduler deadline feature)
grep "deadline" /proc/<PID>/sched        # Check if using deadline scheduler
cat /sys/kernel/debug/sched/debug        # Scheduler debug info

# Measure end-to-end latency
echo "deadline_tracer" > /sys/kernel/debug/tracing/current_tracer  # Trace deadline scheduler
strace -e clock_gettime -p <PID>         # Track time measurements
```

### Camera/Sensor Data Pipeline
```bash
# Check V4L2 devices (camera interfaces)
ls -la /dev/video*                       # List video devices
v4l2-ctl --list-devices                  # List capture devices
v4l2-ctl -d /dev/video0 --all           # Show all settings

# Frame drops & latency
strace -e ioctl -p <PID>                 # Monitor ioctl calls
perf stat -e cache-misses,cache-references ./sensor_app  # Cache behavior
```

### CAN/Vehicle Network Bus
```bash
# CAN interface monitoring
ip link show type can                    # List CAN interfaces
candump can0                             # Monitor CAN traffic
cansend can0 123#DEADBEEF                # Send CAN frame
canstat -r                               # CAN bus statistics

# Socketcan tracing
strace -e socket,sendto,recvfrom -p <PID>  # Socket operations on CAN
tcpdump -i can0 -w can_dump.pcap         # Capture CAN frames
```

---

## 10. Quick Reference: Essential Tools Installation

```bash
# Ubuntu/Debian
sudo apt-get install -y \
  linux-tools-$(uname -r) \
  gdb valgrind strace \
  iotop iftop nethogs \
  htop atop dstat \
  perf-tools bpftrace \
  ros-noetic-desktop-full \
  blktrace

# RHEL/CentOS
sudo yum install -y \
  perf gdb valgrind strace \
  iotop iftop nethogs \
  htop atop dstat

# Real-time tools
sudo apt-get install -y rt-tests hwlatdetect cyclictest
```

---

## 11. Debug Workflow Examples

### Issue: High Latency Spikes
```bash
# 1. Identify process
top -p <PID>                             # Check CPU/memory
pidstat -w 1                             # Monitor context switches

# 2. Trace system calls
strace -c -p <PID> | head -20           # Most frequent syscalls

# 3. Check I/O
iotop -b -n 1 -p <PID>                  # I/O time

# 4. Analyze with perf
perf record -p <PID> -g -- sleep 10
perf report

# 5. Check CPU affinity
taskset -p <PID>
chrt -p <PID>
```

### Issue: Memory Leak
```bash
# 1. Monitor growth
watch -n 1 'ps aux | grep app | grep -v grep'

# 2. Check with valgrind
valgrind --leak-check=full ./app

# 3. Heaptrack analysis
heaptrack ./app
heaptrack_print heaptrack.app.*.gz

# 4. GDB breakpoint analysis
gdb ./app
(gdb) break malloc
(gdb) command 1
(gdb) bt
(gdb) continue
(gdb) end
```

### Issue: Thread Deadlock
```bash
# 1. Find process
ps aux | grep app

# 2. Attach debugger
gdb --pid <PID>

# 3. Analyze threads
(gdb) info threads
(gdb) thread apply all bt

# 4. ThreadSanitizer
CFLAGS="-fsanitize=thread" gcc app.c
TSAN_OPTIONS=verbosity=1 ./app
```

---

## Notes
- Requires root/sudo for kernel tracing features
- Modern kernels prefer `perf`, `bpftrace` over older tools
- Real-time debugging requires CONFIG_HAVE_FUNCTION_TRACER kernel option
- Always test in safe environment before production debugging
