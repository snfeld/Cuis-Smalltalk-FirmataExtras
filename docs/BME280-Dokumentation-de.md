# BME280 – Feuchte-, Druck- & Temperatursensor

Inhalt:
1. Überblick
2. Technische Daten
3. Verdrahtung
4. Klasse und API
5. Beispiel
6. Hinweise

---

## 1. Überblick

Der **BME280** (Bosch Sensortec) ist ein kombinierter Sensor für relative
Luftfeuchtigkeit, barometrischen Luftdruck und Temperatur. Er liefert dieselbe
Druck- und Temperaturausgabe wie der BMP280 (20-Bit-Big-Endian-Register bei
`0xF7` bzw. `0xFA`) plus einen 16-Bit-Ausgang für relative Feuchte bei
`0xFD`. Die Daten werden mit zwei Kalibrierblöcken kompensiert: dem
26-Byte-Block für Temperatur/Druck bei `0x88` (Byte 26, also `0xA1`, ist der
unsigned-Feuchtekoeffizient `dig_H1`) und dem 7-Byte-Feuchteblock bei `0xE1`.

Das Paket `Firmata-BME280` erweitert `Firmata-BMP280` hinter einer
`FirmataI2C`-Verbindung. `initializeDevice` schreibt `CTRL_HUM` (`0xF2`)
**vor** `CTRL_MEAS` (vom Chip gefordert), dann die Konfiguration und das
Messsteuerregister, und liest schließlich beide Kalibrierblöcke.
`startReadingPort` veranlasst den Arduino, die sechs Druck-/Temperaturbytes
bei `0xF7` und die zwei Feuchtebytes bei `0xFD` kontinuierlich zu streamen;
jede eingehende `I2C_REPLY` überschreibt das letzte Messwert-Sample.

Alle sechs Feuchtekoeffizienten (`dig_H1`..`dig_H6`) werden aus dem
nibble-verpackten 0xE1-Block geparst und die Feuchte mit den
Ganzzahl-Formeln des Bosch-Referenztreibers kompensiert (abschneidende
Division, auf den Sensorbereich begrenzt). Temperatur- und
Druckkompensation erbt die Klasse von `FirmataBMP280`.

## 2. Technische Daten

- Kombinierter Sensor für relative Feuchte, barometrischen Druck und
  Temperatur.
- Feuchtebereich: 0–100 % rF; Auflösung 0,008 % rF (Ausgabe als Q10,
  d. h. 102400 = 100 %).
- Druckbereich: 300–1100 hPa; Temperaturauflösung 0,01 °C.
- I2C-Slave-Adresse: **0x76** (SDO low) oder **0x77** (SDO high).
- Betriebsspannung: 1,71–3,6 V.
- Chip-ID-Register (`0xD0`) liefert **0x60** (anders als beim BMP280: 0x58).
- Kalibrierung: 26 Bytes bei `0x88` (dig_T1..T3, dig_P1..P9, dig_H1) und
  7 Bytes bei `0xE1` (dig_H2..dig_H6, nibble-verpackt).

## 3. Verdrahtung

| BME280 | Arduino Uno |
| --- | --- |
| VCC | 3,3 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| SDO | GND (für Adresse 0x76) |

I2C-Pull-ups sitzen auf gängigen Breakout-Boards; ansonsten 4,7 kΩ an
SDA/SCL nach VCC. SDO bestimmt die Adresse: GND → 0x76, VCC → 0x77.

## 4. Klasse und API

`FirmataBME280` erbt von `FirmataBMP280` (Paket `Firmata-BMP280`).

- Initialisierung: `initializeDevice` (schreibt zuerst `CTRL_HUM` 0x01,
  dann `config` 0x00 und `ctrl_meas` 0x27, liest dann die 26 Kalibrierbytes
  bei `0x88` und die 7 Feuchte-Kalibrierbytes bei `0xE1`),
  `registerWithFirmata` (nach der Verdrahtung!), optional `readChipId`.
- Lesen: `startReadingPort` (kontinuierlicher Stream von `0xF7` und `0xFD`)
  bzw. `readOnce` (ein Sample von beidem).
- Rohausgänge: `rawPressure`/`rawTemperature` (20 Bit), `rawHumidity`
  (16-Bit-Big-Endian), `chipId`.
