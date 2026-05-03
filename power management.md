# Power Management

## Table of Contents

- [1. Power and Thermal Guidance](#1-power-and-thermal-guidance)
- [2. Per-Node Power Requirements](#2-per-node-power-requirements)
  - [Sensor Node](#sensor-node-pi-zero-w-v11)
  - [UI Node](#ui-node-pi-zero-w-v11)
  - [Gateway + Master Node](#gateway--master-node-pi-4)
- [3. Storage Wear and Power-Safe Shutdown](#3-storage-wear-and-power-safe-shutdown)
- [4. Power Budget Summary](#4-power-budget-summary)

---

## 1. Power and Thermal Guidance

- Use stable 5V power supplies with current headroom on all nodes
- Prefer short, high-quality USB power cables for Pi Zero stability
- Add thermal management (heatsink/fan) for Pi 4 nodes under AI load
- Consider brownout-safe design for field deployments

## 2. Per-Node Power Requirements

### Sensor Node (Pi Zero W v1.1)
- Supply voltage: 5V via micro-USB
- Typical current draw: 150–300 mA idle, up to 500 mA under Wi-Fi + camera load
- Recommended supply: 5V / 2A minimum
- Notes:
  - Voice Bonnet adds ~50–100 mA draw during active audio
  - Use high-quality short cable to avoid voltage drop brownouts

### UI Node (Pi Zero W v1.1)
- Supply voltage: 5V via micro-USB
- Typical current draw: 150–300 mA idle, up to 500 mA under Wi-Fi + display load
- Recommended supply: 5V / 2A minimum
- Notes:
  - Pirate Audio amplifier adds up to ~600 mA per channel at 3W (speaker output)
  - Size supply to cover combined Pi Zero + amplifier peak

### Gateway + Master Node (Pi 4)
- Supply voltage: 5V via USB-C
- Typical current draw: 600 mA idle, up to 2.5–3 A under full CPU + Wi-Fi + BrainCraft load
- Recommended supply: 5V / 3A (official Raspberry Pi USB-C supply)
- Notes:
  - BrainCraft HAT fan adds ~100–200 mA during active cooling
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
| UI Pi Zero W     | ~200 mA       | ~900 mA     | 5V / 2A           |
| Gateway+Master Pi 4 | ~600 mA    | ~3 A        | 5V / 3A           |
