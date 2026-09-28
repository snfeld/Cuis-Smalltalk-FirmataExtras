# ADXL345 – Accéléromètre 3 axes

Contenu :
1. Aperçu
2. Données techniques
3. Câblage
4. Classe et API
5. Exemple
6. Notes

---

## 1. Aperçu

L'**ADXL345** (Analog Devices) est un accéléromètre numérique 3 axes avec
une résolution de 13 bits en mode résolution complète. Il mesure
l'accélération statique (gravité) et dynamique (mouvement, vibration) et
fournit les résultats dans des registres consécutifs par axe (`DATAX0` à
`DATAZ1`, 6 octets) sous forme de valeurs 16 bits little-endian.

Le paquet `Firmata-ADXL345` encapsule le capteur derrière une connexion
`FirmataI2C`. Avec `startReadingPort`, l'Arduino transmet les registres de
sortie en continu ; chaque `I2C_REPLY` entrant écrase le dernier échantillon.
Les valeurs brutes et mises à l'échelle sont ensuite directement accessibles.

Le capteur fonctionne avec une sensibilité fixe de 256 LSB/g en mode
résolution complète, quel que soit la plage sélectionnée. La plage ne
détermine que la portée maximale, pas la résolution par g.

## 2. Données techniques

- Accéléromètre 3 axes, 13 bits résolution complète (4 mg/LSB, 256 LSB/g)
  pour toutes les plages.
- Plages sélectionnables : **±2 g** (index 0), **±4 g** (index 1),
  **±8 g** (index 2), **±16 g** (index 3).
- Débits via le registre `BW_RATE` (`0x2C`) : codes 0x00 (0,1 Hz) à
  0x0F (3200 Hz), valeur par défaut 0x0A (100 Hz).
- 6 registres de sortie à partir de `DATAX0` (`0x32`) : X0, X1, Y0, Y1, Z0, Z1
  (little-endian, 16 bits signés).
- Adresse I2C : **0x53** (ALT ADDRESS haut) ou **0x1D** (ALT ADDRESS bas).
- Tension : 2,0–3,6 V. Consommation : 23 µA (mesure), 0,1 µA (veille).
- Registre DEVID (`0x00`) renvoie 0xE5 pour l'identification du dispositif.

## 3. Câblage

| ADXL345 | Arduino Uno |
| --- | --- |
| VCC | 3,3 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| CS | VCC (pour le mode I2C) |
| SDO | GND (pour l'adresse 0x53) |

Les résistances pull-up I2C sont généralement présentes sur les cartes
breakout courantes ; sinon, utiliser 4,7 kΩ sur SDA/SCL vers VCC. Le pin CS
doit être mis à haute logique pour activer le mode I2C. SDO détermine
l'adresse : GND → 0x53, VCC → 0x1D.

## 4. Classe et API

`FirmataADXL345` hérite de `FirmataI2CDevice` (paquet `Firmata-I2C`).

- Initialisation : `initializeDevice` (active le bit measure dans le
  registre `POWER_CTL`), `registerWithFirmata` (après le câblage !).
- Configuration : `setAccelerationRange:` (0–3 ↔ ±2/4/8/16 g),
  `setSampleRate:` (0x00–0x0F pour 0,1 Hz à 3200 Hz).
- Lecture : `startReadingPort` (continu) ou `readOnce` (échantillon unique).
- Sorties brutes : `accelX`/`accelY`/`accelZ` (16 bits little-endian signés).
- Sorties mises à l'échelle : `scaledAccelX`/`scaledAccelY`/`scaledAccelZ`
  (en g) — valeur brute divisée par 256,0 (sensibilité fixe résolution complète).
- Sensibilité et plage : `accelSensitivity` (256 LSB/g, fixe),
  `accelRange` (index de plage actuel), `sampleRate` (code actuel).
- Réception : `handleI2CReply:data:` traite la réponse de 6 octets de l'Arduino.
- Helpers hérités (`FirmataI2CDevice`) : `firmata:address:`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataADXL345Constants` (côté classe) contient les registres
(`dataFormatRegister` 0x31, `bandwidthRateRegister` 0x2C,
`powerControlRegister` 0x2D, `dataX0Register` 0x32, `deviceIdRegister` 0x00),
bits (`fullResolutionBit`, `measureBit`), spécifications
(`accelSensitivity` 256, `deviceIdValue` 0xE5, `sensorOutputByteCount` 6)
et valeurs par défaut (`defaultAddress` 0x53, `defaultAccelRange` 0,
`defaultSampleRate` 0x0A).

## 5. Exemple

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

"Configurer la plage et le débit (optionnel)"
sensor setAccelerationRange: 1.    "±4 g"
sensor setSampleRate: 16r0B.       "200 Hz"

"Démarrer le flux continu"
sensor startReadingPort.

"... après quelques étapes :"
sensor accelZ.                     "valeur Z LE-16-bit brute"
sensor scaledAccelZ.               "accélération Z en g"

"Lire un échantillon unique :"
sensor readOnce.

"Arrêter le flux :"
sensor stopReading.
```

## 6. Notes

- **Les valeurs brutes sont little-endian et signées** (16 bits). Le LSB se
  trouve dans le premier registre (`DATAX0`), le MSB dans le second (`DATAX1`).
  Cela diffère du MPU6050 (big-endian).
- **Mode résolution complète (full_res) :** Toujours actif — la sensibilité
  reste fixe à 256 LSB/g quelle que soit la plage sélectionnée. La plage ne
  détermine que la portée maximale.
- **Mise à l'échelle :** `scaled*` = brut / 256,0. Exemple : `scaledAccelZ
  := accelZ / 256.0`.
- **Changement de plage** (`setAccelerationRange:`) écrit les bits 0–1 du
  registre `DATA_FORMAT`. Le bit résolution complète (bit 3) reste activé.
- **Stabilisation après activation :** Après la mise sous tension ou
  `initializeDevice`, patienter un instant ; le capteur a besoin de
  quelques millisecondes pour se stabiliser.
- **Vérification DEVID :** Le registre `DEVID` (`0x00`) doit renvoyer `0xE5`.
  En cas d'écart, une erreur de communication est présente.
- **Capteurs multiples :** Mettre SDO à VCC pour l'adresse 0x1D et
  enregistrer une seconde instance `FirmataADXL345` sur la même connexion
  `FirmataI2C`.
