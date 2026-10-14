# Firmata-Servo – High-Level Servo Control

Contents:
1. Overview
2. Core concepts
3. Class and API
4. Transports (pin and PCA9685)
5. Examples
6. Notes

---

## 1. Overview

The `Firmata-Servo` package lifts the servo control of the Firmata base protocol
to a comfortable level. Instead of sending raw protocol angles, a servo instance
models a single servo with its fixed mounting situation:

- **Speed** in degrees per second — the servo eases towards the target in small
  steps from a background process instead of jumping.
- **180° and 270° servos** — the mechanical swing is taken into account when
  scaling to the 0–180° protocol angle.
- **Restricted and inverted mount ranges** — input values (e.g. 0–100) are mapped
  linearly onto an arbitrary angle range, including servos mounted the other way
  round (e.g. 180° → 0°).
- **Two transports** — directly on an Arduino pin (`FirmataPinServo`) or on a
  PCA9685 channel over I2C (`FirmataPCA9685Servo`).

## 2. Core concepts

A servo spends its working life between a **mount range** (physical angles, see
`minAngle`/`maxAngle`). Its input is an abstract **position value**, typically a
percentage between 0 and 100 (`minPosition`/`maxPosition`). `moveTo:` maps the
value linearly onto the angle range — inverted ranges are allowed for servos
mounted the other way round — clamps it, and drives the servo there.

The **angular speed** (`speedDegreesPerSecond`) controls how fast the angle
changes: with zero speed the servo jumps straight to the target, with a positive
speed it ramps there in small steps. The background process (`startMovingProcess`)
stops by itself once the target is reached. Current and target angle are kept as
state (`currentAngle`, `targetAngle`).

**Never two competing processes:** `moveTo:` during an ongoing movement first ends
the old process (internally `stopMovingProcess`) and then starts the new movement
from the current position. A servo is therefore driven by at most one movement
process at any time. If the speed is set to 0 mid-flight, the next step finishes
the move regularly at the target instead of stepping forever.

The **mechanical range** (`rangeDegrees`, 180 or 270) together with the **pulse
width calibration** (`minPulseMicroseconds`/`maxPulseMicroseconds`) scales the
physical angle to the protocol angle. The actual transport is delegated to the
subclasses (`writeAngle:`).

## 3. Class and API

`FirmataServo` is the abstract base (package `Firmata-Servo`).

Settings (accessing):

- `minPosition:`/`maxPosition:` or `setPositionRangeFrom:to:` — input range
  (default 0–100).
- `minAngle:`/`maxAngle:` or `setAngleRangeFrom:to:` — mount range in physical
  degrees; inverted ranges allowed.
- `rangeDegrees:` — mechanical swing (default 180, e.g. 270 for pan-tilt servos).
- `minPulseMicroseconds:`/`maxPulseMicroseconds:` — pulse width calibration
  (default 544/2400 µs, the StandardFirmata convention).
- `speedDegreesPerSecond:` — speed in degrees per second (0 = jump directly).
- `stepIntervalMilliseconds:` — step interval of the background process (default 20 ms).

Movement (moving):

- `moveTo: aPosition` — give a position (e.g. 0–100); it is mapped to the angle
  range and driven to.
- `moveToAngle: degrees` — move to a physical angle directly.
- `currentAngle`, `targetAngle` — state queries; `isMoving` — is a movement
  running?
- `step` — one single step (used by the background process).
- `startMovingProcess` / `stopMovingProcess` — start/stop the ramping process;
  every `moveTo:` first ends a running process regularly.

Mappings (mapping):

- `positionToAngle:` — position value → physical angle (linear, clamped).
- `protocolAngleForDegrees:` — physical angle → 0–180° protocol angle.
- `clampAngle:` — clamp to the mount range.

Class-side constants (`FirmataServo class`): `defaultRangeDegrees` (180),
`defaultMinPulseMicroseconds` (544), `defaultMaxPulseMicroseconds` (2400),
`defaultSpeedDegreesPerSecond` (0), `defaultStepIntervalMilliseconds` (20).

## 4. Transports (pin and PCA9685)

`FirmataPinServo` (instance variable `pin`) drives a servo connected directly to
an Arduino pin:

- `attach` — set the pin to servo mode and send the pulse width calibration once;
  the start of the mount range serves as the rest angle.
- Afterwards every movement is a `servoOnPin:angle:` message on the Firmata
  connection.

`FirmataPCA9685Servo` (instance variable `channel`) drives a servo on one channel
of a PCA9685 PWM driver over the I2C bus:

- The driver (`FirmataPCA9685`) must be initialized with `initializeDevice`
  first; it enables register auto-increment and programs the PWM frequency, both
  of which the servo needs (see
  [PCA9685-Documentation-en.md](PCA9685-Documentation-en.md)). A separate
  `setFrequency:` is only needed to change the frequency afterwards.
- Every movement is a `setServoOnChannel:angle:minPulse:maxPulse:` message on the
  driver.

## 5. Examples

### 5.1 Servo directly on an Arduino pin

```smalltalk
| bus servo |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.

servo := FirmataPinServo on: bus pin: 9.
servo attach.
servo speedDegreesPerSecond: 45.   "45 degrees per second"
servo moveTo: 50.                   "drive to 50% of the mount range"
```

### 5.2 Restricted and inverted mount ranges

```smalltalk
servo setAngleRangeFrom: 20 to: 160.  "only moveable between 20° and 160°"
servo moveTo: 0.                      "drives to 20°"
servo moveTo: 100.                    "drives to 160°"

servo setAngleRangeFrom: 160 to: 20.  "mounted the other way round"
servo moveTo: 100.                    "drives to 20°"
```

### 5.3 270-degree servo

```smalltalk
servo rangeDegrees: 270.
servo setAngleRangeFrom: 0 to: 270.
servo moveTo: 50.                     "physically 135°, protocol 90°"
```

### 5.4 Servo via PCA9685 (I2C)

```smalltalk
| bus driver servo |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

driver := FirmataPCA9685 new.
driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
driver initializeDevice.                     "modes, auto-increment, 50 Hz"

servo := FirmataPCA9685Servo on: driver channel: 0.
servo speedDegreesPerSecond: 30.
servo moveTo: 50.
```

### 5.5 New target during the movement

```smalltalk
servo speedDegreesPerSecond: 90.
servo moveTo: 100.              "eases towards 100%"
servo moveTo: 0.                "after 5 seconds: the old movement is ended,
                                 the new one starts from the current position"
```

## 6. Notes

- **No competing processes:** every `moveTo:`/`moveToAngle:` ends a running ramp
  process first. If the speed is set to 0, the servo jumps to the target on the
  next `step` and the process ends regularly.
- **Background process:** the ramp process runs at the active priority of the
  caller and is named `FirmataServo <class>`. It ends itself once the target is
  reached.
- **`targetAngle:` starts no process** — it only sets the target state (for
  applications that clock `step` themselves). Start movement with `moveTo:` or
  `moveToAngle:`.
- **Pulse calibration:** the defaults 544/2400 µs follow the StandardFirmata
  convention; if your servos differ, adjust both values per servo.
- **Upgrade recommendation:** for new projects prefer the high-level
  `FirmataServo` API over the raw `servoOnPin:angle:` usage of the base protocol.

Test status: the `Tests-Firmata-Servo` suite is part of the headless overall run
(`passed=221 failures=0 errors=0`, 2026-09-24, Cuis 7.8 #7977).
