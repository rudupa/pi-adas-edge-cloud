# Linux & QNX Scheduling and Core Partitioning for AV Compute Nodes

## Table of Contents

- [Linux \& QNX Scheduling and Core Partitioning for AV Compute Nodes](#linux--qnx-scheduling-and-core-partitioning-for-av-compute-nodes)
  - [Table of Contents](#table-of-contents)
  - [1. Linux Scheduling](#1-linux-scheduling)
    - [Scheduler Types](#scheduler-types)
    - [Process Priority \& Nice Values](#process-priority--nice-values)
    - [Real-Time Scheduling Classes](#real-time-scheduling-classes)
    - [CPU Affinity \& Pinning](#cpu-affinity--pinning)
    - [Load Balancing \& Migrations](#load-balancing--migrations)
  - [2. Linux Core Partitioning \& Isolation](#2-linux-core-partitioning--isolation)
    - [CPU Isolation (isolcpus)](#cpu-isolation-isolcpus)
    - [Cpuset Control Group](#cpuset-control-group)
    - [IRQ Affinity](#irq-affinity)
    - [RCU Offloading](#rcu-offloading)
    - [Kernel Thread Placement](#kernel-thread-placement)
  - [3. QNX Scheduling](#3-qnx-scheduling)
    - [Microkernel Scheduling Model](#microkernel-scheduling-model)
    - [Priority Levels](#priority-levels)
    - [Scheduling Classes](#scheduling-classes)
    - [Thread Scheduling](#thread-scheduling)
    - [Scheduling Policy Options](#scheduling-policy-options)
  - [4. QNX Adaptive Partitioning](#4-qnx-adaptive-partitioning)
    - [Partition Concepts](#partition-concepts)
    - [CPU Budget Management](#cpu-budget-management)
    - [Memory Partitioning](#memory-partitioning)
    - [Configuration \& Setup](#configuration--setup)
    - [Monitoring Partitions](#monitoring-partitions)
  - [5. Linux CGroup \& Resource Control](#5-linux-cgroup--resource-control)
    - [CGroup v1 Overview](#cgroup-v1-overview)
    - [CGroup v2 Architecture](#cgroup-v2-architecture)
    - [CPU Subsystem](#cpu-subsystem)
    - [Memory Subsystem](#memory-subsystem)
    - [Cpuset Subsystem](#cpuset-subsystem)
  - [6. Real-Time Kernel Variants](#6-real-time-kernel-variants)
    - [PREEMPT\_RT Kernel](#preempt_rt-kernel)
    - [Determinism Features](#determinism-features)
    - [Latency Comparison](#latency-comparison)
  - [7. Thread \& Process Creation](#7-thread--process-creation)
    - [Linux Thread Creation](#linux-thread-creation)
    - [QNX Thread Creation](#qnx-thread-creation)
    - [Priority Inheritance](#priority-inheritance)
    - [Thread-Specific Affinity](#thread-specific-affinity)
  - [8. Debugging \& Monitoring](#8-debugging--monitoring)
    - [Linux Scheduling Tools](#linux-scheduling-tools)
    - [QNX Scheduling Tools](#qnx-scheduling-tools)
    - [Performance Profiling](#performance-profiling)
    - [Trace Analysis](#trace-analysis)
  - [9. AV-Specific Use Cases](#9-av-specific-use-cases)
    - [Sensor Processing Pipeline](#sensor-processing-pipeline)
    - [Decision Making Unit](#decision-making-unit)
    - [Control \& Actuation](#control--actuation)
    - [Safety-Critical Components](#safety-critical-components)
  - [10. Best Practices \& Configuration](#10-best-practices--configuration)
    - [Linux Configuration](#linux-configuration)
    - [QNX Configuration](#qnx-configuration)
    - [Determinism Checklist](#determinism-checklist)
  - [11. Comparison Matrix](#11-comparison-matrix)
  - [12. Troubleshooting](#12-troubleshooting)
    - [Debugging Scheduling Issues](#debugging-scheduling-issues)
  - [Notes](#notes)
  - [References](#references)

---

## 1. Linux Scheduling

### Scheduler Types

```bash
# Modern Linux uses Completely Fair Scheduler (CFS) for non-realtime
# and a fixed-priority preemptive scheduler for realtime tasks

# Check current scheduler
cat /sys/kernel/sched_features           # Scheduler features enabled
cat /sys/kernel/debug/sched/features     # Alternative location

# CFS (default for non-RT tasks)
# - Fair CPU time division
# - Virtual runtime tracking
# - Red-black tree for task ordering
# - O(log n) complexity

# Real-Time Scheduler
# - SCHED_FIFO: Fixed-priority FIFO
# - SCHED_RR: Fixed-priority round-robin
# - SCHED_DEADLINE: Deadline-based scheduling (Linux 3.14+)

# Check kernel version for DEADLINE support
uname -r                                 # Must be 3.14+
grep SCHED_DEADLINE /boot/config-$(uname -r)  # Verify enabled
```

### Process Priority & Nice Values

```bash
# Priority Range in Linux
# -20 to +19: Nice values (CFS priority)
# 0-39: Realtime priority (for SCHED_FIFO/RR)
# -1: Kernel threads
# Lower nice = higher priority

# Set priority with nice (at startup)
nice -n -10 ./app                        # Run with priority -10 (high)
nice -n +10 ./app                        # Run with priority +10 (low)

# Change priority of running process
renice -10 -p <PID>                      # Increase priority of PID
renice +10 -p <PID>                      # Decrease priority of PID

# View priority
ps -eo pid,ni,pri,comm | grep <process>  # ni=nice, pri=priority
top -p <PID>                             # Shows priority in interactive mode

# Get current nice
getpriority PRIO_PROCESS <PID>           # System call via strace or perl

# Kernel API
# setpriority(PRIO_PROCESS, pid, priority)
// In code:
setpriority(PRIO_PROCESS, 0, -10);      // Set current process priority
```

### Real-Time Scheduling Classes

```bash
# SCHED_FIFO - Fixed Priority First-In-First-Out
# - Preemptive: Higher priority preempts lower
# - No time-slicing: Runs until yield, block, or preemption
# - Starvation risk: Lower priority may never run

# Set SCHED_FIFO with priority 99
chrt -f -p 99 <PID>                      # Set FIFO priority 99
chrt -p <PID>                            # Check current scheduling

// In code:
struct sched_param param;
param.sched_priority = 99;
pthread_setschedparam(pthread_self(), SCHED_FIFO, &param);

# SCHED_RR - Real-Time Round-Robin
# - Preemptive with time-slice (quantum)
# - Similar to SCHED_FIFO but time-limited
# - Fairer distribution but higher overhead

# Set SCHED_RR
chrt -r -p 50 <PID>                      # RR priority 50

// In code:
param.sched_priority = 50;
pthread_setschedparam(pthread_self(), SCHED_RR, &param);

# SCHED_DEADLINE - Deadline Scheduler
# - Requires kernel 3.14+ with CONFIG_SMP=y
# - Uses CBS (Constant Bandwidth Server)
# - Parameters: runtime, deadline, period

# Set deadline scheduling
sched_setattr()                          # System call
// In code:
struct sched_attr attr = {
  .size = sizeof(attr),
  .sched_policy = SCHED_DEADLINE,
  .sched_runtime = 10000000,             // 10ms
  .sched_deadline = 30000000,            // 30ms deadline
  .sched_period = 30000000,              // 30ms period
};
sched_setattr(0, &attr, 0);

# Check deadlines
cat /proc/<PID>/sched | grep deadline    # Show deadline info
```

### CPU Affinity & Pinning

```bash
# Set CPU affinity - bind process to specific CPU(s)
taskset -c 0,1,2 ./app                   # Run on CPUs 0,1,2
taskset -p <PID>                         # Show CPU affinity
taskset -cp 0 <PID>                      # Bind to CPU 0

# CPU affinity mask (hex)
taskset -c 0x1 ./app                     # CPU 0 (hex: 0x1 = 0b0001)
taskset -c 0x3 ./app                     # CPUs 0,1 (hex: 0x3 = 0b0011)
taskset -c 0xF ./app                     # CPUs 0,1,2,3 (hex: 0xF = 0b1111)

# In C code
#include <sched.h>
cpu_set_t set;
CPU_ZERO(&set);
CPU_SET(0, &set);                        // Add CPU 0
CPU_SET(2, &set);                        // Add CPU 2
sched_setaffinity(0, sizeof(set), &set); // Apply to current process

// Get affinity
sched_getaffinity(0, sizeof(set), &set);
for (int i = 0; i < CPU_SETSIZE; i++) {
  if (CPU_ISSET(i, &set)) printf("CPU %d\n", i);
}

# Thread affinity
pthread_setaffinity_np(thread, sizeof(set), &set);  // Set thread affinity
pthread_getaffinity_np(thread, sizeof(set), &set);  // Get thread affinity
```

### Load Balancing & Migrations

```bash
# Linux automatically migrates processes across CPUs
# CFS load balancer triggers on scheduler tick, new task, etc.

# Check scheduler load balance
cat /sys/kernel/debug/sched_debug | grep -A 20 "runnable tasks"

# Disable load balancing (improves predictability)
echo 0 > /sys/kernel/sched_features      # Disables features (use carefully)

# Scheduler features
cat /sys/kernel/sched_features           # List all features

# Force rebalancing
# Manually via taskset or migrate_pages
migrate_pages <PID> <from> <to>          # Migrate pages between nodes

# Per-CPU idle time
# Monitor migration impact:
perf stat -e context-switches,migrations <command>
```

---

## 2. Linux Core Partitioning & Isolation

### CPU Isolation (isolcpus)

```bash
# Isolate CPUs from kernel scheduler
# Add to kernel boot parameters:
# isolcpus=2,3,4

# Check isolated CPUs
cat /proc/cmdline | grep isolcpus

# View in /proc/stat
cat /proc/stat                           # Isolated CPUs still appear but kernel avoids them

# Manually isolate processes
taskset -c 2-4 ./app                     # Bind to isolated cores

# Combine with cpuset for better control
# (See cpuset section below)

# Benefits:
# - Kernel threads avoid isolated cores
# - Fewer context switches
# - Deterministic CPU availability
# - Lower cache contention

# Limitations:
# - Cannot completely prevent all kernel activity
# - Housekeeping threads still run
# - Need cpuset for strict control
```

### Cpuset Control Group

```bash
# Cpuset provides fine-grained CPU/memory isolation
# Hierarchy-based assignment of CPUs and memory nodes to process groups

# Enable cpuset
grep cgroup /proc/mounts | grep cpuset   # Check if mounted
mount | grep cgroup                      # List all cgroup mounts

# Typical cgroup mount
mount -t cgroup -o cpuset cpuset /cgroup/cpuset

# Create cpuset
mkdir /cgroup/cpuset/realtime
echo "2-4" > /cgroup/cpuset/realtime/cpuset.cpus      # Assign CPUs 2-4
echo "0" > /cgroup/cpuset/realtime/cpuset.mems        # Memory node 0

# Add process to cpuset
echo $$ > /cgroup/cpuset/realtime/tasks               # Add current process
echo <PID> > /cgroup/cpuset/realtime/tasks            # Add specific process

# Verify
cat /cgroup/cpuset/realtime/cpuset.cpus               # Show assigned CPUs
cat /cgroup/cpuset/realtime/tasks                     # Show processes

# View all cpuset hierarchies
cd /cgroup/cpuset
find . -type d | head -10

# Exclusive CPUs (prevents sibling groups from using)
echo 1 > /cgroup/cpuset/realtime/cpuset.cpu_exclusive

# CPUset vs isolcpus comparison:
# isolcpus: Boot parameter, kernel-level isolation, all processes
# cpuset: Runtime cgroup, per-process-group, fine-grained control
```

### IRQ Affinity

```bash
# Direct interrupts to specific CPU(s)
# Prevents interrupts from disturbing realtime tasks on isolated CPUs

# View IRQ affinity
cat /proc/irq/*/smp_affinity             # Hex bitmask
cat /proc/irq/*/smp_affinity_list        # Human-readable CPU list

# IRQ 35 example
cat /proc/irq/35/smp_affinity            # Show current affinity
echo "1" > /proc/irq/35/smp_affinity     # Bind to CPU 0 (0x1 = binary 0001)
echo "f" > /proc/irq/35/smp_affinity     # Bind to CPUs 0-3 (0xf = binary 1111)

# Human-readable
echo "1,3" > /proc/irq/35/smp_affinity_list  # CPUs 1 and 3

# Bind all network IRQs to CPU 0 (leave CPU 2-3 free)
for irq in $(ls /proc/irq | grep -E '^[0-9]+$'); do
  echo "1" > /proc/irq/$irq/smp_affinity
done

# Kernel-mode interrupt handling
# irqbalance: Automatic IRQ balancer (disable for realtime)
systemctl stop irqbalance
systemctl disable irqbalance

# Show IRQ statistics
cat /proc/interrupts | head -20
watch -n 1 "cat /proc/interrupts"        # Monitor in real-time
```

### RCU Offloading

```bash
# RCU (Read-Copy-Update) synchronization can cause latency
# Offload RCU callback processing to specific CPUs

# Enable RCU offloading at boot
# Add to kernel parameters: rcu_nocbs=2,3,4

# Check RCU configuration
cat /proc/cmdline | grep rcu_nocbs

# View RCU grace period info
grep "rcu_sched" /proc/slabinfo

# RCU_TRACE config (if enabled)
cat /sys/kernel/debug/rcu/rcu_sched/rcugp  # Grace period info

# Disable RCU self-report (reduces overhead)
# Compile option: CONFIG_RCU_STALL_COMMON=n
```

### Kernel Thread Placement

```bash
# Kernel threads (prefixed with 'k' in ps output) can disturb realtime tasks
# Examples: kswapd, kworker, ksoftirqd, kthreadd, etc.

# Find kernel threads
ps aux | grep "^\s*root\s*[0-9]*\s*0"   # Filter by CPU 0 and root user
ps -eo pid,cmd | grep "^\s*[0-9]*\s*\["  # Process name in brackets = kernel thread

# Manual kernel thread pinning
# Identify which threads disturb your workload:
# 1. Trace with perf to find context switches
# 2. Identify kernel thread causing switches
# 3. Pin to separate CPUs

# Pin ksoftirqd to CPU 0 (example)
PID=$(ps -eo pid,cmd | grep ksoftirqd | head -1 | awk '{print $1}')
taskset -cp 0 $PID

# Pin kworker threads
for pid in $(ps -eo pid,cmd | grep kworker | awk '{print $1}'); do
  taskset -cp 0 $pid
done

# Workqueue affinity (kernel 4.13+)
# Configure: /sys/devices/virtual/workqueue/<workqueue>/cpumask

# Disable unbound workqueues on isolated CPUs
echo 1 > /sys/module/workqueue/parameters/power_efficient  # Power efficiency
echo 0 > /sys/module/workqueue/parameters/power_efficient  # Performance
```

---

## 3. QNX Scheduling

### Microkernel Scheduling Model

```bash
# QNX uses preemptive priority-based scheduling
# Lowest latency in microkernel: minimal context switch overhead
# Neutrino kernel with 256 priority levels

# Scheduling decisions occur on:
# - Kernel call (e.g., pthread_create, MsgReceive)
# - ISR/timer interrupt
# - Priority change

# No forced time-slicing at priority level
# (unlike Linux CFS with fair scheduling)

# Get scheduler debug info
pidin -r                                 # Show runnable threads
cat /proc/sched_debug                    # Scheduler state (if available)

# Check if process is running or blocked
pidin -p <PID> pri                       # Priority info
pidin -p <PID> tcr                       # Thread creation/resume info
```

### Priority Levels

```bash
# QNX Priority Range: 1-255
# 1-63: Background (non-preemptive, cooperative)
# 64-255: Real-time (preemptive)

# Critical priorities in AV:
# 90-100: Safety-critical, hard realtime
# 80-89: Hard realtime, mission-critical
# 64-79: Soft realtime
# 1-63: Background services

# Set process priority at spawn
getprio <PID>                            # Get current priority
setprio <priority> <PID>                 # Set new priority

// In C code
int prio = 90;
if (setprio(getpid(), prio) == -1) {
  perror("setprio");
}

# Thread priority (via POSIX)
pthread_t tid;
struct sched_param param;
param.sched_priority = 90;
pthread_create(&tid, NULL, thread_func, NULL);
pthread_setschedparam(tid, SCHED_FIFO, &param);

# Verify thread priority
cat /proc/<PID>/stat | awk '{print "Priority:", $18}'  // Linux
pidin -p <PID> -t <TID> info              // QNX
```

### Scheduling Classes

```bash
# QNX POSIX Scheduling Classes

# SCHED_FIFO: Real-Time FIFO (priority >= 64)
// Set in code:
struct sched_param param;
param.sched_priority = 100;
pthread_setschedparam(tid, SCHED_FIFO, &param);

# SCHED_RR: Real-Time Round-Robin (priority >= 64)
# - Similar to FIFO but with time quantum
# - Thread yields after time slice
param.sched_priority = 100;
pthread_setschedparam(tid, SCHED_RR, &param);

# SCHED_OTHER: Background (priority 1-63)
param.sched_priority = 10;
pthread_setschedparam(tid, SCHED_OTHER, &param);

# Check current scheduling class
ps -eo pid,cls,pri,comm                  # cls = scheduling class
pidin -p <PID> tcr                       # Thread creation info

# Scheduling class codes:
# 'f' = FIFO
# 'r' = RR
# 'o' = Other
# 'a' = Adaptive
```

### Thread Scheduling

```bash
# QNX thread creation with scheduling parameters
pthread_attr_t attr;
pthread_attr_init(&attr);

// Set priority
pthread_attr_setschedpolicy(&attr, SCHED_FIFO);
struct sched_param param;
param.sched_priority = 90;
pthread_attr_setschedparam(&attr, &param);

// Set CPU affinity (if SMP)
cpu_set_t cpuset;
CPU_ZERO(&cpuset);
CPU_SET(0, &cpuset);                    // CPU 0
pthread_attr_setaffinity_np(&attr, sizeof(cpu_set_t), &cpuset);

// Create thread
pthread_t tid;
pthread_create(&tid, &attr, thread_func, NULL);

# Thread information
pidin -p <PID> at                        # All threads of process
ps -eLf                                  # List threads
ps -p <PID> -L                           # Threads of process

# Blocking/Unblocking threads
// Thread blocks on MsgReceive, condition variable, etc.
// Highest priority runnable thread always runs
```

### Scheduling Policy Options

```bash
# QNX SMP (Symmetric Multiprocessing)
# Enable at boot: proc boot ... -n 4     (4 processors)

# Thread affinity (SMP systems)
// Set in code:
#include <sched.h>
cpu_set_t set;
CPU_ZERO(&set);
CPU_SET(0, &set);
pthread_setaffinity_np(tid, sizeof(set), &set);

// Get affinity
pthread_getaffinity_np(tid, sizeof(set), &set);

# Check SMP configuration
ls -la /dev/cpu/                         # CPU devices
cat /proc/cpuinfo                        # CPU info

# Processor affinity info
cat /proc/stat | grep cpu                # Per-CPU stats

# Disable SMP migration
# Requires kernel modification or partition management
```

---

## 4. QNX Adaptive Partitioning

### Partition Concepts

```bash
# Adaptive Partitioning provides CPU and memory budget management
# Partitions guarantee minimum CPU bandwidth even under overload
# Key for safety-critical AV applications

# Types of partitions:
# - System: Kernel and core services
# - Critical: Safety-critical code (high budget)
# - Normal: General workload
# - Background: Low-priority background tasks

# Partition structure
/proc/partition                          # Partition filesystem
/proc/partition/budget                   # CPU budget info
/proc/partition/attributes               # Partition attributes

# View partitions
cat /proc/partition | head -20

# View CPU budget
cat /proc/partition/budget               # Shows budget and consumed

# Show per-partition info
pidin partition                          # Partition assignment
```

### CPU Budget Management

```bash
# Each partition has guaranteed minimum CPU time
# Budget: percentage of CPU time (e.g., 10% = 0.1 guaranteed bandwidth)

# Partition configuration file
# /etc/partition.conf or /etc/system/partition.conf

# Example config:
[system]
cpu = 40                                 # System partition: 40% CPU

[safety_critical]
cpu = 30                                 # Safety partition: 30% CPU

[general]
cpu = 20                                 # General partition: 20% CPU

[background]
cpu = 10                                 # Background partition: 10% CPU

# Load partition configuration
partman -c /etc/partition.conf           # Configure partitions

# Start partition manager
partman start                            # Enable adaptive partitioning

# Verify budget distribution
cat /proc/partition/budget               # Show consumed budget
watch -n 1 "cat /proc/partition/budget"  # Monitor continuously

# Assign process to partition
# Via configuration or:
partman -a <partition_name> <PID>       # Add process to partition

# Move process between partitions
partman -m <partition_name> <PID>       # Move process

# Partition statistics
cat /proc/partition/stats                # Partition usage statistics
```

### Memory Partitioning

```bash
# QNX supports memory partitioning alongside CPU budgets
# Each partition can have memory limits

# Memory partition config
[safety_critical]
cpu = 30
memory = 512M                            # Limit to 512MB

[general]
cpu = 20
memory = 256M

# Check memory per partition
cat /proc/meminfo                        # System memory
cat /proc/partition/mem                  # Partition memory (if available)

# Per-process memory
pidin -p <PID> info                      # Memory usage of process

# Memory reservation prevents OOM
# Configured partition ensures minimum memory available
```

### Configuration & Setup

```bash
# Adaptive Partitioning setup steps:

# 1. Enable in kernel config
cat /proc/sys/kernel/partition_enabled

# 2. Create partition configuration
cat > /etc/partition.conf << EOF
[system]
cpu = 40

[safety]
cpu = 30
priority = 100

[general]
cpu = 20

[background]
cpu = 10
EOF

# 3. Load configuration
partman start
partman -c /etc/partition.conf
partman -l                               # List partitions

# 4. Assign process to partition
partman -a safety <PID>                  # Assign PID to safety partition

# 5. Verify configuration
cat /proc/partition/budget               # Show budget usage
ps -eo pid,partition,comm                # Show partition per process

# Dynamic partition adjustment
# Requires partman daemon or configuration daemon

# Monitor partition health
cat /proc/partition/status               # Partition status
```

### Monitoring Partitions

```bash
# Real-time partition monitoring
cat /proc/partition/budget | head -5     # Budget header
cat /proc/partition/budget | grep -E "<partition_name>"

# Formatted partition info
pidin partition                          # Show all partitions & processes

# Per-process partition info
ps -eo pid,partition,comm | head -20

# Alarm on budget overrun
# Monitor:
cat /proc/partition/budget | grep "overrun"

# Partition-aware tracing
tracelogger -c                           # Include partition info in trace
traceparser -i trace.kev | grep -i partition

# CPU usage per partition
# Calculate from: /proc/partition/budget
# Format: partition_name cpu_used cpu_budget cpu_percent

# Example script to show partition CPU usage:
#!/bin/bash
echo "Partition CPU Usage:"
awk '/^[^#]/ {print $1, ($2/$3)*100 "%"}' /proc/partition/budget
```

---

## 5. Linux CGroup & Resource Control

### CGroup v1 Overview

```bash
# CGroup v1: Hierarchical resource management
# Mounted per subsystem (cpuset, cpu, memory, etc.)

# Check mounted cgroups
mount | grep cgroup
ls /cgroup/                              # Or /sys/fs/cgroup/

# Common cgroup subsystems
# - cpuset: CPU and memory node assignment
# - cpu: CPU time allocation (shares, quota)
# - cpuacct: CPU accounting
# - memory: Memory limits
# - blkio: Block device I/O control
# - freezer: Process suspension
# - devices: Device access control

# View all cgroups
ps -eo cgroup,pid,comm                   # Show cgroup per process
cat /proc/cgroups                        # Cgroup subsystems
cat /proc/<PID>/cgroup                   # Process cgroup membership

# Hierarchy structure
cat /cgroup/cgroup.procs                 # Root cgroup processes
find /cgroup -name "cgroup.procs" | head -5
```

### CGroup v2 Architecture

```bash
# CGroup v2: Unified hierarchy (introduced in kernel 4.5)
# Single hierarchy, unified interface

# Check if v2 is available
mount | grep cgroup2                     # Check v2 mount
ls /sys/fs/cgroup/ | grep -E "^[a-z]"  # List v2 hierarchy

# Mount v2 if not present
mount -t cgroup2 none /sys/fs/cgroup/unified

# Create cgroup in v2
mkdir /sys/fs/cgroup/unified/mycgroup
echo "+cpu +memory" > /sys/fs/cgroup/unified/cgroup.subtree_control

# Add process to v2 cgroup
echo <PID> > /sys/fs/cgroup/unified/mycgroup/cgroup.procs

# Set CPU limits (v2)
# cpu.max: <max> <period>
echo "100000 100000" > /sys/fs/cgroup/unified/mycgroup/cpu.max  # 100% CPU

# Set memory limits (v2)
echo "512M" > /sys/fs/cgroup/unified/mycgroup/memory.max
```

### CPU Subsystem

```bash
# CPU cgroup v1: Shares-based fair distribution
# Default: 1024 shares per process

# CFS share assignment
cat /cgroup/cpu/cpu.shares               # Show CPU shares (default: 1024)
echo 512 > /cgroup/cpu/mycgroup/cpu.shares  # Half the shares (lower priority)
echo 2048 > /cgroup/cpu/mycgroup/cpu.shares # Double the shares (higher priority)

# CPU quota enforcement (CPU limits)
# cpu.cfs_quota_us: Maximum CPU time (microseconds)
# cpu.cfs_period_us: Period (default: 100000 μs = 100ms)

# Limit process to 50% CPU (1 CPU out of 2)
echo 50000 > /cgroup/cpu/mycgroup/cpu.cfs_quota_us    # 50ms per 100ms period
echo 100000 > /cgroup/cpu/mycgroup/cpu.cfs_period_us  # 100ms period

# Limit to 1.5 CPUs on quad-core system
echo 150000 > /cgroup/cpu/mycgroup/cpu.cfs_quota_us   # 150ms
echo 100000 > /cgroup/cpu/mycgroup/cpu.cfs_period_us  # per 100ms

# Check CPU accounting
cat /cgroup/cpuacct/mycgroup/cpuacct.usage            # Total CPU time (ns)
cat /cgroup/cpuacct/mycgroup/cpuacct.usage_percpu     # Per-CPU usage

# Real-time bandwidth (for SCHED_FIFO/RR)
cat /cgroup/cpu/cpu.rt_period_us                      # RT period
cat /cgroup/cpu/cpu.rt_runtime_us                     # RT budget
echo 600000 > /cgroup/cpu/mycgroup/cpu.rt_runtime_us  # 600ms RT per 1s
```

### Memory Subsystem

```bash
# Memory cgroup: Limit and account memory usage

# Create memory cgroup
mkdir /cgroup/memory/mycgroup

# Set memory limit
echo 512M > /cgroup/memory/mycgroup/memory.limit_in_bytes

# Set memory+swap limit (includes swap space)
echo 1G > /cgroup/memory/mycgroup/memory.memsw.limit_in_bytes

# Add process to memory cgroup
echo <PID> > /cgroup/memory/mycgroup/cgroup.procs

# View memory usage
cat /cgroup/memory/mycgroup/memory.usage_in_bytes       # Current usage
cat /cgroup/memory/mycgroup/memory.max_usage_in_bytes   # Peak usage
cat /cgroup/memory/mycgroup/memory.stat                 # Detailed stats

# Memory reclaim (soft limit)
# Kernel tries to reclaim when below soft limit
echo 256M > /cgroup/memory/mycgroup/memory.soft_limit_in_bytes

# OOM killer behavior
echo 1 > /cgroup/memory/mycgroup/memory.oom_control     # Disable OOM killer for this cgroup

# Memory pressure level
cat /proc/pressure/memory                # System-wide memory pressure (PSI)
cat /cgroup/memory/mycgroup/memory.pressure_level       # Cgroup pressure level
```

### Cpuset Subsystem

```bash
# Cpuset: Bind processes to specific CPUs and memory nodes (NUMA)

# Create cpuset
mkdir /cgroup/cpuset/mycgroup

# Assign CPUs and memory nodes
echo "1,2,3" > /cgroup/cpuset/mycgroup/cpuset.cpus     # CPUs 1, 2, 3
echo "0" > /cgroup/cpuset/mycgroup/cpuset.mems         # Memory node 0

# Add process
echo <PID> > /cgroup/cpuset/mycgroup/cgroup.procs

# Exclusive cpuset (siblings cannot use these CPUs)
echo 1 > /cgroup/cpuset/mycgroup/cpuset.cpu_exclusive
echo 1 > /cgroup/cpuset/mycgroup/cpuset.mem_exclusive

# Load balancing behavior
echo 0 > /cgroup/cpuset/mycgroup/cpuset.sched_load_balance  # Disable balance

# View cpuset assignments
cat /cgroup/cpuset/mycgroup/cpuset.cpus
cat /cgroup/cpuset/mycgroup/cpuset.effective_cpus      # After constraints

# Verify process binding
ps -p <PID> -o pid,psr                  # Processor (psr) for process
taskset -p <PID>                        # Show CPU affinity
```

---

## 6. Real-Time Kernel Variants

### PREEMPT_RT Kernel

```bash
# PREEMPT_RT: Real-Time patch set for Linux
# Reduces latency by making kernel more preemptible
# Applied on top of standard kernel

# Check if RT kernel is installed
uname -r | grep -i rt                    # Shows "rt" in version if installed
grep PREEMPT /boot/config-$(uname -r)    # Check kernel config

# RT patch configs to enable:
# CONFIG_PREEMPT_RT=y
# CONFIG_PREEMPT_RT_FULL=y               # (on older versions)
# CONFIG_HIGH_RES_TIMERS=y
# CONFIG_NO_HZ_FULL=y                    # Full dynticks (on isolated CPUs)

# Preemption levels available
grep CONFIG_PREEMPT /boot/config-$(uname -r)

# Standard Preemption Models:
# CONFIG_PREEMPT_NONE: No preemption (desktop kernel)
# CONFIG_PREEMPT_VOLUNTARY: Voluntary preemption
# CONFIG_PREEMPT: Kernel preemption (general purpose)
# CONFIG_PREEMPT_RT: Real-time preemption (PREEMPT_RT patch)

# Check current preemption model
cat /proc/sys/kernel/config_preempt       # If accessible
```

### Determinism Features

```bash
# Features that reduce latency variability:

# 1. High-Resolution Timers (HRT)
CONFIG_HIGH_RES_TIMERS=y
# Enables nanosecond-precision timers instead of jiffies

# 2. Dynamic Tick (CONFIG_NO_HZ)
grep CONFIG_NO_HZ /boot/config-$(uname -r)
# Disables timer ticks when idle, reduces interrupt latency

# 3. Full Dynticks (CONFIG_NO_HZ_FULL)
grep CONFIG_NO_HZ_FULL /boot/config-$(uname -r)
# For isolated CPUs - no kernel ticks needed

# Boot parameter for full dynticks:
# nohz_full=2,3,4              # Enable on CPUs 2,3,4
cat /proc/cmdline | grep nohz_full

# 4. Spin-lock to Mutex conversion (PREEMPT_RT)
# Critical sections use preemptible mutexes instead of spinlocks
# Reduces worst-case latency

# 5. Interrupt handling
# PREEMPT_RT converts hardirq to threaded IRQ
cat /proc/interrupts | head -3           # IRQ threads shown
ps aux | grep -i "irq/"                  # Show IRQ threads

# 6. Scheduler precision
# SCHED_DEADLINE for deadline-based scheduling
grep SCHED_DEADLINE /boot/config-$(uname -r)

# 7. RCU grace period efficiency
# RCU offloading and NOCBS CPUs
cat /proc/cmdline | grep rcu_nocbs
```

### Latency Comparison

```bash
# Typical latency figures (cycle time from event to execution):

# Desktop/Server Kernel:
# - Max latency: 100-1000 microseconds
# - Average latency: 10-50 microseconds
# - Variability: High (context switches, interrupts)

# Standard Linux (CONFIG_PREEMPT):
# - Max latency: 10-100 microseconds
# - Average latency: 1-10 microseconds
# - Variability: Moderate

# PREEMPT_RT Kernel:
# - Max latency: 1-10 microseconds (on isolated CPUs)
# - Average latency: <1 microsecond
# - Variability: Very low

# QNX Microkernel:
# - Max latency: <1 microsecond
# - Average latency: <0.5 microseconds
# - Variability: Extremely low

# Measure latency on your system
cyclictest -p 99 -n -l 10000             # Run 10000 cycles at priority 99

# Interpretation of cyclictest output:
# min: Minimum latency observed
# avg: Average latency
# max: Maximum latency (worst-case)
```

---

## 7. Thread & Process Creation

### Linux Thread Creation

```bash
// POSIX thread creation with scheduling parameters
#include <pthread.h>
#include <sched.h>

void* thread_func(void* arg) {
  printf("Thread running\n");
  return NULL;
}

int main() {
  pthread_t tid;
  pthread_attr_t attr;
  struct sched_param param;
  
  // Initialize attribute
  pthread_attr_init(&attr);
  
  // Set policy to FIFO (realtime)
  pthread_attr_setschedpolicy(&attr, SCHED_FIFO);
  
  // Set priority
  param.sched_priority = 90;
  pthread_attr_setschedparam(&attr, &param);
  
  // Set inherit scheduling (explicit vs inherited)
  pthread_attr_setinheritsched(&attr, PTHREAD_EXPLICIT_SCHED);
  
  // Set CPU affinity
  cpu_set_t cpuset;
  CPU_ZERO(&cpuset);
  CPU_SET(0, &cpuset);  // Pin to CPU 0
  pthread_attr_setaffinity_np(&attr, sizeof(cpu_set_t), &cpuset);
  
  // Create thread
  pthread_create(&tid, &attr, thread_func, NULL);
  
  // Wait for thread
  pthread_join(tid, NULL);
  
  pthread_attr_destroy(&attr);
  return 0;
}

# Process creation (fork + exec)
pid_t pid = fork();
if (pid == 0) {
  // Child process
  execve("./app", NULL, NULL);
} else {
  // Parent process
  waitpid(pid, NULL, 0);
}

# Set priority after creation
setpriority(PRIO_PROCESS, pid, -10);
sched_setaffinity(pid, sizeof(cpu_set_t), &cpuset);
```

### QNX Thread Creation

```bash
// QNX thread creation
#include <pthread.h>
#include <sched.h>

void* thread_func(void* arg) {
  printf("QNX Thread\n");
  return NULL;
}

int main() {
  pthread_t tid;
  pthread_attr_t attr;
  struct sched_param param;
  
  pthread_attr_init(&attr);
  
  // Set priority (QNX: 1-255)
  param.sched_priority = 90;
  pthread_attr_setschedparam(&attr, &param);
  
  // Set scheduling class
  pthread_attr_setschedpolicy(&attr, SCHED_FIFO);
  
  // CPU affinity (SMP systems)
  cpu_set_t cpuset;
  CPU_ZERO(&cpuset);
  CPU_SET(0, &cpuset);
  pthread_attr_setaffinity_np(&attr, sizeof(cpu_set_t), &cpuset);
  
  // Create thread
  pthread_create(&tid, &attr, thread_func, NULL);
  
  pthread_join(tid, NULL);
  pthread_attr_destroy(&attr);
  return 0;
}

# QNX spawn command
spawn -f 99 -s f ./app                  # Spawn with FIFO priority 99

# getprio / setprio
getprio(getpid());                      // Get current priority
setprio(getpid(), 90);                  // Set priority to 90
```

### Priority Inheritance

```bash
// Priority inheritance with mutexes
// Prevents priority inversion

#include <pthread.h>

int main() {
  pthread_mutex_t mutex;
  pthread_mutexattr_t attr;
  
  pthread_mutexattr_init(&attr);
  
  // Enable priority inheritance
  pthread_mutexattr_setprotocol(&attr, PTHREAD_PRIO_INHERIT);
  
  // Alternative: PTHREAD_PRIO_PROTECT (priority ceiling)
  // pthread_mutexattr_setprotocol(&attr, PTHREAD_PRIO_PROTECT);
  // pthread_mutexattr_setprioceiling(&attr, 100);
  
  pthread_mutex_init(&mutex, &attr);
  
  // Usage
  pthread_mutex_lock(&mutex);
  // Critical section
  pthread_mutex_unlock(&mutex);
  
  pthread_mutexattr_destroy(&attr);
  pthread_mutex_destroy(&mutex);
  return 0;
}

# Protocols:
# PTHREAD_PRIO_NONE: No inheritance (default)
# PTHREAD_PRIO_INHERIT: Blocked high-priority thread raises lock holder priority
# PTHREAD_PRIO_PROTECT: Lock has fixed ceiling priority (prevents inversion)

# Real-time best practice: Use PTHREAD_PRIO_INHERIT for safety-critical code
```

### Thread-Specific Affinity

```bash
// Set affinity after thread creation
#include <sched.h>

cpu_set_t set;
CPU_ZERO(&set);
CPU_SET(0, &set);  // CPU 0
CPU_SET(1, &set);  // CPU 1

// Linux
pthread_setaffinity_np(tid, sizeof(set), &set);
pthread_getaffinity_np(tid, sizeof(set), &set);

// QNX
pthread_setaffinity_np(tid, sizeof(set), &set);
pthread_getaffinity_np(tid, sizeof(set), &set);

# Command-line affinity
taskset -cp 0,1 <PID>                   # Linux/QNX
taskset -p <PID>                        # Check affinity
```

---

## 8. Debugging & Monitoring

### Linux Scheduling Tools

```bash
# ps - Process status
ps -eo pid,tid,pri,rtprio,stat,comm     # Priority and realtime info
ps -eLf                                 # Long format with threads
ps -p <PID> -L                          # Threads of process

# top - System monitoring
top -p <PID>                            # Monitor specific process
top -H -p <PID>                         # Monitor threads of process
# Press 'f' to customize columns (PRIORITY, RR_TIME_SLICE, etc.)

# chrt - Show/change scheduling
chrt -p <PID>                           # Show scheduling class and priority
chrt -f -p 99 <PID>                     # Set FIFO priority 99
chrt -r -p 50 <PID>                     # Set RR priority 50

# taskset - CPU affinity
taskset -p <PID>                        # Show CPU affinity
taskset -cp 0,1,2 <PID>                 # Set to CPUs 0,1,2

# perf - Performance analysis
perf stat -e context-switches,cpu-migrations <command>  # Count switches
perf record -p <PID> -- sleep 10        # Record performance events
perf report                             # View results

# trace-cmd / kernelshark - Kernel tracing
trace-cmd record -p function_graph       # Trace kernel functions
kernelshark                             # GUI trace viewer

# ftrace - Kernel tracer
echo "function" > /sys/kernel/debug/tracing/current_tracer
cat /sys/kernel/debug/tracing/trace_pipe # View trace output

# Scheduling debug
cat /sys/kernel/debug/sched_debug       # Detailed scheduler info
cat /proc/sched_debug                   # (alternate location)
```

### QNX Scheduling Tools

```bash
# pidin - Process and thread information
pidin                                   # All processes
pidin -p <PID>                          # Specific process
pidin -p <PID> at                       # All threads
pidin -r                                # Run queue status
pidin partition                         # Partition info

# ps - Standard process status
ps -eo pid,pri,cls,comm                 # Priority, class, and name
ps -eLf                                 # Long format with threads

# getprio / setprio - Thread priority
getprio <PID>                           # Get priority
setprio 90 <PID>                        # Set priority

# pdebug - Attach debugger
pdebug -p <PID>                         # Attach to process

# tracelogger - Kernel event tracing
tracelogger -c -d /tmp/trace.kev        # Start tracing to file
traceparser -i /tmp/trace.kev           # Parse and view

# sloginfo - System log info
sloginfo                                # View system logs
sloginfo -w                             # Watch logs continuously

# Adaptive Partitioning monitor
partman -l                              # List partitions
cat /proc/partition/budget              # CPU budget info
```

### Performance Profiling

```bash
# Linux profiling
perf record -a -g -- sleep 30           # Record system-wide with call graphs
perf report                             # View call graph
perf stat -e cycles,instructions ./app  # Count events
perf top                                # Live profiling

# Flame graphs (performance visualization)
perf record -F 99 -a -g -- sleep 10
perf script | stackcollapse-perf.pl | flamegraph.pl > graph.svg

# Python profiling (for control algorithms)
import cProfile
cProfile.run('main()')

# C/C++ profiling with gprof
gcc -pg app.c -o app
./app
gprof app gmon.out

# Memory profiling
valgrind --tool=callgrind ./app
callgrind_annotate callgrind.out.* | head -50
```

### Trace Analysis

```bash
# Linux trace-cmd
trace-cmd record -e sched_switch -p function ./app
trace-cmd report                        # View traces

# Trace specific events
trace-cmd record -e sched:sched_switch,sched:sched_wakeup
trace-cmd report | grep sched_switch | head -20

# QNX traceparser
tracelogger -c -n 8 -b 128k             # High-res logging
traceparser -i trace.kev | grep -i context  # Context switches
traceparser -i trace.kev -f txt > trace.txt # Export to text

# Latency analysis from trace
# Extract timestamps and calculate deltas
awk '{if (prev) print $1 - prev; prev = $1}' trace.txt | sort -n
```

---

## 9. AV-Specific Use Cases

### Sensor Processing Pipeline

```bash
# Multi-stage pipeline with strict timing requirements

# Architecture:
# Camera Input (interrupt)
#   |
#   v
# [Priority 100] Image Capture Thread
#   |
#   v
# [Priority 90] Image Processing (FPGA/GPU)
#   |
#   v
# [Priority 80] Object Detection
#   |
#   v
# [Priority 70] Sensor Fusion

# Thread hierarchy setup (Linux)
#!/bin/bash
# Capture thread: High priority, pinned to CPU 0
taskset -c 0 nice -n -20 ./capture &
CAPTURE_PID=$!

# Processing thread: Priority 90, CPU 1
PID=$(pgrep process)
taskset -cp 1 $PID
setpriority PRIO_PROCESS $PID -15

# Detection thread: Priority 80, CPU 2
PID=$(pgrep detect)
taskset -cp 2 $PID
setpriority PRIO_PROCESS $PID -10

# Message passing between stages
// Use lockfree queues for IPC
// Or: ROS topics with fixed-size buffers

# QNX variant
spawn -f 100 -s f taskset -c 0 ./capture    # Camera thread
spawn -f 90 -s f taskset -c 1 ./process     # Processing thread
spawn -f 80 -s f taskset -c 2 ./detect      # Detection thread

# Deadline monitoring
cyclictest -p 99 -m -n -l 100000           # Measure deadline miss rate
```

### Decision Making Unit

```bash
# Path planning and decision making with strict latency

# Requirements:
# - <50ms decision latency
# - Priority 70 (high but not critical)
# - CPU 3 dedicated
# - Soft realtime with graceful degradation

# Setup (Linux)
#!/bin/bash
# Create cgroup for decision unit
mkdir /cgroup/cpu/planning
echo 50 > /cgroup/cpu/planning/cpu.cfs_quota_us   # 50% CPU limit
echo 100000 > /cgroup/cpu/planning/cpu.cfs_period_us

# Launch planning threads
export PATH_PLANNER_PID=$(pgrep planner)
taskset -cp 3 $PATH_PLANNER_PID
renice -5 -p $PATH_PLANNER_PID
echo $PATH_PLANNER_PID > /cgroup/cpu/planning/cgroup.procs

# Deadline tracking
deadline_ns=50000000  # 50ms
start_time=$(date +%s%N)
# ... planning logic ...
end_time=$(date +%s%N)
latency_ns=$((end_time - start_time))

if [ $latency_ns -gt $deadline_ns ]; then
  echo "DEADLINE MISS: $latency_ns > $deadline_ns"
fi
```

### Control & Actuation

```bash
# Motor control with microsecond-level jitter requirement

# Hard realtime requirements:
# - 5kHz control loop (200 μs period)
# - Max jitter: <10 μs
# - Priority 95 (hard realtime)
# - Isolated CPU core

# Linux PREEMPT_RT setup
#!/bin/bash
# Boot parameters:
# isolcpus=2 nohz_full=2 rcu_nocbs=2

# Control loop thread
#!/bin/bash
taskset -c 2 ./motor_control &
CONTROL_PID=$!

# Set FIFO priority
chrt -f -p 95 $CONTROL_PID

# Verify isolated CPU
cat /proc/sched_debug | grep "CPU 2"

// Motor control loop code
#include <time.h>
#include <sched.h>

int main() {
  struct sched_param param;
  param.sched_priority = 95;
  sched_setscheduler(0, SCHED_FIFO, &param);
  
  struct timespec next_wake;
  clock_gettime(CLOCK_MONOTONIC, &next_wake);
  
  while (1) {
    // Read sensor
    // Compute control law
    // Send actuation command
    
    // Sleep until next period (200 us)
    next_wake.tv_nsec += 200000;  // 200 us
    clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next_wake, NULL);
  }
  return 0;
}

# QNX variant
spawn -f 95 -s f ./motor_control          # Spawn FIFO priority 95
# CPU affinity set via SMP configuration or partition
```

### Safety-Critical Components

```bash
# Emergency Braking / Failsafe with guaranteed response

# Hard guarantees:
# - Emergency detection: <1ms latency (Priority 255 or highest)
# - Brake activation: <5ms
# - Health monitoring: continuous

# Architecture
# Watchdog timer (independent hardware)
#   |
#   v
# Safety Monitor [Priority 255] - monitors all critical threads
#   |
#   +--- Thread health check
#   +--- Sensor validity check
#   +--- Actuator feedback check
#
# Fallback Controller [Priority 240]
#   | (only if primary fails)
#   v
# Emergency Brake Output

// Safety monitor code
#include <signal.h>
#include <pthread.h>

#define MAX_LATENCY_NS 1000000  // 1ms

void* safety_monitor(void* arg) {
  struct sched_param param;
  param.sched_priority = 255;            // Highest priority
  pthread_setschedparam(pthread_self(), SCHED_FIFO, &param);
  
  while (1) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    
    // Check all critical threads' heartbeats
    if (check_thread_alive(sensor_thread) == FAIL ||
        check_thread_alive(decision_thread) == FAIL) {
      trigger_emergency_brake();
    }
    
    // Sleep for monitoring period (1ms)
    nanosleep(&(struct timespec){0, 1000000}, NULL);
  }
  return NULL;
}

# Linux configuration
# - Separate CPU for safety monitor
# - Memory locking (mlockall) to prevent page faults
# - Realtime priority inheritance enabled
```

---

## 10. Best Practices & Configuration

### Linux Configuration

```bash
# Boot parameters for realtime performance
# Add to /boot/grub/grub.cfg or /boot/cmdline.txt

# Full configuration line example:
# isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3 nosoftlockup kthread_cpus=0,1 irqaffinity=0,1

# Parameter explanations:
# isolcpus=2,3          # Isolate CPUs 2-3 from scheduler
# nohz_full=2,3         # Disable ticks on CPUs 2-3
# rcu_nocbs=2,3         # Offload RCU callbacks from CPUs 2-3
# nosoftlockup          # Disable lockup warnings
# kthread_cpus=0,1      # Kernel threads on CPUs 0-1
# irqaffinity=0,1       # Interrupts on CPUs 0-1

# System configuration file
# /etc/security/limits.conf - User limits
@realtime soft rtprio 99
@realtime soft memlock unlimited

# Verify realtime capability
ulimit -r                               # Real-time priority limit
ulimit -l                               # Max locked memory

# Sysctl settings
# /etc/sysctl.d/99-realtime.conf
kernel.sched_rt_period_us = 1000000
kernel.sched_rt_runtime_us = 950000     # 95% CPU for RT tasks
kernel.sched_migration_cost_ns = 5000000
kernel.timer_migration = 0              # Disable timer migration

# Apply settings
sudo sysctl -p /etc/sysctl.d/99-realtime.conf
```

### QNX Configuration

```bash
# QNX system startup configuration
# /boot/build/system.build

# SMP configuration
proc boot -n 4              # Enable 4 CPUs

# Partition configuration file
# /etc/partition.conf
[system]
cpu = 40

[safety]
cpu = 30
priority = 100

[general]
cpu = 20

# Memory configuration
[memory]
total = 2G              # Total system memory

# Load configuration
partman -c /etc/partition.conf

# Thread stack sizes
# In code:
pthread_attr_setstacksize(&attr, 64*1024);  // 64KB stack

# Process creation with options
spawn -H localhost -p 90 -s f ./app     # Priority 90, FIFO scheduling

# IPC message size
# Larger messages = higher latency but fewer context switches
# Typical: 4KB-64KB for sensor data
```

### Determinism Checklist

```bash
# Pre-deployment verification

## Memory
[ ] mlockall() enabled for critical threads?
    // Lock all memory to prevent page faults
    mlockall(MCL_CURRENT | MCL_FUTURE);

[ ] Swapping disabled?
    free | grep Swap    # Should show 0

[ ] Memory overcommit disabled (Linux)?
    cat /proc/sys/vm/overcommit_memory  # Should be 2

## CPU
[ ] CPU affinity set for all critical threads?
    taskset -p <PID>    # Verify pinning

[ ] Isolated CPUs verified?
    cat /proc/cmdline | grep isolcpus

[ ] IRQ affinity configured?
    cat /proc/irq/*/smp_affinity_list | grep -v 0,1

[ ] Load balancing disabled on isolated CPUs?
    cat /sys/kernel/debug/sched_debug | grep "cpu #"

## Scheduling
[ ] Real-time priority levels set correctly?
    ps -eo pid,pri,cls | head -20

[ ] Priority inheritance enabled for mutexes?
    // Check in code for PTHREAD_PRIO_INHERIT

[ ] No priority inversion scenarios?
    // Review critical section code

## Monitoring
[ ] Latency monitoring enabled?
    perf stat -e context-switches ./app

[ ] Deadline enforcement verified?
    # Run test load and verify no missed deadlines

[ ] Emergency failsafe tested?
    # Simulate thread failure and verify recovery

## Testing
[ ] Load testing completed?
    # Run at 95-100% load for 24 hours

[ ] Thermal stress testing?
    # Run full load continuously

[ ] Failover scenarios tested?
    # Network partition, sensor failures, etc.
```

---

## 11. Comparison Matrix

| Feature | Linux CFS | Linux RT | QNX | Notes |
|---------|-----------|----------|-----|-------|
| **Scheduler Type** | Fair queue | Fixed priority | Fixed priority | QNX: Preemptive 256 levels |
| **Max Priority Levels** | 20 (nice) + 40 (RT) | 40 (RT) | 256 | QNX: 64-255 realtime |
| **Preemption Latency** | 100-1000 μs | 10-100 μs | <1 μs | With PREEMPT_RT/isolated CPU |
| **Context Switch** | ~5 μs | ~1-5 μs | <0.5 μs | Microkernel advantage |
| **Priority Inheritance** | Available | PTHREAD_PRIO_INHERIT | Built-in | QNX: Native support |
| **CPU Affinity** | taskset/cpuset | taskset/cpuset | pthread API | Both support pinning |
| **Core Isolation** | isolcpus + cpuset | isolcpus + cpuset | Partitions | QNX: More deterministic |
| **Memory Limits** | CGroup memory | CGroup memory | Partition memory | QNX: Stricter boundaries |
| **Interrupt Handling** | Standard | Threaded IRQ | Optimized ISR/DSR | QNX: Dual-level ISR/DSR |
| **Multiprocessing** | Standard fork | Standard fork | Standard spawn | QNX: Priority aware |
| **Worst-Case Jitter** | High | Low (μs class) | Very low (<ns class) | AV requires <10 μs |
| **Memory Overhead** | ~100MB+ | ~100MB+ | ~50MB+ | Varies by configuration |
| **Real-Time Guarantees** | Soft realtime | Hard realtime* | Hard realtime | *With PREEMPT_RT + config |

---

## 12. Troubleshooting

### Debugging Scheduling Issues

```bash
# Symptom: Task not running at expected priority

# 1. Check current priority
ps -p <PID> -o pid,ni,pri,cls

# 2. Verify scheduling class
chrt -p <PID>

# 3. Check if task is blocked
cat /proc/<PID>/status | grep State

# 4. Check runqueue
cat /proc/sched_debug | grep -A 20 "runnable tasks"

# 5. Monitor context switches
perf stat -e context-switches -p <PID> -- sleep 1

# Symptom: High latency spikes

# 1. Identify source
# CPU migration, page faults, interrupts, etc.

# Monitor page faults
cat /proc/<PID>/stat | awk '{print "Major:", $11, "Minor:", $10}'

# Monitor context switches
pidstat -w 1 -p <PID>

# Monitor migrations
perf stat -e cpu-migrations -p <PID> -- sleep 1

# Monitor interrupts
cat /proc/interrupts | head
watch -n 1 "cat /proc/interrupts"

# 2. Fix high-frequency interrupts
# Bind to isolated CPU, disable irqbalance

# Symptom: Deadline misses in partition

# 1. Check partition budget
cat /proc/partition/budget

# 2. Check partition assignment
pidin partition

# 3. Increase CPU budget for partition
# Edit /etc/partition.conf and reload

# Symptom: Memory pressure

# 1. Check memory usage
free -h
cat /proc/meminfo

# 2. Check memory limit
ulimit -m
cat /cgroup/memory/mycgroup/memory.limit_in_bytes

# 3. Monitor OOM killer
dmesg | tail -20  # Look for "Out of memory"

# Enable cgroup OOM detection
cat /cgroup/memory/mycgroup/memory.oom_control
```

---

## Notes

- Linux: Flexibility and ecosystem vs. determinism tradeoff
- QNX: Designed for determinism from the ground up
- PREEMPT_RT brings Linux closer to QNX latency (but not identical)
- AV applications typically use soft/hard realtime hybrid approach
- Modern systems combine both: Linux host + QNX hypervisor layer
- Proper testing and validation critical before deployment
- Monitor long-term for memory leaks, CPU drift, deadline violations
- Always have fallback/watchdog mechanisms for safety-critical components

---

## References

- Linux kernel documentation: https://www.kernel.org/doc/
- QNX Neutrino documentation: http://qnx.com/developers/docs/
- POSIX real-time specification
- CGroup documentation: https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html
- Adaptive Partitioning for QNX
- Automotive real-time standards (AUTOSAR, ISO 26262)
