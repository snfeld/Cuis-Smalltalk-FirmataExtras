# Cuis-Smalltalk 向け Firmata

目次：
1. Firmata とは
2. 前提条件とインストール
3. 接続とバックグラウンド処理
4. API 概要
5. 使用方法と例
6. 新しい I2C デバイスの追加方法
7. Cuis 固有の注意点と落とし穴

---

## 1. Firmata とは

Firmata は、マイクロコントローラ（Arduino など）をホストコンピュータから
制御するための、プロトコルベースのオープンな方法です。Arduino 側では
**StandardFirmata** ファームウェアが動作し、ホスト（ここでは Cuis-Smalltalk
イメージ）はシリアル接続（USB）または TCP/IP ネットワーク経由でコンパクトな
バイトコマンドを送信し、Arduino は測定値やステータスメッセージで応答します。
どのピンや I2C デバイスを接続しても、インターフェースは常に同じです。

プロトコルは 7 ビット値を用います。各数値は LSB/MSB のペアとして送信され
ます。I2C などの複雑な拡張には SYSEX メカニズムを使います。メッセージは
`START_SYSEX`（`0xF0`）で始まり `END_SYSEX`（`0xF7`）で終わります。この
パッケージは I2C SYSEX コマンドを含む完全な標準を実装しています。

## 2. 前提条件とインストール

**Arduino 側**（Arduino IDE、Smalltalk コミュニティの *Firmata* ライブラリ）：

- `StandardFirmata`：USB/シリアル用。
- `StandardFirmataEthernet` または `StandardFirmataWiFi`：ネットワーク用。
- 独自のファームウェアロジックには `ConfigurableFirmata`（このプロジェクトの
  すべての例とテストは、これらのスケッチにバイト単位で合わせてあります）。

**Cuis-Smalltalk では**、パッケージブラウザまたは次のコードでロードします：

```smalltalk
Feature require: #'Firmata'.            "基本プロトコル（シリアルポート）"
Feature require: #'Firmata-I2C'.        "I2C サポート"
Feature require: #'Firmata-PCA9685'.    "PCA9685 16 チャンネル PWM/サーボドライバ"
Feature require: #'Firmata-MPU6050'.    "MPU6050 IMU"
Feature require: #'Firmata-Servo'.      "高水準サーボ制御（速度、範囲）"
Feature require: #'Firmata-Net'.        "TCP/IP トランスポート（Network-Kernel が必要）"
```

依存関係は自動的に解決されます。`Firmata-Net` には `Network-Kernel` パッケージ
がインストールされている必要があります（上記の順序：まず `Network-Kernel`、
次に `Firmata-Net`）。

**配線の基本：** すべての信号でグランドを共通にします。I2C ではさらに
`SDA`/`SCL` から `VCC` へのプルアップ抵抗（通常 4.7 kΩ）が必要です——多くの
ブレークアウトボードにはすでに付いています。

## 3. 接続とバックグラウンド処理

各接続クラス（`Firmata`、`FirmataI2C`、`FirmataNet`、`FirmataNetI2C`）は
`port`（バイトトランスポート）と、接続を継続的にポーリングするバックグラウンド
プロセスを保持します：

- `connectOnPort:baudRate:` — シリアル接続（クラス `Firmata`、`FirmataI2C`）。
- `connectToHost:port:` — TCP/IP 接続（クラス `FirmataNet`、`FirmataNetI2C`）。
- `startSteppingProcess` — ポーラーを起動します。接続時に自動的に呼ばれます。
- `step` / `stepTime` — ポーリングの 1 ステップと、その間隔（ミリ秒）。`step`
  は `processInput` で保留中のすべてのバイトを読み取ります。読み取りエラーは
  `port := nil` を設定し、接続が閉じられたとみなしてバックグラウンドプロセスを
  自動的に停止させます。
- `stopSteppingProcess` — ポーラーを停止します（`disconnect` が呼びます）。
- `disconnect` — ポーラーを停止し、ポートを閉じ、`port := nil` を設定して
  プロトコル状態をリセットします。繰り返し呼び出しても安全です。
- `isConnected` — `^port notNil`。
- `isFirmataInstalled` — 応答が届くまでバージョン問い合わせを送り続けます
  （最大 5 秒）。

## 4. API 概要

### `Firmata` — 基本プロトコル（パッケージ `Firmata`）

- ライフサイクル/接続：`connectOnPort:baudRate:`、`disconnect`、
  `isConnected`、`controlConnection`、`controlFirmataInstallation`。
- バックグラウンドプロセス：`startSteppingProcess`、`step`、`stepTime`、
  `stopSteppingProcess`。
- 受信：`processInput`、`parseCommandHeader:`、`parseData:`、`parseSysex:`、
  `parsingSysex`。
- 状態：`isFirmataInstalled`、`version`、`majorVersion`、`minorVersion`、
  `nameSymbol`、`port`。
- ピンモード：`pin:mode:`（および `valueForInputMode`、`valueForOutputMode`、
  `valueForPwmMode`、`valueForServoMode`）、`digitalPin:mode:`。
