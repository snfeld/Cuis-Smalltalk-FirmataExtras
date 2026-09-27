# Firmata pour Cuis-Smalltalk

Sommaire :
1. Qu'est-ce que Firmata ?
2. Prérequis et installation
3. Connexion et traitement en arrière-plan
4. Aperçu de l'API
5. Guide d'utilisation avec exemples
6. Ajouter un nouveau périphérique I2C
7. Notes et pièges spécifiques à Cuis

---

## 1. Qu'est-ce que Firmata ?

Firmata est une méthode ouverte, fondée sur un protocole, pour piloter un
microcontrôleur (par exemple une carte Arduino) depuis un ordinateur hôte. Sur
l'Arduino tourne le micrologiciel **StandardFirmata** ; l'hôte (ici une image
Cuis-Smalltalk) envoie des commandes compactes en octets via une connexion série
(USB) ou un réseau TCP/IP, et l'Arduino répond avec des mesures et des messages
d'état. L'interface reste toujours la même, quel que soit le câblage des broches
ou des périphériques I2C.

Le protocole travaille avec des valeurs de 7 bits : chaque nombre est transmis
sous forme de paire LSB/MSB. Les extensions complexes (comme I2C) utilisent le
mécanisme SYSEX : un message commence par `START_SYSEX` (`0xF0`) et se termine
par `END_SYSEX` (`0xF7`). Ce paquet implémente le standard complet, y compris les
commandes I2C SYSEX.

## 2. Prérequis et installation

**Sur l'Arduino** (IDE Arduino, bibliothèque *Firmata* de la communauté
Smalltalk) :

- `StandardFirmata` pour USB/série.
- `StandardFirmataEthernet` ou `StandardFirmataWiFi` pour le fonctionnement en
  réseau.
- Pour une logique de firmware personnalisée : `ConfigurableFirmata` (tous les
  exemples et tests de ce projet sont ajustés octet par octet à ces croquis).

**Dans Cuis-Smalltalk**, chargez les paquets via le navigateur de paquets ou
avec :

```smalltalk
Feature require: #'Firmata'.            "protocole de base (port série)"
Feature require: #'Firmata-I2C'.        "prise en charge I2C"
Feature require: #'Firmata-PCA9685'.    "driver PWM/servo 16 canaux PCA9685"
Feature require: #'Firmata-MPU6050'.    "IMU MPU6050"
Feature require: #'Firmata-Servo'.      "pilotage de servos de haut niveau (vitesse, plages)"
Feature require: #'Firmata-Net'.        "transport TCP/IP (nécessite Network-Kernel)"
```

Les dépendances se résolvent automatiquement. Pour `Firmata-Net`, le paquet
`Network-Kernel` doit être installé (séquence ci-dessus : d'abord
`Network-Kernel`, puis `Firmata-Net`).

**Câblage de base :** masse commune pour tous les signaux ; pour I2C ajouter en
outre des résistances de tirage (typiquement 4,7 kΩ) de `SDA`/`SCL` vers `VCC` —
la plupart des cartes de dérivation les embarquent déjà.

## 3. Connexion et traitement en arrière-plan

