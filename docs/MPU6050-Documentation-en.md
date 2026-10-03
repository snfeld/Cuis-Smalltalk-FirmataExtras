# MPU6050 — 6-axis IMU

Contents:
1. Overview
2. Technical data
3. Wiring
4. Classes and API
5. Example
6. Notes

---

## 1. Overview

The **MPU6050** (InvenSense) is a 6-axis motion sensor: a 3-axis accelerometer, a
3-axis gyroscope and a temperature sensor. All readings sit together in 14
consecutive registers starting at `ACCEL_XOUT_H` (`0x3B`), streamed with a single
continuous I2C read.

The `Firmata-MPU6050` package wraps the sensor behind a `FirmataI2C` connection.
With `startReading` the Arduino streams the output registers continuously; each
incoming `I2C_REPLY` overwrites the last sample. Raw and scaled values (g and
degrees per second) are then directly available.

In short: `accelX` = raw count ±32767, `scaledAccelX` = acceleration in g,
`scaledGyroX` = rotation rate in degrees per second.

## 2. Technical data

- Accelerometer: 3 axes, 16-bit, selectable full-scale range
  **±2 g / ±4 g / ±8 g / ±16 g** (sensitivity 16384/8192/4096/2048 LSB/g).
- Gyroscope: 3 axes, 16-bit, selectable full-scale range
  **±250 / ±500 / ±1000 / ±2000 dps** (sensitivity 131/65.5/32.8/16.4 LSB/(°/s)).
- Temperature: 16-bit, scale 340 LSB/°C, offset 36.53 °C.
- 14 consecutive output registers from 0x3B (raw accel, temperature, raw gyro,
  big-endian, 16-bit signed).
- I2C slave address: **0x68** with the AD0 pin low (otherwise 0x69);
  `whoAmI` answers 0x68.
- Internal 8 MHz clock; the sensor starts in sleep mode
  (`initializeDevice` wakes it up).

## 3. Wiring

| MPU6050 | Arduino |
| --- | --- |
| VCC | 3.3 V (breakout boards with level shifting often also 5 V) |
| GND | GND |
| SDA | A4 (Uno) / 20 (Mega) |
| SCL | A5 (Uno) / 21 (Mega) |
| AD0 | GND for address 0x68, VCC for 0x69 |
| INT (optional) | leave floating (polling happens via the Firmata step) |

I2C pull-ups are on common breakout boards; otherwise 4.7 kΩ on SDA/SCL to VCC.

## 4. Classes and API

`FirmataMPU6050` inherits from `FirmataI2CDevice` (package `Firmata-I2C`).

- Initialization: `initialize`, `initializeDevice` (activates the sensor by
  clearing the sleep bit), `registerWithFirmata` (after wiring!).
- Sensor configuration: `setAccelerationRange:` (0–3 ↔ ±2/4/8/16 g),
  `setGyroRange:` (0–3 ↔ ±250/500/1000/2000 dps).
- Reading: `startReading` (continuous) or `readOnce` (a single sample). Stop with
  `stopReading`.
- Raw outputs: `accelX`/`accelY`/`accelZ`, `gyroX`/`gyroY`/`gyroZ`,
  `temperature` (in °C).
- Scaled outputs: `scaledAccelX`/`scaledAccelY`/`scaledAccelZ` (in g),
  `scaledGyroX`/`scaledGyroY`/`scaledGyroZ` (in dps) — depending on the
  configured range.
- Sensitivities: `accelSensitivity` (LSB/g), `gyroSensitivity`
  (LSB/(°/s)); halved per range step.
- Range index: `accelRange`, `gyroRange`.
- Inherited helpers (`FirmataI2CDevice`): `firmata:address:`,
  `registerWithFirmata`, `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataMPU6050Constants` (class side) holds the registers
(`accelXHighRegister` 0x3B, `gyroXHighRegister` 0x43,
`temperatureHighRegister` 0x41, `accelConfigRegister` 0x1C,
`gyroConfigRegister` 0x1B, `configRegister` 0x1A, `smplrtDivRegister` 0x19,
`powerManagement1Register` 0x6B, `powerManagement2Register` 0x6C,
`whoAmIRegister` 0x75), power bits (`awakeValue` 0, `deviceResetBit`,
`sleepBit`, `temperatureDisableBit`), specification (`accelSensitivity` 16384,
`gyroSensitivity` 131.0, `sensorOutputByteCount` 14, `temperatureScaleFactor`
340.0, `temperatureOffset` 36.53) and the defaults (`defaultAddress` 0x68,
`defaultAccelRange` 0, `defaultGyroRange` 0).

## 5. Example

```smalltalk
| bus sensor |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

sensor := FirmataMPU6050 new.
sensor firmata: bus address: FirmataMPU6050Constants defaultAddress.
sensor initializeDevice.
sensor registerWithFirmata.

"Choose more sensitive ranges (optional)"
sensor setAccelerationRange: 1.    "+/-4 g"
sensor setGyroRange: 1.            "+/-500 dps"

"Start continuous streaming"
sensor startReading.

"... after a few steps:"
sensor accelZ.                     "raw 16-bit Z count"
sensor scaledAccelZ.               "Z acceleration in g"
sensor scaledGyroX.                "X rotation rate in dps"
sensor temperature.                "temperature in °C"

"Alternatively a single sample:"
sensor readOnce.

"Stop streaming:"
sensor stopReading.
```

## 6. Notes

- **Raw values are big-endian and signed** (16-bit). A sample is only available
  after an `I2C_REPLY`; the accessors are initially `nil` until the first reply
  has been processed.
- **Scaling:** `scaled*` = raw / sensitivity of the configured range. Example:
  `scaledAccelX := accelX / 16384.0` at ±2 g.
- **Range change** (`setAccelerationRange:`/`setGyroRange:`) writes the
  configuration register; valid indices 0–3, otherwise `error:`.
- **Temperature formula:** `raw/340.0 + 36.53` in °C.
- **Stabilization:** let the sensor settle briefly after waking up; on first use
  read `whoAmI` (0x68) as a sanity check.
- **Multiple sensors:** set AD0 to 0x69 and register a second `FirmataMPU6050`
  instance on the same `FirmataI2C` connection.
