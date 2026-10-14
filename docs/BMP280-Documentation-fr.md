# BMP280 – Capteur barométrique de pression et de température

Sommaire :
1. Vue d'ensemble
2. Caractéristiques
3. Câblage
4. Classe et API
5. Exemple
6. Remarques

---

## 1. Vue d'ensemble

Le **BMP280** (Bosch Sensortec) est un capteur barométrique de pression et
de température. Il mesure la pression absolue dans la plage 300–1100 hPa et
fournit le résultat dans trois registres de sortie 20 bits big-endian à
partir de `0xF7` (pression MSB, LSB, XLSB), suivis des trois registres de
température à partir de `0xFA`. Les compteurs bruts 20 bits sont compensés
avec les coefficients d'étalonnage d'usine stockés dans un bloc de 24 octets
à l'adresse `0x88`.

Le paquet `Firmata-BMP280` encapsule le capteur derrière une connexion
`FirmataI2C`. `initializeDevice` écrit une fois la configuration et le
registre de contrôle de mesure (surs-échantillonnage x1, mode normal), puis
lit le bloc d'étalonnage. Avec `startReadingPort`, l'Arduino diffuse en
continu les six octets de sortie ; chaque `I2C_REPLY` entrante écrase le
dernier échantillon. Les valeurs mises à l'échelle sont alors accessibles
directement.

La compensation suit les formules entières du pilote de référence Bosch
(division entière C, bornée à la plage du capteur), de sorte que les
résultats correspondent exactement aux calculs de la fiche technique.

## 2. Caractéristiques

- Capteur combiné de pression barométrique et de température.
- Plage de pression : 300–1100 hPa ; sortie jusqu'à 20 bits, big-endian
  (MSB en premier).
- Précision absolue de température : ±1,0 °C ; résolution 0,01 °C.
- Résolution de pression : 0,01 hPa (unité de sortie) ; bruit RMS typique
  bien inférieur à 1 hPa.
- Adresse I2C : **0x76** (SDO au niveau bas) ou **0x77** (SDO au niveau
  haut).
- Tension d'alimentation : 1,71–3,6 V.
- Le registre d'identifiant (`0xD0`) renvoie **0x58**.
- 24 octets d'étalonnage à `0x88` (dig_T1..T3, dig_P1..P9).

## 3. Câblage

| BMP280 | Arduino Uno |
| --- | --- |
| VCC | 3,3 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| SDO | GND (pour l'adresse 0x76) |

Les résistances de tirage I2C sont généralement présentes sur les modules
courants ; sinon, 4,7 kΩ sur SDA/SCL vers VCC. SDO détermine l'adresse :
GND → 0x76, VCC → 0x77.

## 4. Classe et API

`FirmataBMP280` hérite de `FirmataI2CDevice` (paquet `Firmata-I2C`).

- Initialisation : `initializeDevice` (écrit `config` 0x00 et `ctrl_meas`
  0x27, puis lit les 24 octets d'étalonnage), `registerWithFirmata` (après
  le câblage !), `readChipId` optionnel.
- Lecture : `startReadingPort` (continu) ou `readOnce` (un échantillon des
  six octets de sortie à `0xF7`).
- Sorties brutes : `rawPressure`/`rawTemperature` (compteurs entiers 20 bits
  big-endian), `chipId` (après `readChipId`).
- Sorties compensées :
  - `compensatedTemperature` — 0,01 °C en entier, borné à [-4000, 8500]
    (−40,00 °C à 85,00 °C).
  - `temperatureCelsius` — degrés Celsius en Float.
  - `compensatedPressure` — pression en Pascal en entier, bornée à
    [30000, 110000].
  - `pressurePascal` — identique à `compensatedPressure`.
  - `pressureHectoPascal` — pression en hPa en Float.
- Étalonnage : `calibrationData` (24 octets), `isCalibrationLoaded`.
- Interne : `tFine` (température fine partagée par les deux formules).
- Réception : `handleI2CReply:data:` répartit les réponses d'identifiant,
  d'étalonnage et de sortie.
- Aides héritées (`FirmataI2CDevice`) : `firmata:address:`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataBMP280Constants` (côté classe) contient les registres
(`calibrationRegister` 0x88, `chipIdRegister` 0xD0, `configRegister` 0xF5,
`ctrlMeasRegister` 0xF4, `dataRegister` 0xF7, `resetRegister` 0xE0,
`statusRegister` 0xF3), la configuration (`configValue` 0x00,
`ctrlMeasValue` 0x27), la spécification (`chipIdValue` 0x58,
`calibrationByteCount` 24, `sensorOutputByteCount` 6) et la valeur par défaut
(`defaultAddress` 0x76).

## 5. Exemple

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

"Facultatif : identification du circuit"
sensor readChipId.
sensor chipId.                          "16r58"

"Démarrage du flux continu"
sensor startReadingPort.

"... après quelques pas :"
sensor temperatureCelsius.              "température en C"
sensor pressureHectoPascal.             "pression en hPa"

"Lecture d'un échantillon unique :"
sensor readOnce.

"Arrêt du flux :"
sensor stopReading.
```

## 6. Remarques

- **Les valeurs 20 bits sont big-endian :** pression = MSB, LSB, XLSB, MSB en
  premier ; le nibble bas de l'octet XLSB est toujours nul. L'entier brut est
  `((MSB << 16) + (LSB << 8) + XLSB) >> 4`.
- **Ordre de sortie :** les six octets de sortie à `0xF7` sont pression MSB,
  LSB, XLSB, puis température MSB, LSB, XLSB. `rawPressure` et
  `rawTemperature` les déballent en conséquence (indices 1 et 4).
- **La compensation est une arithmétique entière** conforme au pilote de
  référence Bosch : division tronquée vers zéro (`quo:`), même `t_fine` pour
  les formules de température et de pression, plus bornage à la plage du
  capteur.
- **nil avant étalonnage :** `temperatureCelsius`, `compensatedPressure` et
  `tFine` répondent nil tant que le bloc d'étalonnage n'est pas arrivé. Après
  un reset, rappelez `initializeDevice` ou attendez la réponse suivante.
- **Vérification de l'identifiant :** `readChipId` + `chipId` doit répondre
  `0x58`. Sinon, il y a une erreur de communication.
- **Registre `0xF7` vs. fin Sysex Firmata** `0xF7` : dans les tests, les deux
  apparaissent dans les tableaux d'octets ; ils sont indépendants. Le registre
  de sortie `0xF7` est simplement l'adresse d'un registre de la puce sur le
  bus I2C.
- **Plusieurs capteurs :** mettez SDO à VCC pour l'adresse 0x77 et
  enregistrez une seconde instance `FirmataBMP280` sur la même connexion
  `FirmataI2C`.