Chaque classe de connexion (`Firmata`, `FirmataI2C`, `FirmataNet`,
`FirmataNetI2C`) contient un `port` (le transport d'octets) et un processus en
arrière-plan qui interroge la connexion en continu :

- `connectOnPort:baudRate:` — connexion série (classes `Firmata`, `FirmataI2C`).
- `connectToHost:port:` — connexion TCP/IP (classes `FirmataNet`,
  `FirmataNetI2C`).
- `startSteppingProcess` — démarre l'interrogateur ; appelé automatiquement à la
  connexion.
- `step` / `stepTime` — une étape d'interrogation, respectivement son intervalle
  en millisecondes. `step` lit tous les octets en attente via `processInput`. Une
  erreur de lecture met `port := nil`, ce qui marque la connexion comme fermée et
  arrête le processus en arrière-plan de lui-même.
- `stopSteppingProcess` — arrête l'interrogateur (appelé par `disconnect`).
- `disconnect` — arrête l'interrogateur, ferme le port, met `port := nil` et
  réinitialise l'état du protocole. Il est sûr de l'appeler plusieurs fois.
- `isConnected` — `^port notNil`.
- `isFirmataInstalled` — envoie des requêtes de version jusqu'à ce qu'une réponse
  arrive (5 secondes maximum).

## 4. Aperçu de l'API

### `Firmata` — protocole de base (paquet `Firmata`)

- Cycle de vie/connexion : `connectOnPort:baudRate:`, `disconnect`,
  `isConnected`, `controlConnection`, `controlFirmataInstallation`.
- Processus en arrière-plan : `startSteppingProcess`, `step`, `stepTime`,
  `stopSteppingProcess`.
- Réception : `processInput`, `parseCommandHeader:`, `parseData:`,
  `parseSysex:`, `parsingSysex`.
- État : `isFirmataInstalled`, `version`, `majorVersion`, `minorVersion`,
  `nameSymbol`, `port`.
- Modes de broche : `pin:mode:` (et `valueForInputMode`, `valueForOutputMode`,
  `valueForPwmMode`, `valueForServoMode`), `digitalPin:mode:`.
- Broches numériques : `digitalWrite:value:`, `digitalRead:`,
  `analogWrite:value:`, `digitalPortReport:onOff:`, `activateDigitalPort:`,
  `deactivateDigitalPort:`, `setDigitalInputs:data:`.
- Broches analogiques : `analogRead:`, `analogPinReport:onOff:`,
  `activateAnalogPin:`, `deactivateAnalogPin:`, `setAnalogInput:value:`.
- Servos : `attachServoToPin:`, `detachServoFromPin:`, `servoOnPin:angle:`,
  `servoConfig:minPulse:maxPulse:angle:`.
- Autres commandes : `queryVersion`, `queryFirmware`, `reportFirmware`,
  `systemReset`, `startSysex`, `endSysex`, `firmataString`,
  `sysexNonRealtime`, `sysexRealtime`.
- Initialisation : `initialize`, `initializeVariables`.

### `FirmataConstants` (paquet `Firmata`)

Méthodes de classe pour les numéros du protocole : `analogMessage`,
`digitalMessage`, `reportAnalog`, `reportDigital`, `reportVersion`,
`setPinMode`, `startSysex`, `endSysex`, `systemReset`, `maxDataBytes`, etc.

### `FirmataI2C` — couche I2C (paquet `Firmata-I2C`)

Étend `Firmata` avec les messages I2C SYSEX :

- `i2cConfig` / `i2cConfigDelay:` — règle le délai entre une requête I2C et
  l'interruption de réponse (par défaut 0 µs).
- `i2cRequestWrite:register:data:` — écrit des données dans un registre de
  l'esclave.
- `i2cRequestRead:register:byteCount:` — lit une fois.
- `i2cRequestReadContinuously:register:byteCount:` — lecture continue (l'Arduino
  envoie automatiquement à chaque changement).
- `i2cStopReading:` — arrête la lecture continue.
- Registre des périphériques : `registerI2CDevice:`, `registeredDeviceFor:`.
- Traitement SYSEX : `parseSysex:`, `dispatchSysexMessageOfLength:`,
  `parseI2CReplyOfLength:`.

### `FirmataI2CDevice` — base abstraite des périphériques (paquet `Firmata-I2C`)

- Câblage : `firmata:address:`, `registerWithFirmata`.
- Opérations I2C : `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.
- Accès : `address`, `address:`, `firmata`, `firmata:`.
- Responsabilité des sous-classes : `initializeDevice` (configurer le
  périphérique sur le bus) et `handleI2CReply:data:` (traiter les réponses).

### `FirmataNet` / `FirmataNetI2C` — TCP/IP (paquet `Firmata-Net`)

- `connectToHost:` / `connectToHost:port:` — connexion à un Arduino
  StandardFirmataEthernet/-WiFi ; `defaultPort` (par défaut 3030).
- `FirmataNetI2C` combine capacités réseau et I2C (pour les classes de
  périphériques I2C en mode réseau).
- `FirmataNetPort` enveloppe un `SocketStream` comme transport d'octets et connaît
  `readByteArray`, `nextPutAll:`, `close`, `isConnected`.
- `FirmataNetConstants` — valeurs par défaut du réseau (port par défaut).

## 5. Guide d'utilisation avec exemples

### 5.1 Connexion série et vérification de version

```smalltalk
| firmata |
firmata := Firmata new.
firmata connectOnPort: '/dev/ttyACM0' baudRate: 57600.
firmata isFirmataInstalled.          "true dès que la poignée de main réussit"
firmata version.                     "par exemple 2.5 (StandardFirmata)"
```

### 5.2 Sorties numériques (LED)

```smalltalk
"Broche 13 en sortie, puis l'allumer"
firmata digitalPin: 13 mode: 1.      "OUTPUT = 1"
firmata digitalWrite: 13 value: 1.
```

> La valeur du mode de broche est un octet du protocole. Les helpers de haut
> niveau `pin:mode:` acceptent le mode numérique du croquis Arduino (`INPUT = 0`,
> `OUTPUT = 1`, `ANALOG = 2`, `PWM = 3`, `SERVO = 4`).

### 5.3 Entrées numériques (bouton) et lectures analogiques

```smalltalk
firmata digitalRead: 2.                  "0 ou 1"
firmata analogRead: 0.                   "valeur sur 10 bits 0..1023"
firmata analogPinReport: 0 onOff: 1.     "active le rapport analogique"
firmata digitalPortReport: 0 onOff: 1.   "active le rapport numérique"
```

### 5.4 Servos

```smalltalk
firmata attachServoToPin: 9.
firmata servoOnPin: 9 angle: 90.
firmata servoOnPin: 9 angle: 45.
firmata detachServoFromPin: 9.
```

Pour un pilotage de haut niveau avec vitesse, plages de montage et servos
180°/270° (broche ou PCA9685), utilisez le paquet `Firmata-Servo`, voir
[Servo-Documentation-fr.md](Servo-Documentation-fr.md).

### 5.5 Utilisation d'un périphérique I2C (exemple PCA9685)

```smalltalk
| firmata pwm |
firmata := FirmataI2C new.
firmata connectOnPort: '/dev/ttyACM0' baudRate: 57600.
firmata isFirmataInstalled.
firmata i2cConfig.
pwm := FirmataPCA9685 new firmata: firmata address: 0x40.
pwm registerWithFirmata.                "enregistre le périphérique sur le bus"
pwm initializeDevice.                   "modes, auto-incrément et 50 Hz"
pwm setPWMOnChannel: 0 value: 128.      "rapport cyclique 128/4096"
pwm setServoOnChannel: 1 angle: 90.     "servo sur le canal 1 à 90 °"
```

### 5.6 Connexion réseau

```smalltalk
| firmataNet |
firmataNet := FirmataNet new.
firmataNet connectToHost: '192.168.1.100' port: 3030.
firmataNet isFirmataInstalled.
firmataNet digitalWrite: 13 value: 1.
```

### 5.7 Nettoyage

```smalltalk
firmata disconnect.       "arrête l'interrogateur et ferme le port"
```

## 6. Ajouter un nouveau périphérique I2C

Voici comment intégrer un autre composant I2C (les deux exemples existants sont
`FirmataPCA9685` et `FirmataMPU6050`) :

1. **Créez un nouveau paquet** `Firmata-<Périphérique>` (source : `.pck.st`,
   chargée avec `Feature require:`), avec `!requires: 'Firmata-I2C' 1 nil 1!` et
   une catégorie `'Firmata-<Périphérique>'`.

2. **Modélisez la classe du périphérique :** sous-classe de `FirmataI2CDevice`
   (`FirmataI2CDevice subclass: #Firmata<Périphérique> ...`) avec les variables
   d'instance nécessaires, plus une classe de constantes
   `Firmata<Périphérique>Constants` pour les adresses de registres, les valeurs
   par défaut et les bits de mode.

3. **Implémentez les méthodes obligatoires :**
   - `defaultAddress` — l'adresse esclave I2C (côté classe `defaults`).
   - `initializeDevice` — configuration du circuit via des écritures de registres
     (`writeRegister:data:`).
   - `handleI2CReply:data:` — interpréter les mesures entrantes et les stocker
     dans les variables d'instance du périphérique.
   - `registerWithFirmata` est appelé après le câblage et enregistre le
     périphérique pour son adresse via `firmata registerI2CDevice: self`.

4. **Ajoutez l'interface publique**, par exemple `setPWMOnChannel:value:`,
   `setServoOnChannel:angle:`, `readOnce`, `startReading`, `scaledAccelX`, etc.

5. **Options de configuration comme valeurs par défaut de classe** (`defaults`).

6. **Écrivez les tests** (paquet `Tests-Firmata-<Périphérique>`) — conventions de
   ce projet :
   - Un `FirmataNetStreamMock`/mock série alimente l'analyseur avec exactement les
     octets qu'envoie un vrai Arduino (paires de 7 bits LSB/MSB, SYSEX).
   - Assertions octet pour octet : le tableau d'octets (SYSEX) émis est comparé.
   - `TestCase` utilise la catégorie `'testing'` pour les méthodes de test ; les
     helpers vont dans `'support'`.
   - Lancer la suite dans l'exécuteur sans affichage (headless).

7. **Complétez la documentation** dans le dossier `docs/` (voir le README).

## 7. Notes et pièges spécifiques à Cuis

- **Convention des paires de 7 bits :** les nombres voyagent comme des paires
  LSB/MSB (octet faible d'abord). `parseData` range l'octet 1 dans l'emplacement 2
  et l'octet 2 dans l'emplacement 1 (indice 1 = premier octet lu). Ne permutez
  jamais l'ordre en analysant manuellement — un ancien bug lisait `REPORT_VERSION`
  à l'envers (la version 2.5 était renvoyée 5.2).
- **Tests sans affichage (`-vm-display-null`):** `FileEntry>>writeStreamDo:`
  demande (« Overwrite ? ») quand le fichier existe déjà et bloque ainsi
  l'exécution. Utilisez `forceWriteStreamDo:` pour les sorties. En outre, les
  classes ne doivent pas être référencées avant leur installation (Undeclared →
  `UndefinedObject>>new`) ; dans les scripts qui installent, utilisez
  `Smalltalk classNamed:`.
- **Registre des périphériques :** un périphérique I2C n'est adressable qu'après
  `registerWithFirmata` ; les réponses non enregistrées sont ignorées.
- **Comportement en cas d'erreur :** une erreur de lecture dans l'interrogateur
  met `port := nil` ; tout appel ultérieur via l'accesseur `port` lèvera alors
  « Serial port is not connected ». Rappelez `connectOnPort:...` (ou
  `connectToHost:port:`) avant toute réutilisation.

État des tests : les 15 suites sont vertes sans affichage (`passed=221 failures=0
errors=0`, 2026-09-24, Cuis 7.8 #7977).
