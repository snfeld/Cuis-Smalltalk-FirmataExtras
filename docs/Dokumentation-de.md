# Firmata für Cuis-Smalltalk

Inhalt:
1. Was ist Firmata?
2. Voraussetzungen und Installation
3. Verbindung und Hintergrundverarbeitung
4. API-Übersicht
5. Anleitung mit Beispielen
6. Neues I2C-Gerät hinzufügen
7. Hinweise und Stolperfallen für Cuis

---

## 1. Was ist Firmata?

Firmata ist ein offenes, protokollbasiertes Verfahren, um einen Mikrocontroller
(zum Beispiel ein Arduino-Board) von einem übergeordneten Rechner aus zu steuern.
Auf dem Arduino läuft die **StandardFirmata**-Firmware; der Rechner (hier ein
Cuis-Smalltalk-Image) sendet kompakte Byte-Befehle über eine serielle Verbindung
(USB) oder ein TCP/IP-Netzwerk, und der Arduino antwortet mit Messwerten und
Statusmeldungen. Die Schnittstelle bleibt dabei immer dieselbe, unabhängig davon,
welche Pins oder I2C-Geräte angeschlossen sind.

Das Protokoll arbeitet mit 7-Bit-Werten: Jede beliebige Zahl wird als LSB/MSB-Paar
übertragen. Komplexe Erweiterungen (wie I2C) verwenden den SYSEX-Mechanismus:
eine Nachricht beginnt mit `START_SYSEX` (`0xF0`) und endet mit `END_SYSEX`
(`0xF7`). Dieses Paket implementiert den kompletten Standard, einschließlich der
I2C-SYSEX-Befehle.

## 2. Voraussetzungen und Installation

**Auf dem Arduino** (Arduino IDE, Bibliothek *Firmata* von der Smalltalk-Community):

- `StandardFirmata` für USB/seriell.
- `StandardFirmataEthernet` oder `StandardFirmataWiFi` für Netzwerk­betrieb.
- Für eigene Firmware-Logik: `ConfigurableFirmata` (alle Beispiele und Tests
  dieses Projekts sind byte-genau zu diesen Skizzen abgestimmt).

**In Cuis-Smalltalk** werden die Pakete über den Package-Browser geladen oder mit:

```smalltalk
Feature require: #'Firmata'.            "Basisprotokoll (serieller Port)"
Feature require: #'Firmata-I2C'.        "I2C-Unterstützung"
Feature require: #'Firmata-PCA9685'.    "PCA9685 16-Kanal PWM/Servo-Treiber"
Feature require: #'Firmata-MPU6050'.    "MPU6050-IMU"
Feature require: #'Firmata-Servo'.      "hochsprachliche Servo-Steuerung (Speed, Bereiche)"
Feature require: #'Firmata-Net'.        "TCP/IP-Transport (benötigt Network-Kernel)"
```

Die Abhängigkeiten lösen sich automatisch auf. Für `Firmata-Net` muss das Paket
`Network-Kernel` installiert sein (eigene Sequenz oben: erst `Network-Kernel`, dann
`Firmata-Net`).

**Verdrahtung grundsätzlich:** Signal-Masse gemeinsam, für I2C zusätzlich
Pull-up-Widerstände (typisch 4,7 kΩ) auf `SDA`/`SCL` gegen `VCC` — bei den
meisten Breakout-Boards bereits vorhanden.

## 3. Verbindung und Hintergrundverarbeitung

Jede der Verbindungsklassen (`Firmata`, `FirmataI2C`, `FirmataNet`, `FirmataNetI2C`)
hält einen `port` (den Byte-Transport) und einen Hintergrundprozess, der die
Verbindung laufend abfragt:

- `connectOnPort:baudRate:` — serielle Verbindung (Klasse `Firmata`, `FirmataI2C`).
- `connectToHost:port:` — TCP/IP-Verbindung (Klassen `FirmataNet`, `FirmataNetI2C`).
- `startSteppingProcess` — startet den Poller; wird beim Verbinden automatisch
  aufgerufen.
