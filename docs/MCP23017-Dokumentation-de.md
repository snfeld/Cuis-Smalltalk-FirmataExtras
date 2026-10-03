# MCP23017 – 16-Bit-I/O-Expander

Inhalt:
1. Überblick
2. Technische Daten
3. Verdrahtung
4. Klasse und API
5. Beispiel
6. Hinweise

---

## 1. Überblick

Der **MCP23017** (Microchip) ist ein 16-Bit-I2C-I/O-Expander mit zwei
8-Bit-Ports, GPIOA (Pins 0–7) und GPIOB (Pins 8–15). Jeder Pin wird über die
Richtungsregister IODIR einzeln als Ein- oder Ausgang konfiguriert, bekommt
über GPPU einen optionalen internen Pull-up und wird über die
GPIO-Ausgangslatches geschrieben bzw. gelesen.

Das Paket `Firmata-MCP23017` kapselt den Expander hinter einer
`FirmataI2C`-Verbindung. Richtungs-, Pull-up- und Ausgangseinstellungen
werden in Schattenbytes auf der Smalltalk-Seite gehalten, sodass
Einzel-Pin-Operationen nur das betroffene Bit ändern und danach als ganzes
Portbyte an den Chip geschrieben werden. Lesezugriffe laufen über das
registerbasierte I2C-Format, das StandardFirmata bedient, ohne den
Portzustand zu verändern.

## 2. Technische Daten

- 16 I/O-Pins in zwei 8-Bit-Ports: GPIOA (Pins 0–7) und GPIOB (Pins 8–15).
- Richtung über IODIRA/IODIRB: ein Bit von `0` bedeutet Ausgang, ein Bit von
  `1` bedeutet Eingang.
- Interne Pull-ups (≈100 kΩ) pro Pin über GPPUA/GPPUB.
- Betriebsspannung: **1,8 V – 5,5 V**.
- Sink-/Source-Strom: **25 mA pro Pin**.
- I2C-Adressbereich: **0x20 – 0x27** (3 Adresspins A0–A2; alle auf GND =
  0x20).
- Power-on-Default: alle Pins Eingänge, alle Pull-ups aus, Ausgangslatches
  lesen `1`.
- INT-Ausgang: Open-Drain, aktiv low (in diesem Paket nicht genutzt).

## 3. Verdrahtung

| MCP23017 | Arduino Uno |
| --- | --- |
| VCC | 5 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| A0 | GND (Adresse 0x20) |
| A1 | GND (Adresse 0x20) |
| A2 | GND (Adresse 0x20) |
| GPA0–GPA7 | GPIOA-Pins |
| GPB0–GPB7 | GPIOB-Pins |

Für einen zweiten Expander am selben Bus setzen Sie die Adresspins
entsprechend, z. B. A0 → VCC für 0x21. Falls nicht auf dem Breakout-Board
vorhanden: 4,7-kΩ-Pull-ups auf SDA/SCL nach VCC.

## 4. Klasse und API

`FirmataMCP23017` erweitert `FirmataI2CDevice` (Paket `Firmata-I2C`).

- Initialisierung: `initializeDevice` (schreibt IODIRA/B = 0xFF und GPPUA/B =
  0x00), `registerWithFirmata` (nach dem Verdrahten!), `addressWithAddressPins:`.
- Pin-Operationen: `setPinMode:value:` (Pin 0–15; `true` = Ausgang),
  `digitalWritePin:value:` (Ausgangspin), `digitalReadPin:` (Eingangspin),
  `setPullUpPin:value:` (interner Pull-up an/aus).
- Port-Operationen: `writePort:value:` (8 GPIOA- oder GPIOB-Pins auf einmal),
  `readPort:` (0 = GPIOA, 1 = GPIOB), `startReadingPort:` (kontinuierliches
  Polling), `stopReading` (beendet den Strom).
- Callback: `handleI2CReply:data:` (verarbeitet eingehende `I2C_REPLY`-Daten
  und aktualisiert die Port-Eingangswerte).
- Zugriff: `inputValueForPort:`, `outputValueForPort:`, `directionA`,
  `directionB`.

`FirmataMCP23017Constants` (Klassenseite) enthält die Registerkarte
(`iodirARegister` 0x00, `iodirBRegister` 0x01, `gppuARegister` 0x0C,
`gppuBRegister` 0x0D, `gpioARegister` 0x12, `gpioBRegister` 0x13) und die
Spezifikation (`pinCount` 16, `portPinCount` 8, `portCount` 2,
`baseAddress`/`defaultAddress` 0x20, `addressCount` 8).

## 5. Beispiel

```smalltalk
| bus expander |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

expander := FirmataMCP23017 new.
expander firmata: bus address: FirmataMCP23017Constants defaultAddress.
expander initializeDevice.
expander registerWithFirmata.

"Pin 0 auf GPIOA als Ausgang, niedrig gehalten"
expander setPinMode: 0 value: true.
expander digitalWritePin: 0 value: false.

"Pin 8 (GPIOB-Eingang) mit internem Pull-up"
expander setPinMode: 8 value: false.
expander setPullUpPin: 8 value: true.

"Alle acht GPIOA-Pins auf einmal schreiben"
expander writePort: 0 value: 16r55.

"GPIOA einlesen und einen Pin abfragen"
expander readPort: 0.
expander inputValueForPort: 0.      "letztes gelesenes GPIOA-Byte"
expander digitalReadPin: 1.         "true, wenn Pin 1 high ist"

"GPIOB kontinuierlich streamen"
expander startReadingPort: 1.
expander stopReading.
```

## 6. Hinweise

- **Richtungs-Bit-Bedeutung:** In den IODIR-Registern bedeutet ein Bit von
  `0` Ausgang und ein Bit von `1` Eingang. `setPinMode:value:` versteckt
  das: `true` für Ausgang, `false` für Eingang übergeben.
- **Schattenbytes:** `directionA/B` und die Ausgangslatches werden als Bytes
  im Image gehalten. `setPinMode:`, `digitalWritePin:` und `setPullUpPin:`
  ändern nur das betroffene Bit und schreiben das ganze Portbyte zurück,
  sodass gemischte Konfigurationen ohne erneutes Lesen konsistent bleiben.
- **Pin-Nummerierung:** Pin 0–7 liegen in GPIOA, Pin 8–15 in GPIOB. Die
  privaten Helfer `portForPin:` und `bitForPin:` bilden einen Pin-Index auf
  Port und Bit ab.
- **GPIO lesen:** `readPort:` liest das GPIOA/GPIOB-Register über das
  registerbasierte I2C-Leseformat (StandardFirmata ≥ 2.5), das den
  Portzustand nicht verändert. Bei Eingangspins spiegelt der Wert den
  Pin-Level, bei Ausgangspins den getriebenen Latch-Wert.
- **Mehrere Geräte:** Bis zu 8 MCP23017 am selben I2C-Bus über die
  Adresspins. Pro Chip eine eigene `FirmataMCP23017`-Instanz registrieren und
  die Adresse mit `FirmataMCP23017 addressWithAddressPins:` berechnen.
- **Stromversorgung:** 25 mA pro Pin ist das Chip-Limit; höhere Lasten über
  externe Treiberstufen oder Transistoren schalten.
