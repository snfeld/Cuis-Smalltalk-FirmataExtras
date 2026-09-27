# Firmata for Cuis-Smalltalk

Contents:
1. What is Firmata?
2. Prerequisites and installation
3. Connection and background processing
4. API overview
5. Usage guide with examples
6. Adding a new I2C device
7. Cuis-specific notes and pitfalls

---

## 1. What is Firmata?

Firmata is an open, protocol-based way to control a microcontroller (e.g. an
Arduino board) from a host computer. The **StandardFirmata** firmware runs on the
Arduino; the host (here a Cuis-Smalltalk image) sends compact byte commands over
a serial connection (USB) or a TCP/IP network, and the Arduino responds with
readings and status messages. The interface stays the same regardless of which
pins or I2C devices are attached.

The protocol works with 7-bit values: every number is transmitted as an LSB/MSB
pair. Complex extensions (like I2C) use the SYSEX mechanism: a message starts
with `START_SYSEX` (`0xF0`) and ends with `END_SYSEX` (`0xF7`). This package
implements the full standard, including the I2C SYSEX commands.

## 2. Prerequisites and installation

**On the Arduino** (Arduino IDE, *Firmata* library by the Smalltalk community):

- `StandardFirmata` for USB/serial.
- `StandardFirmataEthernet` or `StandardFirmataWiFi` for network operation.
- For custom firmware logic: `ConfigurableFirmata` (all examples and tests in
  this project are byte-exact against these sketches).

**In Cuis-Smalltalk**, load the packages via the package browser or with:

```smalltalk
Feature require: #'Firmata'.            "core protocol (serial port)"
Feature require: #'Firmata-I2C'.        "I2C support"
Feature require: #'Firmata-PCA9685'.    "PCA9685 16-channel PWM/servo driver"
Feature require: #'Firmata-MPU6050'.    "MPU6050 IMU"
Feature require: #'Firmata-Servo'.      "high-level servo control (speed, ranges)"
Feature require: #'Firmata-Net'.        "TCP/IP transport (needs Network-Kernel)"
```

Dependencies resolve automatically. For `Firmata-Net`, the `Network-Kernel`
package must be installed (sequence above: `Network-Kernel` first, then
`Firmata-Net`).

**Wiring basics:** common ground for all signals; for I2C additionally pull-up
resistors (typically 4.7 kΩ) from `SDA`/`SCL` to `VCC` — most breakout boards
already carry them.

## 3. Connection and background processing

Each connection class (`Firmata`, `FirmataI2C`, `FirmataNet`, `FirmataNetI2C`)
holds a `port` (the byte transport) and a background process that polls the
connection continuously:

- `connectOnPort:baudRate:` — serial connection (classes `Firmata`, `FirmataI2C`).
- `connectToHost:port:` — TCP/IP connection (classes `FirmataNet`, `FirmataNetI2C`).
- `startSteppingProcess` — starts the poller; called automatically on connect.
- `step` / `stepTime` — one poll step, respectively its interval in milliseconds.
  `step` reads all pending bytes via `processInput`. A read error sets
  `port := nil`, which marks the connection as closed and stops the background
  process by itself.
- `stopSteppingProcess` — stops the poller (called by `disconnect`).
- `disconnect` — stops the poller, closes the port, sets `port := nil` and
  resets the protocol state. Safe to call repeatedly.
- `isConnected` — `^port notNil`.
- `isFirmataInstalled` — sends version queries until an answer arrives (max
  5 seconds).

## 4. API overview

### `Firmata` — core protocol (package `Firmata`)

- Lifecycle/connection: `connectOnPort:baudRate:`, `disconnect`, `isConnected`,
  `controlConnection`, `controlFirmataInstallation`.
- Background process: `startSteppingProcess`, `step`, `stepTime`,
  `stopSteppingProcess`.
- Receiving: `processInput`, `parseCommandHeader:`, `parseData:`, `parseSysex:`,
  `parsingSysex`.
- Status: `isFirmataInstalled`, `version`, `majorVersion`, `minorVersion`,
  `nameSymbol`, `port`.
- Pin modes: `pin:mode:` (and `valueForInputMode`, `valueForOutputMode`,
  `valueForPwmMode`, `valueForServoMode`), `digitalPin:mode:`.
