# QNX Kernel, Middleware & Apps Debug Cheatsheet for AV Compute Nodes

## Table of Contents

- [QNX Kernel, Middleware \& Apps Debug Cheatsheet for AV Compute Nodes](#qnx-kernel-middleware--apps-debug-cheatsheet-for-av-compute-nodes)
  - [Table of Contents](#table-of-contents)
  - [1. QNX System Basics \& Architecture](#1-qnx-system-basics--architecture)
    - [QNX Process Model](#qnx-process-model)
    - [Microkernel Architecture](#microkernel-architecture)
  - [2. Process \& Thread Debugging](#2-process--thread-debugging)
    - [Process Management](#process-management)
    - [Thread Analysis](#thread-analysis)
    - [Priority \& Scheduling](#priority--scheduling)
  - [3. Memory Debugging](#3-memory-debugging)
    - [Memory Analysis Tools](#memory-analysis-tools)
    - [Memory Faults \& Protection](#memory-faults--protection)
    - [Memory Mapping \& Shared Objects](#memory-mapping--shared-objects)
  - [4. IPC \& Message Passing](#4-ipc--message-passing)
    - [Message Queue Analysis](#message-queue-analysis)
    - [Channel Communication](#channel-communication)
    - [Pulse Debugging](#pulse-debugging)
  - [5. Real-Time Scheduling \& Latency](#5-real-time-scheduling--latency)
    - [Real-Time Priority Management](#real-time-priority-management)
    - [Latency Measurement](#latency-measurement)
    - [Adaptive Partitioning](#adaptive-partitioning)
  - [6. I/O \& Driver Debugging](#6-io--driver-debugging)
    - [Device Driver Inspection](#device-driver-inspection)
    - [I/O Statistics \& Tracing](#io-statistics--tracing)
    - [Interrupt Handling](#interrupt-handling)
  - [7. Network Debugging](#7-network-debugging)
    - [Network Stack Analysis](#network-stack-analysis)
    - [TCP/IP Diagnostics](#tcpip-diagnostics)
    - [Socket Inspection](#socket-inspection)
  - [8. Tracing \& Profiling](#8-tracing--profiling)
    - [System Tracing](#system-tracing)
    - [Event Tracing](#event-tracing)
    - [Performance Analysis](#performance-analysis)
  - [9. Debugging Tools](#9-debugging-tools)
    - [GDB Integration](#gdb-integration)
    - [QNX IDE \& Debugging](#qnx-ide--debugging)
    - [Core Dumps](#core-dumps)
  - [10. Resource Management](#10-resource-management)
    - [CPU Usage Monitoring](#cpu-usage-monitoring)
    - [Memory Usage Monitoring](#memory-usage-monitoring)
    - [Resource Limits](#resource-limits)
  - [11. Middleware \& Services Debugging](#11-middleware--services-debugging)
    - [ROS on QNX](#ros-on-qnx)
    - [AUTOSAR Services](#autosar-services)
    - [System Services](#system-services)
  - [12. AV-Specific Debug Scenarios](#12-av-specific-debug-scenarios)
    - [Real-Time Deadline Monitoring](#real-time-deadline-monitoring)
    - [Sensor Data Pipeline](#sensor-data-pipeline)
    - [CAN Bus Debugging](#can-bus-debugging)
  - [13. Common Issues \& Troubleshooting](#13-common-issues--troubleshooting)
    - [Priority Inversion](#priority-inversion)
    - [Resource Exhaustion](#resource-exhaustion)
    - [Timing Violations](#timing-violations)
  - [14. QNX Tools Installation \& Setup](#14-qnx-tools-installation--setup)
    - [Essential QNX Development Tools](#essential-qnx-development-tools)
    - [Kernel \& Runtime Configuration](#kernel--runtime-configuration)
    - [Build with Debug Symbols](#build-with-debug-symbols)
  - [15. Quick Reference Guide](#15-quick-reference-guide)
    - [Common Debug Workflow](#common-debug-workflow)
    - [One-Liners for Quick Diagnostics](#one-liners-for-quick-diagnostics)
  - [16. Performance Tuning Tips](#16-performance-tuning-tips)
    - [Optimization for Low-Latency](#optimization-for-low-latency)
    - [Monitoring Steady State](#monitoring-steady-state)
  - [Notes](#notes)
  - [References](#references)

---

## 1. QNX System Basics & Architecture

### QNX Process Model

```bash
# List all processes (similar to ps)
ps                                       # List processes with PID, priority, name
ps -e                                    # List all processes with extended info
ps -ef                                   # Full format with command line
ps -eo pid,ppid,tid,pri,comm             # Custom output format
ps -eo pid,ppid,priority,comm --sort=-priority

# Process information
pidin -p <PID> -f a                      # Detailed info for process
pidin info                               # System information
pidin -p <PID> info                      # Process info
```

### Microkernel Architecture

```bash
# Microkernel & system services
pidin b                                  # Boot info and system state
pidin h                                  # Header info with system specs
pidin a                                  # All processes and threads

# Show Neutrino kernel version
uname -a                                 # Kernel and system info
uname -r                                 # Kernel release
cat /proc/version                        # Version details

# Resource manager inspection
ls -la /proc                             # Process filesystem
ls -la /dev                              # Device drivers
ls -la /fs                               # Filesystem drivers
```

---

## 2. Process & Thread Debugging

### Process Management

```bash
# Process creation & termination
slay -f <process_name>                   # Kill process by name (force)
slay <process_name>                      # Gracefully kill process
slay -9 <PID>                            # Kill with SIGKILL
slay -p <PID>                            # Kill by PID

# Process spawning
spawn [options] <command>                # Spawn new process
spawn -H <host> <command>                # Remote spawn (Momentics IDE)
spawn -n <priority> <command>            # Spawn with specific priority

# Process status
ps -A                                    # All processes with full status
ps -a                                    # All processes with terminal
waitfor <process_name>                   # Wait for process to complete
```

### Thread Analysis

```bash
# List threads
pidin -p <PID> at                        # All threads of process
ps -eLf                                  # Extended thread information
ps -p <PID> -L                           # Threads of specific process

# Thread-specific info
dumper -p <PID>                          # Dump process/thread info
pidin -p <PID> arg                       # Arguments and environment

# Thread priority & scheduling
display_msg                              # Display message queue contents (IPC)
```

### Priority & Scheduling

```bash
# Get/set process priority
nice -n <priority> <command>             # Run with specific priority
renice <new_priority> -p <PID>           # Change priority of running process
getprio <PID>                            # Get current priority
setprio <priority> <PID>                 # Set priority

# Real-time scheduling classes
# Priority range: 0-255 (0=lowest, 255=highest for realtime)
# 0-63: Other scheduling class (timesharing)
# 64-255: Realtime scheduling class

# Thread scheduling info
pidin -p <PID> tcr                       # Thread creation/resume info
cat /proc/<PID>/stat                     # Process statistics including priority
```

---

## 3. Memory Debugging

### Memory Analysis Tools

```bash
# Memory usage summary
ps -eo pid,vsz,rss,comm                  # Virtual and resident memory
pidin -p <PID> info                      # Process memory info
cat /proc/meminfo                        # System memory statistics
cat /proc/<PID>/status                   # Detailed process memory

# Memory accounting
dumper -p <PID>                          # Full process dump (includes memory map)
dumper -p <PID> | head -100              # First 100 lines of dump

# Memory mapping
cat /proc/<PID>/maps                     # Memory mapping of process
cat /proc/<PID>/smaps                    # Detailed memory mapping with sizes
pidin m                                  # Memory usage summary
```

### Memory Faults & Protection

```bash
# Fault status
pidin f                                  # Fault and exception information
pidin -p <PID> fault                     # Process faults

# Page faults monitoring
# Monitor faults in kernel:
# /proc/<PID>/stat contains page fault counts (14th and 15th fields)

# Watchdog & fault detection
watchdog -t 2000                         # Enable watchdog with 2000ms timeout
slogger2                                 # System logging daemon (may catch crashes)

# Get crash logs
slogprt -h /dev/slog/klog                # Print kernel log
slogprt -h /dev/slog/ulog                # Print user log
```

### Memory Mapping & Shared Objects

```bash
# Shared object mapping
ls -la /lib                              # Standard libraries
ls -la /usr/lib                          # User libraries
ldd <executable>                         # List dynamic dependencies

# Loaded libraries per process
pidin -p <PID> dll                       # DLLs loaded by process
objdump -p <executable> | grep NEEDED   # Show library dependencies

# Shared memory inspection
pidin m                                  # Memory usage (includes shared segments)
ls -la /dev/shmem                        # Shared memory devices
```

---

## 4. IPC & Message Passing

### Message Queue Analysis

```bash
# List active channels & connections
pidin -p <PID> io                        # I/O connections of process
pidin c                                  # All channels
pidin -p <PID> ch                        # Channels for specific process

# Channel information
ls -la /proc/<PID>/as                    # Address space mapping
cat /proc/<PID>/cmdline                  # Command line (may show IPC details)

# Message queue depth & stats
# QNX doesn't have explicit msgqueue like SYSV IPC
# Use pulse-based messaging or message passing via channels
```

### Channel Communication

```bash
# Channel debugging via slay/pidin
pidin                                    # Show all active processes & channels
pidin -p <PID> fds                       # File descriptors (includes channels)

# Trace message passing
trace                                    # Start kernel event tracer
tracelogger -n 8 -b 128k -N 256k         # Start high-res tracing
traceparser                              # Parse trace output
```

### Pulse Debugging

```bash
# Pulse is lightweight IPC in QNX
# Cannot directly list pulses, but can trace delivery:

# Trace pulse delivery
tracelogger -c                           # Log kernel events (includes pulses)
traceparser                              # Parse and view pulse events

# Check code for pulse sending
grep -r "MsgSendPulse\|pulses_" /code   # Find pulse usage in code

# IPC statistics (if using Momentics IDE)
# IDE provides real-time visualization of IPC
```

---

## 5. Real-Time Scheduling & Latency

### Real-Time Priority Management

```bash
# Real-time process priority
# Priority 1-63: Background (cooperative)
# Priority 64-255: Realtime (preemptive)

# Set realtime priority
renice 100 -p <PID>                      # Set to realtime priority 100
getprio <PID>                            # Get current priority

# Check realtime capabilities
pidin -p <PID> pri                       # Process priority info
ps -eo pri,tid,comm                      # All thread priorities

# Realtime thread creation
# In code: pthread_create_with_priority()
# Or via command line with spawn -n
```

### Latency Measurement

```bash
# Timer-based latency testing
timer_latency                            # Measure timer interrupt latency (if available)

# Trace-based analysis
tracelogger -c -d /tmp/trace.kev         # Start kernel event logging
# Run your test application
# Stop with Ctrl+C
traceparser -i /tmp/trace.kev -o /tmp/trace.txt  # Parse events

# Manual timestamp measurement
date +%s%N                               # Nanosecond precision timestamp
# Use in bash scripts to measure intervals

# Performance counter inspection
getpmctl                                 # Get CPU performance counters
setpmctl                                 # Set performance monitoring

# Context switch analysis
pidin -r                                 # Show run queue and scheduling info
```

### Adaptive Partitioning

```bash
# Check adaptive partitioning status
cat /proc/partition                      # Current partition info
pidin -p <PID> partition                 # Partition assignment

# Set partition for process
# Requires partition daemon: partman
partman start                            # Start partition manager
partman -l                               # List partitions
# Configure via /etc/partition.conf

# Monitor partition usage
cat /proc/partition/budget               # Partition CPU budget usage
```

---

## 6. I/O & Driver Debugging

### Device Driver Inspection

```bash
# List device drivers
pidin -f a                               # All device managers
ls -la /dev                              # Device files

# Device manager info
pidin devi                               # Interrupt handlers and device info
pidin dm                                 # Device managers list

# Driver resource usage
pidin -p <driver_PID> io                 # I/O operations of driver
```

### I/O Statistics & Tracing

```bash
# I/O activity monitoring
pidin f                                  # Fault/event stats (includes I/O)
cat /proc/stat                           # System I/O statistics

# Trace I/O operations
tracelogger -c                           # Start event tracing (includes I/O)
# In kernel: shows read/write/seek events

# Filesystem statistics
df -h                                    # Filesystem usage
mount                                    # Mounted filesystems
ls -la /fs                               # Filesystem resource managers
```

### Interrupt Handling

```bash
# Interrupt information
pidin -v                                 # Verbose output including interrupts
cat /proc/interrupts                     # If available on QNX version
cat /proc/imask                          # Interrupt mask status

# Interrupt latency tracing
tracelogger -c -d /tmp/int_trace.kev     # Capture interrupt events
traceparser -i /tmp/int_trace.kev | grep "INTR\|INT"

# Interrupt storm detection
# Monitor with traceparser for excessive interrupts
```

---

## 7. Network Debugging

### Network Stack Analysis

```bash
# Network interface status
ifconfig                                 # Interface configuration
netstat -i                               # Interface statistics
pidin -s                                 # System statistics (includes network)

# Routing information
route print                              # Display routing table (Windows-like output)
netstat -rn                              # Routing table (numeric format)
arp -a                                   # ARP cache

# Network stack info
netstat -s                               # Statistics by protocol
netstat -ss                              # Extended stats
```

### TCP/IP Diagnostics

```bash
# Active connections
netstat -an                              # All connections with numeric addresses
netstat -tulnp                           # TCP/UDP listening + PIDs
ss -tulnp                                # Modern socket stats (if available)

# Connection tracking
pidin -p <PID> fds                       # File descriptors including sockets
lsof -i :port                            # Process on port
netstat -anp | grep <PID>                # Connections for process

# Connection timing
netstat -o                               # Show timers
```

### Socket Inspection

```bash
# Socket information
ls /proc/<PID>/fd                        # File descriptors (includes sockets)
cat /proc/<PID>/status                   # Shows socket usage

# TCP window & congestion
netstat -i                               # Shows interface RX/TX
netstat -s | grep -i "segment\|window\|retrans"

# UDP statistics
netstat -s | grep -i "UDP"
```

---

## 8. Tracing & Profiling

### System Tracing

```bash
# Kernel event tracing
tracelogger                              # Start capturing kernel events (default: circular buffer)
tracelogger -n 8 -b 128k -N 256k         # Configure: 8 buffers, 128KB each
tracelogger -c -d /tmp/trace.kev         # Capture to file

# Stop tracing
# Press Ctrl+C in tracelogger window or:
kill -15 <tracelogger_PID>

# Parse trace output
traceparser -i /tmp/trace.kev            # Interactive trace viewer
traceparser -i /tmp/trace.kev -o /tmp/trace.txt -f txt  # Export to text
```

### Event Tracing

```bash
# Trace specific events
# Events include: KERNEL, INTR, EMIT, NANO_MSG, etc.

# Start with event filtering
tracelogger -c                           # Capture all kernel events
# Filter in traceparser

# Custom event tracing (user code)
# Include: <trace.h>
// In code:
TraceEvent(_NTO_TRACE_KERCALL, <call_code>);

# Print formatted trace
traceparser -i /tmp/trace.kev -f txt | grep -i "<event_name>"
```

### Performance Analysis

```bash
# CPU profiling
gprof                                    # GNU profiler (if gprof support enabled)
perfmon                                  # Performance monitoring tool (if available)

# Call stack profiling
# Enable in code with backtrace()
backtrace()                              # Get stack trace at runtime

# Memory profiling
# Compile with -g and use GDB
gdb ./app
(gdb) set print pretty on
(gdb) break malloc
(gdb) command
(gdb) bt
(gdb) continue
(gdb) end
```

---

## 9. Debugging Tools

### GDB Integration

```bash
# Standard GDB usage
gdb ./app                                # Launch debugger
gdb --args ./app arg1 arg2               # With arguments
gdb --pid <PID>                          # Attach to running process

# GDB commands
(gdb) run                                # Start program
(gdb) break main                         # Set breakpoint
(gdb) continue                           # Continue
(gdb) step                               # Step into
(gdb) next                               # Next line
(gdb) print var                          # Print variable
(gdb) backtrace                          # Stack trace
(gdb) info threads                       # List threads
(gdb) thread 2                           # Switch thread

# Remote GDB (over network)
# On target:
gdbserver --attach localhost:1234 <PID>
# On host:
gdb ./app
(gdb) target remote <target_IP>:1234
```

### QNX IDE & Debugging

```bash
# QNX Momentics IDE (GUI-based debugging)
# Launch from command line:
qde                                      # QNX Development Environment

# Command-line debugging in IDE project
# Build with debug symbols: qcc -g app.c -o app

# pdebug (IDE debugger server)
pdebug -v                                # Start IDE debug server (verbose)
pdebug -n <node_name>                    # Debug specific node

# Remote debugging via IDE
# File > Debug Configurations > Configure remote target
```

### Core Dumps

```bash
# Enable core dumps
ulimit -c unlimited                      # Allow unlimited core size
ulimit -a                                # Show all limits

# Core dump location
cat /proc/sys/kernel/core_pattern        # Default: core

# Analyze core dump
gdb ./app core                           # Open core with executable
gdb -ex "bt full" -ex "quit" ./app core # Quick backtrace

# Generate on demand
dumper -p <PID>                          # Dump process state
dumper -p <PID> > /tmp/process.dump      # Save to file
```

---

## 10. Resource Management

### CPU Usage Monitoring

```bash
# Process CPU usage
ps -eo pid,pid,%cpu,comm                 # CPU percentage per process
top                                      # Real-time CPU monitor (if available)
pidin a                                  # All processes with status

# CPU affinity
sysctl -a | grep cpu                     # CPU settings
# QNX: CPU binding via SMP settings
# Enable with: proc boot ... smp

# Per-CPU statistics
# Show via tracing or kernel events
```

### Memory Usage Monitoring

```bash
# System memory
pidin m                                  # Memory summary
cat /proc/meminfo                        # Detailed memory stats
free -h                                  # Human-readable free memory

# Per-process memory
ps -eo pid,vsz,rss,comm                  # VSZ and RSS
pidin -p <PID> info                      # Process memory info
cat /proc/<PID>/status                   # Memory details

# Memory limit enforcement
# Via ulimit or resource limits in startup script
```

### Resource Limits

```bash
# View limits
ulimit -a                                # All limits
cat /proc/<PID>/limits                   # Process limits

# Set limits (in bash)
ulimit -c unlimited                      # Unlimited core dumps
ulimit -n 4096                           # Max open files
ulimit -m unlimited                      # Max memory

# Per-process resource control
# QNX: Use CGROUP or partition management
partman                                  # Partition manager for CPU/memory budgets
```

---

## 11. Middleware & Services Debugging

### ROS on QNX

```bash
# ROS node management
rosnode list                             # List active nodes
rostopic list                            # List topics
rostopic echo /topic                     # Print topic messages
rosparam list                            # List parameters

# ROS service calls
rosservice list                          # List services
rosservice call /service_name            # Call service

# ROS debugging
# ROS_DEBUG_LOG environment var
# Or configure via launch file

# Bag recording
rosbag record -a                         # Record all topics
rosbag play bag_file.bag                 # Playback
```

### AUTOSAR Services

```bash
# AUTOSAR Service Manager
# Common on QNX for automotive

# Service discovery
# Via service manager (proprietary)
ps -ef | grep -i autosar                # Find AUTOSAR processes

# Service status
# Check via AUTOSAR monitoring tool
# Or: grep in /dev for service devices

# Trace AUTOSAR calls
# Enable AUTOSAR diagnostics if available
```

### System Services

```bash
# List services/daemons
pidin                                    # All processes (includes services)
ps -ef | grep -v grep                    # All running processes

# Service status
ps -p <service_PID>                      # Check if running
pidin -p <service_PID> info              # Service info

# System logging
slogger2                                 # System logging daemon
slogprt -h /dev/slog/klog                # Print kernel log
slogprt -h /dev/slog/ulog                # Print user log

# View slog
slog2info -w                             # Continuous log display
slog2info -f <filter>                    # Filtered output
```

---

## 12. AV-Specific Debug Scenarios

### Real-Time Deadline Monitoring

```bash
# Monitor deadline scheduler (if using adaptive partitioning)
cat /proc/partition/budget               # CPU budget consumption
cat /proc/partition                      # Partition configuration

# Trace deadline misses
tracelogger -c -d /tmp/deadline.kev      # Start tracing
# Run application with tight deadlines
traceparser -i /tmp/deadline.kev | grep -i "deadline\|timeout"

# Measure jitter
# Use timestamps in code:
clock_gettime(CLOCK_MONOTONIC, &start);
// ... code ...
clock_gettime(CLOCK_MONOTONIC, &end);

# Check timer precision
# Build with: qcc -lm app.c -o app
# timer_create() with CLOCK_MONOTONIC
```

### Sensor Data Pipeline

```bash
# Device input monitoring
ls -la /dev/sensor*                      # Sensor device files
ls -la /dev/camera*                      # Camera device files

# Trace sensor I/O
tracelogger -c                           # Capture I/O events
# Monitor for delays in sensor reads

# Check sensor process priority
ps -eo pri,comm | grep sensor            # Sensor process priority
renice 200 -p <sensor_PID>               # Boost to realtime if needed

# Verify data throughput
# Count sensor messages per second
pidin -p <sensor_app_PID> io             # I/O statistics
```

### CAN Bus Debugging

```bash
# CAN interface configuration
ls -la /dev/can*                         # CAN devices
ls -la /dev/can/can*                     # Alternative location

# CAN statistics
# Via: devcan (CAN device manager)
devcan -l                                # List CAN channels (if available)

# Monitor CAN traffic
# Use custom CAN tracing or filters in code
# Or via hardware protocol analyzer

# CAN error detection
# Monitor in kernel logs:
pidin f                                  # Faults (may show CAN errors)
```

---

## 13. Common Issues & Troubleshooting

### Priority Inversion

```bash
# Detect priority inversion
# Symptoms: High-priority task blocked by low-priority task

# Check priorities
ps -eo tid,pri,comm | sort -k2           # Sort by priority

# Monitor for blocking
tracelogger -c                           # Trace all events
traceparser -i trace.kev | grep -i "mutex\|lock\|wait"

# Solution: Use priority inheritance mutexes
# In code: pthread_mutexattr_setprotocol(PTHREAD_PRIO_INHERIT)
```

### Resource Exhaustion

```bash
# Check resource usage
cat /proc/meminfo                        # Memory availability
pidin m                                  # Memory summary
ulimit -a                                # System limits
cat /proc/<PID>/limits                   # Process limits

# Find resource hogs
ps -eo pid,%mem,comm --sort=-%mem | head  # Top memory consumers
ps -eo pid,%cpu,comm --sort=-%cpu | head  # Top CPU consumers

# Monitor file descriptors
lsof | wc -l                             # Total open files
lsof -p <PID> | wc -l                    # Per-process open files
ulimit -n                                # Max file descriptors
```

### Timing Violations

```bash
# Detect missed deadlines
tracelogger -c -d /tmp/timing.kev        # Capture events
traceparser -i /tmp/timing.kev | grep -i "timeout\|deadline\|miss"

# Measure latency
# Use high-resolution timer:
clock_gettime(CLOCK_MONOTONIC, &start);
// Critical section
clock_gettime(CLOCK_MONOTONIC, &end);
latency_ns = (end.tv_sec - start.tv_sec) * 1e9 + (end.tv_nsec - start.tv_nsec);

# Trace context switches
tracelogger -c | grep -i "context\|switch"

# Check system load
pidin -r                                 # Run queue status
cat /proc/loadavg                        # Load average
```

---

## 14. QNX Tools Installation & Setup

### Essential QNX Development Tools

```bash
# QNX SDP (Software Development Platform)
# Download from: http://qnx.com/download

# Extract and setup
export QNX_TARGET=/path/to/qnx/target
export QNX_HOST=/path/to/qnx/host
export PATH=$QNX_HOST/usr/bin:$PATH

# Core tools
qcc                                      # QNX C compiler
ld                                       # Linker
qmake                                    # Build tool
```

### Kernel & Runtime Configuration

```bash
# Check QNX installation
qde --version                            # IDE version
qcc --version                            # Compiler version
uname -a                                 # Runtime kernel version

# Available tools
which pidin                              # Process info
which pdebug                             # Debugger
which tracelogger                        # Event tracing
which gdb                                # GNU debugger
which dumper                             # Process dumper
```

### Build with Debug Symbols

```bash
# Compile with debugging support
qcc -g -O0 app.c -o app                  # Debug: no optimization, symbols
qcc -g -O2 app.c -o app                  # Debug: with optimization

# Link with debug info
qcc -g app.c lib.a -o app

# Verify debug symbols
nm -g app                                # Show symbols
objdump -h app                           # Show sections (should have .debug)
```

---

## 15. Quick Reference Guide

### Common Debug Workflow

```bash
# 1. Identify problem process
pidin                                    # List all processes
pidin -p <PID> info                      # Get process info

# 2. Check priority & scheduling
ps -eo pri,tid,comm | grep <process>
getprio <PID>

# 3. Monitor resource usage
pidin m                                  # Memory
pidin -p <PID> io                        # I/O

# 4. Trace execution
tracelogger -c -d /tmp/trace.kev
# Run test
traceparser -i /tmp/trace.kev -f txt > trace.txt

# 5. Debug with GDB
gdb --pid <PID>
(gdb) bt
(gdb) info threads
(gdb) print var

# 6. Analyze core dump
dumper -p <PID> > core.dump
gdb ./app core.dump
(gdb) bt full
```

### One-Liners for Quick Diagnostics

```bash
# What's consuming CPU?
ps -eo %cpu,pid,comm --sort=-%cpu | head -5

# What's consuming memory?
ps -eo %mem,pid,vsz,comm --sort=-%mem | head -5

# Who's on the run queue?
pidin -r

# What's blocking priority?
tracelogger -c 2>/dev/null & sleep 5; kill $!; traceparser -i trace.kev | grep INTR

# What's waiting on locks?
tracelogger -c 2>/dev/null & sleep 5; kill $!; traceparser -i trace.kev | grep SYNC

# Real-time processes
ps -eo pri,tid,comm | awk '$1 > 63'

# Check file descriptor usage
lsof -p <PID> | wc -l

# Find process by port
netstat -tulnp | grep :port
```

---

## 16. Performance Tuning Tips

### Optimization for Low-Latency

```bash
# 1. Use realtime priority (>= 64)
renice 100 -p <PID>

# 2. Pin to CPU (SMP systems)
# Set in startup script: proc boot ... -n 4

# 3. Use high-resolution timers
clock_nanosleep(CLOCK_MONOTONIC, 0, &req, NULL);

# 4. Minimize context switches
pidin -r                                 # Monitor run queue

# 5. Lock memory pages (prevent page faults)
# In code: mlock(ptr, size);
```

### Monitoring Steady State

```bash
# Collect baseline
pidin > baseline.txt
ps -eo pid,%cpu,%mem,comm > baseline_ps.txt

# After 1 hour
pidin > current.txt
diff baseline.txt current.txt

# Check for memory leaks
ps -eo pid,vsz,comm | grep <process>    # Monitor VSZ growth

# Check for file descriptor leaks
lsof -p <PID> | wc -l                    # Should stay constant
```

---

## Notes

- QNX is a commercial RTOS with different licensing models (Neutrino is the kernel)
- Priority range 0-63 is background, 64-255 is realtime (preemptive)
- Pulse is lightweight IPC compared to message passing
- Adaptive Partitioning adds CPU/memory budget management
- QNX IDE (Momentics) provides GUI-based debugging
- Tools like pidin, pdebug, dumper are QNX-specific equivalents to Linux tools
- Real-time tracing requires kernel compiled with tracing support
- GDB works over network for remote debugging via pdebug
- QNX is deterministic - good for automotive and industrial control
- Temporal partitioning ensures predictable behavior even under overload

---

## References

- QNX Neutrino RTOS Documentation
- QNX Momentics IDE Help
- POSIX Real-Time Programming Guide
- Automotive real-time requirements (ISO 26262, AUTOSAR)
