# ADXL345 – 三轴加速度计

目录：
1. 概述
2. 技术参数
3. 接线
4. 类与API
5. 示例
6. 注意事项

---

## 1. 概述

**ADXL345**（Analog Devices）是一款3轴数字加速度计，在全分辨率模式下具有
13位分辨率。它可以测量静态加速度（重力）和动态加速度（运动、振动），
并在每个轴的连续寄存器中输出结果（`DATAX0`到`DATAZ1`，共6字节），
采用小端序16位数值。

`Firmata-ADXL345`包将传感器封装在`FirmataI2C`连接之后。通过
`startReadingPort`，Arduino持续流式传输输出寄存器；每次收到的
`I2C_REPLY`会覆盖上一个采样值。原始值和缩放值可直接访问。

传感器在全分辨率模式下使用固定的256 LSB/g灵敏度，与所选量程无关。
量程仅影响最大测量范围，不影响每g的分辨率。

## 2. 技术参数

- 3轴加速度计，13位全分辨率（4 mg/LSB灵敏度，256 LSB/g），适用于所有量程。
- 可选全量程范围：**±2g**（索引0）、**±4g**（索引1）、
  **±8g**（索引2）、**±16g**（索引3）。
- 输出数据率通过`BW_RATE`寄存器（`0x2C`）设置：代码0x00（0.1 Hz）
  至0x0F（3200 Hz），默认值0x0A（100 Hz）。
- 6个输出寄存器，起始地址`DATAX0`（`0x32`）：X0、X1、Y0、Y1、Z0、Z1
  （小端序，有符号16位）。
- I2C从机地址：**0x53**（ALT ADDRESS高电平）或**0x1D**（ALT ADDRESS低电平）。
- 工作电压：2.0–3.6V。功耗：23 µA（测量模式），0.1 µA（待机模式）。
- DEVID寄存器（`0x00`）返回0xE5用于设备识别。

## 3. 接线

| ADXL345 | Arduino Uno |
| --- | --- |
| VCC | 3.3V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| CS | VCC（用于I2C模式） |
| SDO | GND（用于地址0x53） |

常见的分线板上通常已集成I2C上拉电阻；否则需在SDA/SCL与VCC之间接
4.7 kΩ电阻。CS引脚必须接高电平以启用I2C模式。SDO决定地址：
GND → 0x53，VCC → 0x1D。

## 4. 类与API

`FirmataADXL345`继承自`FirmataI2CDevice`（`Firmata-I2C`包）。

- 初始化：`initializeDevice`（在`POWER_CTL`寄存器中设置measure位），
  `registerWithFirmata`（接线后执行！）。
- 传感器配置：`setAccelerationRange:`（0–3 ↔ ±2/4/8/16g），
  `setSampleRate:`（0x00–0x0F，对应0.1 Hz至3200 Hz）。
- 读取：`startReadingPort`（连续模式）或`readOnce`（单次采样）。
- 原始输出：`accelX`/`accelY`/`accelZ`（有符号16位小端序）。
- 缩放输出：`scaledAccelX`/`scaledAccelY`/`scaledAccelZ`（单位g）
  — 原始值除以256.0（全分辨率固定灵敏度）。
- 灵敏度与量程：`accelSensitivity`（256 LSB/g，固定），
  `accelRange`（当前量程索引），`sampleRate`（当前代码）。
- 接收处理：`handleI2CReply:data:`处理Arduino的6字节应答。
- 继承的辅助方法（`FirmataI2CDevice`）：`firmata:address:`、
  `writeRegister:data:`、`readRegister:byteCount:`、
  `readRegisterContinuously:byteCount:`、`stopReading`。

`FirmataADXL345Constants`（类端）保存寄存器地址
（`dataFormatRegister` 0x31、`bandwidthRateRegister` 0x2C、
`powerControlRegister` 0x2D、`dataX0Register` 0x32、`deviceIdRegister` 0x00），
位定义（`fullResolutionBit`、`measureBit`），规格参数
（`accelSensitivity` 256、`deviceIdValue` 0xE5、`sensorOutputByteCount` 6）
和默认值（`defaultAddress` 0x53、`defaultAccelRange` 0、
`defaultSampleRate` 0x0A）。

## 5. 示例

```smalltalk
| bus sensor |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

sensor := FirmataADXL345 new.
sensor firmata: bus address: FirmataADXL345Constants defaultAddress.
sensor initializeDevice.
sensor registerWithFirmata.

"配置量程和采样率（可选）"
sensor setAccelerationRange: 1.    "±4g"
sensor setSampleRate: 16r0B.       "200 Hz"

"启动连续流式传输"
sensor startReadingPort.

"... 几步之后："
sensor accelZ.                     "原始小端序16位Z值"
sensor scaledAccelZ.               "Z轴加速度（单位g）"

"读取单次采样："
sensor readOnce.

"停止流式传输："
sensor stopReading.
```

## 6. 注意事项

- **原始值为小端序有符号16位**。LSB在第一个寄存器（`DATAX0`）中，
  MSB在第二个（`DATAX1`）中。这与MPU6050（大端序）不同。
- **全分辨率模式（full_res）：** 始终激活 — 无论选择哪个量程，
  灵敏度始终保持256 LSB/g固定值。量程仅决定最大测量范围。
- **缩放计算：** `scaled*` = 原始值 / 256.0。示例：`scaledAccelZ :=
  accelZ / 256.0`。
- **量程切换**（`setAccelerationRange:`）写入`DATA_FORMAT`寄存器的
  位0–1。全分辨率位（位3）保持设置状态。
- **上电后稳定：** 在上电或执行`initializeDevice`后需稍等片刻；
  传感器需要几毫秒才能稳定。
- **DEVID验证：** `DEVID`寄存器（`0x00`）必须返回`0xE5`。
  如果不符，则存在通信错误。
- **多传感器：** 将SDO接至VCC以使用地址0x1D，并在同一`FirmataI2C`
  连接上注册第二个`FirmataADXL345`实例。
