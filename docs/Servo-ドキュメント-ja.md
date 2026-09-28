# Firmata-Servo – 高水準サーボ制御

目次：
1. 概要
2. 基本概念
3. クラスと API
4. 接続方式（ピンと PCA9685）
5. 例
6. 注意点

---

## 1. 概要

`Firmata-Servo` パッケージは、Firmata 基本プロトコルのサーボ制御を手軽な水準に
引き上げます。生のプロトコル角度を送る代わりに、サーボのインスタンスが単一の
サーボとその固定取り付け状態をモデル化します。

- **速度**（度/秒）——サーボはジャンプせず、バックグラウンドプロセスから
  小さなステップで滑らかに目標へ動きます。
- **180°・270°サーボ**——0–180° プロトコル角度への換算時に機械的な可動範囲が
  考慮されます。
- **制限付き・反転した取り付け範囲**——入力値（例：0–100）は任意の角度範囲へ
  線形に写像され、逆向きに取り付けたサーボ（例：180° → 0°）にも対応します。
- **2 つの接続方式**——Arduino のピンに直接（`FirmataPinServo`）、または I2C を
  通して PCA9685 のチャンネルに（`FirmataPCA9685Servo`）。

## 2. 基本概念

サーボは**取り付け範囲**（物理角度。`minAngle`/`maxAngle` 参照）の間で動作し
ます。その入力は抽象的な**位置値**で、通常 0〜100 のパーセント値
（`minPosition`/`maxPosition`）です。`moveTo:` は値を線形に角度範囲へ写像し——
逆向きに取り付けたサーボでは反転範囲も可能——境界にクランプして、その位置へ
サーボを動かします。

**角速度**（`speedDegreesPerSecond`）は角度の変化速度を決めます。速度ゼロでは
サーボは直接目標へ跳び、正の速度では小さなステップで徐々に近づきます。
バックグラウンドプロセス（`startMovingProcess`）は目標到達時に自動で停止します。
現在角度と目標角度は状態として保持されます（`currentAngle`、`targetAngle`）。

**競合するプロセスは決して作らない：**動作中に `moveTo:` を呼ぶと、まず古い
プロセスを終了し（内部で `stopMovingProcess`）、現在位置から新しい動きを
開始します。つまりサーボは常に最大 1 つの動作プロセスで駆動されます。移動の途中
で速度を 0 にしても、次の `step` で目標まで到達して正常に終了し、無限に進み続ける
ことはありません。

**機械的可動範囲**（`rangeDegrees`、180 または 270）と**パルス幅キャリブレーション**
（`minPulseMicroseconds`/`maxPulseMicroseconds`）により、物理角度をプロトコル角度
へ換算します。実際の転送はサブクラスに委譲されます（`writeAngle:`）。

## 3. クラスと API

`FirmataServo` が抽象ベースです（パッケージ `Firmata-Servo`）。

設定（accessing）：

- `minPosition:`/`maxPosition:` または `setPositionRangeFrom:to:` — 入力範囲
  （既定 0–100）。
- `minAngle:`/`maxAngle:` または `setAngleRangeFrom:to:` — 物理角度での取り付け
  範囲。反転も可。
- `rangeDegrees:` — 機械的可動範囲（既定 180。例：雲台サーボは 270）。
- `minPulseMicroseconds:`/`maxPulseMicroseconds:` — パルス幅キャリブレーション
  （既定 544/2400 µs、StandardFirmata の慣例）。
- `speedDegreesPerSecond:` — 度/秒（0 = 直接ジャンプ）。
- `stepIntervalMilliseconds:` — バックグラウンドプロセスのステップ間隔（既定
  20 ms）。

動作（moving）：

- `moveTo: aPosition` — 位置を指定（例：0–100）。角度範囲へ写像して駆動します。
- `moveToAngle: degrees` — 物理角度へ直接移動。
- `currentAngle`、`targetAngle` — 状態の問い合わせ；`isMoving` — 動作中か？
- `step` — 単一ステップ（バックグラウンドプロセスが使用）。
- `startMovingProcess` / `stopMovingProcess` — ランププロセスの開始/停止。どの
  `moveTo:` もまず実行中のプロセスを正常に終了します。

写像（mapping）：

- `positionToAngle:` — 位置値 → 物理角度（線形、クランプ）。
- `protocolAngleForDegrees:` — 物理角度 → 0–180° プロトコル角度。
- `clampAngle:` — 取り付け範囲へクランプ。

