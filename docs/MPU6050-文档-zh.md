# MPU6050 — 6 轴惯性测量单元

目录：
1. 概述
2. 技术规格
3. 接线
4. 类与 API
5. 示例
6. 注意事项

---

## 1. 概述

**MPU6050**（InvenSense）是一款 6 轴运动传感器：一个 3 轴加速度计、一个 3 轴
陀螺仪和一个温度传感器。所有读数集中在从 `ACCEL_XOUT_H`（`0x3B`）开始的 14 个
连续寄存器中，可通过一次连续的 I2C 读取进行流式传输。

`Firmata-MPU6050` 包将该传感器封装在 `FirmataI2C` 连接之后。使用 `startReading`
时，Arduino 连续流式传输输出寄存器；每一条传入的 `I2C_REPLY` 都会覆盖上一个
采样值。之后即可直接读取原始值和带物理单位的换算值（g 和 度/秒）。

简言之：`accelX` = 原始计数 ±32767，`scaledAccelX` = 以 g 为单位的加速度，
`scaledGyroX` = 以 度/秒 为单位的旋转速率。

## 2. 技术规格

- 加速度计：3 轴，16 位，可选满量程 **±2 g / ±4 g / ±8 g / ±16 g**
  （灵敏度 16384/8192/4096/2048 LSB/g）。
- 陀螺仪：3 轴，16 位，可选满量程 **±250 / ±500 / ±1000 / ±2000 度/秒**
  （灵敏度 131/65.5/32.8/16.4 LSB/(度/秒)）。
- 温度：16 位，比例因子 340 LSB/°C，偏移 36.53 °C。
- 从 0x3B 开始的 14 个连续输出寄存器（原始加速度、温度、原始陀螺仪，
  大端序、16 位有符号）。
- I2C 从机地址：AD0 引脚接低时为 **0x68**（否则为 0x69）；`whoAmI` 应答 0x68。
- 内部 8 MHz 时钟；传感器默认处于睡眠模式（`initializeDevice` 会将其唤醒）。

## 3. 接线

| MPU6050 | Arduino |
| --- | --- |
| VCC | 3.3 V（带电平转换的扩展板通常也支持 5 V） |
| GND | GND |
| SDA | A4（Uno）/ 20（Mega） |
| SCL | A5（Uno）/ 21（Mega） |
| AD0 | 接地为地址 0x68，接 VCC 为 0x69 |
| INT（可选） | 悬空（轮询由 Firmata 的 step 完成） |

常见扩展板自带 I2C 上拉电阻；否则在 SDA/SCL 到 VCC 之间接 4.7 kΩ。

## 4. 类与 API

`FirmataMPU6050` 继承自 `FirmataI2CDevice`（包 `Firmata-I2C`）。

- 初始化：`initialize`、`initializeDevice`（清除睡眠位以激活传感器）、
  `registerWithFirmata`（接线后调用！）。
- 传感器配置：`setAccelerationRange:`（0–3 ↔ ±2/4/8/16 g）、
  `setGyroRange:`（0–3 ↔ ±250/500/1000/2000 度/秒）。
- 读取：`startReading`（连续）或 `readOnce`（单个采样）。用 `stopReading`
  停止。
- 原始输出：`accelX`/`accelY`/`accelZ`、`gyroX`/`gyroY`/`gyroZ`、
  `temperature`（单位 °C）。
- 换算输出：`scaledAccelX`/`scaledAccelY`/`scaledAccelZ`（单位 g）、
  `scaledGyroX`/`scaledGyroY`/`scaledGyroZ`（单位 度/秒）——取决于配置的
  满量程范围。
- 灵敏度：`accelSensitivity`（LSB/g）、`gyroSensitivity`（LSB/(度/秒)）；
  每升一档范围减半。
- 量程索引：`accelRange`、`gyroRange`。
- 继承的帮助方法（`FirmataI2CDevice`）：`firmata:address:`、
  `registerWithFirmata`、`writeRegister:data:`、`readRegister:byteCount:`、
  `readRegisterContinuously:byteCount:`、`stopReading`。

`FirmataMPU6050Constants`（类侧）存放寄存器（`accelXHighRegister` 0x3B、
`gyroXHighRegister` 0x43、`temperatureHighRegister` 0x41、
`accelConfigRegister` 0x1C、`gyroConfigRegister` 0x1B、`configRegister` 0x1A、
`smplrtDivRegister` 0x19、`powerManagement1Register` 0x6B、
`powerManagement2Register` 0x6C、`whoAmIRegister` 0x75）、电源位
（`awakeValue` 0、`deviceResetBit`、`sleepBit`、`temperatureDisableBit`）、规格
（`accelSensitivity` 16384、`gyroSensitivity` 131.0、`sensorOutputByteCount`
14、`temperatureScaleFactor` 340.0、`temperatureOffset` 36.53）以及默认值
（`defaultAddress` 0x68、`defaultAccelRange` 0、`defaultGyroRange` 0）。

## 5. 示例

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

"选择更敏感的量程（可选）"
sensor setAccelerationRange: 1.    "+/-4 g"
sensor setGyroRange: 1.            "+/-500 度/秒"

"开始连续流式传输"
sensor startReading.

"...经过几个 step 之后："
sensor accelZ.                     "Z 轴原始 16 位计数"
sensor scaledAccelZ.               "Z 轴加速度（g）"
sensor scaledGyroX.                "X 轴旋转速率（度/秒）"
sensor temperature.                "温度（°C）"

"或者只读一个采样："
sensor readOnce.

"停止流式传输："
sensor stopReading.
```

## 6. 注意事项

- **原始值为大端序且有符号**（16 位）。只有在收到 `I2C_REPLY` 之后才有采样值；
  在第一条应答被处理之前，各访问器初始为 `nil`。
- **换算：** `scaled*` = 原始值 / 所配置量程的灵敏度。例如在 ±2 g 时：
  `scaledAccelX := accelX / 16384.0`。
- **更改量程**（`setAccelerationRange:`/`setGyroRange:`）会写入配置寄存器；
  有效索引 0–3，否则抛出 `error:`。
- **温度公式：** `原始值/340.0 + 36.53`，单位 °C。
- **稳定时间：** 唤醒后让传感器短暂稳定；首次上电时读取 `whoAmI`（0x68）作
  一致性检查。
- **多传感器：** 把 AD0 接到 0x69，并在同一 `FirmataI2C` 连接上注册第二个
  `FirmataMPU6050` 实例。
