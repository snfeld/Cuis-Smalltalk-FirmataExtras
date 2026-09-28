# Firmata-Servo – Hochsprachliche Servo-Ansteuerung

Inhalt:
1. Überblick
2. Grundkonzepte
3. Klasse und API
4. Anbindungen (Pin und PCA9685)
5. Beispiele
6. Hinweise

---

## 1. Überblick

Das Paket `Firmata-Servo` hebt die Servo-Ansteuerung des Firmata-Basisprotokolls
auf eine komfortable Stufe. Statt Protokoll-Winkel direkt zu senden, modelliert
eine Servo-Instanz einen einzelnen Servo mit fester Einbau-Situation:

- **Geschwindigkeit** in Grad pro Sekunde — der Servo fährt in kleinen Schritten
  aus einem Hintergrundprozess sanft zum Ziel statt zu springen.
- **180°- und 270°-Servos** — der mechanische Drehbereich wird bei der Umrechnung
  auf den 0–180°-Protokollwinkel berücksichtigt.
- **Eingeschränkte und invertierte Einbaurichtungen** — Eingangswerte (z. B. 0–100)
  werden linear auf einen beliebigen Winkelbereich abgebildet, auch „rückwärts"
  eingebaute Servos (z. B. 180° → 0°).
- **Zwei Anbindungen** — direkt an einem Arduino-Pin (`FirmataPinServo`) oder über
  einen PCA9685-Kanal auf dem I2C-Bus (`FirmataPCA9685Servo`).

## 2. Grundkonzepte

Ein Servo arbeitet zwischen einer **Einbaugrenze** (physikalische Winkel, siehe
`minAngle`/`maxAngle`). Sein Eingang ist ein abstrakter **Positionswert**,
üblicherweise eine Prozentangabe zwischen 0 und 100 (`minPosition`/`maxPosition`).
`moveTo:` bildet den Wert linear auf den Winkelbereich ab — invertierte Bereiche
sind für rückwärts montierte Servos erlaubt — klemmt ihn auf die Grenzen und fährt
den Servo dorthin.

Die **Winkelgeschwindigkeit** (`speedDegreesPerSecond`) steuert, wie schnell der
Winkel sich ändert: Bei Geschwindigkeit 0 springt der Servo direkt ans Ziel, bei
einer positiven Geschwindigkeit fährt er in kleinen Schritten dorthin. Der
Hintergrundprozess (`startMovingProcess`) stoppt von selbst, sobald das Ziel
erreicht ist. Aktueller und Zielwinkel werden als Zustand geführt
(`currentAngle`, `targetAngle`).

**Nie zwei konkurrierende Prozesse:** `moveTo:` während einer laufenden Bewegung
beendet zuerst den alten Prozess (intern `stopMovingProcess`) und startet dann die
neue Bewegung aus der aktuellen Position. Ein Servo wird also jederzeit von höchstens
einem Bewegungsprozess gefahren. Wird die Geschwindigkeit mitten in der Fahrt auf 0
gesetzt, beendet der nächste Schritt die Bewegung regulär am Ziel statt endlos zu
weiterzulaufen.

Der **mechanische Drehbereich** (`rangeDegrees`, 180 oder 270) zusammen mit der
**Impulsbreiten-Kalibrierung** (`minPulseMicroseconds`/`maxPulseMicroseconds`) skaliert
den physikalischen Winkel auf den Protokollwinkel. Die eigentliche Übertragung ist in
die Unterklassen delegiert (`writeAngle:`).

## 3. Klasse und API

`FirmataServo` ist die abstrakte Basis (Paket `Firmata-Servo`).

Einstellungen (Accessing):

- `minPosition:`/`maxPosition:` bzw. `setPositionRangeFrom:to:` — Eingangsbereich
  (Standard 0–100).
- `minAngle:`/`maxAngle:` bzw. `setAngleRangeFrom:to:` — Einbau­bereich in
  physikalischen Grad; invertierte Bereiche erlaubt.
- `rangeDegrees:` — mechanischer Drehbereich (Standard 180, z. B. 270 für
  Pan-Tilt-Servos).
- `minPulseMicroseconds:`/`maxPulseMicroseconds:` — Impulsbreiten-Kalibrierung
  (Standard 544/2400 µs, die StandardFirmata-Konvention).
- `speedDegreesPerSecond:` — Geschwindigkeit in Grad/Sekunde (0 = direkt sprin­gen).
- `stepIntervalMilliseconds:` — Schrittintervall des Hintergrundprozesses (Standard 20 ms).

Bewegung (moving):

- `moveTo: aPosition` — Position angeben (z. B. 0–100), wird auf den Winkelbereich
  abgebildet und angefahren.
- `moveToAngle: degrees` — direkt einen physikalischen Winkel ansteuern.
- `currentAngle`, `targetAngle` — Zustandsabfrage; `isMoving` — läuft gerade eine
  Bewegung?
- `step` — ein Einzelschritt (vom Hintergrundprozess verwendet).
- `startMovingProcess` / `stopMovingProcess` — Rampenprozess starten/beenden;
  bei jedem `moveTo:` wird ein laufender Prozess zuvor regulär beendet.

