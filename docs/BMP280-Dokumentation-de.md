# BMP280 – Barometrischer Druck- & Temperatursensor

Inhalt:
1. Überblick
2. Technische Daten
3. Verdrahtung
4. Klasse und API
5. Beispiel
6. Hinweise

---

## 1. Überblick

Der **BMP280** (Bosch Sensortec) ist ein barometrischer Druck- und
Temperatursensor. Er misst den absoluten Luftdruck im Bereich 300–1100 hPa
und liefert das Ergebnis in drei Big-Endian-20-Bit-Ausgaberegistern ab
`0xF7` (Druck MSB, LSB, XLSB), gefolgt von den drei Temperaturregistern ab
`0xFA`. Die rohen 20-Bit-Zählwerte werden mit werkseitigen
Kalibrierkoeffizienten kompensiert, die in einem 24-Byte-Block bei `0x88`
liegen.

Das Paket `Firmata-BMP280` kapselt den Sensor hinter einer
`FirmataI2C`-Verbindung. `initializeDevice` schreibt einmalig die
Konfiguration und das Messsteuerregister (Oversampling x1, Normalmodus) und
liest den Kalibrierblock. Mit `startReadingPort` streamt der Arduino die
sechs Ausgabebytes kontinuierlich; jede eingehende `I2C_REPLY` überschreibt
das letzte Messwert-Sample. Danach sind die skalierten Werte direkt
abrufbar.

Die Kompensation folgt den Ganzzahl-Formeln des offiziellen
Bosch-Referenztreibers (C-Ganzzahldivision, auf den Sensorbereich begrenzt),
sodass die Ergebnisse exakt den Datenblatt-Berechnungen entsprechen.

## 2. Technische Daten

- Kombinierter barometrischer Druck- und Temperatursensor.
- Druckbereich: 300–1100 hPa; Ausgabe bis 20 Bit, Big-Endian (MSB zuerst).
- Absolute Temperaturgenauigkeit: ±1,0 °C; Auflösung 0,01 °C.
- Druckauflösung: 0,01 hPa (Ausgabeeinheit); typisches Rauschen deutlich
  unter 1 hPa.
- I2C-Slave-Adresse: **0x76** (SDO low) oder **0x77** (SDO high).
- Betriebsspannung: 1,71–3,6 V.
- Chip-ID-Register (`0xD0`) liefert **0x58** zur Identifikation.
- 24 Kalibrierbytes bei `0x88` (dig_T1..T3, dig_P1..P9).

## 3. Verdrahtung

| BMP280 | Arduino Uno |
| --- | --- |
| VCC | 3,3 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| SDO | GND (für Adresse 0x76) |

I2C-Pull-ups sitzen auf gängigen Breakout-Boards; ansonsten 4,7 kΩ an
SDA/SCL nach VCC. SDO bestimmt die Adresse: GND → 0x76, VCC → 0x77.

## 4. Klasse und API

`FirmataBMP280` erbt von `FirmataI2CDevice` (Paket `Firmata-I2C`).

- Initialisierung: `initializeDevice` (schreibt `config` 0x00 und
  `ctrl_meas` 0x27, liest dann die 24 Kalibrierbytes),
  `registerWithFirmata` (nach der Verdrahtung!), optional `readChipId`.
- Lesen: `startReadingPort` (kontinuierlich) bzw. `readOnce` (ein Sample der
  sechs Ausgabebytes bei `0xF7`).
- Rohausgänge: `rawPressure`/`rawTemperature` (20-Bit-Big-Endian-Zählwerte),
  `chipId` (nach `readChipId`).
- Kompensierte Ausgänge:
  - `compensatedTemperature` — 0,01 °C als Integer, begrenzt auf
    [-4000, 8500] (−40,00 °C bis 85,00 °C).
  - `temperatureCelsius` — Grad Celsius als Float.
  - `compensatedPressure` — Druck in Pascal als Integer, begrenzt auf
    [30000, 110000].
  - `pressurePascal` — identisch mit `compensatedPressure`.
  - `pressureHectoPascal` — Druck in hPa als Float.
- Kalibrierung: `calibrationData` (24 Bytes), `isCalibrationLoaded`.
- Intern: `tFine` (Feintemperatur, von beiden Kompensationsformeln genutzt).
- Empfang: `handleI2CReply:data:` verteilt Chip-ID-, Kalibrier- und
  Ausgabe-Antworten.
- Geerbte Helfer (`FirmataI2CDevice`): `firmata:address:`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataBMP280Constants` (Klassenseite) hält die Register
(`calibrationRegister` 0x88, `chipIdRegister` 0xD0, `configRegister` 0xF5,
`ctrlMeasRegister` 0xF4, `dataRegister` 0xF7, `resetRegister` 0xE0,
`statusRegister` 0xF3), die Konfiguration (`configValue` 0x00,
`ctrlMeasValue` 0x27), die Spezifikation (`chipIdValue` 0x58,
`calibrationByteCount` 24, `sensorOutputByteCount` 6) und den Default
(`defaultAddress` 0x76).

## 5. Beispiel

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

"Optional: Chip-Identifikation"
sensor readChipId.
sensor chipId.                          "16r58"

"Kontinuierliches Streaming starten"
sensor startReadingPort.

"... nach einigen Schritten:"
sensor temperatureCelsius.              "Temperatur in C"
sensor pressureHectoPascal.             "Druck in hPa"

"Alternativ ein einzelnes Sample:"
sensor readOnce.

"Streaming stoppen:"
sensor stopReading.
```

## 6. Hinweise

- **20-Bit-Werte sind Big-Endian:** Druck = Druck-MSB, Druck-LSB,
  Druck-XLSB, MSB zuerst; das Low-Nibble des XLSB-Bytes ist immer null. Der
  Rohwert ist `((MSB << 16) + (LSB << 8) + XLSB) >> 4`.
- **Ausgabereihenfolge:** die sechs Ausgabebytes bei `0xF7` sind Druck MSB,
  LSB, XLSB, danach Temperatur MSB, LSB, XLSB. `rawPressure` und
  `rawTemperature` packen sie entsprechend aus (Indizes 1 und 4).
- **Kompensation ist Ganzzahlarithmetik** nach dem Bosch-Referenztreiber:
  Division mit Abschneiden gegen null (`quo:`), derselbe `t_fine` für die
  Temperatur- und die Druckformel, plus Begrenzung auf den Sensorbereich.
- **nil vor der Kalibrierung:** `temperatureCelsius`, `compensatedPressure`
  und `tFine` antworten nil, solange der Kalibrierblock nicht eingetroffen
  ist. Nach einem Reset `initializeDevice` erneut aufrufen oder auf die
  nächste Antwort warten.
- **Chip-ID prüfen:** `readChipId` + `chipId` sollte `0x58` liefern. Bei
  Abweichung liegt ein Kommunikationsfehler vor.
- **Register `0xF7` vs. Firmata-Sysex-Ende** `0xF7`: In den Tests erscheinen
  beide in Byte-Arrays; sie sind unabhängig. Das Ausgaberegister `0xF7` ist
  nur eine Chip-Registeradresse auf dem I2C-Bus.
- **Mehrere Sensoren:** SDO auf VCC legen für Adresse 0x77 und eine zweite
  `FirmataBMP280`-Instanz auf derselben `FirmataI2C`-Verbindung registrieren.
