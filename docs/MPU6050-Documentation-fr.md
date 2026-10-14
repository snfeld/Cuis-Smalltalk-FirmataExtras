# MPU6050 — centrale inertielle à 6 axes

Sommaire :
1. Aperçu
2. Caractéristiques techniques
3. Câblage
4. Classes et API
5. Exemple
6. Remarques

---

## 1. Aperçu

Le **MPU6050** (InvenSense) est un capteur de mouvement à 6 axes : un
accéléromètre 3 axes, un gyroscope 3 axes et un capteur de température. Toutes
les mesures se trouvent dans 14 registres consécutifs à partir de `ACCEL_XOUT_H`
(`0x3B`), lus par une seule lecture I2C continue.

Le paquet `Firmata-MPU6050` encapsule le capteur derrière une connexion
`FirmataI2C`. Avec `startReading`, l'Arduino diffuse en continu les registres de
sortie ; chaque `I2C_REPLY` entrante écrase le dernier échantillon. Les valeurs
brutes et normalisées (g et degrés par seconde) sont ensuite directement
disponibles.

En résumé : `accelX` = compte brut ±32767, `scaledAccelX` = accélération en g,
`scaledGyroX` = vitesse de rotation en degrés par seconde.

## 2. Caractéristiques techniques

- Accéléromètre : 3 axes, 16 bits, pleine échelle sélectionnable
  **±2 g / ±4 g / ±8 g / ±16 g** (sensibilité 16384/8192/4096/2048 LSB/g).
- Gyroscope : 3 axes, 16 bits, pleine échelle sélectionnable
  **±250 / ±500 / ±1000 / ±2000 °/s** (sensibilité 131/65,5/32,8/16,4
  LSB/(°/s)).
- Température : 16 bits, facteur 340 LSB/°C, offset 36,53 °C.
- 14 registres de sortie consécutifs à partir de 0x3B (accéléro, température et
  gyro bruts, big-endian, signés sur 16 bits).
- Adresse esclave I2C : **0x68** avec la broche AD0 à la masse (sinon 0x69) ;
  `whoAmI` répond 0x68.
- Horloge interne de 8 MHz ; le capteur démarre en mode veille
  (`initializeDevice` le réveille).

## 3. Câblage

| MPU6050 | Arduino |
| --- | --- |
| VCC | 3,3 V (les cartes à décalage de niveau souvent 5 V aussi) |
| GND | GND |
| SDA | A4 (Uno) / 20 (Mega) |
| SCL | A5 (Uno) / 21 (Mega) |
| AD0 | masse pour l'adresse 0x68, VCC pour 0x69 |
| INT (facultatif) | laisser libre (le sondage se fait dans l'étape Firmata) |

Les résistances de tirage I2C sont présentes sur les cartes de dérivation
courantes ; sinon 4,7 kΩ sur SDA/SCL vers VCC.

## 4. Classes et API

`FirmataMPU6050` hérite de `FirmataI2CDevice` (paquet `Firmata-I2C`).

- Initialisation : `initialize`, `initializeDevice` (active le capteur en
  effaçant le bit de veille), `registerWithFirmata` (après le câblage !).
- Configuration du capteur : `setAccelerationRange:` (0–3 ↔ ±2/4/8/16 g),
  `setGyroRange:` (0–3 ↔ ±250/500/1000/2000 °/s).
- Lecture : `startReading` (continue) ou `readOnce` (un seul échantillon).
  Arrêter avec `stopReading`.
- Sorties brutes : `accelX`/`accelY`/`accelZ`, `gyroX`/`gyroY`/`gyroZ`,
  `temperature` (en °C).
- Sorties normalisées : `scaledAccelX`/`scaledAccelY`/`scaledAccelZ` (en g),
  `scaledGyroX`/`scaledGyroY`/`scaledGyroZ` (en °/s) — selon l'échelle
  configurée.
- Sensibilités : `accelSensitivity` (LSB/g), `gyroSensitivity`
  (LSB/(°/s)) ; divisées par deux à chaque pas d'échelle.
- Index d'échelle : `accelRange`, `gyroRange`.
- Helpers hérités (`FirmataI2CDevice`) : `firmata:address:`,
  `registerWithFirmata`, `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataMPU6050Constants` (côté classe) contient les registres
(`accelXHighRegister` 0x3B, `gyroXHighRegister` 0x43,
`temperatureHighRegister` 0x41, `accelConfigRegister` 0x1C,
`gyroConfigRegister` 0x1B, `configRegister` 0x1A, `smplrtDivRegister` 0x19,
`powerManagement1Register` 0x6B, `powerManagement2Register` 0x6C,
`whoAmIRegister` 0x75), les bits d'alimentation (`awakeValue` 0,
`deviceResetBit`, `sleepBit`, `temperatureDisableBit`), la spécification
(`accelSensitivity` 16384, `gyroSensitivity` 131,0, `sensorOutputByteCount` 14,
`temperatureScaleFactor` 340,0, `temperatureOffset` 36,53) et les valeurs par
défaut (`defaultAddress` 0x68, `defaultAccelRange` 0, `defaultGyroRange` 0).

## 5. Exemple

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

"Choisir des échelles plus sensibles (facultatif)"
sensor setAccelerationRange: 1.    "+/-4 g"
sensor setGyroRange: 1.            "+/-500 °/s"

"Démarrer la diffusion continue"
sensor startReading.

"... après quelques étapes :"
sensor accelZ.                     "compte brut Z sur 16 bits"
sensor scaledAccelZ.               "accélération Z en g"
sensor scaledGyroX.                "vitesse de rotation X en °/s"
sensor temperature.                "température en °C"

"Sinon un seul échantillon :"
sensor readOnce.

"Arrêter la diffusion :"
sensor stopReading.
```

## 6. Remarques

- **Les valeurs brutes sont big-endian et signées** (16 bits). Un échantillon
  n'est disponible qu'après une `I2C_REPLY` ; les accesseurs sont initialement
  `nil` jusqu'à la première réponse traitée.
- **Normalisation :** `scaled*` = brut / sensibilité de l'échelle configurée.
  Exemple : `scaledAccelX := accelX / 16384.0` à ±2 g.
- **Changement d'échelle** (`setAccelerationRange:`/`setGyroRange:`) écrit le
  registre de configuration ; indices valides 0–3, sinon `error:`.
- **Formule de température :** `brut/340,0 + 36,53` en °C.
- **Stabilisation :** laissez le capteur se stabiliser brièvement après le
  réveil ; à la première mise en service, lisez `whoAmI` (0x68) comme contrôle de
  cohérence.
- **Plusieurs capteurs :** mettez AD0 à 0x69 et enregistrez une seconde instance
  `FirmataMPU6050` sur la même connexion `FirmataI2C`.
