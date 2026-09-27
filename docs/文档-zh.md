# 用于 Cuis-Smalltalk 的 Firmata

目录：
1. 什么是 Firmata？
2. 前提条件与安装
3. 连接与后台处理
4. API 概览
5. 使用指南与示例
6. 如何添加新的 I2C 设备
7. Cuis 专用说明与注意事项

---

## 1. 什么是 Firmata？

Firmata 是一种基于协议的开放方法，用于从主机（host）控制微控制器（例如
Arduino 开发板）。Arduino 上运行 **StandardFirmata** 固件；主机（这里是
Cuis-Smalltalk 映像）通过串口（USB）或 TCP/IP 网络发送紧凑的字节命令，
Arduino 则以测量值和状态消息应答。无论连接了哪些引脚或 I2C 设备，接口都
保持不变。

协议使用 7 位数值：每个数字都以 LSB/MSB 字节对形式传输。复杂的扩展（如
I2C）使用 SYSEX 机制：消息以 `START_SYSEX`（`0xF0`）开始，以 `END_SYSEX`
（`0xF7`）结束。本包实现了完整的标准，包括 I2C SYSEX 命令。

## 2. 前提条件与安装

**在 Arduino 上**（Arduino IDE，Smalltalk 社区的 *Firmata* 库）：

- `StandardFirmata`：用于 USB/串口。
- `StandardFirmataEthernet` 或 `StandardFirmataWiFi`：用于网络模式。
- 自定义固件逻辑：`ConfigurableFirmata`（本项目中的所有示例和测试都与这些
  示例程序逐字节对齐）。

**在 Cuis-Smalltalk 中**，通过包浏览器或以下代码加载包：

```smalltalk
Feature require: #'Firmata'.            "核心协议（串口）"
Feature require: #'Firmata-I2C'.        "I2C 支持"
Feature require: #'Firmata-PCA9685'.    "PCA9685 16 通道 PWM/舵机驱动"
Feature require: #'Firmata-MPU6050'.    "MPU6050 惯性测量单元"
Feature require: #'Firmata-Servo'.      "高级舵机控制（速度、范围）"
Feature require: #'Firmata-Net'.        "TCP/IP 传输（需要 Network-Kernel）"
```

依赖关系会自动解析。对于 `Firmata-Net`，必须先安装 `Network-Kernel` 包
（上面的顺序：先 `Network-Kernel`，再 `Firmata-Net`）。

**基本接线：** 所有信号共用接地；I2C 还需在 `SDA`/`SCL` 到 `VCC` 之间加上拉
电阻（通常 4.7 kΩ）——大多数开发板已自带。

## 3. 连接与后台处理

每个连接类（`Firmata`、`FirmataI2C`、`FirmataNet`、`FirmataNetI2C`）都持有
一个 `port`（字节传输）和一个持续轮询连接的后台进程：

- `connectOnPort:baudRate:` — 串口连接（类 `Firmata`、`FirmataI2C`）。
- `connectToHost:port:` — TCP/IP 连接（类 `FirmataNet`、`FirmataNetI2C`）。
- `startSteppingProcess` — 启动轮询器；连接时自动调用。
- `step` / `stepTime` — 一次轮询步骤，以及它的间隔（毫秒）。`step` 通过
  `processInput` 读取所有待处理字节。读取错误会将 `port := nil`，从而标记连接
  已关闭，后台进程会自动停止。
- `stopSteppingProcess` — 停止轮询器（由 `disconnect` 调用）。
- `disconnect` — 停止轮询器，关闭端口，设置 `port := nil` 并重置协议状态。
  可安全地重复调用。
- `isConnected` — `^port notNil`。
- `isFirmataInstalled` — 反复发送版本查询，直到收到应答（最长 5 秒）。

## 4. API 概览

### `Firmata` — 核心协议（包 `Firmata`）

- 生命周期/连接：`connectOnPort:baudRate:`、`disconnect`、`isConnected`、
  `controlConnection`、`controlFirmataInstallation`。
- 后台进程：`startSteppingProcess`、`step`、`stepTime`、`stopSteppingProcess`。
- 接收：`processInput`、`parseCommandHeader:`、`parseData:`、`parseSysex:`、
  `parsingSysex`。
- 状态：`isFirmataInstalled`、`version`、`majorVersion`、`minorVersion`、
  `nameSymbol`、`port`。
- 引脚模式：`pin:mode:`（以及 `valueForInputMode`、`valueForOutputMode`、
  `valueForPwmMode`、`valueForServoMode`）、`digitalPin:mode:`。