- `step` / `stepTime` — ein Poll-Schritt bzw. dessen Intervall (Millisekunden).
  `step` liest alle anstehenden Bytes aus `processInput`. Ein Fehler beim Lesen
  setzt `port := nil`, wodurch die Verbindung als beendet gilt und der
  Hintergrundprozess von selbst stoppt.
- `stopSteppingProcess` — beendet den Poller (wird von `disconnect` aufgerufen).
- `disconnect` — beendet den Poller, schließt den Port, setzt `port := nil` und
  setzt den Protokollzustand zurück. Ist sicher mehrfach aufrufbar.
- `isConnected` — `^port notNil`.
- `isFirmataInstalled` — sendet solange Versionsabfragen, bis eine Antwort
  vorliegt (maximal 5 Sekunden).

## 4. API-Übersicht

### `Firmata` — Basisprotokoll (Paket `Firmata`)

- Betrieb/Verbindung: `connectOnPort:baudRate:`, `disconnect`, `isConnected`,
  `controlConnection`, `controlFirmataInstallation`.
- Hintergrundprozess: `startSteppingProcess`, `step`, `stepTime`,
  `stopSteppingProcess`.
- Empfang: `processInput`, `parseCommandHeader:`, `parseData:`, `parseSysex:`,
  `parsingSysex`.
- Status: `isFirmataInstalled`, `version`, `majorVersion`, `minorVersion`,
  `nameSymbol`, `port`.
- Pin-Modi: `pin:mode:` (und `valueForInputMode`, `valueForOutputMode`,
  `valueForPwmMode`, `valueForServoMode`), `digitalPin:mode:`.
- Digitale Pins: `digitalWrite:value:`, `digitalRead:`, `analogWrite:value:`,
  `digitalPortReport:onOff:`, `activateDigitalPort:`, `deactivateDigitalPort:`,
  `setDigitalInputs:data:`.
- Analoge Pins: `analogRead:`, `analogPinReport:onOff:`,
  `activateAnalogPin:`, `deactivateAnalogPin:`, `setAnalogInput:value:`.
- Servos: `attachServoToPin:`, `detachServoFromPin:`, `servoOnPin:angle:`,
  `servoConfig:minPulse:maxPulse:angle:`.
- Weitere Befehle: `queryVersion`, `queryFirmware`, `reportFirmware`,
  `systemReset`, `startSysex`, `endSysex`, `firmataString`,
  `sysexNonRealtime`, `sysexRealtime`.
- Initialisierung: `initialize`, `initializeVariables`.

### `FirmataConstants` (Paket `Firmata`)

Klassenmethoden für die Protokollnummern: `analogMessage`, `digitalMessage`,
`reportAnalog`, `reportDigital`, `reportVersion`, `setPinMode`, `startSysex`,
`endSysex`, `systemReset`, `maxDataBytes` u. a.

### `FirmataI2C` — I2C-Schicht (Paket `Firmata-I2C`)

Erweitert `Firmata` um die I2C-SYSEX-Nachrichten:

- `i2cConfig` / `i2cConfigDelay:` — Verzögerung zwischen I2C-Anforderung und
  Antwortunterbrechung setzen (Standard: 0 µs).
- `i2cRequestWrite:register:data:` — Daten an ein Slave-Register schreiben.
- `i2cRequestRead:register:byteCount:` — einmalig lesen.
- `i2cRequestReadContinuously:register:byteCount:` — fortlaufend lesen
  (Arduino sendet bei jeder Änderung automatisch).
- `i2cStopReading:` — fortlaufendes Lesen beenden.
- Geräteverzeichnis: `registerI2CDevice:`, `registeredDeviceFor:`.
- SYSEX-Verarbeitung: `parseSysex:`, `dispatchSysexMessageOfLength:`,
  `parseI2CReplyOfLength:`.

### `FirmataI2CDevice` — abstrakte Gerätebasis (Paket `Firmata-I2C`)