クラス側定数（`FirmataServo class`）：`defaultRangeDegrees`（180）、
`defaultMinPulseMicroseconds`（544）、`defaultMaxPulseMicroseconds`（2400）、
`defaultSpeedDegreesPerSecond`（0）、`defaultStepIntervalMilliseconds`（20）。

## 4. 接続方式（ピンと PCA9685）

`FirmataPinServo`（インスタンス変数 `pin`）は Arduino のピンに直接接続された
サーボを駆動します：

- `attach` — ピンをサーボモードに設定し、パルス幅キャリブレーションを一度送信。
  取り付け範囲の始点が静止角度になります。
- 以降、各動作は Firmata 接続への `servoOnPin:angle:` メッセージです。

`FirmataPCA9685Servo`（インスタンス変数 `channel`）は I2C バス経由で PCA9685
PWM ドライバの 1 チャンネルのサーボを駆動します：

- ドライバ（`FirmataPCA9685`）はまず `initializeDevice` で初期化する必要があります。
  これがレジスタの自動インクリメントを有効にし、PWM 周波数を設定します。サーボに
  はどちらも必要です（[PCA9685-ドキュメント-ja.md](PCA9685-ドキュメント-ja.md)
  参照）。`setFrequency:` を別に呼ぶのは、その後に周波数を変える場合だけです。
- 各動作はドライバへの `setServoOnChannel:angle:minPulse:maxPulse:` メッセージです。

## 5. 例

### 5.1 Arduino のピンに直接接続したサーボ

```smalltalk
| bus servo |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.

servo := FirmataPinServo on: bus pin: 9.
servo attach.
servo speedDegreesPerSecond: 45.   "毎秒 45 度"
servo moveTo: 50.                   "取り付け範囲の 50% へ移動"
```

### 5.2 制限付き・反転した取り付け範囲

```smalltalk
servo setAngleRangeFrom: 20 to: 160.  "20°～160° の間でのみ可動"
servo moveTo: 0.                      "20° へ移動"
servo moveTo: 100.                    "160° へ移動"

servo setAngleRangeFrom: 160 to: 20.  "逆向きに取り付け"
servo moveTo: 100.                    "20° へ移動"
```

### 5.3 270 度サーボ

```smalltalk
servo rangeDegrees: 270.
servo setAngleRangeFrom: 0 to: 270.
servo moveTo: 50.                     "物理 135°、プロトコル 90°"
```

### 5.4 PCA9685（I2C）経由のサーボ

```smalltalk
| bus driver servo |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

driver := FirmataPCA9685 new.
driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
driver initializeDevice.                     "モード、自動インクリメント、50 Hz"

servo := FirmataPCA9685Servo on: driver channel: 0.
servo speedDegreesPerSecond: 30.
servo moveTo: 50.
```

### 5.5 動作中に新しい目標を指定

```smalltalk
servo speedDegreesPerSecond: 90.
servo moveTo: 100.              "100% へ滑らかに移動"
servo moveTo: 0.                "5 秒後：古い動作が終了し、現在位置から新しい動作を開始"
```

## 6. 注意点

- **競合プロセスなし：**どの `moveTo:`/`moveToAngle:` もまず実行中のランププロセス
  を終了します。速度を 0 にすると、次の `step` で目標に到達して正常終了します。
- **バックグラウンドプロセス：**呼び出し側のアクティブ優先度で実行され、
  `FirmataServo <クラス>` という名前です。目標到達時に自動終了します。
- **`targetAngle:` はプロセスを起動しません** — 目標状態を設定するだけです
  （`step` を自前で駆動するアプリ向け）。動作は `moveTo:` または `moveToAngle:` で
  開始してください。
- **パルスキャリブレーション：**既定の 544/2400 µs は StandardFirmata の慣例に
  従います。異なるサーボでは 2 つの値をサーボごとに調整してください。
- **移行推奨：**新規プロジェクトでは、基本プロトコルの生の `servoOnPin:angle:`
  使用よりも高水準の `FirmataServo` API を推奨します。

テスト状況：`Tests-Firmata-Servo` スイートはヘッドレス全体実行の一部です
（`passed=221 failures=0 errors=0`、2026-09-24、Cuis 7.8 #7977）。