- 数字引脚：`digitalWrite:value:`、`digitalRead:`、`analogWrite:value:`、
  `digitalPortReport:onOff:`、`activateDigitalPort:`、`deactivateDigitalPort:`、
  `setDigitalInputs:data:`。
- 模拟引脚：`analogRead:`、`analogPinReport:onOff:`、`activateAnalogPin:`、
  `deactivateAnalogPin:`、`setAnalogInput:value:`。
- 舵机：`attachServoToPin:`、`detachServoFromPin:`、`servoOnPin:angle:`、
  `servoConfig:minPulse:maxPulse:angle:`。
- 其他命令：`queryVersion`、`queryFirmware`、`reportFirmware`、`systemReset`、
  `startSysex`、`endSysex`、`firmataString`、`sysexNonRealtime`、
  `sysexRealtime`。
- 初始化：`initialize`、`initializeVariables`。

### `FirmataConstants`（包 `Firmata`）

协议编号的类方法：`analogMessage`、`digitalMessage`、`reportAnalog`、
`reportDigital`、`reportVersion`、`setPinMode`、`startSysex`、`endSysex`、
`systemReset`、`maxDataBytes` 等。

### `FirmataI2C` — I2C 层（包 `Firmata-I2C`）

为 `Firmata` 扩展 I2C SYSEX 消息：

- `i2cConfig` / `i2cConfigDelay:` — 设置 I2C 请求与应答中断之间的延迟
  （默认 0 µs）。
- `i2cRequestWrite:register:data:` — 向从机寄存器写入数据。
- `i2cRequestRead:register:byteCount:` — 读取一次。
- `i2cRequestReadContinuously:register:byteCount:` — 连续读取（Arduino 在每次
  变化时自动发送）。
- `i2cStopReading:` — 停止连续读取。
- 设备注册表：`registerI2CDevice:`、`registeredDeviceFor:`。
- SYSEX 处理：`parseSysex:`、`dispatchSysexMessageOfLength:`、
  `parseI2CReplyOfLength:`。

### `FirmataI2CDevice` — 抽象设备基类（包 `Firmata-I2C`）

- 接线：`firmata:address:`、`registerWithFirmata`。
- I2C 操作：`writeRegister:data:`、`readRegister:byteCount:`、
  `readRegisterContinuously:byteCount:`、`stopReading`。
- 访问：`address`、`address:`、`firmata`、`firmata:`。
- 子类职责：`initializeDevice`（在总线上配置设备）和 `handleI2CReply:data:`
  （处理应答）。

### `FirmataNet` / `FirmataNetI2C` — TCP/IP（包 `Firmata-Net`）

- `connectToHost:` / `connectToHost:port:` — 连接到运行 StandardFirmataEthernet
  /-WiFi 的 Arduino；`defaultPort`（默认 3030）。
- `FirmataNetI2C` 结合了网络与 I2C 能力（用于网络模式下使用 I2C 设备类）。
- `FirmataNetPort` 将 `SocketStream` 封装为字节传输，具有 `readByteArray`、
  `nextPutAll:`、`close`、`isConnected`。
- `FirmataNetConstants` — 网络默认值（默认端口）。

## 5. 使用指南与示例

### 5.1 串口连接与版本检查

```smalltalk
| firmata |
firmata := Firmata new.
firmata connectOnPort: '/dev/ttyACM0' baudRate: 57600.
firmata isFirmataInstalled.          "握手成功时为 true"
firmata version.                     "例如 2.5（StandardFirmata）"
```

### 5.2 数字输出（LED）

```smalltalk
"把引脚 13 设为输出并点亮"
firmata digitalPin: 13 mode: 1.      "OUTPUT = 1"
firmata digitalWrite: 13 value: 1.
```

> 引脚模式值是协议的一个字节。高层辅助方法 `pin:mode:` 接受 Arduino 示例程序
> 中的数字模式（`INPUT = 0`、`OUTPUT = 1`、`ANALOG = 2`、`PWM = 3`、
> `SERVO = 4`）。

### 5.3 数字输入（按键）和模拟读数

```smalltalk
firmata digitalRead: 2.                  "0 或 1"
firmata analogRead: 0.                   "10 位值 0..1023"
firmata analogPinReport: 0 onOff: 1.     "启用模拟上报"
firmata digitalPortReport: 0 onOff: 1.   "启用数字上报"
```

### 5.4 舵机

```smalltalk
firmata attachServoToPin: 9.
firmata servoOnPin: 9 angle: 90.
firmata servoOnPin: 9 angle: 45.
firmata detachServoFromPin: 9.
```

