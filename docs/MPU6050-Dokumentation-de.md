# MPU6050 – 6-Achsen-IMU

Inhalt:
1. Überblick
2. Technische Daten
3. Verdrahtung
4. Klasse und API
5. Beispiel
6. Hinweise

---

## 1. Überblick

Der **MPU6050** (InvenSense) ist ein 6-Achsen-Bewegungssensor: ein
3-Achsen-Beschleunigungssensor, ein 3-Achsen-Gyroskop und ein Temperatursensor.
Alle Messwerte liegen konzentriert in 14 aufeinanderfolgenden Registern ab
`ACCEL_XOUT_H` (`0x3B`), die mit einer einzigen kontinuierlichen I2C-Leseoperation
gestreamt werden.

Das Paket `Firmata-MPU6050` kapselt den Sensor hinter einer
`FirmataI2C`-Verbindung. Mit `startReading` streamt der Arduino die Ausgaberegister
kontinuierlich; jede eingehende `I2C_REPLY` überschreibt das letzte Messwert­sample.
Roh- und skalierte Werte (g bzw. Grad pro Sekunde) sind danach direkt abrufbar.

Rot gilt: `accelX` = Rohwert ±32767, `scaledAccelX` = Beschleunigung in g,
`scaledGyroX` = Drehrate in Grad/s.

## 2. Technische Daten

- Beschleunigungssensor: 3 Achsen, 16-Bit, wählbarer Vollausschlag
  **±2 g / ±4 g / ±8 g / ±16 g** (Empfindlichkeit 16384/8192/4096/2048 LSB/g).
- Gyroskop: 3 Achsen, 16-Bit, wählbarer Vollausschlag
  **±250 / ±500 / ±1000 / ±2000 Grad/s** (Empfindlichkeit 131/65.5/32.8/16.4
  LSB/(°/s)).
- Temperatur: 16-Bit, Skalierung 340 LSB/°C, Offset 36,53 °C.
- 14 zusammenhängende Ausgaberegister ab 0x3B (Accel-Roh, Temp, Gyro-Roh,
  Big-Endian, 16-Bit signiert).
- I2C-Slave-Adresse: **0x68** bei tiefem AD0-Pin (sonst 0x69);
  `whoAmI` antwortet 0x68.
- Interner 8-MHz-Takt; der Sensor startet im Schlafmodus
  (`initializeDevice` weckt ihn auf).

## 3. Verdrahtung

| MPU6050 | Arduino |
| --- | --- |
| VCC | 3,3 V (Breakout-Boards mit Level-Shifter oft auch 5 V) |
| GND | GND |
| SDA | A4 (Uno) / 20 (Mega) |
| SCL | A5 (Uno) / 21 (Mega) |
| AD0 | GND für Adresse 0x68, VCC für 0x69 |
| INT (optional) | frei lassen (Polling erfolgt über den Firmata-Step) |

I2C-Pull-ups sitzen auf gängigen Breakout-Boards; ansonsten 4,7 kΩ an SDA/SCL
nach VCC.

## 4. Klasse und API

`FirmataMPU6050` erbt von `FirmataI2CDevice` (Paket `Firmata-I2C`).

- Initialisierung: `initialize`, `initializeDevice` (aktiviert den Sensor durch
  Löschen des Sleep-Bits), `registerWithFirmata` (nach der Verdrahtung!).
- Sensor-Konfiguration: `setAccelerationRange:` (0–3 ↔ ±2/4/8/16 g),
  `setGyroRange:` (0–3 ↔ ±250/500/1000/2000 °/s).
- Lesen: `startReading` (kontinuierlich) bzw. `readOnce` (ein Sample; hängt vom
  `FirmataI2C`-Streambetrieb und `FirmataI2CDevice>>readRegisterContinuously:...`
  ab).
- Rohausgänge: `accelX`/`accelY`/`accelZ`, `gyroX`/`gyroY`/`gyroZ`,
  `temperature` (in °C).
- Skalierte Ausgänge: `scaledAccelX`/`scaledAccelY`/`scaledAccelZ` (in g),
  `scaledGyroX`/`scaledGyroY`/`scaledGyroZ` (in °/s) — je nach konfiguriertem
  Vollausschlag.
- Empfindlichkeiten: `accelSensitivity` (LSB/g), `gyroSensitivity`
  (LSB/(°/s)); halbieren/dritteln sich pro Bereichsstufe.
- Bereichs-Index: `accelRange`, `gyroRange`.
- Geerbte Helfer (`FirmataI2CDevice`): `firmata:address:`, `registerWithFirmata`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataMPU6050Constants` (Klassenseite) hält die Register
(`accelXHighRegister` 0x3B, `gyroXHighRegister` 0x43,
`temperatureHighRegister` 0x41, `accelConfigRegister` 0x1C,
`gyroConfigRegister` 0x1B, `configRegister` 0x1A, `smplrtDivRegister` 0x19,
`powerManagement1Register` 0x6B, `powerManagement2Register` 0x6C,
`whoAmIRegister` 0x75), Power-Bits (`awakeValue` 0, `deviceResetBit`,
`sleepBit`, `temperatureDisableBit`), Spezifikation
(`accelSensitivity` 16384, `gyroSensitivity` 131.0, `sensorOutputByteCount` 14,
`temperatureScaleFactor` 340.0, `temperatureOffset` 36.53) und Defaults
(`defaultAddress` 0x68, `defaultAccelRange` 0, `defaultGyroRange` 0).

## 5. Beispiel

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

"Empfindlichere Bereiche wählen (optional)"
sensor setAccelerationRange: 1.    "±4 g"
sensor setGyroRange: 1.            "±500 °/s"

"Kontinuierliches Streaming starten"
sensor startReading.

"... nach einigen Schritten:"
sensor accelZ.                     "roher 16-Bit-Z-Wert"
sensor scaledAccelZ.               "Z-Beschleunigung in g"
sensor scaledGyroX.                "X-Drehrate in °/s"
sensor temperature.                "Temperatur in °C"

"Alternativ ein einzelnes Sample:"
sensor readOnce.

"Streaming stoppen:"
sensor stopReading.
```

## 6. Hinweise

- **Rohwerte sind Big-Endian und signiert** (16-Bit). Ein Sample liegt erst nach
  einer `I2C_REPLY` vor; die Accessoren sind anfangs `nil`, bis die erste Antwort
  verarbeitet wurde.
- **Skalierung:** `scaled*` = Rohwert / Empfindlichkeit des eingestellten
  Vollausschlags. Beispiel: `scaledAccelX := accelX / 16384.0` bei ±2 g.
- **Bereichswechsel** (`setAccelerationRange:`/`setGyroRange:`) schreibt das
  Konfigurationsregister; gültige Indizes 0–3, sonst `error:`.
- **Temperaturformel:** `raw/340.0 + 36.53` in °C.
- **Rauschen/Nüchterheit:** Nach dem Aufwecken kurz stabilisieren lassen; bei
  erster Inbetriebnahme `whoAmI` (0x68) zur Kontrolle lesen.
- **Mehrere Sensoren:** AD0 auf 0x69 legen und eine zweite `FirmataMPU6050`-Instanz
  auf derselben `FirmataI2C`-Verbindung registrieren.