Umrechnung (mapping):

- `positionToAngle:` — Positionswert → physikalischer Winkel (linear, geklemmt).
- `protocolAngleForDegrees:` — physikalischer Winkel → 0–180°-Protokollwinkel.
- `clampAngle:` — auf den Einbaubereich klemmen.

Konstanten auf der Klassenseite (`FirmataServo class`): `defaultRangeDegrees`
(180), `defaultMinPulseMicroseconds` (544), `defaultMaxPulseMicroseconds` (2400),
`defaultSpeedDegreesPerSecond` (0), `defaultStepIntervalMilliseconds` (20).

## 4. Anbindungen (Pin und PCA9685)

`FirmataPinServo` (Instanzvariable `pin`) fährt einen direkt am Arduino-Pin
angeschlossenen Servo:

- `attach` — Pin auf Servo-Modus stellen und die Impulsbreiten-Kalibrierung einmal
  senden; als Ruhewinkel dient der Beginn des Einbaubereichs.
- Danach ist jede Bewegung eine `servoOnPin:angle:`-Nachricht auf der Firmata-
  Verbindung.

`FirmataPCA9685Servo` (Instanzvariable `channel`) fährt einen Servo auf einem Kanal
eines PCA9685-PWM-Treibers über den I2C-Bus:

- Der Treiber (`FirmataPCA9685`) muss zuerst mit `initializeDevice` initialisiert
  werden; das aktiviert das Register-Auto-Increment und programmiert die
  PWM-Frequenz, beides für den Servo nötig (siehe
  [PCA9685-Dokumentation-de.md](PCA9685-Dokumentation-de.md)). Ein separates
  `setFrequency:` ist nur nötig, um die Frequenz danach zu ändern.
- Jede Bewegung ist eine `setServoOnChannel:angle:minPulse:maxPulse:`-Nachricht auf
  den Treiber.

## 5. Beispiele

### 5.1 Servo direkt an einem Arduino-Pin

```smalltalk
| bus servo |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.

servo := FirmataPinServo on: bus pin: 9.
servo attach.
servo speedDegreesPerSecond: 45.   "45° pro Sekunde"
servo moveTo: 50.                   "auf 50% der Einbaugrenze fahren"
```

### 5.2 Eingeschränkter und invertierter Einbaubereich

```smalltalk
servo setAngleRangeFrom: 20 to: 160.  "nur zwischen 20° und 160° fahrbar"
servo moveTo: 0.                      "fährt auf 20°"
servo moveTo: 100.                    "fährt auf 160°"

servo setAngleRangeFrom: 160 to: 20.  "rückwärts eingebaut"
servo moveTo: 100.                    "fährt auf 20°"
```

### 5.3 270-Grad-Servo

```smalltalk
servo rangeDegrees: 270.
servo setAngleRangeFrom: 0 to: 270.
servo moveTo: 50.                     "physikalisch 135°, Protokoll 90°"
```

### 5.4 Servo über PCA9685 (I2C)

```smalltalk
| bus driver servo |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

driver := FirmataPCA9685 new.
driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
driver initializeDevice.                     "Modi, Auto-Increment, 50 Hz"

servo := FirmataPCA9685Servo on: driver channel: 0.
servo speedDegreesPerSecond: 30.
servo moveTo: 50.
```

### 5.5 Neues Ziel während der Fahrt

```smalltalk
servo speedDegreesPerSecond: 90.
servo moveTo: 100.              "fährt sanft auf 100%"
servo moveTo: 0.                "nach 5 Sekunden: alte Fahrt wird beendet,
                                 neue startet aus der aktuellen Position"
```

## 6. Hinweise

- **Keine konkurrierenden Prozesse:** Jeder `moveTo:`/`moveToAngle:` beendet einen
  laufenden Rampenprozess zuerst. Wird die Geschwindigkeit auf 0 gesetzt, springt
  der Servo beim nächsten `step` ans Ziel und der Prozess endet regulär.
- **Hintergrundprozess:** Der Rampenprozess läuft mit der aktiven Priorität des
  Aufrufers und trägt den Namen `FirmataServo <Klasse>`. Er beendet sich selbst,
  sobald das Ziel erreicht ist.
- **`targetAngle:` startet keinen Prozess** — es setzt nur den Zielzustand (für
  Applikationen, die `step` selbst takten). Bewegung startest du mit `moveTo:` bzw.
  `moveToAngle:`.
- **Pulse-Kalibrierung:** Die Standardwerte 544/2400 µs folgen der
  StandardFirmata-Konvention; weichen deine Servos davon ab, passe die beiden Werte
  pro Servo an.
- **Upgrade-Empfehlung:** Für neue Projekte die hochsprachliche `FirmataServo`-API
  der rohen `servoOnPin:angle:`-Nutzung des Basisprotokolls vorziehen.

Teststatus: Die Suite `Tests-Firmata-Servo` ist Teil des Headless-Gesamtlaufs
(`passed=221 failures=0 errors=0`, 2026-09-24, Cuis 7.8 #7977).