- Digital pins: `digitalWrite:value:`, `digitalRead:`, `analogWrite:value:`,
  `digitalPortReport:onOff:`, `activateDigitalPort:`, `deactivateDigitalPort:`,
  `setDigitalInputs:data:`.
- Analog pins: `analogRead:`, `analogPinReport:onOff:`, `activateAnalogPin:`,
  `deactivateAnalogPin:`, `setAnalogInput:value:`.
- Servos: `attachServoToPin:`, `detachServoFromPin:`, `servoOnPin:angle:`,
  `servoConfig:minPulse:maxPulse:angle:`.
- Other commands: `queryVersion`, `queryFirmware`, `reportFirmware`,
  `systemReset`, `startSysex`, `endSysex`, `firmataString`,
  `sysexNonRealtime`, `sysexRealtime`.
- Initialization: `initialize`, `initializeVariables`.

### `FirmataConstants` (package `Firmata`)

Class methods for the protocol numbers: `analogMessage`, `digitalMessage`,
`reportAnalog`, `reportDigital`, `reportVersion`, `setPinMode`, `startSysex`,
`endSysex`, `systemReset`, `maxDataBytes` and more.

### `FirmataI2C` — I2C layer (package `Firmata-I2C`)

Extends `Firmata` with the I2C SYSEX messages:

- `i2cConfig` / `i2cConfigDelay:` — set the delay between an I2C request and the
  reply interrupt (default 0 µs).
- `i2cRequestWrite:register:data:` — write data to a slave register.
- `i2cRequestRead:register:byteCount:` — read once.
- `i2cRequestReadContinuously:register:byteCount:` — read continuously (the
  Arduino sends automatically on every change).
- `i2cStopReading:` — stop continuous reading.
- Device registry: `registerI2CDevice:`, `registeredDeviceFor:`.
- SYSEX processing: `parseSysex:`, `dispatchSysexMessageOfLength:`,
  `parseI2CReplyOfLength:`.

### `FirmataI2CDevice` — abstract device base (package `Firmata-I2C`)

- Wiring: `firmata:address:`, `registerWithFirmata`.
- I2C operations: `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.
- Accessing: `address`, `address:`, `firmata`, `firmata:`.
- Subclass responsibility: `initializeDevice` (configure the device on the bus)
  and `handleI2CReply:data:` (process replies).

### `FirmataNet` / `FirmataNetI2C` — TCP/IP (package `Firmata-Net`)

- `connectToHost:` / `connectToHost:port:` — connect to a
  StandardFirmataEthernet/-WiFi Arduino; `defaultPort` (default 3030).
- `FirmataNetI2C` combines network and I2C capability (for the I2C device
  classes in network mode).
- `FirmataNetPort` wraps a `SocketStream` as a byte transport and knows
  `readByteArray`, `nextPutAll:`, `close`, `isConnected`.
- `FirmataNetConstants` — network defaults (default port).

## 5. Usage guide with examples

### 5.1 Serial connection and version check

```smalltalk
| firmata |
firmata := Firmata new.
firmata connectOnPort: '/dev/ttyACM0' baudRate: 57600.
firmata isFirmataInstalled.          "true once the handshake succeeds"
firmata version.                     "e.g. 2.5 (StandardFirmata)"
```

### 5.2 Digital outputs (LED)

```smalltalk
"Pin 13 as output, then turn it on"
firmata digitalPin: 13 mode: 1.      "OUTPUT = 1"
firmata digitalWrite: 13 value: 1.
```

> The pin-mode value is one byte of the protocol. The high-level helpers
> `pin:mode:` accept the numeric mode from the Arduino sketch (`INPUT = 0`,
> `OUTPUT = 1`, `ANALOG = 2`, `PWM = 3`, `SERVO = 4`).

### 5.3 Digital inputs (button) and analog readings

```smalltalk
firmata digitalRead: 2.                  "0 or 1"
firmata analogRead: 0.                   "10-bit value 0..1023"
firmata analogPinReport: 0 onOff: 1.     "enable the analog report"
firmata digitalPortReport: 0 onOff: 1.   "enable the digital report"
```

### 5.4 Servos

```smalltalk
firmata attachServoToPin: 9.
firmata servoOnPin: 9 angle: 90.
firmata servoOnPin: 9 angle: 45.
firmata detachServoFromPin: 9.
```

For high-level control with speed, mount ranges and 180/270 degree servos (pin or
PCA9685), use the `Firmata-Servo` package, see
[Servo-Documentation-en.md](Servo-Documentation-en.md).

### 5.5 Using an I2C device (PCA9685 example)

```smalltalk
| firmata pwm |
firmata := FirmataI2C new.
firmata connectOnPort: '/dev/ttyACM0' baudRate: 57600.
firmata isFirmataInstalled.
firmata i2cConfig.
pwm := FirmataPCA9685 new firmata: firmata address: 0x40.
pwm registerWithFirmata.                "register the device on the bus"
pwm setFrequency: 50.                   "50 Hz (20 ms per channel)"
pwm setPWMOnChannel: 0 value: 128.      "duty 128/4096"
pwm setServoOnChannel: 1 angle: 90.     "servo on channel 1 at 90°"
```

### 5.6 Network connection

```smalltalk
| firmataNet |
firmataNet := FirmataNet new.
firmataNet connectToHost: '192.168.1.100' port: 3030.
firmataNet isFirmataInstalled.
firmataNet digitalWrite: 13 value: 1.
```

### 5.7 Cleanup

```smalltalk
firmata disconnect.       "stops the poller, closes the port"
```

## 6. Adding a new I2C device

This is how you integrate another I2C component (the two existing examples are
`FirmataPCA9685` and `FirmataMPU6050`):

1. **Create a new package** `Firmata-<Device>` (source: `.pck.st`, loaded via
   `Feature require:`), with `!requires: 'Firmata-I2C' 1 nil 1!` and a category
   `'Firmata-<Device>'`.

2. **Model the device class:** subclass of `FirmataI2CDevice`
   (`FirmataI2CDevice subclass: #Firmata<Device> ...`) with the needed instance
   variables, plus a constants class `Firmata<Device>Constants` for register
   addresses, defaults and mode bits.

