# ADXL345 – 3-Axis Accelerometer

Contents:
1. Overview
2. Technical Data
3. Wiring
4. Class and API
5. Example
6. Notes

---

## 1. Overview

The **ADXL345** (Analog Devices) is a 3-axis digital accelerometer with
13-bit resolution in full-resolution mode. It measures static acceleration
(gravity) as well as dynamic acceleration (motion, vibration) and delivers
results in consecutive registers per axis (`DATAX0` to `DATAZ1`, 6 bytes)
as little-endian 16-bit values.

The `Firmata-ADXL345` package wraps the sensor behind a
`FirmataI2C` connection. With `startReadingPort` the Arduino streams the
output registers continuously; each incoming `I2C_REPLY` overwrites the
last sample. Raw and scaled values are then directly accessible.

The sensor operates with a fixed sensitivity of 256 LSB/g in full-resolution
mode — regardless of the selected range. The range only affects the maximum
span, not the resolution per g.

## 2. Technical Data

- 3-axis accelerometer, 13-bit full resolution (4 mg/LSB sensitivity,
  256 LSB/g) for all ranges.
- Selectable full-scale ranges: **±2 g** (index 0), **±4 g** (index 1),
  **±8 g** (index 2), **±16 g** (index 3).
- Output data rates via `BW_RATE` register (`0x2C`): codes 0x00 (0.1 Hz)
  to 0x0F (3200 Hz), default 0x0A (100 Hz).
- 6 output registers starting at `DATAX0` (`0x32`): X0, X1, Y0, Y1, Z0, Z1
  (little-endian, signed 16-bit).
- I2C slave address: **0x53** (ALT ADDRESS high) or **0x1D** (ALT ADDRESS
  low).
- Operating voltage: 2.0–3.6 V. Power consumption: 23 µA (measurement),
  0.1 µA (standby).
- DEVID register (`0x00`) returns 0xE5 for device identification.

## 3. Wiring

| ADXL345 | Arduino Uno |
| --- | --- |
| VCC | 3.3 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| CS | VCC (for I2C mode) |
| SDO | GND (for address 0x53) |

I2C pull-ups are typically present on common breakout boards; otherwise use
4.7 kΩ on SDA/SCL to VCC. The CS pin must be tied high to enable I2C mode.
SDO determines the address: GND → 0x53, VCC → 0x1D.

## 4. Class and API

`FirmataADXL345` extends `FirmataI2CDevice` (package `Firmata-I2C`).

- Initialization: `initializeDevice` (sets the measure bit in the
  `POWER_CTL` register), `registerWithFirmata` (after wiring!).
- Sensor configuration: `setAccelerationRange:` (0–3 ↔ ±2/4/8/16 g),
  `setSampleRate:` (0x00–0x0F for 0.1 Hz to 3200 Hz).
- Reading: `startReadingPort` (continuous) or `readOnce` (single sample).
- Raw outputs: `accelX`/`accelY`/`accelZ` (signed 16-bit little-endian).
- Scaled outputs: `scaledAccelX`/`scaledAccelY`/`scaledAccelZ` (in g)
  — raw value divided by 256.0 (fixed full-resolution sensitivity).
- Sensitivity and range: `accelSensitivity` (256 LSB/g, fixed),
  `accelRange` (current range index), `sampleRate` (current code).
- Reception: `handleI2CReply:data:` processes the Arduino's 6-byte reply.
- Inherited helpers (`FirmataI2CDevice`): `firmata:address:`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataADXL345Constants` (class side) holds the registers
(`dataFormatRegister` 0x31, `bandwidthRateRegister` 0x2C,
`powerControlRegister` 0x2D, `dataX0Register` 0x32, `deviceIdRegister` 0x00),
bits (`fullResolutionBit`, `measureBit`), specification
(`accelSensitivity` 256, `deviceIdValue` 0xE5, `sensorOutputByteCount` 6)
and defaults (`defaultAddress` 0x53, `defaultAccelRange` 0,
`defaultSampleRate` 0x0A).

## 5. Example

```smalltalk
| bus sensor |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

sensor := FirmataADXL345 new.
sensor firmata: bus address: FirmataADXL345Constants defaultAddress.
sensor initializeDevice.
sensor registerWithFirmata.

"Configure range and rate (optional)"
sensor setAccelerationRange: 1.    "±4 g"
sensor setSampleRate: 16r0B.       "200 Hz"

"Start continuous streaming"
sensor startReadingPort.

"... after a few steps:"
sensor accelZ.                     "raw LE-16-bit Z value"
sensor scaledAccelZ.               "Z acceleration in g"

"Alternatively read a single sample:"
sensor readOnce.

"Stop streaming:"
sensor stopReading.
```

## 6. Notes

- **Raw values are little-endian and signed** (16-bit). The LSB is in the
  first register (`DATAX0`), the MSB in the second (`DATAX1`). This differs
  from the MPU6050 (big-endian).
- **Full-resolution mode (full_res):** Always active — sensitivity remains
  fixed at 256 LSB/g regardless of the selected range. The range only
  determines the maximum span.
- **Scaling:** `scaled*` = raw / 256.0. Example: `scaledAccelZ :=
  accelZ / 256.0`.
- **Range changes** (`setAccelerationRange:`) write bits 0–1 of the
  `DATA_FORMAT` register. The full-resolution bit (bit 3) remains set.
- **Stabilization after wake-up:** After power-on or `initializeDevice`, wait
  briefly; the sensor needs a few milliseconds to stabilize.
- **DEVID check:** The `DEVID` register (`0x00`) must return `0xE5`. If it
  does not, a communication error is present.
- **Multiple sensors:** Tie SDO high for address 0x1D and register a second
  `FirmataADXL345` instance on the same `FirmataI2C` connection.
