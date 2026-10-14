# PCF8574 – Expander E/S 8 bits

Sommaire :
1. Aperçu
2. Données techniques
3. Câblage
4. Classe et API
5. Exemple
6. Notes

---

## 1. Aperçu

Le **PCF8574** (NXP/Texas Instruments) est un expandeur d'E/S 8 bits
quasi-bidirectionnel communiquant par I2C. Contrairement aux capteurs basés
sur des registres, il n'y a **pas d'adressage de registre** — une seule
opération d'écriture ou de lecture d'un octet contrôle tout le port (8 broches).

Chaque broche est quasi-bidirectionnelle : écrire `1` configure la broche
comme entrée avec pull-up interne faible ; écrire `0` active la broche comme
sortie en niveau bas. Pour lire des entrées, il faut d'abord configurer
toutes les broches à `1` avant de lire le port.

Le package `Firmata-PCF8574` encapsule l'expander derrière une connexion
`FirmataI2C`. La méthode `readPort` utilise un format de lecture I2C sans
registre (StandardFirmata ≥ 2.5) pour éviter de corrompre l'état du port.

## 2. Données techniques

- Broches E/S quasi-bidirectionnelles 8 bits : pas d'adressage de registre,
  un seul octet contrôle tout le port.
- Tension de fonctionnement : **2,6 V – 6 V**.
- Consommation : **100 µA** max.
- Courant de drain : **25 mA par broche**.
- Plage d'adresse I2C : **0x20 – 0x27** (3 broches d'adresse A0–A2 ;
  toutes à l'état bas = 0x20).
- Valeur par défaut à l'allumage : toutes les broches à l'état haut (mode
  entrée).
- Sortie INT : open-drain, actif à l'état bas (non utilisé dans ce package).

## 3. Câblage

| PCF8574 | Arduino Uno |
| --- | --- |
| VCC | 5 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| A0 | GND (adresse 0x20) |
| A1 | GND (adresse 0x20) |
| A2 | GND (adresse 0x20) |
| P0–P7 | Broches E/S |

Pour un deuxième expandeur sur le même bus I2C, connecter A0 à VCC (adresse
0x21). Utiliser des pull-ups de 4,7 kΩ sur SDA/SCL vers VCC s'ils ne sont
pas présents sur la carte breakout.

## 4. Classe et API

`FirmataPCF8574` hérite de `FirmataI2CDevice` (package `Firmata-I2C`).

- Initialisation : `initializeDevice` (configure les paramètres I2C),
  `registerWithFirmata` (après le câblage !).
- Écriture : `writePort:` (envoie un octet 8 bits à tout le port),
  `digitalWritePin:value:` (définit une broche individuelle ; lit l'état
  actuel du port et modifie uniquement le bit concerné).
- Lecture : `readPort` (lecture I2C sans registre ; résultat dans
  `inputValue`), `digitalReadPin:` (retourne `true`/`false` pour la broche
  spécifiée).
- Streaming : `startReadingPort` (démarre le polling continu via l'étape
  Firmata), `stopReading` (arrête le flux).
- Callback : `handleI2CReply:data:` (traite les données entrantes
  `I2C_REPLY` et met à jour `inputValue`/`outputValue`).

`FirmataPCF8574Constants` (côté classe) contient `portRegister` (0),
`pinCount` (8), `defaultAddress` (0x20), `allPinsHigh` (0xFF).

## 5. Exemple

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

"Configurer toutes les broches comme entrées"
expander writePort: 16rFF.

"Broches 0–3 comme sorties (bas), broches 4–7 comme entrées"
expander writePort: 16r0F.

"Définir une broche individuelle"
expander digitalWritePin: 0 value: true.

"Lire le port"
expander readPort.
expander inputValue.               "dernier octet de port lu"

"Lire une broche individuelle"
expander digitalReadPin: 4.         "true si la broche 4 est à l'état haut"

"Démarrer / arrêter le polling continu"
expander startReadingPort.
expander stopReading.
```

## 6. Notes

- **Broches quasi-bidirectionnelles :** Écrire `1` configure une broche
  comme entrée avec pull-up interne faible. Écrire `0` active la broche
  comme sortie en niveau bas. Il n'y a pas de registres de direction ou de
  configuration comme avec d'autres expandeurs E/S.
- **Lecture des entrées :** Avant de lire, toutes les broches doivent être
  réglées à `1` (`writePort: 16rFF`), sinon les broches maintiendront le
  niveau bas de la dernière valeur de sortie et un signal d'entrée correct
  sera impossible.
- **Lecture sans registre :** La méthode `readPort` utilise un format de
  lecture I2C sans registre (StandardFirmata ≥ 2.5, argc ≠ 6). Cela empêche
  un octet de registre envoyé par accident de corrompre l'état du port.
- **Appareils multiples :** Jusqu'à 8 PCF8574 sur le même bus I2C via
  différentes adresses (A0–A2). Enregistrer une instance séparée de
  `FirmataPCF8574` pour chaque appareil.
- **Pas de map de registres interne :** Il n'y a pas de map de registres
  comme avec les appareils I2C basés sur des registres. Chaque opération
  d'écriture/lecture agit directement sur les 8 broches E/S.
- **Alimentation :** Le PCF8574 consomme max. 100 µA ; pour des charges
  plus élevées (jusqu'à 25 mA de drain) utiliser des étages de pilotage
  externes.
