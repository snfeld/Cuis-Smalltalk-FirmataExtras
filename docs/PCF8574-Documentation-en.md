# PCF8574 – 8-Bit I/O Expander

Contents:
1. Overview
2. Technical Data
3. Wiring
4. Class and API
5. Example
6. Notes

---

## 1. Overview

The **PCF8574** (NXP/Texas Instruments) is an 8-bit quasi-bidirectional I/O
expander communicating over I2C. Unlike register-based sensors, there is **no
register addressing** — a single byte write or read controls the entire port
(all 8 pins).

Each pin is quasi-bidirectional: writing `1` configures the pin as an input
with an internal weak pull-up; writing `0` drives the pin low as an output.
To read inputs, all pins must first be set to `1` before a port read.

The `Firmata-PCF8574` package wraps the expander behind a `FirmataI2C`
connection. The `readPort` method uses a register-less I2C read format
(StandardFirmata ≥ 2.5) to avoid corrupting the port state.

## 2. Technical Data

- 8-bit quasi-bidirectional I/O pins: no register addressing, a single byte
  controls the entire port.
- Operating voltage: **2.6 V – 6 V**.
- Power consumption: **100 µA** max.
- Sink current: **25 mA per pin**.
- I2C address range: **0x20 – 0x27** (3 address pins A0–A2; all low = 0x20).
- Power-on default: all pins high (input mode).
- INT output: open-drain, active low (not used in this package).

## 3. Wiring

| PCF8574 | Arduino Uno |
| --- | --- |
| VCC | 5 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| A0 | GND (address 0x20) |
| A1 | GND (address 0x20) |
| A2 | GND (address 0x20) |
| P0–P7 | I/O pins |

For a second expander on the same I2C bus, tie A0 to VCC (address 0x21).
Use 4.7 kΩ pull-ups on SDA/SCL to VCC if not present on the breakout board.

## 4. Class and API

`FirmataPCF8574` extends `FirmataI2CDevice` (package `Firmata-I2C`).

- Initialization: `initializeDevice` (configures the I2C settings),
  `registerWithFirmata` (after wiring!).
- Writing: `writePort:` (sends an 8-bit byte to the entire port),
  `digitalWritePin:value:` (sets a single pin; reads the current port state
  and modifies only the affected bit).
- Reading: `readPort` (register-less I2C read; result in `inputValue`),
  `digitalReadPin:` (returns `true`/`false` for the specified pin).
- Streaming: `startReadingPort` (starts continuous polling via the Firmata
  step), `stopReading` (halts the stream).
- Callback: `handleI2CReply:data:` (processes incoming `I2C_REPLY` data and
  updates `inputValue`/`outputValue`).

`FirmataPCF8574Constants` (class side) holds `portRegister` (0),
`pinCount` (8), `defaultAddress` (0x20), `allPinsHigh` (0xFF).

## 5. Example

```smalltalk
| bus expander |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

expander := FirmataPCF8574 new.
expander firmata: bus address: FirmataPCF8574Constants defaultAddress.
expander initializeDevice.
expander registerWithFirmata.

"Configure all pins as inputs"
expander writePort: 16rFF.

"Pins 0–3 as outputs (low), pins 4–7 as inputs"
expander writePort: 16r0F.

"Set a single pin"
expander digitalWritePin: 0 value: true.

"Read the port"
expander readPort.
expander inputValue.               "last port byte read"

"Read a single pin"
expander digitalReadPin: 4.         "true if pin 4 is high"

"Start / stop continuous polling"
expander startReadingPort.
expander stopReading.
```

## 6. Notes

- **Quasi-bidirectional pins:** Writing `1` configures a pin as an input
  with an internal weak pull-up. Writing `0` drives the pin low as an output.
  There are no direction or configuration registers as with other I/O
  expanders.
- **Reading inputs:** Before reading, all pins must be set to `1`
  (`writePort: 16rFF`), otherwise the pins will drive the low level of the
  last output value and a correct input signal is impossible.
- **Register-less read:** The `readPort` method uses a register-less I2C
  read format (StandardFirmata ≥ 2.5, argc ≠ 6). This prevents a
  accidentally sent register byte from corrupting the port state.
- **Multiple devices:** Up to 8 PCF8574 on the same I2C bus via different
  addresses (A0–A2). Register a separate `FirmataPCF8574` instance for each
  device.
- **No internal register map:** There is no register map as with
  register-based I2C devices. Every write/read operation acts directly on
  the 8 I/O pins.
- **Power supply:** The PCF8574 consumes max. 100 µA; for higher loads (up
  to 25 mA sink) use external driver stages.
