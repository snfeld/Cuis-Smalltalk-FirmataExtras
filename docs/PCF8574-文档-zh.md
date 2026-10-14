# PCF8574 – 8位I/O扩展器

目录：
1. 概述
2. 技术参数
3. 接线
4. 类与API
5. 示例
6. 注意事项

---

## 1. 概述

**PCF8574**（NXP/Texas Instruments）是一款通过I2C通信的8位准双向I/O扩展器。与基于寄存器的传感器不同，它**没有寄存器寻址** — 单字节的写入或读取操作即可控制整个端口（8个引脚）。

每个引脚均为准双向：写入`1`将引脚配置为带内部弱上拉的输入模式；写入`0`将引脚配置为低电平输出。要读取输入，必须先将所有引脚设置为`1`，然后才能读取端口。

`Firmata-PCF8574`包将扩展器封装在`FirmataI2C`连接之后。`readPort`方法使用无寄存器I2C读取格式（StandardFirmata ≥ 2.5），以避免损坏端口状态。

## 2. 技术参数

- 8位准双向I/O引脚：无寄存器寻址，单字节控制整个端口。
- 工作电压：**2.6 V – 6 V**。
- 功耗：最大**100 µA**。
- 灌电流：每引脚**25 mA**。
- I2C地址范围：**0x20 – 0x27**（3个地址引脚A0–A2；全部拉低 = 0x20）。
- 上电默认值：所有引脚为高电平（输入模式）。
- INT输出：开漏，低电平有效（本包不使用）。

准双向引脚模式：

| 写入值 | 引脚状态 |
| --- | --- |
| `1` | 输入模式，带内部弱上拉（弱上拉） |
| `0` | 输出模式，低电平 |

没有独立的输入/输出方向寄存器：同一个字节同时定义了方向和输出电平。

## 3. 接线

| PCF8574 | Arduino Uno |
| --- | --- |
| VCC | 5 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| A0 | GND（地址 0x20） |
| A1 | GND（地址 0x20） |
| A2 | GND（地址 0x20） |
| P0–P7 | I/O引脚 |

在同一I2C总线上使用第二个扩展器时，将A0接VCC（地址0x21）。如果分线板上没有上拉电阻，需在SDA/SCL上接4.7 kΩ上拉电阻到VCC。

## 4. 类与API

`FirmataPCF8574`继承自`FirmataI2CDevice`（包`Firmata-I2C`）。

- 初始化：`initializeDevice`（配置I2C设置），`registerWithFirmata`（接线之后！）。
- 写入：`writePort:`（向整个端口发送8位字节），`digitalWritePin:value:`（设置单个引脚；读取当前端口状态并仅修改相关位）。
- 读取：`readPort`（无寄存器I2C读取；结果在`inputValue`中），`digitalReadPin:`（返回指定引脚的`true`/`false`）。
- 流：`startReadingPort`（通过Firmata步骤启动连续轮询），`stopReading`（停止流）。
- 回调：`handleI2CReply:data:`（处理传入的`I2C_REPLY`数据并更新`inputValue`/`outputValue`）。

`FirmataPCF8574Constants`（类侧）包含`portRegister`（0）、`pinCount`（8）、`defaultAddress`（0x20）、`allPinsHigh`（0xFF）。

`handleI2CReply:data:`由`FirmataI2C`连接在收到`I2C_REPLY`消息时自动调用，无需手动触发。`startReadingPort`通过Firmata步骤以轮询间隔持续读取端口，`inputValue`保存最后一个完整端口字节。

## 5. 示例

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

"将所有引脚配置为输入"
expander writePort: 16rFF.

"引脚0–3为输出（低电平），引脚4–7为输入"
expander writePort: 16r0F.

"设置单个引脚"
expander digitalWritePin: 0 value: true.

"读取端口"
expander readPort.
expander inputValue.               "最后读取的端口字节"

"读取单个引脚"
expander digitalReadPin: 4.         "引脚4为高电平时返回true"

"启动/停止连续轮询"
expander startReadingPort.
expander stopReading.
```

## 6. 注意事项

- **准双向引脚：** 写入`1`将引脚配置为带内部弱上拉的输入模式。写入`0`将引脚配置为低电平输出。与其他I/O扩展器不同，没有方向或配置寄存器。
- **读取输入：** 读取前必须将所有引脚设置为`1`（`writePort: 16rFF`），否则引脚将驱动上次输出值的低电平，无法获得正确的输入信号。
- **无寄存器读取：** `readPort`方法使用无寄存器I2C读取格式（StandardFirmata ≥ 2.5，argc ≠ 6）。这可防止意外发送的寄存器字节损坏端口状态。
- **多设备：** 同一I2C总线上最多8个PCF8574，通过不同地址（A0–A2）区分。为每个设备注册独立的`FirmataPCF8574`实例。
- **无内部寄存器映射：** 与基于寄存器的I2C设备不同，没有寄存器映射。每次写入/读取操作直接作用于8个I/O引脚。
- **电源：** PCF8574最大功耗100 µA；对于更大负载（最高25 mA灌电流），应使用外部驱动级。
- **拉电阻：** 输入端使用内部弱上拉即可，无需额外上拉电阻；但若输入为中阻抗信号源，请考虑外部上拉以保证明确的高电平。
