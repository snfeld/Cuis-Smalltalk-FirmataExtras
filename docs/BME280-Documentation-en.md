# BME280 – Humidity, Pressure & Temperature Sensor

Contents:
1. Overview
2. Technical Data
3. Wiring
4. Class and API
5. Example
6. Notes

---

## 1. Overview

The **BME280** (Bosch Sensortec) is a combined relative humidity, barometric
pressure and temperature sensor. It measures the same pressure and
temperature output as the BMP280 (20-bit big-endian registers at `0xF7` and
`0xFA`), plus a 16-bit relative humidity output at `0xFD`. The data is
compensated with two calibration blocks: the 26-byte temperature/pressure
block at `0x88` (byte 26, i.e. `0xA1`, is the unsigned humidity coefficient
`dig_H1`) and the 7-byte humidity block at `0xE1`.

The `Firmata-BME280` package extends `Firmata-BMP280` behind a
`FirmataI2C` connection. `initializeDevice` writes `CTRL_HUM` (`0xF2`)
*before* `CTRL_MEAS` (required by the chip), then the configuration and the
measurement control register, and finally reads both calibration blocks.
`startReadingPort` asks the Arduino to stream the six pressure/temperature
bytes at `0xF7` and the two humidity bytes at `0xFD`; every incoming
`I2C_REPLY` overwrites the last sample.

All six calibration coefficients (`dig_H1`..`dig_H6`) are parsed from the
nibble-packed 0xE1 block, and the humidity is compensated with the integer
formulas of the Bosch reference driver (truncating division, clamped to the
sensor range). Temperature and pressure compensation is inherited from
`FirmataBMP280`.

## 2. Technical Data

- Combined relative humidity, barometric pressure and temperature sensor.
- Humidity range: 0–100 % RH; resolution 0.008 % RH (output in Q10, so
  102400 = 100 %).
- Pressure range: 300–1100 hPa; temperature resolution 0.01 °C.
- I2C slave address: **0x76** (SDO low) or **0x77** (SDO high).
- Operating voltage: 1.71–3.6 V.
- Chip ID register (`0xD0`) returns **0x60** (unlike the BMP280's 0x58).
- Calibration: 26 bytes at `0x88` (dig_T1..T3, dig_P1..P9, dig_H1) and 7
  bytes at `0xE1` (dig_H2..dig_H6 in nibble-packed form).

## 3. Wiring

| BME280 | Arduino Uno |
| --- | --- |
| VCC | 3.3 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| SDO | GND (for address 0x76) |

I2C pull-ups are typically present on common breakout boards; otherwise use
4.7 kΩ on SDA/SCL to VCC. SDO determines the address: GND → 0x76, VCC →
0x77.

## 4. Class and API

`FirmataBME280` extends `FirmataBMP280` (package `Firmata-BMP280`).

- Initialization: `initializeDevice` (writes `CTRL_HUM` 0x01 first, then
  `config` 0x00 and `ctrl_meas` 0x27, then reads the 26 calibration bytes at
  `0x88` and the 7 humidity calibration bytes at `0xE1`),
  `registerWithFirmata` (after wiring!), optional `readChipId`.
- Reading: `startReadingPort` (continuous stream of `0xF7` and `0xFD`) or
  `readOnce` (a single sample of both).
- Raw outputs: `rawPressure`/`rawTemperature` (20-bit), `rawHumidity`
  (16-bit big-endian), `chipId`.
- Compensated outputs:
  - `temperatureCelsius`, `compensatedTemperature`, `pressureHectoPascal`,
    `pressurePascal`, `compensatedPressure` — inherited from `FirmataBMP280`.
  - `compensatedHumidity` — relative humidity as a Q10 Integer, clamped to
    [0, 102400] (102400 = 100 %).
  - `humidityPercent` — relative humidity in percent as a Float
    (`compensatedHumidity / 1024.0`).
- Calibration: `calibrationData` (26 bytes), `humidityCalibration`
  (7 bytes), `isCalibrationLoaded`, `isHumidityCalibrationLoaded`, and the
  parsed coefficients `digH1`..`digH6` (accessible for tests).
- Reception: `handleI2CReply:data:` dispatches the humidity calibration and
  humidity output replies before delegating to `FirmataBMP280`.
- Inherited helpers (`FirmataI2CDevice`): `firmata:address:`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataBME280Constants` extends `FirmataBMP280Constants` and adds
(`ctrlHumRegister` 0xF2, `humidityCalibrationRegister` 0xE1,
`humidityDataRegister` 0xFD), specification (`calibrationByteCount` 26,
`humidityCalibrationByteCount` 7, `humidityOutputByteCount` 2,
`chipIdValue` 0x60) and the default (`defaultAddress` 0x76).

## 5. Example

```smalltalk
| bus sensor |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

sensor := FirmataBME280 new.
sensor firmata: bus address: FirmataBME280Constants defaultAddress.
sensor initializeDevice.
sensor registerWithFirmata.

"Optional: chip identification"
sensor readChipId.
sensor chipId.                          "16r60"

"Start continuous streaming"
sensor startReadingPort.

"... after a few steps:"
sensor temperatureCelsius.              "temperature in C"
sensor pressureHectoPascal.             "pressure in hPa"
sensor humidityPercent.                 "relative humidity in %"

"Alternatively read a single sample:"
sensor readOnce.

"Stop streaming:"
sensor stopReading.
```

## 6. Notes

- **`CTRL_HUM` before `CTRL_MEAS`:** the BME280 only takes the humidity
  oversampling from `CTRL_HUM` (`0xF2`) if it is written before the
  measurement control register. `initializeDevice` does this in the correct
  order.
- **26 calibration bytes:** the BME280 needs the full 26 bytes of the
  0x88 block; byte 26 (register `0xA1`) holds the unsigned `dig_H1`. The
  BMP280 only needs the first 24.
- **Humidity calibration layout (`0xE1`..`0xE7`):** `dig_H2` is a little
  endian signed 16-bit value at `0xE1`, `dig_H3` unsigned at `0xE3`,
  `dig_H4` and `dig_H5` are split into signed MSB bytes (`0xE4`/`0xE6`) plus
  a nibble of the byte `0xE5` (`dig_H4` uses the low nibble, `dig_H5` the
  high nibble), and `dig_H6` is the signed byte at `0xE7`. The coefficients
  `digH1`..`digH6` are parsed accordingly.
- **Humidity output is 16-bit big-endian** at `0xFD` (MSB first).
- **Compensation is integer arithmetic** matching the Bosch reference driver:
  truncating division toward zero (`quo:`), the same `t_fine` shared by the
  temperature, pressure and humidity formulas, and clamping to the sensor
  range.
- **nil before calibration:** the compensated values answer nil until both
  calibration blocks have been received.
- **Chip ID check:** `readChipId` + `chipId` should answer `0x60`. If it
  does not, a communication error is present.
- **Multiple sensors:** Tie SDO high for address 0x77 and register a second
  `FirmataBME280` instance on the same `FirmataI2C` connection.
