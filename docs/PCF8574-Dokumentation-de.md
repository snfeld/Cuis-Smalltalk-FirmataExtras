# PCF8574 – 8-Bit-I/O-Expander

Inhalt:
1. Überblick
2. Technische Daten
3. Verdrahtung
4. Klasse und API
5. Beispiel
6. Hinweise

---

## 1. Überblick

Der **PCF8574** (NXP/Texas Instruments) ist ein 8-Bit quasi-bidirektionaler
I/O-Expander über I2C. Anders als Register-basierte Sensoren gibt es **kein
Adressregister** – eine einzelne Byte-Schreib- oder Leseoperation steuert den
gesamten Port (8 Pins).

Jeder Pin ist quasi-bidirektional: Schreibt man `1`, wird der Pin als Eingang
mit internem Pull-up konfiguriert; schreibt man `0`, wird der Pin als Ausgang
mit niedrigem Pegel aktiviert. Zum Lesen von Eingängen müssen zunächst alle
Pins auf `1` gesetzt werden, bevor der Port gelesen werden kann.

Das Paket `Firmata-PCF8574` kapselt den Expander hinter einer
`FirmataI2C`-Verbindung. Der `readPort`-Aufruf nutzt ein registerloses
I2C-Read-Format (StandardFirmata ≥ 2.5), um eine Beschädigung des Portzustands
zu vermeiden.

## 2. Technische Daten

- 8-Bit quasi-bidirektionale I/Pins: kein Register-Adressierung, ein Byte
  steuert den gesamten Port.
- Eingangsspannung: **2,6 V – 6 V**.
- Stromverbrauch: max. **100 µA**.
- Senkenstrom: **25 mA pro Pin**.
- I2C-Adressbereich: **0x20 – 0x27** (3 Adresspins A0–A2; alle Tief = 0x20).
- Power-on-Standard: alle Pins hoch (Eingangsmodus).
- INT-Ausgang: Open-Drain, aktiv niedrig (wird in diesem Paket nicht verwendet).

## 3. Verdrahtung

| PCF8574 | Arduino Uno |
| --- | --- |
| VCC | 5 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| A0 | GND (Adresse 0x20) |
| A1 | GND (Adresse 0x20) |
| A2 | GND (Adresse 0x20) |
| P0–P7 | I/O-Pins |

Für einen zweiten Expander auf derselben I2C-Leitung A0 auf VCC legen
(Adresse 0x21). 4,7 kΩ Pull-ups an SDA/SCL nach VCC, falls nicht auf dem
Breakout-Board vorhanden.

## 4. Klasse und API

`FirmataPCF8574` erbt von `FirmataI2CDevice` (Paket `Firmata-I2C`).

- Initialisierung: `initializeDevice` (setzt die I2C-Konfiguration),
  `registerWithFirmata` (nach der Verdrahtung!).
- Schreiben: `writePort:` (sendet ein 8-Bit-Byte an den gesamten Port),
  `digitalWritePin:value:` (setzt einen einzelnen Pin; liest den aktuellen
  Portzustand und ändert nur das betreffende Bit).
- Lesen: `readPort` (registerloses I2C-Read; Ergebnis in `inputValue`),
  `digitalReadPin:` (gibt `true`/`false` für den angegebenen Pin zurück).
- Stream: `startReadingPort` (startet kontinuierliches Polling über den
  Firmata-Step), `stopReading` (hält den Stream an).
- Callback: `handleI2CReply:data:` (verarbeitet eingehende `I2C_REPLY`-Daten
  und aktualisiert `inputValue`/`outputValue`).

`FirmataPCF8574Constants` (Klassenseite) hält `portRegister` (0),
`pinCount` (8), `defaultAddress` (0x20), `allPinsHigh` (0xFF).

## 5. Beispiel

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

"Alle Pins als Eingänge konfigurieren"
expander writePort: 16rFF.

"Pins 0–3 als Ausgänge (niedrig), Pins 4–7 als Eingänge"
expander writePort: 16r0F.

"Einen einzelnen Pin setzen"
expander digitalWritePin: 0 value: true.

"Port lesen"
expander readPort.
expander inputValue.               "letztes gelesenes Port-Byte"

"Einen einzelnen Pin lesen"
expander digitalReadPin: 4.         "true wenn Pin 4 high ist"

"Kontinuierliches Polling starten/stoppen"
expander startReadingPort.
expander stopReading.
```

## 6. Hinweise

- **Quasi-bidirektionale Pins:** Schreibt man `1` an einen Pin, wird dieser
  als Eingang mit internem Pull-up konfiguriert. Schreibt man `0`, wird der
  Pin als Ausgang mit niedrigem Pegel aktiviert. Es gibt keine Richtungs-
  oder Konfigurationsregister wie bei anderen I/O-Expandern.
- **Eingänge lesen:** Vor dem Lesen müssen alle Pins auf `1` gesetzt werden
  (`writePort: 16rFF`), da die Pins sonst den niedrigen Pegel des letzten
  Ausgangswerts treiben und kein korrektes Eingangssignal möglich ist.
- **Registerloses Read:** Der `readPort`-Aufruf verwendet ein
  registerloses I2C-Read-Format (StandardFirmata ≥ 2.5, argc ≠ 6). Dies
  verhindert, dass ein versehentlich gesendetes Register-Byte den
  Portzustand beschädigt.
- **Mehrere Devices:** Bis zu 8 PCF8574 auf derselben I2C-Leitung durch
  verschiedene Adressen (A0–A2). Pro Device eine eigene
  `FirmataPCF8574`-Instanz registrieren.
- **Kein internes Register:** Es gibt kein Register-Map wie bei
  Register-basierten I2C-Devices. Jede Schreib-/Leseoperation wirkt direkt
  auf die 8 I/O-Pins.
- **Stromversorgung:** Der PCF8574 verbraucht max. 100 µA; bei höheren
  Lasten (bis 25 mA/Sink) externe Treiberstufen verwenden.
