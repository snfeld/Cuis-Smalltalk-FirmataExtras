# BME280 – 湿度・気圧・温度センサー 

目次:
1. 概要
2. 技術仕様
3. 配線
4. クラスと API
5. 例
6. 注意点

---

## 1. 概要

**BME280** (Bosch Sensortec) は相対湿度・気圧・温度の一体型センサーです。
BMP280 と同じ気圧・温度出力（`0xF7`・`0xFA` のビッグエンディアン 20 ビット
レジスタ）に加えて、`0xFD` に 16 ビットの相対湿度出力を持ちます。データは
2 つのキャリブレーションブロックで補正されます: `0x88` の 26 バイト温度・
気圧ブロック（26 バイト目 = `0xA1` が符号なし湿度係数 `dig_H1`）と、
`0xE1` の 7 バイト湿度ブロックです。

`Firmata-BME280` パッケージは `Firmata-BMP280` を `FirmataI2C` 接続の背後で
拡張します。`initializeDevice` は `CTRL_HUM`（`0xF2`）を `CTRL_MEAS` の
**前**に書き（チップの要件）、次に設定と測定制御レジスタを書き、最後に
両方のキャリブレーションブロックを読みます。`startReadingPort` で Arduino
が `0xF7` の気圧・温度 6 バイトと `0xFD` の湿度 2 バイトを連続ストリームし、
受信した `I2C_REPLY` ごとに最後のサンプルが上書きされます。

6 つの湿度係数（`dig_H1`..`dig_H6`）はニブル詰めの 0xE1 ブロックから解析し、
湿度は Bosch 公式リファレンスドライバの整数式（切り捨て除算、センサー範囲
へのクランプ）で補正します。温度・気圧の補正は `FirmataBMP280` から継承します。

## 2. 技術仕様

- 相対湿度・気圧・温度一体型センサー。
- 湿度範囲: 0–100 % RH。分解能 0.008 % RH（Q10 出力のため 102400 = 100 %）。
- 気圧範囲: 300–1100 hPa。温度分解能 0.01 °C。
- I2C スレーブアドレス: **0x76**（SDO を Low）または **0x77**（SDO を High）。
- 動作電圧: 1.71–3.6 V。
- チップ ID レジスタ（`0xD0`）は **0x60** を返す（BMP280 の 0x58 とは異なる）。
- キャリブレーション: `0x88` に 26 バイト（dig_T1..T3、dig_P1..P9、dig_H1）、
  `0xE1` に 7 バイト（dig_H2..dig_H6、ニブル詰め）。

## 3. 配線

| BME280 | Arduino Uno |
| --- | --- |
| VCC | 3.3 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| SDO | GND（アドレス 0x76 用） |

一般的なブレイクアウト基板には I2C プルアップが実装されています。
なければ SDA/SCL から VCC へ 4.7 kΩ を付けます。SDO でアドレスが決まり
ます: GND → 0x76、VCC → 0x77。

## 4. クラスと API

`FirmataBME280` は `FirmataBMP280`（パッケージ `Firmata-BMP280`）の
サブクラスです。

- 初期化: `initializeDevice`（先に `CTRL_HUM` 0x01、次に `config` 0x00 と
  `ctrl_meas` 0x27 を書き、その後 `0x88` の 26 バイトと `0xE1` の
  7 バイトを読む）、`registerWithFirmata`（配線後！）、任意で `readChipId`。
- 読み取り: `startReadingPort`（`0xF7` と `0xFD` の連続ストリーム）または
  `readOnce`（両方を 1 回読む）。
- 生出力: `rawPressure`/`rawTemperature`（20 ビット）、`rawHumidity`
  （16 ビット・ビッグエンディアン）、`chipId`。
- 補正済み出力:
  - `temperatureCelsius`、`compensatedTemperature`、`pressureHectoPascal`、
    `pressurePascal`、`compensatedPressure` — `FirmataBMP280` から継承。
  - `compensatedHumidity` — 相対湿度の Q10 整数。[0, 102400]
    （102400 = 100 %）にクランプ。
  - `humidityPercent` — 相対湿度（Float、%）= `compensatedHumidity / 1024.0`。
- キャリブレーション: `calibrationData`（26 バイト）、`humidityCalibration`
  （7 バイト）、`isCalibrationLoaded`、`isHumidityCalibrationLoaded`、
  解析済み係数 `digH1`..`digH6`（テストで参照可）。
- 受信: `handleI2CReply:data:` は湿度キャリブレーションと湿度出力の
  レスポンスを振り分けてから `FirmataBMP280` に委譲します。
- 継承ヘルパー（`FirmataI2CDevice`）: `firmata:address:`、
  `writeRegister:data:`、`readRegister:byteCount:`、
  `readRegisterContinuously:byteCount:`、`stopReading`。

`FirmataBME280Constants` は `FirmataBMP280Constants` を拡張し
（`ctrlHumRegister` 0xF2、`humidityCalibrationRegister` 0xE1、
`humidityDataRegister` 0xFD）、仕様（`calibrationByteCount` 26、
`humidityCalibrationByteCount` 7、`humidityOutputByteCount` 2、
`chipIdValue` 0x60）とデフォルト（`defaultAddress` 0x76）を追加します。

## 5. 例

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

"任意: チップ識別"
sensor readChipId.
sensor chipId.                          "16r60"

"連続ストリーミング開始"
sensor startReadingPort.

"... 数ステップ後:"
sensor temperatureCelsius.              "温度（℃）"
sensor pressureHectoPascal.             "気圧（hPa）"
sensor humidityPercent.                 "相対湿度（%）"

"1 サンプルだけ読む場合:"
sensor readOnce.

"ストリーミング停止:"
sensor stopReading.
```

## 6. 注意点

- **`CTRL_HUM` は `CTRL_MEAS` の前:** BME280 は `CTRL_HUM`（`0xF2`）の湿度
  オーバーサンプリングを、測定制御レジスタより前に書かれた場合のみ反映し
  ます。`initializeDevice` は正しい順序で行います。
- **26 バイトのキャリブレーション:** BME280 は 0x88 ブロックの全 26 バイト
  が必要で、26 バイト目（レジスタ `0xA1`）が符号なし `dig_H1` です。BMP280
  は最初の 24 バイトで足ります。
- **湿度キャリブレーションの配置（`0xE1`..`0xE7`）:** `dig_H2` は `0xE1`
  のリトルエンディアン符号付き 16 ビット値、`dig_H3` は `0xE3` の符号なし、
  `dig_H4`・`dig_H5` は符号付き MSB バイト（`0xE4`/`0xE6`）と `0xE5` の
  ニブルに分割（`dig_H4` は下位ニブル、`dig_H5` は上位ニブル）、`dig_H6`
  は `0xE7` の符号付きバイトです。`digH1`..`digH6` コントローラはこの配置で
  解析します。
- **湿度出力は 16 ビット・ビッグエンディアン**（`0xFD`、MSB が先頭）。
- **補正は整数演算:** Bosch リファレンスドライバ準拠。ゼロ方向への切り捨て
  除算（`quo:`）、温度・気圧・湿度式で同じ `t_fine` を使用し、センサー範囲に
  クランプします。
- **キャリブレーション前は nil:** 両方のキャリブレーションブロックが届くまで
  補正済みの値は nil を返します。
- **チップ ID 確認:** `readChipId` + `chipId` は `0x60` を返すはずです。
  違う場合は通信エラーです。
- **複数センサー:** SDO を VCC にしてアドレス 0x77 にし、同じ `FirmataI2C`
  接続に 2 つ目の `FirmataBME280` インスタンスを登録します。