- デジタルピン：`digitalWrite:value:`、`digitalRead:`、`analogWrite:value:`、
  `digitalPortReport:onOff:`、`activateDigitalPort:`、`deactivateDigitalPort:`、
  `setDigitalInputs:data:`。
- アナログピン：`analogRead:`、`analogPinReport:onOff:`、`activateAnalogPin:`、
  `deactivateAnalogPin:`、`setAnalogInput:value:`。
- サーボ：`attachServoToPin:`、`detachServoFromPin:`、`servoOnPin:angle:`、
  `servoConfig:minPulse:maxPulse:angle:`。
- その他のコマンド：`queryVersion`、`queryFirmware`、`reportFirmware`、
  `systemReset`、`startSysex`、`endSysex`、`firmataString`、`sysexNonRealtime`、
  `sysexRealtime`。
- 初期化：`initialize`、`initializeVariables`。

### `FirmataConstants`（パッケージ `Firmata`）

プロトコル番号のクラスメソッド：`analogMessage`、`digitalMessage`、
`reportAnalog`、`reportDigital`、`reportVersion`、`setPinMode`、`startSysex`、
`endSysex`、`systemReset`、`maxDataBytes` など。

### `FirmataI2C` — I2C レイヤー（パッケージ `Firmata-I2C`）

`Firmata` に I2C SYSEX メッセージを追加します：

- `i2cConfig` / `i2cConfigDelay:` — I2C リクエストと応答割り込みの間の遅延を
  設定します（デフォルト 0 µs）。
- `i2cRequestWrite:register:data:` — スレーブレジスタにデータを書き込みます。
- `i2cRequestRead:register:byteCount:` — 1 回読み込みます。
- `i2cRequestReadContinuously:register:byteCount:` — 継続的に読み込みます
  （Arduino が変化のたびに自動送信）。
- `i2cStopReading:` — 継続読み込みを停止します。
- デバイスレジストリ：`registerI2CDevice:`、`registeredDeviceFor:`。
- SYSEX 処理：`parseSysex:`、`dispatchSysexMessageOfLength:`、
  `parseI2CReplyOfLength:`。

### `FirmataI2CDevice` — 抽象デバイス基底クラス（パッケージ `Firmata-I2C`）

- 配線：`firmata:address:`、`registerWithFirmata`。
- I2C 操作：`writeRegister:data:`、`readRegister:byteCount:`、
  `readRegisterContinuously:byteCount:`、`stopReading`。
- アクセス：`address`、`address:`、`firmata`、`firmata:`。
- サブクラスの責務：`initializeDevice`（バス上のデバイスを設定）と
  `handleI2CReply:data:`（応答を処理）。

### `FirmataNet` / `FirmataNetI2C` — TCP/IP（パッケージ `Firmata-Net`）

- `connectToHost:` / `connectToHost:port:` — StandardFirmataEthernet/-WiFi の
  Arduino に接続します。`defaultPort`（デフォルト 3030）。
- `FirmataNetI2C` はネットワークと I2C の能力を組み合わせます（ネットワーク
  モードでの I2C デバイスクラス用）。
- `FirmataNetPort` は `SocketStream` をバイトトランスポートとしてラップし、
  `readByteArray`、`nextPutAll:`、`close`、`isConnected` を提供します。
- `FirmataNetConstants` — ネットワークのデフォルト値（デフォルトポート）。

## 5. 使用方法と例

### 5.1 シリアル接続とバージョン確認

```smalltalk
| firmata |
firmata := Firmata new.
firmata connectOnPort: '/dev/ttyACM0' baudRate: 57600.
firmata isFirmataInstalled.          "ハンドシェイクが成功すると true"
firmata version.                     "例: 2.5（StandardFirmata）"
```

### 5.2 デジタル出力（LED）

```smalltalk
"ピン 13 を出力にして点灯させる"
firmata digitalPin: 13 mode: 1.      "OUTPUT = 1"
firmata digitalWrite: 13 value: 1.
```

> ピンモードの値はプロトコルの 1 バイトです。高水準ヘルパー `pin:mode:` は
> Arduino スケッチの数値モード（`INPUT = 0`、`OUTPUT = 1`、`ANALOG = 2`、
> `PWM = 3`、`SERVO = 4`）を受け付けます。

### 5.3 デジタル入力（ボタン）とアナログ読み取り

```smalltalk
firmata digitalRead: 2.                  "0 または 1"
firmata analogRead: 0.                   "10 ビット値 0..1023"
firmata analogPinReport: 0 onOff: 1.     "アナログレポートを有効化"
firmata digitalPortReport: 0 onOff: 1.   "デジタルレポートを有効化"
```

### 5.4 サーボ

```smalltalk
firmata attachServoToPin: 9.
firmata servoOnPin: 9 angle: 90.
firmata servoOnPin: 9 angle: 45.
firmata detachServoFromPin: 9.
```

速度・取り付け範囲・180°/270° サーボを使った高水準制御（ピンまたは PCA9685）には
`Firmata-Servo` パッケージを使用してください（
[Servo-ドキュメント-ja.md](Servo-ドキュメント-ja.md) 参照）。

