# Kernel Module Inventory

This document lists the Linux kernel configuration options required per node.

## Sensor & UI (Raspberry Pi Zero W, ARMv6l / BCM2835)

### Core
- `CONFIG_BCM2835_MBOX=y`          – Raspberry Pi mailbox (firmware communication)
- `CONFIG_BCM2835_VCHIQ=y`         – VCHI queue interface
- `CONFIG_I2C_BCM2835=y`           – I2C bus for codec/sensor control
- `CONFIG_SPI_BCM2835=y`           – SPI bus for display
- `CONFIG_GPIO_BCM2835=y`          – GPIO for LEDs and buttons
- `CONFIG_GPIOLIB_IRQCHIP=y`       – GPIO interrupt support

### Audio
- `CONFIG_SND_BCM2835=y`           – Built-in audio (fallback)
- `CONFIG_SND_SOC_WM8960=m`        – Voice Bonnet WM8960 codec (Sensor)
- `CONFIG_SND_SOC_MAX98357A=m`     – Pirate Audio MAX98357A amp (UI)
- `CONFIG_SND_SOC_SIMPLE_CARD=m`   – ASoC simple card driver

### Video / Camera (Sensor only)
- `CONFIG_V4L2_MEM2MEM_DEV=y`      – Video4Linux memory-to-memory
- `CONFIG_VIDEO_V4L2=y`            – Camera video device interface

### Display (UI only)
- `CONFIG_DRM=y`                   – Direct Rendering Manager
- `CONFIG_DRM_VC4=y`               – VideoCore IV GPU display
- `CONFIG_FB_SPI=m`                – SPI framebuffer
- `CONFIG_BACKLIGHT_CLASS_DEVICE=y`
- `CONFIG_LCD_CLASS_DEVICE=y`

### Networking
- `CONFIG_WIRELESS=y`
- `CONFIG_CFG80211=y`
- `CONFIG_MAC80211=y`              – 802.11 stack for WiFi

---

## Gateway (Raspberry Pi 4, ARMv7l / BCM2711)

### Core
- `CONFIG_ARCH_BCM2835=y`
- `CONFIG_SOC_BCM2711=y`           – Pi 4 SoC
- `CONFIG_GPIO_RASPBERRYPI=y`      – GPIO USB power control

### Wireless AP
- `CONFIG_MAC80211=y`
- `CONFIG_CFG80211=y`
- `CONFIG_NL80211_TESTMODE=y`
- `BR2_PACKAGE_HOSTAPD=y`          – WiFi Access Point daemon (Buildroot package, not a kernel option)

### Thermal / Power
- `CONFIG_THERMAL=y`
- `CONFIG_THERMAL_OF=y`
- `CONFIG_RASPBERRYPI_HWMON=y`     – Temperature monitoring
- `CONFIG_PWM_BCM2835=y`           – PWM for fan control

### Video Hardware Decode
- `CONFIG_MEDIA_SUPPORT=y`
- `CONFIG_V4L2_MEM2MEM_DEV=y`
- `CONFIG_VIDEO_RPIVID=m`          – H.264 hardware decoder

### Container / Security (future)
- `CONFIG_CGROUPS=y`
- `CONFIG_NAMESPACES=y`
- `CONFIG_SECCOMP=y`
