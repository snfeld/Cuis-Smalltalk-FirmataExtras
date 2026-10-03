# MPU6050 — 6 軸 IMU

目次：
1. 概要
2. 技術仕様
3. 配線
4. クラスと API
5. 例
6. 注意点

---

## 1. 概要

**MPU6050**（InvenSense）は、3 軸加速度計、3 軸ジャイロスコープ、温度センサー
を備えた 6 軸モーションセンサーです。すべての測定値は `ACCEL_XOUT_H`（`0x3B`）
から始まる連続した 14 個のレジスタに並んでおり、1 回の連続 I2C 読み取りで
ストリーミングできます。

`Firmata-MPU6050` パッケージは、このセンサーを `FirmataI2C` 接続の背後にラップ
します。`startReading` を使うと Arduino が出力レジスタを継続的にストリーミング
し、届いた各 `I2C_REPLY` が直前のサンプルを上書きします。生の値とスケール済みの
値（g と 度/秒）をそのまま読み取ることができます。

簡単に言えば：`accelX` = 生カウント ±32767、`scaledAccelX` = 加速度（g）、
`scaledGyroX` = 回転角速度（度/秒）です。

## 2. 技術仕様

- 加速度計：3 軸、16 ビット、フルスケールは選択可能
  **±2 g / ±4 g / ±8 g / ±16 g**（感度 16384/8192/4096/2048 LSB/g）。
- ジャイロスコープ：3 軸、16 ビット、フルスケールは選択可能
  **±250 / ±500 / ±1000 / ±2000 度/秒**（感度 131/65.5/32.8/16.4
  LSB/(度/秒)）。
- 温度：16 ビット、スケール 340 LSB/°C、オフセット 36.53 °C。
- 0x3B から連続する 14 個の出力レジスタ（生の加速度・温度・ジャイロ、
  ビッグエンディアン、16 ビット符号付き）。
- I2C スレーブアドレス：AD0 ピンが LOW のとき **0x68**（そうでなければ 0x69）。
  `whoAmI` は 0x68 を応答します。
- 内部 8 MHz クロック。センサーはスリープモードで起動します
  （`initializeDevice` が起こします）。

## 3. 配線

| MPU6050 | Arduino |
| --- | --- |
| VCC | 3.3 V（レベルシフト付きかいヒト板なら 5 V も可） |
| GND | GND |
| SDA | A4（Uno）/ 20（Mega） |
| SCL | A5（Uno）/ 21（Mega） |
| AD0 | アドレス 0x68 にするなら GND、0x69 なら VCC |
| INT（任意） | 接続しない（ポーリングは Firmata の step で行う） |

一般的なかいヒト板には I2C プルアップ抵抗があります。無い場合は SDA/SCL から
VCC へ 4.7 kΩ を付けます。

## 4. クラスと API

`FirmataMPU6050` は `FirmataI2CDevice`（パッケージ `Firmata-I2C`）を継承します。

- 初期化：`initialize`、`initializeDevice`（スリープビットを消してセンサーを
  有効化）、`registerWithFirmata`（配線後に呼びます！）。
- センサー設定：`setAccelerationRange:`（0–3 ↔ ±2/4/8/16 g）、
  `setGyroRange:`（0–3 ↔ ±250/500/1000/2000 度/秒）。
- 読み取り：`startReading`（継続）または `readOnce`（1 回のみ）。
  停止は `stopReading`。
- 生の出力：`accelX`/`accelY`/`accelZ`、`gyroX`/`gyroY`/`gyroZ`、
  `temperature`（単位 °C）。
- スケール済み出力：`scaledAccelX`/`scaledAccelY`/`scaledAccelZ`（単位 g）、
  `scaledGyroX`/`scaledGyroY`/`scaledGyroZ`（単位 度/秒）——設定したフルスケール
  に依存します。
- 感度：`accelSensitivity`（LSB/g）、`gyroSensitivity`（LSB/(度/秒)）。レンジ
  が 1 段上がるごとに半減します。
- レンジインデックス：`accelRange`、`gyroRange`。
- 継承したヘルパー（`FirmataI2CDevice`）：`firmata:address:`、
  `registerWithFirmata`、`writeRegister:data:`、`readRegister:byteCount:`、
  `readRegisterContinuously:byteCount:`、`stopReading`。

`FirmataMPU6050Constants`（クラス側）はレジスタ（`accelXHighRegister` 0x3B、
`gyroXHighRegister` 0x43、`temperatureHighRegister` 0x41、
`accelConfigRegister` 0x1C、`gyroConfigRegister` 0x1B、`configRegister` 0x1A、
`smplrtDivRegister` 0x19、`powerManagement1Register` 0x6B、
`powerManagement2Register` 0x6C、`whoAmIRegister` 0x75）、電源ビット
（`awakeValue` 0、`deviceResetBit`、`sleepBit`、`temperatureDisableBit`）、
仕様（`accelSensitivity` 16384、`gyroSensitivity` 131.0、
`sensorOutputByteCount` 14、`temperatureScaleFactor` 340.0、
`temperatureOffset` 36.53）、デフォルト値（`defaultAddress` 0x68、
`defaultAccelRange` 0、`defaultGyroRange` 0）を保持します。

## 5. 例

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

"より高感度なレンジを選ぶ（任意）"
sensor setAccelerationRange: 1.    "+/-4 g"
sensor setGyroRange: 1.            "+/-500 度/秒"

"継続的なストリーミングを開始"
sensor startReading.

"... 数ステップ後に："
sensor accelZ.                     "Z 軸の生の 16 ビットカウント"
sensor scaledAccelZ.               "Z 軸加速度（g）"
sensor scaledGyroX.                "X 軸回転角速度（度/秒）"
sensor temperature.                "温度（°C）"

"または 1 回だけ読み取る："
sensor readOnce.

"ストリーミングを停止："
sensor stopReading.
```

## 6. 注意点

- **生の値はビッグエンディアンの符号付き**（16 ビット）です。サンプルは
  `I2C_REPLY` を受け取るまではありません。最初の応答を処理するまでアクセサは
  `nil` です。
- **スケール変換：** `scaled*` = 生値 ÷ 設定レンジの感度。例（±2 g 時）：
  `scaledAccelX := accelX / 16384.0`。
- **レンジ変更**（`setAccelerationRange:`/`setGyroRange:`）は設定レジスタに
  書き込みます。有効なインデックスは 0–3、それ以外は `error:` になります。
- **温度の計算式：** `生値/340.0 + 36.53`（°C）。
- **安定化：** 起動直後は少し落ち着くまで待ってください。初回は `whoAmI`
  （0x68）を読んで整合性を確認します。
- **複数センサー：** AD0 を 0x69 に設定し、同じ `FirmataI2C` 接続上に 2 台目の
  `FirmataMPU6050` インスタンスを登録します。
