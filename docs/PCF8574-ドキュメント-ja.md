# PCF8574 – 8ビット I/Oエキスパンダー

目次：
1. 概述
2. 技術仕様
3. 配線
4. クラスとAPI
5. 使用例
6. 注意点

---

## 1. 概述

**PCF8574**（NXP/Texas Instruments）はI2C通信による8ビット擬似双方向I/Oエキスパンダーです。レジスタベースのセンサーとは異なり、**レジスタアドレッシングがありません** — 1バイトの書き込みまたは読み取り操作でポート全体（8ピン）を制御します。

各ピンは擬似双方向です：`1`を書き込むと内部弱プルアップ付きの入力として設定され、`0`を書き込むとローレベル出力として駆動されます。入力を読むには、ポートを読み取る前にすべてのピンを`1`に設定する必要があります。

`Firmata-PCF8574`パッケージはエキスパンダーを`FirmataI2C`接続の背後にカプセル化します。`readPort`メソッドはレジスタなしI2C読み取り形式（StandardFirmata ≥ 2.5）を使用し、ポート状態の破損を防ぎます。

## 2. 技術仕様

- 8ビット擬似双方向I/Oピン：レジスタアドレッシングなし、1バイトでポート全体を制御。
- 動作電圧：**2.6 V – 6 V**。
- 消費電力：最大**100 µA**。
- シンク電流：ピンあたり**25 mA**。
- I2Cアドレス範囲：**0x20 – 0x27**（アドレスピンA0–A2、すべてLow = 0x20）。
- 電源投入時のデフォルト：すべてのピンがハイレベル（入力モード）。
- INT出力：オープンドレイン、アクティブLow（このパッケージでは未使用）。

擬似双方向ピンのモード：

| 書き込み値 | ピン状態 |
| --- | --- |
| `1` | 入力モード、内部弱プルアップ付き |
| `0` | 出力モード、ローレベル |

方向と出力レベルの独立レジスタはありません：同じ1バイトが方向と出力レベルを同時に定義します。

## 3. 配線

| PCF8574 | Arduino Uno |
| --- | --- |
| VCC | 5 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| A0 | GND（アドレス 0x20） |
| A1 | GND（アドレス 0x20） |
| A2 | GND（アドレス 0x20） |
| P0–P7 | I/Oピン |

同一I2Cバスに2つ目のエキスパンダーを接続する場合、A0をVCCに接続します（アドレス0x21）。ブレイクアウトボードにプルアップ抵抗がない場合は、SDA/SCLにVCC向けの4.7 kΩプルアップを使用してください。

## 4. クラスとAPI

`FirmataPCF8574`は`FirmataI2CDevice`を継承します（パッケージ`Firmata-I2C`）。

- 初期化：`initializeDevice`（I2C設定を構成）、`registerWithFirmata`（配線後！）。
- 書き込み：`writePort:`（8ビットバイトをポート全体に送信）、`digitalWritePin:value:`（単一ピンを設定；現在のポート状態を読み取り、影響するビットのみを変更）。
- 読み取り：`readPort`（レジスタなしI2C読み取り；結果は`inputValue`）、`digitalReadPin:`（指定ピンの`true`/`false`を返す）。
- ストリーム：`startReadingPort`（Firmataステップ経由の継続的ポーリングを開始）、`stopReading`（ストリームを停止）。
- コールバック：`handleI2CReply:data:`（受信した`I2C_REPLY`データを処理し、`inputValue`/`outputValue`を更新）。

`FirmataPCF8574Constants`（クラス側）には`portRegister`（0）、`pinCount`（8）、`defaultAddress`（0x20）、`allPinsHigh`（0xFF）が定義されています。

`handleI2CReply:data:`は`FirmataI2C`接続が`I2C_REPLY`メッセージを受信した際に自動的に呼び出されるため、手動でトリガーする必要はありません。`startReadingPort`はFirmataステップ経由でポーリング間隔に従ってポートを継続的に読み取り、`inputValue`に最後の完全なポートバイトを保持します。

## 5. 使用例

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

"すべてのピンを入力に設定"
expander writePort: 16rFF.

"ピン0–3を出力（Low）、ピン4–7を入力に設定"
expander writePort: 16r0F.

"単一ピンを設定"
expander digitalWritePin: 0 value: true.

"ポートを読み取り"
expander readPort.
expander inputValue.               "最後に読み取ったポートバイト"

"単一ピンを読み取り"
expander digitalReadPin: 4.         "ピン4がハイの場合はtrue"

"継続的ポーリングの開始/停止"
expander startReadingPort.
expander stopReading.
```

## 6. 注意点

- **擬似双方向ピン：** `1`を書き込むと内部弱プルアップ付きの入力として設定されます。`0`を書き込むとローレベル出力として駆動されます。他のI/Oエキスパンダーにあるような方向や構成レジスタはありません。
- **入力の読み取り：** 読み取る前にすべてのピンを`1`に設定する必要があります（`writePort: 16rFF`）。そうしないと、ピンは最後の出力値のローレベルを駆動し、正しい入力信号を取得できません。
- **レジスタなし読み取り：** `readPort`メソッドはレジスタなしI2C読み取り形式（StandardFirmata ≥ 2.5、argc ≠ 6）を使用します。これにより、誤って送信されたレジスタバイトがポート状態を破損するのを防ぎます。
- **複数デバイス：** 同じI2Cバスに最大8個のPCF8574を異なるアドレス（A0–A2）で接続できます。各デバイスに独立した`FirmataPCF8574`インスタンスを登録してください。
- **内部レジスタマップなし：** レジスタベースのI2Cデバイスのようなレジスタマップはありません。すべての書き込み/読み取り操作は8つのI/Oピンに直接作用します。
- **電源：** PCF8574の最大消費電力は100 µAです。より大きな負荷（最大25 mAのシンク）には外部ドライバステージを使用してください。
- **プルアップ：** 入力には内部弱プルアップで十分です。外部プルアップは不要ですが、入力信号源の中間インピーダンスが疑わしい場合は明確なハイレベルを確保するために追加してください。