- Kompensierte Ausgänge:
  - `temperatureCelsius`, `compensatedTemperature`, `pressureHectoPascal`,
    `pressurePascal`, `compensatedPressure` — von `FirmataBMP280` geerbt.
  - `compensatedHumidity` — relative Feuchte als Q10-Integer, begrenzt auf
    [0, 102400] (102400 = 100 %).
  - `humidityPercent` — relative Feuchte in Prozent als Float
    (`compensatedHumidity / 1024.0`).
- Kalibrierung: `calibrationData` (26 Bytes), `humidityCalibration`
  (7 Bytes), `isCalibrationLoaded`, `isHumidityCalibrationLoaded` und die
  geparsten Koeffizienten `digH1`..`digH6` (für Tests zugänglich).
- Empfang: `handleI2CReply:data:` verteilt die Feuchte-Kalibrier- und
  Feuchte-Ausgabe-Antworten, bevor an `FirmataBMP280` delegiert wird.
- Geerbte Helfer (`FirmataI2CDevice`): `firmata:address:`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataBME280Constants` erweitert `FirmataBMP280Constants` und ergänzt
(`ctrlHumRegister` 0xF2, `humidityCalibrationRegister` 0xE1,
`humidityDataRegister` 0xFD), Spezifikation (`calibrationByteCount` 26,
`humidityCalibrationByteCount` 7, `humidityOutputByteCount` 2,
`chipIdValue` 0x60) und den Default (`defaultAddress` 0x76).

## 5. Beispiel

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

"Optional: Chip-Identifikation"
sensor readChipId.
sensor chipId.                          "16r60"

"Kontinuierliches Streaming starten"
sensor startReadingPort.

"... nach einigen Schritten:"
sensor temperatureCelsius.              "Temperatur in C"
sensor pressureHectoPascal.             "Druck in hPa"
sensor humidityPercent.                 "relative Feuchte in %"

"Alternativ ein einzelnes Sample:"
sensor readOnce.

"Streaming stoppen:"
sensor stopReading.
```

## 6. Hinweise

- **`CTRL_HUM` vor `CTRL_MEAS`:** der BME280 übernimmt das
  Feuchte-Oversampling aus `CTRL_HUM` (`0xF2`) nur, wenn dieses vor dem
  Messsteuerregister geschrieben wird. `initializeDevice` macht das in der
  richtigen Reihenfolge.
- **26 Kalibrierbytes:** der BME280 braucht den vollständigen 26-Byte-Block
  ab `0x88`; Byte 26 (Register `0xA1`) enthält das unsigned `dig_H1`. Der
  BMP280 benötigt nur die ersten 24.
- **Feuchte-Kalibrierlayout (`0xE1`..`0xE7`):** `dig_H2` ist ein
  Little-Endian-signed-16-Bit-Wert bei `0xE1`, `dig_H3` unsigned bei `0xE3`,
  `dig_H4` und `dig_H5` sind auf signierte MSB-Bytes (`0xE4`/`0xE6`) plus
  ein Nibble des Bytes `0xE5` aufgeteilt (`dig_H4` nutzt das Low-Nibble,
  `dig_H5` das High-Nibble), und `dig_H6` ist das signierte Byte bei `0xE7`.
  Die Koeffizienten `digH1`..`digH6` werden entsprechend geparst.
- **Feuchteausgang ist 16-Bit-Big-Endian** bei `0xFD` (MSB zuerst).
- **Kompensation ist Ganzzahlarithmetik** nach dem Bosch-Referenztreiber:
  Division mit Abschneiden gegen null (`quo:`), derselbe `t_fine` für die
  Temperatur-, Druck- und Feuchteformel, plus Begrenzung auf den
  Sensorbereich.
- **nil vor der Kalibrierung:** die kompensierten Werte antworten nil,
  bis beide Kalibrierblöcke eingetroffen sind.
- **Chip-ID prüfen:** `readChipId` + `chipId` sollte `0x60` liefern. Bei
  Abweichung liegt ein Kommunikationsfehler vor.
- **Mehrere Sensoren:** SDO auf VCC legen für Adresse 0x77 und eine zweite
  `FirmataBME280`-Instanz auf derselben `FirmataI2C`-Verbindung registrieren.
