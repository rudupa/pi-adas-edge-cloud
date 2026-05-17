# Power Management

## Table of Contents

- [1. Power and Thermal Guidance](#1-power-and-thermal-guidance)
- [2. Per-Node Power Requirements](#2-per-node-power-requirements)
  - [Sensor Node](#sensor-node-pi-zero-w-v11)
  - [Sensor Node (QNX)](#sensor-node-qnx-pi-4--braincraft-hat)
  - [UI Node](#ui-node-pi-zero-w-v11)
  - [Compute Node](#compute-node-pi-5)
- [3. Storage Wear and Power-Safe Shutdown](#3-storage-wear-and-power-safe-shutdown)
- [4. Power Budget Summary](#4-power-budget-summary)

---

## 1. Power and Thermal Guidance

- Use stable 5V power supplies with current headroom on all nodes
- Prefer short, high-quality USB power cables for Pi Zero stability
- Add thermal management (heatsink/fan) for Pi 4/Pi 5 nodes under AI load
- Consider brownout-safe design for field deployments

## 2. Per-Node Power Requirements

### Sensor Node (Pi Zero W v1.1)
- Supply voltage: 5V via micro-USB
- Typical current draw: 150–300 mA idle, up to 500 mA under Wi-Fi + camera load
- Recommended supply: 5V / 2A minimum
- Notes:
  - Voice Bonnet adds ~50–100 mA draw during active audio
  - Use high-quality short cable to avoid voltage drop brownouts

### Sensor Node (QNX Pi 4 + BrainCraft HAT)
- Supply voltage: 5V via USB-C
- Typical current draw: 500–900 mA idle, up to 2.5 A under active processing + fan
- Recommended supply: 5V / 3A minimum
- Notes:
  - BrainCraft fan and display increase peak transients
  - Reserve thermal margin for deterministic workloads

### UI Node (Pi Zero W v1.1)
- Supply voltage: 5V via micro-USB
- Typical current draw: 150–300 mA idle, up to 500 mA under Wi-Fi + display load
- Recommended supply: 5V / 2A minimum
- Notes:
  - Pirate Audio amplifier adds up to ~600 mA per channel at 3W (speaker output)
  - Size supply to cover combined Pi Zero + amplifier peak

### Compute Node (Pi 5)
- Supply voltage: 5V via USB-C
- Typical current draw: 700 mA idle, up to 4–5 A under full CPU + Wi-Fi + orchestration load
- Recommended supply: 5V / 5A (official Raspberry Pi 5 USB-C PD supply)
- Notes:
  - Optional HAT fan adds additional transient draw
  - PoE HAT (optional) can replace USB-C supply for cleaner cabling

## 3. Storage Wear and Power-Safe Shutdown

- Use high-endurance microSD cards to minimize wear from frequent writes
- Keep logs bounded with rotation policies to reduce write amplification
- Implement a graceful shutdown handler on each node triggered via MQTT or GPIO button
- Do not cut power abruptly during active writes; risk of filesystem corruption

## 4. Power Budget Summary

| Node             | Idle (typical) | Peak (max)  | Recommended Supply |
|------------------|---------------|-------------|-------------------|
| Sensor Pi Zero W | ~200 mA       | ~600 mA     | 5V / 2A           |
| Sensor Pi 4 (QNX) | ~700 mA      | ~2.5 A      | 5V / 3A           |
| UI Pi Zero W     | ~200 mA       | ~900 mA     | 5V / 2A           |
| Compute Node Pi 5 | ~700 mA    | ~5 A        | 5V / 5A           |
