# BMP280 – 気圧・温度センサー 

目次:
1. 概要
2. 技術仕様
3. 配線
4. クラスと API
5. 例
6. 注意点

---

## 1. 概要

**BMP280** (Bosch Sensortec) は気圧・温度センサーです。絶対圧力を
300–1100 hPa の範囲で測定し、`0xF7` からのビッグエンディアン 20 ビット
出力レジスタ 3 個（圧力 MSB、LSB、XLSB）、続いて `0xFA` からの温度
レジスタ 3 個で結果を提供します。生の 20 ビットカウントは `0x88` にある
24 バイトの工場出荷時キャリブレーションブロックを使って補正します。

`Firmata-BMP280` パッケージは `FirmataI2C` 接続の背後にセンサーを
カプセル化します。`initializeDevice` は設定と測定制御レジスタ
（オーバーサンプリング x1、ノーマルモード）を一度書き込み、次に
キャリブレーションブロックを読みます。`startReadingPort` で Arduino が
6 バイトの出力を連続ストリームし、受信した `I2C_REPLY` ごとに最後の
サンプルが上書きされます。スケール済みの値はそのまま参照できます。

補正は Bosch 公式リファレンスドライバの整数式（C 整数除算、センサー
範囲へのクランプ）に従うため、結果はデータシートの計算と正確に一致します。

## 2. 技術仕様

- 気圧・温度一体型センサー。
- 圧力範囲: 300–1100 hPa。出力は最大 20 ビット、ビッグエンディアン
  （MSB が先頭）。
- 温度の絶対精度: ±1.0 °C。分解能 0.01 °C。
- 圧力分解能: 0.01 hPa（出力単位）。RMS ノイズは 1 hPa を大きく下回る。
- I2C スレーブアドレス: **0x76**（SDO を Low）または **0x77**（SDO を High）。
- 動作電圧: 1.71–3.6 V。
- チップ ID レジスタ（`0xD0`）は **0x58** を返す。
- `0x88` に 24 バイトのキャリブレーションデータ（dig_T1..T3, dig_P1..P9）。

## 3. 配線

| BMP280 | Arduino Uno |
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

`FirmataBMP280` は `FirmataI2CDevice`（パッケージ `Firmata-I2C`）の
サブクラスです。

- 初期化: `initializeDevice`（`config` 0x00 と `ctrl_meas` 0x27 を書き、
  その後 24 バイトのキャリブレーションを読む）、`registerWithFirmata`
  （配線後！）、任意で `readChipId`。
- 読み取り: `startReadingPort`（連続）または `readOnce`（`0xF7` の出力
  6 バイトを一度だけ読む）。
- 生出力: `rawPressure`/`rawTemperature`（20 ビット・ビッグエンディアンの
  整数カウント）、`chipId`（`readChipId` 後）。
- 補正済み出力:
  - `compensatedTemperature` — 0.01 °C 単位の整数。[-4000, 8500]
    （−40.00 °C 〜 85.00 °C）にクランプ。
  - `temperatureCelsius` — 摂氏温度（Float）。
  - `compensatedPressure` — パスカル単位の整数。 [30000, 110000]
    にクランプ。
  - `pressurePascal` — `compensatedPressure` と同じ。
  - `pressureHectoPascal` — hPa 単位の圧力（Float）。
- キャリブレーション: `calibrationData`（24 バイト）、`isCalibrationLoaded`。
- 内部: `tFine`（温度・圧力式が共有するファイン温度）。
- 受信: `handleI2CReply:data:` がチップ ID / キャリブレーション / 出力
  レスポンスを振り分けます。
- 継承ヘルパー（`FirmataI2CDevice`）: `firmata:address:`、
  `writeRegister:data:`、`readRegister:byteCount:`、
  `readRegisterContinuously:byteCount:`、`stopReading`。

`FirmataBMP280Constants`（クラス側）はレジスタ
（`calibrationRegister` 0x88、`chipIdRegister` 0xD0、`configRegister` 0xF5、
`ctrlMeasRegister` 0xF4、`dataRegister` 0xF7、`resetRegister` 0xE0、
`statusRegister` 0xF3）、設定（`configValue` 0x00、`ctrlMeasValue` 0x27）、
仕様（`chipIdValue` 0x58、`calibrationByteCount` 24、
`sensorOutputByteCount` 6）、デフォルト（`defaultAddress` 0x76）を持ちます。

## 5. 例

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

"任意: チップ識別"
sensor readChipId.
sensor chipId.                          "16r58"

"連続ストリーミング開始"
sensor startReadingPort.

"... 数ステップ後:"
sensor temperatureCelsius.              "温度（℃）"
sensor pressureHectoPascal.             "気圧（hPa）"

"1 サンプルだけ読む場合:"
sensor readOnce.

"ストリーミング停止:"
sensor stopReading.
```

## 6. 注意点

- **20 ビット値はビッグエンディアン:** 圧力 = MSB、LSB、XLSB の順で、XLSB
  の下位ニブルは常に 0。生の値は `((MSB << 16) + (LSB << 8) + XLSB) >> 4`。
- **出力の並び:** `0xF7` からの 6 バイトは圧力 MSB、LSB、XLSB、次に温度
  MSB、LSB、XLSB。`rawPressure` と `rawTemperature` が 1 番目と 4 番目から
  正しく展開します。
- **補正は整数演算:** Bosch リファレンスドライバ準拠。ゼロ方向への切り捨て
  除算（`quo:`）、温度・圧力式で同じ `t_fine` を使用し、センサー範囲に
  クランプします。
- **キャリブレーション前は nil:** `temperatureCelsius`、
  `compensatedPressure`、`tFine` はキャリブレーションブロックを受信する
  まで nil を返します。リセット後は `initializeDevice` を呼び直すか、
  次の応答を待ちます。
- **チップ ID 確認:** `readChipId` + `chipId` は `0x58` を返すはずです。
  違う場合は通信エラーです。
- **レジスタ `0xF7` と Firmata Sysex の終端** `0xF7` は無関係です。
  テストのバイト配列に両方が現れますが、出力レジスタ `0xF7` は I2C バス上
  のチップレジスタアドレスにすぎません。
- **複数センサー:** SDO を VCC にしてアドレス 0x77 にし、同じ
  `FirmataI2C` 接続に 2 つ目の `FirmataBMP280` インスタンスを登録します。
