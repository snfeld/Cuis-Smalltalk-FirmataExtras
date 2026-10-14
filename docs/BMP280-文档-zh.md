# BMP280 – 气压与温度传感器

目录:
1. 概述
2. 技术参数
3. 接线
4. 类与 API
5. 示例
6. 说明

---

## 1. 概述

**BMP280**（Bosch Sensortec）是一款气压与温度传感器。它测量 300–1100 hPa
范围内的绝对气压，并通过从 `0xF7` 开始的三个大端 20 位输出寄存器
（压力 MSB、LSB、XLSB）以及从 `0xFA` 开始的三个温度寄存器给出结果。
原始 20 位计数值使用存放在 `0x88` 的 24 字节出厂校准块进行补偿。

`Firmata-BMP280` 包把传感器封装在 `FirmataI2C` 连接之后。
`initializeDevice` 会写入配置和测量控制寄存器（过采样 x1、Normal 模式），
然后读取校准块。使用 `startReadingPort` 时 Arduino 连续流式输出 6 个字节；
每个收到的 `I2C_REPLY` 都会覆盖最新采样值。之后即可直接读取换算后的值。

补偿运算严格遵循博世官方参考驱动的整数公式（C 整数除法、按传感器量程
限幅），因此结果与数据手册计算完全一致。

## 2. 技术参数

- 气压、温度一体式传感器。
- 压力范围：300–1100 hPa；输出最高 20 位，大端（MSB 在前）。
- 温度绝对精度：±1.0 °C；分辨率 0.01 °C。
- 压力分辨率：0.01 hPa（输出单位）；典型 RMS 噪声远低于 1 hPa。
- I2C 从机地址：**0x76**（SDO 拉低）或 **0x77**（SDO 拉高）。
- 工作电压：1.71–3.6 V。
- 芯片 ID 寄存器（`0xD0`）返回 **0x58**。
- `0x88` 处有 24 字节校准数据（dig_T1..T3、dig_P1..P9）。

## 3. 接线

| BMP280 | Arduino Uno |
| --- | --- |
| VCC | 3.3 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| SDO | GND（用于地址 0x76） |

常见模块通常已带 I2C 上拉电阻；否则在 SDA/SCL 与 VCC 之间接 4.7 kΩ。
SDO 决定地址：GND → 0x76，VCC → 0x77。

## 4. 类与 API

`FirmataBMP280` 继承自 `FirmataI2CDevice`（包 `Firmata-I2C`）。

- 初始化：`initializeDevice`（写入 `config` 0x00 和 `ctrl_meas` 0x27，
  然后读取 24 字节校准）、`registerWithFirmata`（接线之后！）、
  可选 `readChipId`。
- 读取：`startReadingPort`（连续）或 `readOnce`（读取一次 `0xF7` 处的
  6 个输出字节）。
- 原始输出：`rawPressure`/`rawTemperature`（20 位大端整数计数值）、
  `chipId`（`readChipId` 之后）。
- 补偿后输出：
  - `compensatedTemperature` — 以 0.01 °C 为单位的整数，限幅到
    [-4000, 8500]（−40.00 °C 至 85.00 °C）。
  - `temperatureCelsius` — 摄氏温度（Float）。
  - `compensatedPressure` — 以 Pa 为单位的整数，限幅到
    [30000, 110000]。
  - `pressurePascal` — 同 `compensatedPressure`。
  - `pressureHectoPascal` — 以 hPa 为单位的压力（Float）。
- 校准：`calibrationData`（24 字节）、`isCalibrationLoaded`。
- 内部：`tFine`（温度与压力公式共用的精细温度）。
- 接收：`handleI2CReply:data:` 分发芯片 ID、校准和输出响应。
- 继承的辅助方法（`FirmataI2CDevice`）：`firmata:address:`、
  `writeRegister:data:`、`readRegister:byteCount:`、
  `readRegisterContinuously:byteCount:`、`stopReading`。

`FirmataBMP280Constants`（类侧）包含寄存器（`calibrationRegister` 0x88、
`chipIdRegister` 0xD0、`configRegister` 0xF5、`ctrlMeasRegister` 0xF4、
`dataRegister` 0xF7、`resetRegister` 0xE0、`statusRegister` 0xF3）、
配置（`configValue` 0x00、`ctrlMeasValue` 0x27）、规范（`chipIdValue` 0x58、
`calibrationByteCount` 24、`sensorOutputByteCount` 6）和默认值
（`defaultAddress` 0x76）。

## 5. 示例

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

"可选：芯片识别"
sensor readChipId.
sensor chipId.                          "16r58"

"启动连续流式读取"
sensor startReadingPort.

"... 几步之后："
sensor temperatureCelsius.              "摄氏温度"
sensor pressureHectoPascal.             "气压（hPa）"

"读取单次采样："
sensor readOnce.

"停止流式读取："
sensor stopReading.
```

## 6. 说明

- **20 位数值为大端：** 压力顺序为 MSB、LSB、XLSB；XLSB 的低半字节始终为零。
  原始值为 `((MSB << 16) + (LSB << 8) + XLSB) >> 4`。
- **输出顺序：** `0xF7` 处的 6 个字节依次为压力 MSB、LSB、XLSB，然后是
  温度 MSB、LSB、XLSB。`rawPressure` 和 `rawTemperature` 分别从第 1 个和
  第 4 个字节展开。
- **补偿为整数运算：** 与博世参考驱动一致，采用向零截断除法（`quo:`），
  温度与压力公式共用同一个 `t_fine`，并限幅到传感器量程。
- **校准前为 nil：** `temperatureCelsius`、`compensatedPressure` 和
  `tFine` 在校准块到达前返回 nil。复位后请再次调用 `initializeDevice`
  或等待下一次响应。
- **芯片 ID 检查：** `readChipId` + `chipId` 应返回 `0x58`，否则存在通信错误。
- **寄存器 `0xF7` 与 Firmata Sysex 结束符** `0xF7` 无关：测试的字节数组
  中两者都会出现，但输出寄存器 `0xF7` 只是 I2C 总线上的芯片寄存器地址。
- **多传感器：** 把 SDO 接到 VCC 以获得地址 0x77，并在同一个 `FirmataI2C`
  连接上注册第二个 `FirmataBMP280` 实例。
