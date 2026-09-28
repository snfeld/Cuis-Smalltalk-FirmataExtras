# ADXL345 – 3軸加速度センサー

目次：
1. 概要
2. 技術仕様
3. 配線
4. クラスとAPI
5. 使用例
6. 注意点

---

## 1. 概要

**ADXL345**（Analog Devices）は、フル解像度モードで13ビット分解能を持つ
3軸デジタル加速度センサーです。静的加速度（重力）と動的加速度（運動、
振動）を測定し、各軸の連続レジスタ（`DATAX0`から`DATAZ1`、6バイト）に
リトルエンディアン16ビット値として出力します。

`Firmata-ADXL345`パッケージは、`FirmataI2C`接続の背後にセンサーを
カプセル化します。`startReadingPort`を使用すると、Arduinoが出力レジスタを
ストリーミングします。受信した各`I2C_REPLY`が最新のサンプルを上書きします。
生値とスケーリングされた値は直接アクセス可能です。

フル解像度モードでは、選択したレンジに関係なく感度は256 LSB/gに固定されます。
レンジは最大測定範囲のみに影響し、1gあたりの分解能には影響しません。

## 2. 技術仕様

- 3軸加速度センサー、13ビットフル解像度（4 mg/LSB、256 LSB/g）、全レンジで共通。
- 選択可能なフルスケールレンジ：**±2g**（インデックス0）、**±4g**（1）、
  **±8g**（2）、**±16g**（3）。
- 出力データレート：`BW_RATE`レジスタ（`0x2C`）で設定、コード0x00（0.1 Hz）
  ～0x0F（3200 Hz）、デフォルト0x0A（100 Hz）。
- 6つの出力レジスタ、`DATAX0`（`0x32`）から：X0、X1、Y0、Y1、Z0、Z1
  （リトルエンディアン、符号付き16ビット）。
- I2Cスレーブアドレス：**0x53**（ALT ADDRESS HIGH）または
  **0x1D**（ALT ADDRESS LOW）。
- 動作電圧：2.0〜3.6V。消費電力：23 µA（測定時）、0.1 µA（待機時）。
- DEVIDレジスタ（`0x00`）はデバイス識別用に0xE5を返します。

## 3. 配線

| ADXL345 | Arduino Uno |
| --- | --- |
| VCC | 3.3V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| CS | VCC（I2Cモード用） |
| SDO | GND（アドレス0x53用） |

一般的なブレークアウトボードにはI2Cプルアップ抵抗が搭載されています。
なければ、SDA/SCLとVCCの間に4.7kΩを接続してください。
CSピンはハイに固定してI2Cモードを有効にします。SDOがアドレスを決定します：
GND → 0x53、VCC → 0x1D。

## 4. クラスとAPI

`FirmataADXL345`は`FirmataI2CDevice`を継承します（パッケージ`Firmata-I2C`）。

- 初期化：`initializeDevice`（`POWER_CTL`レジスタのmeasureビットをセット）、
  `registerWithFirmata`（配線後！）。
- センサー設定：`setAccelerationRange:`（0–3 ↔ ±2/4/8/16g）、
  `setSampleRate:`（0x00–0x0Fで0.1Hz〜3200Hz）。
- 読み取り：`startReadingPort`（連続）または`readOnce`（単一サンプル）。
- 生出力：`accelX`/`accelY`/`accelZ`（符号付き16ビットリトルエンディアン）。
- スケーリング出力：`scaledAccelX`/`scaledAccelY`/`scaledAccelZ`（単位g）
  — 生値を256.0で割った値（フル解像度固定感度）。
- 感度とレンジ：`accelSensitivity`（256 LSB/g、固定）、
  `accelRange`（現在のレンジインデックス）、`sampleRate`（現在のコード）。
- 受信処理：`handleI2CReply:data:`がArduinoの6バイト応答を処理します。
- 継承ヘルパー（`FirmataI2CDevice`）：`firmata:address:`、
  `writeRegister:data:`、`readRegister:byteCount:`、
  `readRegisterContinuously:byteCount:`、`stopReading`。

`FirmataADXL345Constants`（クラス側）は以下の保持：
レジスタ（`dataFormatRegister` 0x31、`bandwidthRateRegister` 0x2C、
`powerControlRegister` 0x2D、`dataX0Register` 0x32、`deviceIdRegister` 0x00）、
ビット（`fullResolutionBit`、`measureBit`）、仕様
（`accelSensitivity` 256、`deviceIdValue` 0xE5、`sensorOutputByteCount` 6）、
デフォルト値（`defaultAddress` 0x53、`defaultAccelRange` 0、
`defaultSampleRate` 0x0A）。

## 5. 使用例

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

"レンジとレートの設定（オプション）"
sensor setAccelerationRange: 1.    "±4g"
sensor setSampleRate: 16r0B.       "200 Hz"

"連続ストリーミング開始"
sensor startReadingPort.

"... 数ステップ後："
sensor accelZ.                     "生のLE-16ビットZ値"
sensor scaledAccelZ.               "Z加速度（単位g）"

"単一サンプルの読み取り："
sensor readOnce.

"ストリーミング停止："
sensor stopReading.
```

## 6. 注意点

- **生値はリトルエンディアンの符号付き16ビット**です。LSBは最初のレジスタ
  （`DATAX0`）に、MSBは2番目のレジスタ（`DATAX1`）にあります。これは
  MPU6050（ビッグエンディアン）とは異なります。
- **フル解像度モード（full_res）：** 常に有効 — 選択したレンジに関係なく
  感度は256 LSB/gに固定されます。レンジは最大測定範囲のみを決定します。
- **スケーリング：** `scaled*` = 生値 / 256.0。例：`scaledAccelZ :=
  accelZ / 256.0`。
- **レンジ切替**（`setAccelerationRange:`）は`DATA_FORMAT`レジスタの
  ビット0〜1を書き込みます。フル解像度ビット（ビット3）は維持されます。
- **起動後の安定化：** 電源投入または`initializeDevice`実行後、少し待つ
  必要があります。センサーの安定に数ミリ秒必要です。
- **DEVID確認：** `DEVID`レジスタ（`0x00`）は`0xE5`を返す必要があります。
  異なる場合は通信エラーが発生しています。
- **複数センサー：** SDOをVCCに接続してアドレス0x1Dを使用し、同じ
  `FirmataI2C`接続に2番目の`FirmataADXL345`インスタンスを登録します。
