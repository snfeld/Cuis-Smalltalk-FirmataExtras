# Firmata for Cuis-Smalltalk

Cuis-Smalltalk implementation of the [Firmata protocol](https://github.com/firmata/protocol).
Talk to an Arduino (or any Firmata host) from Cuis over a serial port or a TCP/IP
network connection, including full I2C device support.

## Modules

| Package | Purpose |
|---------|---------|
| `Firmata` | Core protocol: pin modes (input, output, PWM, servo), digital and analog I/O, servo control, firmware-version query, system reset and a background stepping process that keeps reading the bus. Uses the standard `SerialPort` class for a USB/serial connection (`connectOnPort:baudRate:`). This package has to be downloaded from the Cuis-Smalltalk-Firmata repository (branch: fix). |
| `Firmata-I2C` | I2C layer of the Firmata protocol (SYSEX `I2C_CONFIG`/`I2C_REQUEST`/`I2C_REPLY`). Adds the low-level I2C messages and the abstract device base class `FirmataI2CDevice` plus its device registry. Requires `Firmata`. |
| `Firmata-PCA9685` | Driver for the PCA9685 16-channel PWM / servo driver (I2C). Builds on `Firmata-I2C`. |
| `Firmata-MPU6050` | Driver for the MPU6050 inertial measurement unit — accelerometer, gyroscope and temperature (I2C). Builds on `Firmata-I2C`. |
| `Firmata-ADXL345` | Driver for the ADXL345 three-axis digital accelerometer (I2C). Full-resolution mode, fixed 4 mg/LSB sensitivity. Builds on `Firmata-I2C`. |
| `Firmata-PCF8574` | Driver for the PCF8574 8-bit I/O expander (I2C). Register-less reads avoid port corruption on StandardFirmata. Builds on `Firmata-I2C`. |
| `Firmata-BMP280` | Driver for the Bosch BMP280 barometric pressure and temperature sensor (I2C). Integer compensation follows the Bosch reference driver; 20-bit big-endian outputs at `0xF7`/`0xFA`. Builds on `Firmata-I2C`. |
| `Firmata-BME280` | Driver for the Bosch BME280 humidity, pressure and temperature sensor (I2C). Extends `Firmata-BMP280` with the 16-bit humidity output and the nibble-packed 0xE1 humidity calibration. Builds on `Firmata-BMP280`. |
| `Firmata-MCP23017` | Driver for the MCP23017 16-bit I/O expander (I2C). Two 8-bit ports with per-pin direction, pull-up and output latch shadow bytes. Builds on `Firmata-I2C`. |
| `Firmata-MPU9250` | Driver for the MPU-9250 nine-axis IMU (I2C). Extends `Firmata-MPU6050` with the correct wake-up register and temperature formula plus the AK8963 magnetometer on the I2C bypass with microtesla scaling and heading. Builds on `Firmata-MPU6050`. |
| `Firmata-Servo` | High-level servo control on top of the Firmata servo protocol: configurable angular speed (degrees per second) with step-wise ramping in a background process, 180° and 270° servos (incl. restricted and inverted mount ranges), and an abstract position-to-angle mapping. Transport via `FirmataPinServo` (direct pin) or `FirmataPCA9685Servo` (PCA9685 channel over I2C). Requires `Firmata`, builds on `Firmata-PCA9685`. |
| `Firmata-Net` | Firmata over TCP/IP using `SocketStream` (Network-Kernel). `FirmataNet` / `FirmataNetI2C` talk to an Arduino running StandardFirmataEthernet/WiFi or a serial-to-TCP bridge. `FirmataNetPort` wraps the socket as a byte transport. Requires `Firmata` and `Network-Kernel`. |
| `Tests-Firmata*` | Test suites, one per package (`Tests-Firmata-I2C`, `Tests-Firmata-PCA9685`, `Tests-Firmata-MPU6050`, `Tests-Firmata-ADXL345`, `Tests-Firmata-PCF8574`, `Tests-Firmata-BMP280`, `Tests-Firmata-BME280`, `Tests-Firmata-MCP23017`, `Tests-Firmata-MPU9250`, `Tests-Firmata-Servo`, `Tests-Firmata-Net`). |

## Loading

Cuis packages are loaded from the package browser or with:

```smalltalk
Feature require: #'Firmata'."            base protocol (serial port)"
"plus, as needed:"
Feature require: #'Firmata-I2C'.        "I2C support"
Feature require: #'Firmata-PCA9685'.    "PCA9685 16-ch PWM/servo driver"
Feature require: #'Firmata-MPU6050'.    "MPU6050 IMU"
Feature require: #'Firmata-ADXL345'.    "ADXL345 accelerometer"
Feature require: #'Firmata-PCF8574'.    "PCF8574 8-bit I/O expander"
Feature require: #'Firmata-BMP280'.    "BMP280 pressure/temperature sensor"
Feature require: #'Firmata-BME280'.    "BME280 humidity/pressure/temperature sensor"
Feature require: #'Firmata-MCP23017'.  "MCP23017 16-bit I/O expander"
Feature require: #'Firmata-MPU9250'.   "MPU-9250 9-axis IMU + magnetometer"
Feature require: #'Firmata-Servo'.     "high-level servo control (speed, ranges)"
Feature require: #'Firmata-Net'.        "TCP/IP transport (needs Network-Kernel)"
```

On the Arduino side, upload **StandardFirmata** (serial) or **StandardFirmataEthernet** /
**StandardFirmataWiFi** (network) from the Arduino IDE as usual.

## Documentation

The documentation is available in six languages (German, English, Spanish, French,
Chinese, Japanese). Detailed documentation, one file per language:

- [Dokumentation-de.md](docs/Dokumentation-de.md) — Deutsch
- [Documentation-en.md](docs/Documentation-en.md) — English
- [Documentación-es.md](docs/Documentaci%C3%B3n-es.md) — Español
- [Documentation-fr.md](docs/Documentation-fr.md) — Français
- [文档-zh.md](docs/%E6%96%87%E6%A1%A3-zh.md) — 中文
- [ドキュメント-ja.md](docs/%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88-ja.md) — 日本語

Device documentation, also in six languages:

- PCA9685 16-channel PWM/servo driver: [PCA9685-Dokumentation-de.md](docs/PCA9685-Dokumentation-de.md) · [PCA9685-Documentation-en.md](docs/PCA9685-Documentation-en.md) · [PCA9685-Documentación-es.md](docs/PCA9685-Documentaci%C3%B3n-es.md) · [PCA9685-Documentation-fr.md](docs/PCA9685-Documentation-fr.md) · [PCA9685-文档-zh.md](docs/PCA9685-%E6%96%87%E6%A1%A3-zh.md) · [PCA9685-ドキュメント-ja.md](docs/PCA9685-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88-ja.md)
- MPU6050 IMU (accelerometer, gyroscope, temperature): [MPU6050-Dokumentation-de.md](docs/MPU6050-Dokumentation-de.md) · [MPU6050-Documentation-en.md](docs/MPU6050-Documentation-en.md) · [MPU6050-Documentación-es.md](docs/MPU6050-Documentaci%C3%B3n-es.md) · [MPU6050-Documentation-fr.md](docs/MPU6050-Documentation-fr.md) · [MPU6050-文档-zh.md](docs/MPU6050-%E6%96%87%E6%A1%A3-zh.md) · [MPU6050-ドキュメント-ja.md](docs/MPU6050-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88-ja.md)
- ADXL345 accelerometer (3-axis, full resolution): [ADXL345-Dokumentation-de.md](docs/ADXL345-Dokumentation-de.md) · [ADXL345-Documentation-en.md](docs/ADXL345-Documentation-en.md) · [ADXL345-Documentación-es.md](docs/ADXL345-Documentaci%C3%B3n-es.md) · [ADXL345-Documentation-fr.md](docs/ADXL345-Documentation-fr.md) · [ADXL345-文档-zh.md](docs/ADXL345-%E6%96%87%E6%A1%A3-zh.md) · [ADXL345-ドキュメント-ja.md](docs/ADXL345-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88-ja.md)
- PCF8574 I/O expander (8-bit quasi-bidirectional): [PCF8574-Dokumentation-de.md](docs/PCF8574-Dokumentation-de.md) · [PCF8574-Documentation-en.md](docs/PCF8574-Documentation-en.md) · [PCF8574-Documentación-es.md](docs/PCF8574-Documentaci%C3%B3n-es.md) · [PCF8574-Documentation-fr.md](docs/PCF8574-Documentation-fr.md) · [PCF8574-文档-zh.md](docs/PCF8574-%E6%96%87%E6%A1%A3-zh.md) · [PCF8574-ドキュメント-ja.md](docs/PCF8574-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88-ja.md)
- BMP280 barometric pressure and temperature sensor: [BMP280-Dokumentation-de.md](docs/BMP280-Dokumentation-de.md) · [BMP280-Documentation-en.md](docs/BMP280-Documentation-en.md) · [BMP280-Documentación-es.md](docs/BMP280-Documentaci%C3%B3n-es.md) · [BMP280-Documentation-fr.md](docs/BMP280-Documentation-fr.md) · [BMP280-文档-zh.md](docs/BMP280-%E6%96%87%E6%A1%A3-zh.md) · [BMP280-ドキュメント-ja.md](docs/BMP280-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88-ja.md)
- BME280 humidity, pressure and temperature sensor: [BME280-Dokumentation-de.md](docs/BME280-Dokumentation-de.md) · [BME280-Documentation-en.md](docs/BME280-Documentation-en.md) · [BME280-Documentación-es.md](docs/BME280-Documentaci%C3%B3n-es.md) · [BME280-Documentation-fr.md](docs/BME280-Documentation-fr.md) · [BME280-文档-zh.md](docs/BME280-%E6%96%87%E6%A1%A3-zh.md) · [BME280-ドキュメント-ja.md](docs/BME280-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88-ja.md)
- MCP23017 I/O expander (16-bit, two 8-bit ports): [MCP23017-Dokumentation-de.md](docs/MCP23017-Dokumentation-de.md) · [MCP23017-Documentation-en.md](docs/MCP23017-Documentation-en.md) · [MCP23017-Documentación-es.md](docs/MCP23017-Documentaci%C3%B3n-es.md) · [MCP23017-Documentation-fr.md](docs/MCP23017-Documentation-fr.md) · [MCP23017-文档-zh.md](docs/MCP23017-%E6%96%87%E6%A1%A3-zh.md) · [MCP23017-ドキュメント-ja.md](docs/MCP23017-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88-ja.md)
- MPU-9250 nine-axis IMU (accelerometer, gyroscope, magnetometer): [MPU9250-Dokumentation-de.md](docs/MPU9250-Dokumentation-de.md) · [MPU9250-Documentation-en.md](docs/MPU9250-Documentation-en.md) · [MPU9250-Documentación-es.md](docs/MPU9250-Documentaci%C3%B3n-es.md) · [MPU9250-Documentation-fr.md](docs/MPU9250-Documentation-fr.md) · [MPU9250-文档-zh.md](docs/MPU9250-%E6%96%87%E6%A1%A3-zh.md) · [MPU9250-ドキュメント-ja.md](docs/MPU9250-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88-ja.md)
- Servo control (angular speed, 180°/270°, mount ranges): [Servo-Dokumentation-de.md](docs/Servo-Dokumentation-de.md) · [Servo-Documentation-en.md](docs/Servo-Documentation-en.md) · [Servo-Documentación-es.md](docs/Servo-Documentaci%C3%B3n-es.md) · [Servo-Documentation-fr.md](docs/Servo-Documentation-fr.md) · [Servo-文档-zh.md](docs/Servo-%E6%96%87%E6%A1%A3-zh.md) · [Servo-ドキュメント-ja.md](docs/Servo-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88-ja.md)


