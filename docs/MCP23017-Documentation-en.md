# MCP23017 – 16-Bit I/O Expander

Contents:
1. Overview
2. Technical Data
3. Wiring
4. Class and API
5. Example
6. Notes

---

## 1. Overview

The **MCP23017** (Microchip) is a 16-bit I2C I/O expander with two 8-bit
ports, GPIOA (pins 0–7) and GPIOB (pins 8–15). Each pin is individually
configured as input or output through the IODIR direction registers, gets an
optional internal pull-up through GPPU and is written or read back through
the GPIO output latch registers.

The `Firmata-MCP23017` package wraps the expander behind a `FirmataI2C`
connection. Direction, pull-up and output settings are kept in shadow bytes
on the Smalltalk side, so per-pin operations only update the affected bit
and are then written back to the chip as a whole port byte. Reads go through
the register-based I2C format, which StandardFirmata serves without touching
the port state.

## 2. Technical Data

- 16 I/O pins in two 8-bit ports: GPIOA (pins 0–7) and GPIOB (pins 8–15).
- Direction via IODIRA/IODIRB: a bit of `0` selects output, a bit of `1`
  selects input.
- Internal pull-ups (≈100 kΩ) per pin via GPPUA/GPPUB.
- Operating voltage: **1.8 V – 5.5 V**.
- Sink/source current: **25 mA per pin**.
- I2C address range: **0x20 – 0x27** (3 address pins A0–A2; all low = 0x20).
- Power-on default: all pins input, all pull-ups disabled, output latches
  reading `1`.
- INT output: open-drain, active low (not used in this package).

## 3. Wiring

| MCP23017 | Arduino Uno |
| --- | --- |
| VCC | 5 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| A0 | GND (address 0x20) |
| A1 | GND (address 0x20) |
| A2 | GND (address 0x20) |
| GPA0–GPA7 | GPIOA pins |
| GPB0–GPB7 | GPIOB pins |

For another expander on the same bus, set the address pins accordingly, e.g.
A0 → VCC for 0x21. Use 4.7 kΩ pull-ups on SDA/SCL to VCC if not present on
the breakout board.

## 4. Class and API

`FirmataMCP23017` extends `FirmataI2CDevice` (package `Firmata-I2C`).

- Initialization: `initializeDevice` (writes IODIRA/B = 0xFF and GPPUA/B =
  0x00), `registerWithFirmata` (after wiring!), `addressWithAddressPins:`.
- Pin operations: `setPinMode:value:` (pin 0–15; `true` = output),
  `digitalWritePin:value:` (output pin), `digitalReadPin:` (input pin),
  `setPullUpPin:value:` (internal pull-up on/off).
- Port operations: `writePort:value:` (8 GPIOA or GPIOB pins at once),
  `readPort:` (0 = GPIOA, 1 = GPIOB), `startReadingPort:` (continuous
  polling), `stopReading` (halts the stream).
- Callback: `handleI2CReply:data:` (processes incoming `I2C_REPLY` data and
  updates the port input values).
- Access: `inputValueForPort:`, `outputValueForPort:`, `directionA`,
  `directionB`.

`FirmataMCP23017Constants` (class side) holds the register map
(`iodirARegister` 0x00, `iodirBRegister` 0x01, `gppuARegister` 0x0C,
`gppuBRegister` 0x0D, `gpioARegister` 0x12, `gpioBRegister` 0x13) and the
specification (`pinCount` 16, `portPinCount` 8, `portCount` 2,
`baseAddress`/`defaultAddress` 0x20, `addressCount` 8).

## 5. Example

```smalltalk
| bus expander |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

expander := FirmataMCP23017 new.
expander firmata: bus address: FirmataMCP23017Constants defaultAddress.
expander initializeDevice.
expander registerWithFirmata.

"Pin 0 on GPIOA as output, driven low"
expander setPinMode: 0 value: true.
expander digitalWritePin: 0 value: false.

"Pin 8 (GPIOB input) with internal pull-up"
expander setPinMode: 8 value: false.
expander setPullUpPin: 8 value: true.

"Write all eight GPIOA pins at once"
expander writePort: 0 value: 16r55.

"Read GPIOA into the port value and a single pin level"
expander readPort: 0.
expander inputValueForPort: 0.      "last GPIOA byte read"
expander digitalReadPin: 1.         "true if pin 1 is high"

"Stream GPIOB continuously"
expander startReadingPort: 1.
expander stopReading.
```

## 6. Notes

- **Direction bit meaning:** In the IODIR registers a bit of `0` means
  output and a bit of `1` means input. `setPinMode:value:` hides this: pass
  `true` for output and `false` for input.
- **Shadow bytes:** `directionA/B` and the output latches are kept as bytes
  in the image. `setPinMode:`, `digitalWritePin:` and `setPullUpPin:` update
  only the affected bit and write the whole port byte back, so mixed
  configurations stay consistent without re-reading the chip.
- **Pin numbering:** Pin 0–7 live in GPIOA, pin 8–15 in GPIOB. The private
  helpers `portForPin:` and `bitForPin:` map a pin index to its port and bit.
- **Reading GPIO:** `readPort:` reads the GPIOA/GPIOB register through the
  register-based I2C read format (StandardFirmata ≥ 2.5), which leaves the
  port state untouched. For input pins the value reflects the pin level, for
  output pins the driven latch value.
- **Multiple devices:** Up to 8 MCP23017 on the same I2C bus through the
  address pins. Register a separate `FirmataMCP23017` instance per chip and
  use `FirmataMCP23017 addressWithAddressPins:` to compute the address.
- **Power supply:** 25 mA per pin is the chip limit; drive higher loads
  through external driver stages or transistors.