如需带速度、安装范围和 180°/270° 舵机的高级控制（引脚或 PCA9685），请使用
`Firmata-Servo` 包，参见 [Servo-文档-zh.md](Servo-文档-zh.md)。
```

### 5.5 使用 I2C 设备（以 PCA9685 为例）

```smalltalk
| firmata pwm |
firmata := FirmataI2C new.
firmata connectOnPort: '/dev/ttyACM0' baudRate: 57600.
firmata isFirmataInstalled.
firmata i2cConfig.
pwm := FirmataPCA9685 new firmata: firmata address: 0x40.
pwm registerWithFirmata.                "在总线上注册设备"
pwm setFrequency: 50.                   "50 Hz（每通道 20 ms）"
pwm setPWMOnChannel: 0 value: 128.      "占空比 128/4096"
pwm setServoOnChannel: 1 angle: 90.     "通道 1 上的舵机转到 90°"
```

### 5.6 网络连接

```smalltalk
| firmataNet |
firmataNet := FirmataNet new.
firmataNet connectToHost: '192.168.1.100' port: 3030.
firmataNet isFirmataInstalled.
firmataNet digitalWrite: 13 value: 1.
```

### 5.7 清理

```smalltalk
firmata disconnect.       "停止轮询器并关闭端口"
```

## 6. 如何添加新的 I2C 设备

集成另一个 I2C 组件的方法如下（现有两个示例是 `FirmataPCA9685` 和
`FirmataMPU6050`）：

1. **创建新包** `Firmata-<设备>`（来源：`.pck.st`，通过 `Feature require:`
   加载），包含 `!requires: 'Firmata-I2C' 1 nil 1!` 和一个类别
   `'Firmata-<设备>'`。

2. **构建设备类：** `FirmataI2CDevice` 的子类
   （`FirmataI2CDevice subclass: #Firmata<设备> ...`），包含所需的实例变量，
   并创建一个常量类 `Firmata<设备>Constants` 存放寄存器地址、默认值和模式位。

3. **实现必需方法：**
   - `defaultAddress` — I2C 从机地址（类侧 `defaults`）。
   - `initializeDevice` — 通过寄存器写入配置芯片（`writeRegister:data:`）。
   - `handleI2CReply:data:` — 解释传入的测量值并存入设备实例变量。
   - `registerWithFirmata` 在接线后调用，通过 `firmata registerI2CDevice: self`
     将设备按地址注册。

4. **添加公开接口**，例如 `setPWMOnChannel:value:`、`setServoOnChannel:angle:`、
   `readOnce`、`startReading`、`scaledAccelX` 等。

5. **把配置选项作为类侧默认值**（`defaults`）。

6. **编写测试**（包 `Tests-Firmata-<设备>`）——本项目的约定：
   - 用 `FirmataNetStreamMock`/串口 Mock 向解析器供给真实 Arduino 发送的
     确切字节（7 位 LSB/MSB 对，SYSEX）。
   - 逐字节断言：比较发送的（SYSEX）字节数组。
   - `TestCase` 用类别 `'testing'` 放测试方法，辅助方法放到 `'support'`。
   - 在无头（headless）runner 中运行整个测试套件。

7. **在 `docs/` 文件夹中补充文档**（参见 README）。

## 7. Cuis 专用说明与注意事项

- **7 位字节对约定：** 数字以 LSB/MSB 对传输（低字节在前）。`parseData` 把
  字节 1 存到槽位 2，字节 2 存到槽位 1（索引 1 = 第一个读到的字节）。手动解析
  时切勿颠倒顺序——早期的一个错误就是因此把 `REPORT_VERSION` 读反了（2.5 的
  版本被报成 5.2）。
- **无头测试（`-vm-display-null`）：** 当文件已存在时
  `FileEntry>>writeStreamDo:` 会弹窗询问（“Overwrite?”）并挂起测试运行。输出
  请使用 `forceWriteStreamDo:`。此外，类不能在安装前被直接引用
  （Undeclared → `UndefinedObject>>new`）；在安装脚本中使用
  `Smalltalk classNamed:`。
- **设备注册表：** I2C 设备只有在 `registerWithFirmata` 之后才能被寻址；未注册
  的应答会被丢弃。
- **错误行为：** 轮询器中的读取错误会把 `port := nil`；之后任何通过 `port`
  访问器的调用都会抛出 “Serial port is not connected”。重新使用前请再次调用
  `connectOnPort:...`（或 `connectToHost:port:`）。

测试状态：全部 15 个测试套件在无头模式下通过（`passed=221 failures=0 errors=0`，
2026-09-24，Cuis 7.8 #7977）。