- Verdrahtung: `firmata:address:`, `registerWithFirmata`.
- I2C-Operationen: `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.
- Accessing: `address`, `address:`, `firmata`, `firmata:`.
- Unterklassen-Pflicht: `initializeDevice` (Gerät auf dem Bus konfigurieren) und
  `handleI2CReply:data:` (Antworten verarbeiten).

### `FirmataNet` / `FirmataNetI2C` — TCP/IP (Paket `Firmata-Net`)

- `connectToHost:` / `connectToHost:port:` — Verbindung zu einem
  StandardFirmataEthernet/-WiFi-Arduino, `defaultPort` (Standard: 3030).
- `FirmataNetI2C` kombiniert Netzwerk- und I2C-Fähigkeit (für die
  I2C-Geräteklassen bei Netzwerkbetrieb).
- `FirmataNetPort` kapselt einen `SocketStream` als Byte-Transport und kennt
  `readByteArray`, `nextPutAll:`, `close`, `isConnected`.
- `FirmataNetConstants` — Netzwerkgrundeinstellungen (Standard-Port).

## 5. Anleitung mit Beispielen

### 5.1 Serielle Verbindung und Versionsprüfung

```smalltalk
| firmata |
firmata := Firmata new.
firmata connectOnPort: '/dev/ttyACM0' baudRate: 57600.
firmata isFirmataInstalled.          "true, sobald der Handshake klappt"
firmata version.                     "z. B. 2.5 (StandardFirmata)"
```

### 5.2 Digitale Ausgänge (LED)

```smalltalk
"Pin 13 als Ausgang und anschalten"
firmata pin: 13 mode: FirmataTest stubbedInputMode.  "siehe Hinweis"
firmata digitalWrite: 13 value: 1.
```

> Der Pin-Modus-Wert ist ein Byte des Protokolls. Die hoch­sprach­lichen Helfer
> `pin:mode:` akzeptieren den numerischen Modus aus dem Arduino-Sketch
> (`INPUT = 0`, `OUTPUT = 1`, `ANALOG = 2`, `PWM = 3`, `SERVO = 4`). Für
> komfortable Symbole filtert der Controller die Werte über die Instanzvariablen
> — in den Tests werden die erwarteten Bytes definiert.

### 5.3 Digitale Eingänge (Taster) und analoge Messwerte

```smalltalk
firmata digitalRead: 2.                  "0 oder 1"
firmata analogRead: 0.                   "10-Bit-Wert 0..1023"
firmata analogPinReport: 0 onOff: 1.     "analogen Report aktivieren"
firmata digitalPortReport: 0 onOff: 1.   "digitalen Report aktivieren"
```

### 5.4 Servos

```smalltalk
firmata attachServoToPin: 9.
firmata servoOnPin: 9 angle: 90.
firmata servoOnPin: 9 angle: 45.
firmata detachServoFromPin: 9.
```

Für hochsprachliche Steuerung mit Geschwindigkeit, Einbaubereichen und
180°/270°-Servos (Pin oder PCA9685) das Paket `Firmata-Servo` verwenden, siehe
[Servo-Dokumentation-de.md](Servo-Dokumentation-de.md).

### 5.5 I2C-Gerät verwenden (PCA9685 als Beispiel)

```smalltalk
| firmata pwm |
firmata := FirmataI2C new.
firmata connectOnPort: '/dev/ttyACM0' baudRate: 57600.
firmata isFirmataInstalled.
firmata i2cConfig.
pwm := FirmataPCA9685 new firmata: firmata address: 0x40.
pwm registerWithFirmata.                "gerät im Bus registrieren"
pwm setFrequency: 50.                   "50 Hz (20 ms pro Kanal)"
pwm setPWMOnChannel: 0 value: 128.      "Duty 128/4096"
pwm setServoOnChannel: 1 angle: 90.     "Servo an Kanal 1 auf 90°"
```

### 5.6 Netzwerkverbindung

```smalltalk
| firmataNet |
firmataNet := FirmataNet new.
firmataNet connectToHost: '192.168.1.100' port: 3030.
firmataNet isFirmataInstalled.
firmataNet digitalWrite: 13 value: 1.
```

### 5.7 Aufräumen

```smalltalk
firmata disconnect.       "stoppt den Poller, schließt den Port"
```

## 6. Neues I2C-Gerät hinzufügen

So integrierst du ein weiteres I2C-Bauteil (die beiden vorhandenen Beispiele sind
`FirmataPCA9685` und `FirmataMPU6050`):

1. **Neues Paket** `Firmata-<Gerät>` anlegen (Quelle: `.pck.st` at package browser
   or `Feature require:`), mit `!requires: 'Firmata-I2C' 1 nil 1!` und einer
   Kategorie `'Firmata-<Gerät>'`.

2. **Device-Klasse** modellieren: Unterklasse von `FirmataI2CDevice`
   (`FirmataI2CDevice subclass: #Firmata<Gerät> ...`) mit den benötigten
   Instanzvariablen. Zusätzlich eine Konstantenklasse
   `Firmata<Gerät>Constants` für Registeradressen, Defaults und Modus-Bits.

