# PCA9685 – 16-Kanal PWM-/Servo-Treiber

Inhalt:
1. Überblick
2. Technische Daten
3. Verdrahtung
4. Klasse und API
5. Beispiel
6. Hinweise

---

## 1. Überblick

Der **PCA9685** (NXP) ist ein 16-Kanal-PWM-Treiber über den I2C-Bus. Jeder der
16 Kanäle erzeugt ein 12-Bit-PWM-Signal (4096 Schritte pro Periode) und kann
Servos, LEDs, Motoren-Regler oder andere pulsgesteuerte Verbraucher ansteuern.
Der Baustein kann sogar 64 Ausgänge über mehrere kaskadierte Chips ansteuern.

Das Paket `Firmata-PCA9685` kapselt den Chip hinter einer `FirmataI2C`-Verbindung:
Der Registerzugriff läuft über den Arduino (I2C-SYSEX), und der Servo-Helfer
`setServoOnChannel:angle:` rechnet Winkel in Impulsbreiten um.

## 2. Technische Daten

- 16 unabhängige PWM-Kanäle, 12-Bit-Auflösung (0–4095).
- Interner Oszillator: 25 MHz; PWM-Frequenz programmierbar (typisch 40–1000 Hz,
  Default 50 Hz; die Prescale-Auflösung bestimmt den nutzbaren Bereich).
- I2C-Slave-Adresse: **0x40** bei geerdeten Adress-Pins A0–A5 (per
  `FirmataPCA9685Constants defaultAddress`), bis zu 62 Adressen.
- Werte auf oder über **4096** erzwingen „volle Eins", negative Werte schalten
  den Kanal aus.
- Einzelne Kanäle: ON/OFF-Phasenregister (4 Register pro Kanal ab 0x06).

## 3. Verdrahtung

| PCA9685 | Arduino |
| --- | --- |
| VCC | 3,3 V (oder 5 V bei Logik-Level-konformen Boards) |
| GND | GND (gemeinsam mit Arduino und Versorgung der Ausgänge) |
| SDA | A4 (Uno) / 20 (Mega) — Pin des StandardFirmata-Boards |
| SCL | A5 (Uno) / 21 (Mega) |
| V+ (falls vorhanden) | externe Versorgung für die Ausgänge (Servos!) |
| A0–A5 | GND für Adresse 0x40, sonst übrige Adresse |

Bei Servos die **Servo-Versorgung getrennt** (5 V, ausreichend Strom!) und alle
Massen verbinden. Pull-ups für I2C sind auf den meisten Breakout-Boards vorhanden.

## 4. Klasse und API

`FirmataPCA9685` erbt von `FirmataI2CDevice` (Paket `Firmata-I2C`).

- Initialisierung: `initialize`, `initializeDevice` (definiert Mode1/Mode2,
  aktiviert Register-Auto-Increment, programmiert die PWM-Frequenz passend zu
  `frequency` und schaltet alle Ausgänge aus).
- PWM: `setPWMOnChannel:value:`, `setAllPWM:`, `setFrequency:`,
  `prescaleForFrequency:`.
- Servos: `setServoOnChannel:angle:`,
  `setServoOnChannel:angle:minPulse:maxPulse:`,
  `pwmCountsForServoAngle:minPulse:maxPulse:`, `pwmCountsForMicroseconds:`.
- Zugriff: `frequency` / `frequency:`, `numberOfChannels`.
- Geerbte Helfer (`FirmataI2CDevice`): `firmata:address:`, `registerWithFirmata`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.
- `handleI2CReply:data:` ist hier bewusst leer (write-only Baustein).

`FirmataPCA9685Constants` (Klassenseite) hält Register (z. B. `mode1Register`,
`mode2Register`, `preScaleRegister`, `led0OnLowRegister`, `allLedOnLowRegister`,
`allLedOffLowRegister`), Modus-Bits (`sleepBit`, `restartBit`, `mode1Default`
= 0x20 Auto-Increment, `mode2Default`) und Spezifikation (`numberOfChannels` = 16,
`resolutionSteps` = 4096, `oscillatorFrequency` = 25 MHz,
`channelRegisterStep` = 4) sowie Defaults (`defaultAddress` = 0x40,
`defaultFrequency` = 50 Hz, `defaultMinPulseMicroseconds` = 544,
`defaultMaxPulseMicroseconds` = 2400).

## 5. Beispiel

```smalltalk
| bus driver |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

driver := FirmataPCA9685 new.
driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
driver initializeDevice.                     "Modi, Auto-Increment, 50 Hz"

driver setPWMOnChannel: 0 value: 2048.      "LED Kanal 0: halbe Helligkeit"
driver setPWMOnChannel: 1 value: -1.        "Kanal 1 aus"
driver setAllPWM: 0.                        "alle aus"

"Servo auf Kanal 2 auf 90°"
driver setServoOnChannel: 2 angle: 90.

"Servicekabel mit eigenem Pulsbereich (500 µs .. 2500 µs)"
driver setServoOnChannel: 3 angle: 30 minPulse: 500 maxPulse: 2500.

"Eine andere PWM-Frequenz (60 Hz) wird genauso programmiert"
driver setFrequency: 60.
```

## 6. Hinweise

- **`initializeDevice` ist einmal nötig:** ohne ihn ist das MODE1-Auto-Increment-
  Bit aus, sodass ein Registerschreiben mit tiefem *und* hohem Phasenbyte (jedes
  `setPWMOnChannel:value:` und `setServoOnChannel:angle:`) sein High-Byte im Chip
  verliert und der Kanal einen viel zu kurzen Impuls bekommt — die Servos
  bewegen sich dann schlicht nicht. Er programmiert außerdem den Oszillator, da
  der Chip mit Prescale 30 (~196,9 Hz) startet, die Zählwerte aber für
  `frequency` berechnet werden.
- **Wertebereich:** 0–4095 setzt das ON/OFF-Phasenpaar; ≥ 4096 = voll an,
  < 0 = voll aus.
- **Frequenzwechsel** erfolgt über Schlaf–Prescale–Aufwachen–Neustart; benutze
  `setFrequency:` statt direkter Registerzugriffe. Zwischen `initializeDevice`
  und dem ersten `setFrequency:` bewegt sich ein Servo nicht korrekt; rufe
  `setFrequency:` nur auf, um die Frequenz danach zu ändern.
- **Winkel-Clamping:** `setServoOnChannel:angle:` klemmt auf 0–180°; die Impuls-
  breite folgt linear zwischen `minPulse` und `maxPulse` (Default 544/2400 µs,
  die StandardFirmata-Servo-Konvention).
- **Write-only:** Der Baustein wird nur beschrieben; `handleI2CReply:data:` bleibt
  leer und es wird nichts gelesen.
- **Mehrere Chips:** A0–A5-Adresspins setzen; pro Chip eine
  `FirmataPCA9685`-Instanz auf derselben `FirmataI2C`-Verbindung registrieren.
