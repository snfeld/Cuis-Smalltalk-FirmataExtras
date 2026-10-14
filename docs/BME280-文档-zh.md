# BME280 – 湿度、气压与温度传感器

目录:
1. 概述
2. 技术参数
3. 接线
4. 类与 API
5. 示例
6. 说明

---

## 1. 概述

**BME280**（Bosch Sensortec）是一款相对湿度、气压和温度一体式传感器。
它与 BMP280 一样提供气压和温度输出（`0xF7`、`0xFA` 处的大端 20 位
寄存器），并且在 `0xFD` 处还有一个 16 位相对湿度输出。数据使用两个
校准块进行补偿：位于 `0x88` 的 26 字节温度/气压块（第 26 字节，即
`0xA1`，是无符号湿度系数 `dig_H1`）以及位于 `0xE1` 的 7 字节湿度块。

`Firmata-BME280` 包在 `FirmataI2C` 连接之后扩展 `Firmata-BMP280`。
`initializeDevice` 会*在* `CTRL_MEAS` 之前写入 `CTRL_HUM`（`0xF2`）
（芯片要求），然后写入配置和测量控制寄存器，最后读取两个校准块。
`startReadingPort` 让 Arduino 连续流式输出 `0xF7` 处的六个气压/温度字节
和 `0xFD` 处的两个湿度字节；每个收到的 `I2C_REPLY` 都会覆盖最新采样值。

六个湿度系数（`dig_H1`..`dig_H6`）从按半字节打包的 0xE1 块中解析，
湿度补偿遵循博世官方参考驱动的整数公式（截断除法、按传感器量程限幅）。
温度与气压补偿继承自 `FirmataBMP280`。

## 2. 技术参数

- 相对湿度、气压、温度一体式传感器。
- 湿度范围：0–100 % RH；分辨率 0.008 % RH（输出为 Q10，故 102400 = 100 %）。
- 气压范围：300–1100 hPa；温度分辨率 0.01 °C。
- I2C 从机地址：**0x76**（SDO 拉低）或 **0x77**（SDO 拉高）。
- 工作电压：1.71–3.6 V。
- 芯片 ID 寄存器（`0xD0`）返回 **0x60**（不同于 BMP280 的 0x58）。
- 校准：`0x88` 处 26 字节（dig_T1..T3、dig_P1..P9、dig_H1），`0xE1` 处
  7 字节（dig_H2..dig_H6，按半字节打包）。

## 3. 接线

| BME280 | Arduino Uno |
| --- | --- |
| VCC | 3.3 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| SDO | GND（用于地址 0x76） |

常见模块通常已带 I2C 上拉电阻；否则在 SDA/SCL 与 VCC 之间接 4.7 kΩ。
SDO 决定地址：GND → 0x76，VCC → 0x77。

## 4. 类与 API

`FirmataBME280` 继承自 `FirmataBMP280`（包 `Firmata-BMP280`）。

- 初始化：`initializeDevice`（先写 `CTRL_HUM` 0x01，再写 `config` 0x00 和
  `ctrl_meas` 0x27，然后读取 `0x88` 的 26 字节和 `0xE1` 的 7 个湿度校准字节）、
  `registerWithFirmata`（接线之后！）、可选 `readChipId`。
- 读取：`startReadingPort`（`0xF7` 和 `0xFD` 的连续流）或 `readOnce`
  （两者各读一次）。
- 原始输出：`rawPressure`/`rawTemperature`（20 位）、`rawHumidity`
  （16 位大端）、`chipId`。
- 补偿后输出：
  - `temperatureCelsius`、`compensatedTemperature`、`pressureHectoPascal`、
    `pressurePascal`、`compensatedPressure` — 继承自 `FirmataBMP280`。
  - `compensatedHumidity` — 相对湿度（Q10 整数），限幅到 [0, 102400]
    （102400 = 100 %）。
  - `humidityPercent` — 相对湿度百分比（Float）= `compensatedHumidity
    / 1024.0`。
- 校准：`calibrationData`（26 字节）、`humidityCalibration`（7 字节）、
  `isCalibrationLoaded`、`isHumidityCalibrationLoaded`，以及解析后的系数
  `digH1`..`digH6`（可供测试访问）。
- 接收：`handleI2CReply:data:` 先分发湿度校准与湿度输出响应，再委托给
  `FirmataBMP280`。
- 继承的辅助方法（`FirmataI2CDevice`）：`firmata:address:`、
  `writeRegister:data:`、`readRegister:byteCount:`、
  `readRegisterContinuously:byteCount:`、`stopReading`。

`FirmataBME280Constants` 扩展 `FirmataBMP280Constants`，新增
（`ctrlHumRegister` 0xF2、`humidityCalibrationRegister` 0xE1、
`humidityDataRegister` 0xFD）、规范（`calibrationByteCount` 26、
`humidityCalibrationByteCount` 7、`humidityOutputByteCount` 2、
`chipIdValue` 0x60）和默认值（`defaultAddress` 0x76）。

## 5. 示例

```smalltalk
| bus sensor |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

sensor := FirmataBME280 new.
sensor firmata: bus address: FirmataBME280Constants defaultAddress.
sensor initializeDevice.
sensor registerWithFirmata.

"可选：芯片识别"
sensor readChipId.
sensor chipId.                          "16r60"

"启动连续流式读取"
sensor startReadingPort.

"... 几步之后："
sensor temperatureCelsius.              "摄氏温度"
sensor pressureHectoPascal.             "气压（hPa）"
sensor humidityPercent.                 "相对湿度（%）"

"读取单次采样："
sensor readOnce.

"停止流式读取："
sensor stopReading.
```

## 6. 说明

- **`CTRL_HUM` 须在 `CTRL_MEAS` 之前写入：** BME280 只有在该寄存器先于
  测量控制寄存器写入时，才会采用 `CTRL_HUM`（`0xF2`）中的湿度过采样。
  `initializeDevice` 已按正确顺序执行。
- **26 字节校准：** BME280 需要完整的 26 字节 0x88 块；第 26 字节
  （寄存器 `0xA1`）为无符号 `dig_H1`。BMP280 只需前 24 字节。
- **湿度校准布局（`0xE1`..`0xE7`）：** `dig_H2` 是 `0xE1` 处的有符号
  16 位小端值，`dig_H3` 是 `0xE3` 处的无符号值，`dig_H4` 和 `dig_H5`
  由有符号 MSB 字节（`0xE4`/`0xE6`）加上 `0xE5` 的一个半字节组成
  （`dig_H4` 用低半字节，`dig_H5` 用高半字节），`dig_H6` 是 `0xE7` 处
  的有符号字节。系数 `digH1`..`digH6` 据此解析。
- **湿度输出为 16 位大端**（`0xFD`，MSB 在前）。
- **补偿为整数运算：** 与博世参考驱动一致，采用向零截断除法（`quo:`），
  温度、气压和湿度公式共用同一个 `t_fine`，并限幅到传感器量程。
- **校准前为 nil：** 两个校准块都收到之前，补偿值返回 nil。
- **芯片 ID 检查：** `readChipId` + `chipId` 应返回 `0x60`，否则存在
  通信错误。
- **多传感器：** 把 SDO 接到 VCC 以获得地址 0x77，并在同一个 `FirmataI2C`
  连接上注册第二个 `FirmataBME280` 实例。
