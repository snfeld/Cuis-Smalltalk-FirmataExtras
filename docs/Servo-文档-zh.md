# Firmata-Servo – 高级舵机控制

目录：
1. 概述
2. 基本概念
3. 类与 API
4. 连接方式（引脚与 PCA9685）
5. 示例
6. 说明

---

## 1. 概述

`Firmata-Servo` 包将 Firmata 基础协议的舵机控制提升到一个便捷的层次。舵机实例
不再是直接发送原始协议角度，而是对一个舵机及其固定安装情况进行建模：

- **速度**（度/秒）——舵机从后台进程以小步长平稳移动到目标，而不是直接跳转。
- **180° 和 270° 舵机**——换算到 0–180° 协议角度时会考虑机械转角范围。
- **受限且可反向的安装范围**——输入值（如 0–100）线性映射到任意角度范围，
  包括反装舵机（如 180° → 0°）。
- **两种连接方式**——直接接在 Arduino 引脚上（`FirmataPinServo`），或通过
  I2C 接在 PCA9685 通道上（`FirmataPCA9685Servo`）。

## 2. 基本概念

舵机在**安装范围**（物理角度，见 `minAngle`/`maxAngle`）之间工作。其输入是
抽象的**位置值**，通常是 0 到 100 之间的百分比（`minPosition`/`maxPosition`）。
`moveTo:` 将该值线性映射到角度范围——反装舵机允许反向范围——并钳位到边界，
然后驱动舵机到达目标。

**角速度**（`speedDegreesPerSecond`）控制角度变化快慢：速度为零时舵机直接跳到
目标；速度为正时以小步长逐渐接近。后台进程（`startMovingProcess`）在到达目标
后自动停止。当前角度与目标角度作为状态保存（`currentAngle`、`targetAngle`）。

**绝无两个竞争进程：**在运动中调用 `moveTo:` 会先结束旧进程（内部调用
`stopMovingProcess`），再从当前位置启动新运动。因此舵机在任何时刻最多由一个运动
进程驱动。若在行驶途中将速度设为 0，下一步会在目标处正常结束运动，而不是无限
步进。

**机械范围**（`rangeDegrees`，180 或 270）加上**脉冲宽度校准**
（`minPulseMicroseconds`/`maxPulseMicroseconds`）将物理角度换算为协议角度。
实际传输委托给子类（`writeAngle:`）。

## 3. 类与 API

`FirmataServo` 是抽象基类（包 `Firmata-Servo`）。

设置（accessing）：

- `minPosition:`/`maxPosition:` 或 `setPositionRangeFrom:to:` — 输入范围（默认
  0–100）。
- `minAngle:`/`maxAngle:` 或 `setAngleRangeFrom:to:` — 物理角度的安装范围；
  允许反向范围。
- `rangeDegrees:` — 机械转角范围（默认 180；如云台舵机可设为 270）。
- `minPulseMicroseconds:`/`maxPulseMicroseconds:` — 脉冲宽度校准（默认
  544/2400 µs，即 StandardFirmata 约定）。
- `speedDegreesPerSecond:` — 度/秒（0 = 直接跳转）。
- `stepIntervalMilliseconds:` — 后台进程的步进间隔（默认 20 毫秒）。

运动（moving）：

- `moveTo: aPosition` — 给出位置（如 0–100）；映射到角度范围并驱动过去。
- `moveToAngle: degrees` — 直接移动到物理角度。
- `currentAngle`、`targetAngle` — 状态查询；`isMoving` — 是否有运动正在进行？
- `step` — 单一步进（供后台进程使用）。
- `startMovingProcess` / `stopMovingProcess` — 启动/停止渐变进程；每次
  `moveTo:` 都会先正常结束正在运行的进程。

映射（mapping）：

- `positionToAngle:` — 位置值 → 物理角度（线性、钳位）。
- `protocolAngleForDegrees:` — 物理角度 → 0–180° 协议角度。
- `clampAngle:` — 钳位到安装范围。