### 5.5 I2C デバイスの使用（PCA9685 の例）

```smalltalk
| firmata pwm |
firmata := FirmataI2C new.
firmata connectOnPort: '/dev/ttyACM0' baudRate: 57600.
firmata isFirmataInstalled.
firmata i2cConfig.
pwm := FirmataPCA9685 new firmata: firmata address: 0x40.
pwm registerWithFirmata.                "デバイスをバスに登録"
pwm initializeDevice.                   "モード、自動インクリメント、50 Hz"
pwm setPWMOnChannel: 0 value: 128.      "デューティ 128/4096"
pwm setServoOnChannel: 1 angle: 90.     "チャンネル 1 のサーボを 90° に"
```

### 5.6 ネットワーク接続

```smalltalk
| firmataNet |
firmataNet := FirmataNet new.
firmataNet connectToHost: '192.168.1.100' port: 3030.
firmataNet isFirmataInstalled.
firmataNet digitalWrite: 13 value: 1.
```

### 5.7 後片付け

```smalltalk
firmata disconnect.       "ポーラーを停止し、ポートを閉じる"
```

## 6. 新しい I2C デバイスの追加方法

別の I2C コンポーネントを統合する手順です（既存の 2 つの例は
`FirmataPCA9685` と `FirmataMPU6050`）：

1. **新しいパッケージ** `Firmata-<デバイス>` を作成します（ソース：
   `.pck.st`、`Feature require:` でロード）。`!requires: 'Firmata-I2C' 1 nil 1!`
   とカテゴリ `'Firmata-<デバイス>'` を含めます。

2. **デバイスクラスを設計します：** `FirmataI2CDevice` のサブクラス
   （`FirmataI2CDevice subclass: #Firmata<デバイス> ...`）に必要なインスタンス
   変数を用意し、レジスタアドレス・デフォルト値・モードビットを保持する定数
   クラス `Firmata<デバイス>Constants` も作成します。

3. **必須メソッドを実装します：**
   - `defaultAddress` — I2C スレーブアドレス（クラス側 `defaults`）。
   - `initializeDevice` — レジスタ書き込みによるチップ設定
     （`writeRegister:data:`）。
   - `handleI2CReply:data:` — 届いた測定値を解釈し、デバイスのインスタンス変数
     に格納します。
   - `registerWithFirmata` は配線後に呼び出し、`firmata registerI2CDevice: self`
     でアドレスごとにデバイスを登録します。

4. **公開インターフェースを追加します**（例：`setPWMOnChannel:value:`、
   `setServoOnChannel:angle:`、`readOnce`、`startReading`、`scaledAccelX` など）。

5. **設定オプションをクラス側のデフォルトにします**（`defaults`）。

6. **テストを書きます**（パッケージ `Tests-Firmata-<デバイス>`）— この
   プロジェクトの規約：
   - `FirmataNetStreamMock`/シリアルモックで、実際の Arduino が送るのとまったく
     同じバイトをパーサーに供給します（7 ビット LSB/MSB ペア、SYSEX）。
   - 送信された（SYSEX）バイト配列を逐バイトで検証します。
   - `TestCase` ではテストメソッドはカテゴリ `'testing'` に、ヘルパーは
     `'support'` に入れます。
   - ヘッドレスランナーでスイート全体を実行します。

7. **`docs/` フォルダのドキュメントを拡張します**（README 参照）。

## 7. Cuis 固有の注意点と落とし穴

- **7 ビットペアの規約：** 数値は LSB/MSB ペアで送られます（下位バイトが先）。
  `parseData` はバイト 1 をスロット 2 に、バイト 2 をスロット 1 に格納します
  （インデックス 1 = 最初に読んだバイト）。手動で解析するときは順序を決して
  入れ替えないでください——以前のバグで `REPORT_VERSION` が逆に読まれ
  （2.5 が 5.2 と報告）、それが原因でした。
- **ヘッドレステスト（`-vm-display-null`）：** ファイルが既に存在する場合、
  `FileEntry>>writeStreamDo:` は「Overwrite?」と尋ね、テスト実行を停止させます。
  出力には `forceWriteStreamDo:` を使ってください。また、クラスはインストール
  前に直接参照してはいけません（Undeclared → `UndefinedObject>>new`）。
  インストールするスクリプトでは `Smalltalk classNamed:` を使ってください。
- **デバイスレジストリ：** I2C デバイスは `registerWithFirmata` の後でしか
  アドレス指定できません。未登録の応答は破棄されます。
- **エラー時の挙動：** ポーラー内の読み取りエラーは `port := nil` を設定します。
  それ以降 `port` アクセサ経由の呼び出しは「Serial port is not connected」を
  送出します。再利用前に再度 `connectOnPort:...`（または
  `connectToHost:port:`）を呼び出してください。

テスト状態：15 のスイートすべてがヘッドレスで成功
（`passed=221 failures=0 errors=0`、2026-09-24、Cuis 7.8 #7977）。
