# Sailfish OS port to Sony Xperia Nagara devices

**Status:** Testing

This repository contains documentation and hosts the issues.

## Documentation

See [Wiki](https://github.com/sailfishos-sony-nagara/main/wiki) for documents. These include users guides and development documents.

## Current state

Port is based on Lineage 21 with Sony stock-based drivers. Linux kernel: 5.10

### Supported devices

The port requires an unlockable bootloader and targets the following models:

- Xperia 1 IV
  - **Codename**: PDX223
  - **Models**:
    - **XQ-CT54**: SIM + eSIM variant; images released and tested
    - **XQ-CT72**: Dual physical SIM; expected to work — open an issue if you have this device to help track its status
   
- Xperia 5 IV
  - **Codename**: PDX224
  - **Models**:
    - **XQ-CQ54**: SIM + eSIM variant; images will be released soon, with some testing performed 
    - **XQ-CQ72**: Dual physical SIM; expected to work — open an issue if you have this device to help track its status

For other models of these phones, please contact the developers by opening an issue or via [FSO](https://forum.sailfishos.org).

### Software stack

- Jolla Store access
- Storage encryption (hardware backed)
- Kernel and OS OTA updates

### Working hardware

- Display
- Touch, multitouch
- LED
- Audio
- Bluetooth
- Calls (earpiece, speaker, wired and Bluetooth headphones)
- GPS
- WLAN (connect and hotspot)
- Cellular network: voice, data, SMS
- VoLTE: voice, SMS
- Camera: 1 (out of 3) back camera and front camera
- Keys (Vol +/-, camera, power)
- USB charging
- Wired headphones
- Wireless Charging
- Fingerprint
- Sensors: light, proximity, gyroscope, acceloremeter, compass, pickup
- Vibrator
- SD card
- Double tap to wake

**Critical issues**: [Critical](https://github.com/sailfishos-sony-nagara/main/issues?q=is%3Aissue%20state%3Aopen%20label%3Acritical)

**Current issues**: [All issues](https://github.com/sailfishos-sony-nagara/main/issues)
