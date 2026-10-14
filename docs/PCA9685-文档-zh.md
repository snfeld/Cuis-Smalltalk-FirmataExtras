# PCA9685 — 16 通道 PWM/舵机驱动模块

目录：
1. 概述
2. 技术规格
3. 接线
4. 类与 API
5. 示例
6. 注意事项

---

## 1. 概述

**PCA9685**（NXP）是一款 I2C 总线上的 16 通道 PWM 驱动器。16 个通道中的每一个
都产生 12 位 PWM 信号（每周期 4096 步），可用于驱动舵机、LED、电机控制器或其它
脉冲控制负载。多块芯片级联后甚至可以驱动多达 64 路输出。

`Firmata-PCA9685` 包将该芯片封装在 `FirmataI2C` 连接之后：寄存器访问经由
Arduino（I2C SYSEX）完成，舵机辅助方法 `setServoOnChannel:angle:` 将角度换算为
脉冲宽度。

## 2. 技术规格

- 16 个独立 PWM 通道，12 位分辨率（0–4095）。
- 内部振荡器：25 MHz；PWM 频率可编程（通常 40–1000 Hz，默认 50 Hz；可用范围由
  预分频分辨率决定）。
- I2C 从机地址：地址引脚 A0–A5 接地时为 **0x40**（通过
  `FirmataPCA9685Constants defaultAddress`），最多 62 个地址。
- 大于等于 **4096** 的值强制“全亮”；负值关闭通道。
- 每个通道：ON/OFF 相位寄存器（从 0x06 起每通道 4 个寄存器）。

## 3. 接线

| PCA9685 | Arduino |
| --- | --- |
| VCC | 3.3 V（逻辑电平兼容的板子可用 5 V） |
| GND | GND（与 Arduino 及输出电源共地） |
| SDA | A4（Uno）/ 20（Mega）——StandardFirmata 板载引脚 |
| SCL | A5（Uno）/ 21（Mega） |
| V+（若有） | 输出的外部电源（舵机！） |
| A0–A5 | 接地得到地址 0x40，否则为其它地址 |

舵机请**单独供电**（5 V，电流要足够！）并连接所有地线。大多数扩展板已带 I2C
上拉电阻。

## 4. 类与 API

`FirmataPCA9685` 继承自 `FirmataI2CDevice`（包 `Firmata-I2C`）。

- 初始化：`initialize`、`initializeDevice`（定义 Mode1/Mode2，启用寄存器自动递增，
  按 `frequency` 设置 PWM 频率，并关闭所有输出）。
- PWM：`setPWMOnChannel:value:`、`setAllPWM:`、`setFrequency:`、
  `prescaleForFrequency:`。
- 舵机：`setServoOnChannel:angle:`、
  `setServoOnChannel:angle:minPulse:maxPulse:`、
  `pwmCountsForServoAngle:minPulse:maxPulse:`、`pwmCountsForMicroseconds:`。
- 访问：`frequency` / `frequency:`、`numberOfChannels`。
- 继承的帮助方法（`FirmataI2CDevice`）：`firmata:address:`、
  `registerWithFirmata`、`writeRegister:data:`、`readRegister:byteCount:`、
  `readRegisterContinuously:byteCount:`、`stopReading`。
- `handleI2CReply:data:` 此处有意留空（只写芯片）。

`FirmataPCA9685Constants`（类侧）存放寄存器（如 `mode1Register`、
`mode2Register`、`preScaleRegister`、`led0OnLowRegister`、
`allLedOnLowRegister`、`allLedOffLowRegister`）、模式位（`sleepBit`、
`restartBit`、`mode1Default` = 0x20 自动递增、`mode2Default`）以及规格
（`numberOfChannels` = 16、`resolutionSteps` = 4096、`oscillatorFrequency` = 25 MHz、
`channelRegisterStep` = 4），另有默认值（`defaultAddress` = 0x40、
`defaultFrequency` = 50 Hz、`defaultMinPulseMicroseconds` = 544、
`defaultMaxPulseMicroseconds` = 2400）。

## 5. 示例

```smalltalk
| bus driver |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

driver := FirmataPCA9685 new.
driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
driver initializeDevice.                     "模式、自动递增、50 Hz"

driver setPWMOnChannel: 0 value: 2048.      "通道 0 的 LED：半亮度"
driver setPWMOnChannel: 1 value: -1.        "通道 1 关闭"
driver setAllPWM: 0.                        "全部关闭"

"通道 2 上的舵机转到 90 度"
driver setServoOnChannel: 2 angle: 90.

"使用自定义脉冲范围的舵机（500 µs .. 2500 µs）"
driver setServoOnChannel: 3 angle: 30 minPulse: 500 maxPulse: 2500.

"其他 PWM 频率（60 Hz）同样通过该方法设置"
driver setFrequency: 60.
```

## 6. 注意事项

- **`initializeDevice` 需要调用一次：** 若不调用，MODE1 的自动递增位处于关闭
  状态，同时写入低字节和高字节相位（每个 `setPWMOnChannel:value:` 和
  `setServoOnChannel:angle:`）时芯片会丢弃高字节，通道得到的脉冲过短——舵机
  干脆不会转动。该方法还会设置振荡器，因为芯片上电时预分频为 30
  （~196.9 Hz），而计数值是按 `frequency` 计算的。
- **取值范围：** 0–4095 设置 ON/OFF 相位对；≥ 4096 = 全亮，< 0 = 全关。
- **频率更改**经过 休眠–预分频–唤醒–重启 序列；请使用 `setFrequency:` 而不是
  直接操作寄存器。在 `initializeDevice` 之后、第一次 `setFrequency:` 之前，
  舵机无法正确转动；只有在之后更改频率时才需要调用 `setFrequency:`。
- **角度限幅：** `setServoOnChannel:angle:` 限制在 0–180°；脉冲宽度在 `minPulse`
  与 `maxPulse` 之间线性变化（默认 544/2400 µs，符合 StandardFirmata 舵机约定）。
- **只写：** 芯片只被写入；`handleI2CReply:data:` 保持为空，不会读取任何内容。
- **多芯片级联：** 设置 A0–A5 地址引脚；在同一 `FirmataI2C` 连接上为每块芯片
  注册一个 `FirmataPCA9685` 实例。
