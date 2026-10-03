# BMP280 – Barometric Pressure & Temperature Sensor

Contents:
1. Overview
2. Technical Data
3. Wiring
4. Class and API
5. Example
6. Notes

---

## 1. Overview

The **BMP280** (Bosch Sensortec) is a barometric pressure and temperature
sensor. It measures absolute pressure in the 300–1100 hPa range and
delivers the result in three big-endian 20-bit output registers starting at
`0xF7` (pressure MSB, LSB, XLSB), followed by the three temperature
registers at `0xFA`. The raw 20-bit counts are compensated with factory
calibration coefficients stored in a 24-byte block at `0x88`.

The `Firmata-BMP280` package wraps the sensor behind a `FirmataI2C`
connection. `initializeDevice` writes the configuration and the measurement
control register once (oversampling x1, normal mode) and reads the
calibration block. With `startReadingPort` the Arduino streams the six
output bytes continuously; each incoming `I2C_REPLY` overwrites the last
sample. Scaled values are then directly accessible.

The compensation follows the integer formulas of the Bosch reference driver
(C integer division, clamped to the sensor range), so the results match the
datasheet calculations exactly.

## 2. Technical Data

- Combined barometric pressure and temperature sensor.
- Pressure range: 300–1100 hPa; output up to 20-bit, big-endian (MSB first).
- Absolute temperature accuracy: ±1.0 °C; resolution 0.01 °C.
- Pressure resolution: 0.01 hPa (output unit); typical RMS noise well below
  1 hPa.
- I2C slave address: **0x76** (SDO low) or **0x77** (SDO high).
- Operating voltage: 1.71–3.6 V.
- Chip ID register (`0xD0`) returns **0x58** for identification.
- 24 calibration bytes at `0x88` (dig_T1..T3, dig_P1..P9).

## 3. Wiring

| BMP280 | Arduino Uno |
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

`FirmataBMP280` extends `FirmataI2CDevice` (package `Firmata-I2C`).

- Initialization: `initializeDevice` (writes `config` 0x00 and `ctrl_meas`
  0x27, then reads the 24 calibration bytes), `registerWithFirmata` (after
  wiring!), optional `readChipId`.
- Reading: `startReadingPort` (continuous) or `readOnce` (single sample of
  the six output bytes at `0xF7`).
- Raw outputs: `rawPressure`/`rawTemperature` (20-bit big-endian integer
  counts), `chipId` (after `readChipId`).
- Compensated outputs:
  - `compensatedTemperature` — 0.01 °C as an Integer, clamped to
    [-4000, 8500] (−40.00 °C to 85.00 °C).
  - `temperatureCelsius` — degrees Celsius as a Float.
  - `compensatedPressure` — pressure in Pascal as an Integer, clamped to
    [30000, 110000].
  - `pressurePascal` — same as `compensatedPressure`.
  - `pressureHectoPascal` — pressure in hPa as a Float.
- Calibration: `calibrationData` (24 bytes), `isCalibrationLoaded`.
- Internal: `tFine` (fine temperature shared by both compensation formulas).
- Reception: `handleI2CReply:data:` dispatches chip-id, calibration and
  output replies.
- Inherited helpers (`FirmataI2CDevice`): `firmata:address:`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataBMP280Constants` (class side) holds the registers
(`calibrationRegister` 0x88, `chipIdRegister` 0xD0, `configRegister` 0xF5,
`ctrlMeasRegister` 0xF4, `dataRegister` 0xF7, `resetRegister` 0xE0,
`statusRegister` 0xF3), the configuration (`configValue` 0x00,
`ctrlMeasValue` 0x27), specification (`chipIdValue` 0x58,
`calibrationByteCount` 24, `sensorOutputByteCount` 6) and the default
(`defaultAddress` 0x76).

## 5. Example

```smalltalk
| bus sensor |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

sensor := FirmataBMP280 new.
sensor firmata: bus address: FirmataBMP280Constants defaultAddress.
sensor initializeDevice.
sensor registerWithFirmata.

"Optional: chip identification"
sensor readChipId.
sensor chipId.                          "16r58"

"Start continuous streaming"
sensor startReadingPort.

"... after a few steps:"
sensor temperatureCelsius.              "temperature in C"
sensor pressureHectoPascal.             "pressure in hPa"

"Alternatively read a single sample:"
sensor readOnce.

"Stop streaming:"
sensor stopReading.
```

## 6. Notes

- **20-bit values are big-endian:** pressure = pressureMSB, pressureLSB,
  pressureXLSB ordered MSB first; the low nibble of the XLSB byte is always
  zero. The raw integer is `((MSB << 16) + (LSB << 8) + XLSB) >> 4`.
- **Output order:** the six output bytes at `0xF7` are pressure MSB, LSB,
  XLSB, then temperature MSB, LSB, XLSB. `rawPressure` and `rawTemperature`
  unpack them accordingly (indices 1 and 4).
- **Compensation is integer arithmetic** matching the Bosch reference driver:
  truncating division toward zero (`quo:`), the same `t_fine` shared by the
  temperature and pressure formulas, and clamping to the sensor range.
- **nil before calibration:** `temperatureCelsius`, `compensatedPressure`
  and `tFine` answer nil until the calibration block has been received.
  After a reset, call `initializeDevice` again or wait for the next reply.
- **Chip ID check:** `readChipId` + `chipId` should answer `0x58`. If it
  does not, a communication error is present.
- **Registers `0xF7` vs. Firmata sysex end** `0xF7`: In the tests both
  appear in byte arrays; they are unrelated. The output register `0xF7` is
  only a chip register address on the I2C bus.
- **Multiple sensors:** Tie SDO high for address 0x77 and register a second
  `FirmataBMP280` instance on the same `FirmataI2C` connection.
