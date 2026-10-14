# BME280 – Capteur d'humidité, de pression et de température

Sommaire :
1. Vue d'ensemble
2. Caractéristiques
3. Câblage
4. Classe et API
5. Exemple
6. Remarques

---

## 1. Vue d'ensemble

Le **BME280** (Bosch Sensortec) est un capteur combiné d'humidité relative,
de pression barométrique et de température. Il fournit la même sortie de
pression et de température que le BMP280 (registres 20 bits big-endian à
`0xF7` et `0xFA`), plus une sortie d'humidité relative 16 bits à `0xFD`. Les
données sont compensées avec deux blocs d'étalonnage : le bloc de 26 octets
température/pression à `0x88` (l'octet 26, soit `0xA1`, est le coefficient
d'humidité non signé `dig_H1`) et le bloc de 7 octets à `0xE1`.

Le paquet `Firmata-BME280` étend `Firmata-BMP280` derrière une connexion
`FirmataI2C`. `initializeDevice` écrit `CTRL_HUM` (`0xF2`) *avant*
`CTRL_MEAS` (exigence de la puce), puis la configuration et le registre de
contrôle de mesure, et lit enfin les deux blocs d'étalonnage.
`startReadingPort` demande à l'Arduino de diffuser en continu les six octets
de pression/température à `0xF7` et les deux octets d'humidité à `0xFD` ;
chaque `I2C_REPLY` entrante écrase le dernier échantillon.

Les six coefficients ( `dig_H1`..`dig_H6`) sont extraits du bloc 0xE1
empaqueté en nibbles, et l'humidité est compensée avec les formules entières
du pilote de référence Bosch (division tronquée, bornée à la plage du
capteur). La compensation de température et de pression est héritée de
`FirmataBMP280`.

## 2. Caractéristiques

- Capteur combiné d'humidité relative, de pression barométrique et de
  température.
- Plage d'humidité : 0–100 % HR ; résolution 0,008 % HR (sortie en Q10, donc
  102400 = 100 %).
- Plage de pression : 300–1100 hPa ; résolution de température 0,01 °C.
- Adresse I2C : **0x76** (SDO au niveau bas) ou **0x77** (SDO au niveau
  haut).
- Tension d'alimentation : 1,71–3,6 V.
- Le registre d'identifiant (`0xD0`) renvoie **0x60** (contrairement au
  BMP280 : 0x58).
- Étalonnage : 26 octets à `0x88` (dig_T1..T3, dig_P1..P9, dig_H1) et 7
  octets à `0xE1` (dig_H2..dig_H6 en forme empaquetée en nibbles).

## 3. Câblage

| BME280 | Arduino Uno |
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

`FirmataBME280` hérite de `FirmataBMP280` (paquet `Firmata-BMP280`).

- Initialisation : `initializeDevice` (écrit d'abord `CTRL_HUM` 0x01, puis
  `config` 0x00 et `ctrl_meas` 0x27, puis lit les 26 octets d'étalonnage à
  `0x88` et les 7 octets d'étalonnage d'humidité à `0xE1`),
  `registerWithFirmata` (après le câblage !), `readChipId` optionnel.
- Lecture : `startReadingPort` (flux continu de `0xF7` et `0xFD`) ou
  `readOnce` (un échantillon des deux).
- Sorties brutes : `rawPressure`/`rawTemperature` (20 bits), `rawHumidity`
  (16 bits big-endian), `chipId`.
- Sorties compensées :
  - `temperatureCelsius`, `compensatedTemperature`, `pressureHectoPascal`,
    `pressurePascal`, `compensatedPressure` — hérités de `FirmataBMP280`.
  - `compensatedHumidity` — humidité relative en entier Q10, bornée à
    [0, 102400] (102400 = 100 %).
  - `humidityPercent` — humidité relative en pour cent en Float
    (`compensatedHumidity / 1024.0`).
- Étalonnage : `calibrationData` (26 octets), `humidityCalibration`
  (7 octets), `isCalibrationLoaded`, `isHumidityCalibrationLoaded`, et les
  coefficients `digH1`..`digH6` (accessibles pour les tests).
- Réception : `handleI2CReply:data:` répartit les réponses d'étalonnage et de
  sortie d'humidité avant de déléguer à `FirmataBMP280`.
- Aides héritées (`FirmataI2CDevice`) : `firmata:address:`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataBME280Constants` étend `FirmataBMP280Constants` et ajoute
(`ctrlHumRegister` 0xF2, `humidityCalibrationRegister` 0xE1,
`humidityDataRegister` 0xFD), la spécification (`calibrationByteCount` 26,
`humidityCalibrationByteCount` 7, `humidityOutputByteCount` 2,
`chipIdValue` 0x60) et la valeur par défaut (`defaultAddress` 0x76).

## 5. Exemple

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

"Facultatif : identification du circuit"
sensor readChipId.
sensor chipId.                          "16r60"

"Démarrage du flux continu"
sensor startReadingPort.

"... après quelques pas :"
sensor temperatureCelsius.              "température en C"
sensor pressureHectoPascal.             "pression en hPa"
sensor humidityPercent.                 "humidité relative en %"

"Lecture d'un échantillon unique :"
sensor readOnce.

"Arrêt du flux :"
sensor stopReading.
```

## 6. Remarques

- **`CTRL_HUM` avant `CTRL_MEAS` :** le BME280 ne prend le sur-échantillonnage
  d'humidité de `CTRL_HUM` (`0xF2`) que si ce registre est écrit avant le
  registre de contrôle de mesure. `initializeDevice` le fait dans le bon
  ordre.
- **26 octets d'étalonnage :** le BME280 a besoin des 26 octets du bloc 0x88 ;
  l'octet 26 (registre `0xA1`) contient `dig_H1` non signé. Le BMP280 n'a
  besoin que des 24 premiers.
- **Disposition de l'étalonnage d'humidité (`0xE1`..`0xE7`) :** `dig_H2` est
  une valeur signée 16 bits little-endian à `0xE1`, `dig_H3` non signée à
  `0xE3`, `dig_H4` et `dig_H5` sont réparties entre octets MSB signés
  (`0xE4`/`0xE6`) et un nibble de l'octet `0xE5` (`dig_H4` utilise le nibble
  bas, `dig_H5` le nibble haut), et `dig_H6` est l'octet signé à `0xE7`. Les
  coefficients `digH1`..`digH6` sont extraits en conséquence.
- **La sortie d'humidité est 16 bits big-endian** à `0xFD` (MSB d'abord).
- **La compensation est une arithmétique entière** conforme au pilote de
  référence Bosch : division tronquée vers zéro (`quo:`), même `t_fine` pour
  les formules de température, de pression et d'humidité, plus bornage à la
  plage du capteur.
- **nil avant étalonnage :** les valeurs compensées répondent nil jusqu'à la
  réception des deux blocs d'étalonnage.
- **Vérification de l'identifiant :** `readChipId` + `chipId` doit répondre
  `0x60`. Sinon, il y a une erreur de communication.
- **Plusieurs capteurs :** mettez SDO à VCC pour l'adresse 0x77 et
  enregistrez une seconde instance `FirmataBME280` sur la même connexion
  `FirmataI2C`.
