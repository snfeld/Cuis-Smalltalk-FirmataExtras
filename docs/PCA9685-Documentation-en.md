# PCA9685 — 16-channel PWM / servo driver

Contents:
1. Overview
2. Technical data
3. Wiring
4. Classes and API
5. Example
6. Notes

---

## 1. Overview

The **PCA9685** (NXP) is a 16-channel PWM driver on the I2C bus. Each of the 16
channels produces a 12-bit PWM signal (4096 steps per period) and can drive
servos, LEDs, motor controllers or other pulse-controlled loads. The chip can
even drive up to 64 outputs with several cascaded chips.

The `Firmata-PCA9685` package wraps the chip behind a `FirmataI2C` connection:
register access runs over the Arduino (I2C SYSEX), and the servo helper
`setServoOnChannel:angle:` converts angles into pulse widths.

## 2. Technical data

- 16 independent PWM channels, 12-bit resolution (0–4095).
- Internal oscillator: 25 MHz; PWM frequency programmable (typically 40–1000 Hz,
  default 50 Hz; the usable range is set by the prescale resolution).
- I2C slave address: **0x40** with grounded address pins A0–A5 (via
  `FirmataPCA9685Constants defaultAddress`), up to 62 addresses.
- Values at or above **4096** force fully on; negative values turn the channel
  off.
- Individual channels: ON/OFF phase registers (4 registers per channel from 0x06).

## 3. Wiring

| PCA9685 | Arduino |
| --- | --- |
| VCC | 3.3 V (or 5 V on logic-level-compatible boards) |
| GND | GND (common with Arduino and output supply) |
| SDA | A4 (Uno) / 20 (Mega) — the StandardFirmata board pin |
| SCL | A5 (Uno) / 21 (Mega) |
| V+ (if present) | external supply for the outputs (servos!) |
| A0–A5 | GND for address 0x40, otherwise another address |

For servos, power the **servo supply separately** (5 V, enough current!) and
connect all grounds. I2C pull-ups are present on most breakout boards.

## 4. Classes and API

`FirmataPCA9685` inherits from `FirmataI2CDevice` (package `Firmata-I2C`).

- Initialization: `initialize`, `initializeDevice` (defines Mode1/Mode2, enables
  register auto-increment, programs the PWM frequency to match `frequency`, and
  clears all outputs).
- PWM: `setPWMOnChannel:value:`, `setAllPWM:`, `setFrequency:`,
  `prescaleForFrequency:`.
- Servos: `setServoOnChannel:angle:`,
  `setServoOnChannel:angle:minPulse:maxPulse:`,
  `pwmCountsForServoAngle:minPulse:maxPulse:`, `pwmCountsForMicroseconds:`.
- Access: `frequency` / `frequency:`, `numberOfChannels`.
- Inherited helpers (`FirmataI2CDevice`): `firmata:address:`,
  `registerWithFirmata`, `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.
- `handleI2CReply:data:` is deliberately empty here (write-only chip).

`FirmataPCA9685Constants` (class side) holds the registers (e.g.
`mode1Register`, `mode2Register`, `preScaleRegister`, `led0OnLowRegister`,
`allLedOnLowRegister`, `allLedOffLowRegister`), mode bits (`sleepBit`,
`restartBit`, `mode1Default` = 0x20 auto-increment, `mode2Default`) and
specification
(`numberOfChannels` = 16, `resolutionSteps` = 4096,
`oscillatorFrequency` = 25 MHz, `channelRegisterStep` = 4) plus the defaults
(`defaultAddress` = 0x40, `defaultFrequency` = 50 Hz,
`defaultMinPulseMicroseconds` = 544, `defaultMaxPulseMicroseconds` = 2400).

## 5. Example

```smalltalk
| bus driver |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

driver := FirmataPCA9685 new.
driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
driver initializeDevice.                     "modes, auto-increment, 50 Hz"

driver setPWMOnChannel: 0 value: 2048.      "LED channel 0: half brightness"
driver setPWMOnChannel: 1 value: -1.        "channel 1 off"
driver setAllPWM: 0.                        "all off"

"Servo on channel 2 at 90 degrees"
driver setServoOnChannel: 2 angle: 90.

"Servo with a custom pulse range (500 us .. 2500 us)"
driver setServoOnChannel: 3 angle: 30 minPulse: 500 maxPulse: 2500.

"A different PWM frequency (60 Hz) is programmed the same way"
driver setFrequency: 60.
```

## 6. Notes

- **`initializeDevice` is required once:** without it the MODE1 auto-increment
  bit is off, so a register write that carries the low *and* high phase byte
  (every `setPWMOnChannel:value:` and `setServoOnChannel:angle:`) loses its high
  byte on the chip and the channel gets far too short a pulse — the servos then
  simply do not move. It also programs the oscillator, because the chip powers up
  at prescale 30 (~196.9 Hz) while the counts are computed for `frequency`.
- **Value range:** 0–4095 sets the ON/OFF phase pair; ≥ 4096 = fully on,
  < 0 = fully off.
- **Frequency change** goes through sleep–prescale–wake–restart; use
  `setFrequency:` instead of direct register access. A servo never moves
  correctly between `initializeDevice` and the first `setFrequency:`; call
  `setFrequency:` only to change the frequency afterwards.
- **Angle clamping:** `setServoOnChannel:angle:` clamps to 0–180°; the pulse
  width follows linearly between `minPulse` and `maxPulse` (default 544/2400 µs,
  the StandardFirmata servo convention).
- **Write-only:** the chip is only written; `handleI2CReply:data:` stays empty
  and nothing is read.
- **Multiple chips:** set the A0–A5 address pins; register one `FirmataPCA9685`
  instance per chip on the same `FirmataI2C` connection.
