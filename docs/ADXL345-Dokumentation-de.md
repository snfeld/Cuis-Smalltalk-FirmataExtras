# ADXL345 – 3-Achsen-Beschleunigungssensor

Inhalt:
1. Überblick
2. Technische Daten
3. Verdrahtung
4. Klasse und API
5. Beispiel
6. Hinweise

---

## 1. Überblick

Der **ADXL345** (Analog Devices) ist ein 3-Achsen-Beschleunigungssensor mit
13-Bit-Auflösung im Vollausschlag-Modus. Er misst statische Beschleunigung
(Schwerkraft) sowie dynamische Beschleunigung (Bewegung, Erschütterung) und
liefert die Ergebnisse in zwei aufeinanderfolgenden Registern pro Achse
(`DATAX0` bis `DATAZ1`, 6 Bytes) als Little-Endian 16-Bit-Werte.

Das Paket `Firmata-ADXL345` kapselt den Sensor hinter einer
`FirmataI2C`-Verbindung. Mit `startReadingPort` streamt der Arduino die
Ausgaberegister kontinuierlich; jede eingehende `I2C_REPLY` überschreibt das
letzte Messwert-Sample. Roh- und skalierte Werte sind danach direkt abrufbar.

Der Sensor arbeitet mit fester Empfindlichkeit von 256 LSB/g im
Vollausschlag-Modus – unabhängig vom gewählten Bereich. Der Bereich beeinflusst
nur den maximalen Ausschlag, nicht die Auflösung pro Grad.

## 2. Technische Daten

- 3-Achsen-Beschleunigungssensor, 13-Bit Vollausschlag (Auflösung 4 mg/LSB,
  256 LSB/g) für alle Bereiche.
- Wählbare Vollausschlagsbereiche: **±2 g** (Index 0), **±4 g** (Index 1),
  **±8 g** (Index 2), **±16 g** (Index 3).
- Ausgaberaten über `BW_RATE`-Register (`0x2C`): Codes 0x00 (0,1 Hz) bis
  0x0F (3200 Hz), Standardwert 0x0A (100 Hz).
- 6 Ausgaberegister ab `DATAX0` (`0x32`): X0, X1, Y0, Y1, Z0, Z1
  (Little-Endian, 16-Bit signiert).
- I2C-Slave-Adresse: **0x53** (ALT ADDRESS high) oder **0x1D** (ALT ADDRESS
  low).
- Betriebsspannung: 2,0–3,6 V. Stromverbrauch: 23 µA (Messung), 0,1 µA
  (Standby).
- DEVID-Register (`0x00`) liefert 0xE5 zur Identifikation.

## 3. Verdrahtung

| ADXL345 | Arduino Uno |
| --- | --- |
| VCC | 3,3 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| CS | VCC (für I2C-Betrieb) |
| SDO | GND (für Adresse 0x53) |

I2C-Pull-ups sitzen auf gängigen Breakout-Boards; ansonsten 4,7 kΩ an SDA/SCL
nach VCC. Der CS-Pin muss auf VCC gelegt werden, um den I2C-Modus zu aktivieren.
SDO bestimmt die Adresse: GND → 0x53, VCC → 0x1D.

## 4. Klasse und API

`FirmataADXL345` erbt von `FirmataI2CDevice` (Paket `Firmata-I2C`).

- Initialisierung: `initializeDevice` (setzt das Measure-Bit im
  `POWER_CTL`-Register), `registerWithFirmata` (nach der Verdrahtung!).
- Sensor-Konfiguration: `setAccelerationRange:` (0–3 ↔ ±2/4/8/16 g),
  `setSampleRate:` (0x00–0x0F für 0,1 Hz bis 3200 Hz).
- Lesen: `startReadingPort` (kontinuierlich) bzw. `readOnce` (ein Sample).
- Rohausgänge: `accelX`/`accelY`/`accelZ` (16-Bit Little-Endian, vorzeichenbehaftet).
- Skalierte Ausgänge: `scaledAccelX`/`scaledAccelY`/`scaledAccelZ` (in g)
  — Rohwert durch 256,0 (feste Empfindlichkeit im Vollausschlag-Modus).
- Empfindlichkeit und Bereich: `accelSensitivity` (256 LSB/g, fest),
  `accelRange` (aktueller Bereichs-Index), `sampleRate` (aktueller Code).
- Empfang: `handleI2CReply:data:` verarbeitet die 6-Byte-Antwort des Arduino.
- Geerbte Helfer (`FirmataI2CDevice`): `firmata:address:`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataADXL345Constants` (Klassenseite) hält die Register
(`dataFormatRegister` 0x31, `bandwidthRateRegister` 0x2C,
`powerControlRegister` 0x2D, `dataX0Register` 0x32, `deviceIdRegister` 0x00),
Bits (`fullResolutionBit`, `measureBit`), Spezifikation
(`accelSensitivity` 256, `deviceIdValue` 0xE5, `sensorOutputByteCount` 6)
und Defaults (`defaultAddress` 0x53, `defaultAccelRange` 0,
`defaultSampleRate` 0x0A).

## 5. Beispiel

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

"Bereich und Rate konfigurieren (optional)"
sensor setAccelerationRange: 1.    "±4 g"
sensor setSampleRate: 16r0B.       "200 Hz"

"Kontinuierliches Streaming starten"
sensor startReadingPort.

"... nach einigen Schritten:"
sensor accelZ.                     "roher LE-16-Bit-Z-Wert"
sensor scaledAccelZ.               "Z-Beschleunigung in g"

"Alternativ ein einzelnes Sample:"
sensor readOnce.

"Streaming stoppen:"
sensor stopReading.
```

## 6. Hinweise

- **Rohwerte sind Little-Endian und signiert** (16-Bit). Das LSB liegt im
  ersten Register (`DATAX0`), das MSB im zweiten (`DATAX1`). Dies unterscheidet
  sich vom MPU6050 (Big-Endian).
- **Vollausschlag-Modus (full_res):** Immer aktiv → Empfindlichkeit bleibt
  fix 256 LSB/g, egal welcher Bereich gewählt ist. Der Bereich bestimmt nur
  den maximalen Ausschlag.
- **Skalierung:** `scaled*` = Rohwert / 256,0. Beispiel: `scaledAccelZ :=
  accelZ / 256.0`.
- **Bereichswechsel** (`setAccelerationRange:`) schreibt Bits 0–1 des
  `DATA_FORMAT`-Registers. Das Full-Resolution-Bit (Bit 3) bleibt gesetzt.
- **Stabilisierung nach Aufwecken:** Nach dem Einschalten oder
  `initializeDevice` kurz warten; der Sensor braucht einige Millisekunden zum
  Stabilisieren.
- **DEVID prüfen:** `DEVID`-Register (`0x00`) muss den Wert `0xE5` liefern.
  Bei Abweichung liegt ein Kommunikationsfehler vor.
- **Mehrere Sensoren:** SDO auf VCC legen für Adresse 0x1D und eine zweite
  `FirmataADXL345`-Instanz auf derselben `FirmataI2C`-Verbindung registrieren.
