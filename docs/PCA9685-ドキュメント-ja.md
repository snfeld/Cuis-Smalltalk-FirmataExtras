# PCA9685 — 16 チャンネル PWM/サーボドライバ

目次：
1. 概要
2. 技術仕様
3. 配線
4. クラスと API
5. 例
6. 注意点

---

## 1. 概要

**PCA9685**（NXP）は、I2C バス上の 16 チャンネル PWM ドライバです。16 チャン
ネルのそれぞれが 12 ビット PWM 信号（1 周期 4096 ステップ）を出力し、サーボ、
LED、モーターコントローラ、その他のパルス制御負荷を駆動できます。複数チップ
をカスケード接続すれば最大 64 出力を駆動できます。

`Firmata-PCA9685` パッケージはこのチップを `FirmataI2C` 接続の背後にラップし
ます。レジスタアクセスは Arduino 経由（I2C SYSEX）で行われ、サーボヘルパー
`setServoOnChannel:angle:` が角度をパルス幅に変換します。

## 2. 技術仕様

- 独立した PWM チャンネル 16 本、12 ビット分解能（0–4095）。
- 内部オシレータ：25 MHz。PWM 周波数はプログラマブル（通常 40–1000 Hz、
  デフォルト 50 Hz）。使用可能な範囲はプリスケーラ分解能で決まります。
- I2C スレーブアドレス：アドレスピン A0–A5 を接地すると **0x40**
  （`FirmataPCA9685Constants defaultAddress`）。最大 62 アドレス。
- **4096** 以上の値は「完全オン」を強制し、負の値はチャンネルをオフにします。
- 各チャンネル：ON/OFF フェーズレジスタ（0x06 から各チャンネル 4 レジスタ）。

## 3. 配線

| PCA9685 | Arduino |
| --- | --- |
| VCC | 3.3 V（ロジックレベル対応ボードなら 5 V） |
| GND | GND（Arduino および出力電源と共通） |
| SDA | A4（Uno）/ 20（Mega）— StandardFirmata のボードピン |
| SCL | A5（Uno）/ 21（Mega） |
| V+（あれば） | 出力用の外部電源（サーボ！） |
| A0–A5 | アドレス 0x40 にするなら GND、それ以外は別アドレス |

サーボは**サーボ用電源を別に用意**し（5 V、十分な電流！）、すべてのグランドを
接続してください。I2C のプルアップ抵抗はほとんどのかいヒト板に付いています。

## 4. クラスと API

`FirmataPCA9685` は `FirmataI2CDevice`（パッケージ `Firmata-I2C`）を継承します。

- 初期化：`initialize`、`initializeDevice`（Mode1/Mode2 を定義し、レジスタの自動
  インクリメントを有効にし、PWM 周波数を `frequency` に合わせて設定し、全出力を
  オフにします）。
- PWM：`setPWMOnChannel:value:`、`setAllPWM:`、`setFrequency:`、
  `prescaleForFrequency:`。
- サーボ：`setServoOnChannel:angle:`、
  `setServoOnChannel:angle:minPulse:maxPulse:`、
  `pwmCountsForServoAngle:minPulse:maxPulse:`、`pwmCountsForMicroseconds:`。
- アクセス：`frequency` / `frequency:`、`numberOfChannels`。
- 継承したヘルパー（`FirmataI2CDevice`）：`firmata:address:`、
  `registerWithFirmata`、`writeRegister:data:`、`readRegister:byteCount:`、
  `readRegisterContinuously:byteCount:`、`stopReading`。
- `handleI2CReply:data:` はここでは意図的に空です（書き込み専用チップ）。

`FirmataPCA9685Constants`（クラス側）はレジスタ（例：`mode1Register`、
`mode2Register`、`preScaleRegister`、`led0OnLowRegister`、`allLedOnLowRegister`、
`allLedOffLowRegister`）、モードビット（`sleepBit`、`restartBit`、
`mode1Default` = 0x20 自動インクリメント、`mode2Default`）、仕様（`numberOfChannels`
= 16、
`resolutionSteps` = 4096、`oscillatorFrequency` = 25 MHz、
`channelRegisterStep` = 4）、デフォルト値（`defaultAddress` = 0x40、
`defaultFrequency` = 50 Hz、`defaultMinPulseMicroseconds` = 544、
`defaultMaxPulseMicroseconds` = 2400）を保持します。

## 5. 例

```smalltalk
| bus driver |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

driver := FirmataPCA9685 new.
driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
driver initializeDevice.                     "モード、自動インクリメント、50 Hz"

driver setPWMOnChannel: 0 value: 2048.      "チャンネル 0 の LED：半分の明るさ"
driver setPWMOnChannel: 1 value: -1.        "チャンネル 1 をオフ"
driver setAllPWM: 0.                        "すべてオフ"

"チャンネル 2 のサーボを 90 度に"
driver setServoOnChannel: 2 angle: 90.

"パルス範囲をカスタムしたサーボ（500 µs .. 2500 µs）"
driver setServoOnChannel: 3 angle: 30 minPulse: 500 maxPulse: 2500.

"別の PWM 周波数（60 Hz）も同様に設定します"
driver setFrequency: 60.
```

## 6. 注意点

- **`initializeDevice` は 1 回だけ必要です：** これがないと MODE1 の自動インクリ
  メントビットがオフになり、Low *と* High の位相バイトをまとめて書き込む
  （`setPWMOnChannel:value:` と `setServoOnChannel:angle:` のすべて）において
  チップ側が High バイトを落とし、チャンネルのパルスが著しく短くなります。そ
  の結果、サーボはまったく動きません。またチップはプリスケーラ 30
  （~196,9 Hz）で起動しますが、カウントは `frequency` を基準に計算されるため、
  このメソッドはオシレータも設定します。
- **値の範囲：** 0–4095 で ON/OFF フェーズペアを設定します。≥ 4096 は完全オン、
  < 0 は完全オフです。
- **周波数の変更**はスリープ→プリスケーラ→ウェイク→再起動の手順を踏みます。
  レジスタ直接操作ではなく `setFrequency:` を使ってください。`initializeDevice`
  の後、最初の `setFrequency:` までの間、サーボは正しく動きません。
  `setFrequency:` はその後の周波数変更時にのみ呼び出してください。
- **角度のクランプ：** `setServoOnChannel:angle:` は 0–180° に制限します。パルス
  幅は `minPulse` と `maxPulse` の間で線形に変化します（デフォルト 544/2400 µs、
  StandardFirmata のサーボ規約）。
- **書き込み専用：** このチップは書き込みのみです。`handleI2CReply:data:` は空の
  ままで、何も読み取りません。
- **複数チップ：** A0–A5 アドレスピンで設定します。同じ `FirmataI2C` 接続上で
  各チップに `FirmataPCA9685` インスタンスを 1 つ登録してください。