类侧常量（`FirmataServo class`）：`defaultRangeDegrees`（180）、
`defaultMinPulseMicroseconds`（544）、`defaultMaxPulseMicroseconds`（2400）、
`defaultSpeedDegreesPerSecond`（0）、`defaultStepIntervalMilliseconds`（20）。

## 4. 连接方式（引脚与 PCA9685）

`FirmataPinServo`（实例变量 `pin`）驱动直接连接在 Arduino 引脚上的舵机：

- `attach` — 将引脚设为舵机模式并发送一次脉冲宽度校准；安装范围的起始点作为
  静止角度。
- 之后每次运动都是 Firmata 连接上的 `servoOnPin:angle:` 消息。

`FirmataPCA9685Servo`（实例变量 `channel`）通过 I2C 总线驱动 PCA9685 PWM 驱动
器某个通道上的舵机：

- 驱动器（`FirmataPCA9685`）必须先用 `initializeDevice` 初始化；它会启用寄存器自动
  递增并设置 PWM 频率，这两者对舵机都是必需的（见
  [PCA9685-文档-zh.md](PCA9685-文档-zh.md)）。只有在之后要更改频率时才需要另外调用
  `setFrequency:`。
- 每次运动都是发给驱动器的 `setServoOnChannel:angle:minPulse:maxPulse:` 消息。

## 5. 示例

### 5.1 舵机直接接在 Arduino 引脚上

```smalltalk
| bus servo |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.

servo := FirmataPinServo on: bus pin: 9.
servo attach.
servo speedDegreesPerSecond: 45.   "每秒 45 度"
servo moveTo: 50.                   "移动到安装范围的 50%"
```

### 5.2 受限且反向的安装范围

```smalltalk
servo setAngleRangeFrom: 20 to: 160.  "只能在 20° 与 160° 之间移动"
servo moveTo: 0.                      "移动到 20°"
servo moveTo: 100.                    "移动到 160°"

servo setAngleRangeFrom: 160 to: 20.  "反装"
servo moveTo: 100.                    "移动到 20°"
```

### 5.3 270 度舵机

```smalltalk
servo rangeDegrees: 270.
servo setAngleRangeFrom: 0 to: 270.
servo moveTo: 50.                     "物理 135°，协议 90°"
```

### 5.4 通过 PCA9685（I2C）控制舵机

```smalltalk
| bus driver servo |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

driver := FirmataPCA9685 new.
driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
driver initializeDevice.                     "模式、自动递增、50 Hz"

servo := FirmataPCA9685Servo on: driver channel: 0.
servo speedDegreesPerSecond: 30.
servo moveTo: 50.
```

### 5.5 运动中给出新目标

```smalltalk
servo speedDegreesPerSecond: 90.
servo moveTo: 100.              "平稳移向 100%"
servo moveTo: 0.                "5 秒后：旧运动结束，新运动从当前位置开始"
```

## 6. 说明

- **无竞争进程：**每次 `moveTo:`/`moveToAngle:` 都会先结束正在运行的渐变进程。
  若速度设为 0，舵机在下一次 `step` 时跳到目标，进程正常结束。
- **后台进程：**以调用者的活动优先级运行，名为 `FirmataServo <类名>`。到达目标
  后自动结束。
- **`targetAngle:` 不启动任何进程**——只设置目标状态（适用于自行驱动 `step`
  的应用）。要启动运动请用 `moveTo:` 或 `moveToAngle:`。
- **脉冲校准：**默认值 544/2400 µs 遵循 StandardFirmata 约定；若你的舵机不同，
  请按舵机分别调整这两个值。
- **升级建议：**新项目优先使用高级 `FirmataServo` API，而不是基础协议原始的
  `servoOnPin:angle:` 用法。

测试状态：`Tests-Firmata-Servo` 套件是 headless 总运行的组成部分
（`passed=221 failures=0 errors=0`，2026-09-24，Cuis 7.8 #7977）。