3. **Pflichtmethoden implementieren:**
   - `defaultAddress` — die I2C-Slave-Adresse (class side `defaults`).
   - `initializeDevice` — Chip-Konfiguration über Register-Schreibzugriffe
     (`writeRegister:data:`).
   - `handleI2CReply:data:` — eingehende Messwerte interpretieren und in
     Geräte-Instanzvariablen ablegen.
   - `registerWithFirmata` wird nach der Verdrahtung aufgerufen und meldet das
     Gerät über `firmata registerI2CDevice: self` für seine Adresse an.

4. **Öffentliche Schnittstelle** ergänzen, z. B.
   `setPWMOnChannel:value:`, `setServoOnChannel:angle:`,
   `readOnce`, `startReading`, `scaledAccelX` usw.

5. **Konfigurationsoptionen** als Defaults auf der Klassenseite (`defaults`).

6. **Tests schreiben** (Paket `Tests-Firmata-<Gerät>`) — Konventionen dieses
   Projekts:
   - Ein `FirmataNetStreamMock`/Seriell-Mock versorgt den Parser mit exakt den
     Bytes, die der echte Arduino sendet (7-Bit-Paare LSB/MSB, SYSEX).
   - Byte-genaue Assertions: Das gesendete (SYSEX-)Byte­array wird verglichen.
   - `TestCase` verwendet die Kategorie `'testing'` für Testmethoden,
     Helfer gehören nach `'support'`.
   - Suite im Headless-Runner abfahren.

7. **Dokumentation** im `docs/`-Ordner ergänzen (siehe README).

## 7. Hinweise und Stolperfallen für Cuis

- **7-Bit-Paar-Konvention:** Zahlen werden als LSB/MSB-Paar übertragen
  (niederwertiges Byte zuerst). `parseData` speichert Byte 1 in Slot 2 und Byte 2
  in Slot 1 (Index 1 = erstes gelesenes Byte). Beim manuellen Parser nie die
  Reihenfolge vertauschen — ein früherer Fehler las `REPORT_VERSION` dadurch
  falsch herum (Version 2.5 wurde als 5.2 gemeldet).
- **Headless-Tests (`-vm-display-null`):** `FileEntry>>writeStreamDo:` meldet eine
  Nachfrage („Overwrite?"), wenn die Datei bereits existiert und hängt damit den
  Testskriptlauf. Für Ausgaben `forceWriteStreamDo:` verwenden. Außerdem dürfen
  Klassen vor ihrer Installation nicht direkt referenziert werden (Undeclared
  → `UndefinedObject>>new`); in installierenden Skripten `Smalltalk classNamed:`
  verwenden.
- **Geräte-Verzeichnis:** Ein I2C-Gerät ist erst nach `registerWithFirmata`
  ansprechbar; Antworten ohne Registrierung werden verworfen.
- **Fehlerverhalten:** Ein Lesefehler im Poller setzt `port := nil`; alle weiteren
  Aufrufe über den `port`-Accessor werfen dann „Serial port is not connected".
  Vor der erneuten Nutzung `connectOnPort:...` (bzw. `connectToHost:port:`)
  aufrufen.

Teststatus: Alle 15 Suiten headless grün (`passed=221 failures=0 errors=0`,
2026-09-24, Cuis 7.8 #7977).