3. **Implement the required methods:**
   - `defaultAddress` — the I2C slave address (class side `defaults`).
   - `initializeDevice` — chip configuration via register writes
     (`writeRegister:data:`).
   - `handleI2CReply:data:` — interpret incoming readings and store them in the
     device's instance variables.
   - `registerWithFirmata` is called after wiring and registers the device for
     its address via `firmata registerI2CDevice: self`.

4. **Add the public interface**, e.g. `setPWMOnChannel:value:`,
   `setServoOnChannel:angle:`, `readOnce`, `startReading`, `scaledAccelX` etc.

5. **Configuration options as class-side defaults** (`defaults`).

6. **Write tests** (package `Tests-Firmata-<Device>`) — conventions of this
   project:
   - A `FirmataNetStreamMock`/serial mock feeds the parser exactly the bytes a
     real Arduino sends (7-bit LSB/MSB pairs, SYSEX).
   - Byte-exact assertions: the transmitted (SYSEX-)byte array is compared.
   - `TestCase` uses the category `'testing'` for test methods, helpers go to
     `'support'`.
   - Run the suite in the headless runner.

7. **Extend the documentation** in the `docs/` folder (see README).

## 7. Cuis-specific notes and pitfalls

- **7-bit pair convention:** numbers travel as LSB/MSB pairs (low byte first).
  `parseData` stores byte 1 in slot 2 and byte 2 in slot 1 (index 1 = first read
  byte). Never swap the order when parsing manually — an earlier bug read
  `REPORT_VERSION` the wrong way round (version 2.5 came back as 5.2).
- **Headless tests (`-vm-display-null`):** `FileEntry>>writeStreamDo:` asks
  (“Overwrite?”) when the file already exists and thereby hangs the test run. Use
  `forceWriteStreamDo:` for outputs. Also, classes must not be referenced before
  they are installed (Undeclared → `UndefinedObject>>new`); in installing scripts
  use `Smalltalk classNamed:`.
- **Device registry:** an I2C device is addressable only after
  `registerWithFirmata`; replies without registration are discarded.
- **Error behavior:** a read error in the poller sets `port := nil`; any further
  calls through the `port` accessor then raise “Serial port is not connected”.
  Call `connectOnPort:...` (or `connectToHost:port:`) again before reuse.

Test status: all 15 suites green headless (`passed=221 failures=0 errors=0`,
2026-09-24, Cuis 7.8 #7977).
