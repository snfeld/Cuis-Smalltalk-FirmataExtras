# MCP23017 – Expandeur d'E/S 16 bits

Sommaire :
1. Aperçu
2. Données techniques
3. Câblage
4. Classe et API
5. Exemple
6. Remarques

---

## 1. Aperçu

Le **MCP23017** (Microchip) est un expandeur d'E/S 16 bits sur bus I2C avec
deux ports de 8 bits, GPIOA (broches 0–7) et GPIOB (broches 8–15). Chaque
broche est configurée individuellement en entrée ou en sortie grâce aux
registres de direction IODIR, reçoit un pull-up interne optionnel via GPPU et
est écrite ou lue par les registres de verrouillage GPIO.

Le paquet `Firmata-MCP23017` enveloppe l'expandeur derrière une connexion
`FirmataI2C`. Les réglages de direction, de pull-up et de sortie sont
conservés dans des octets d'ombre côté Smalltalk : les opérations par broche
ne modifient que le bit concerné, puis réécrivent l'octet de port entier au
circuit. Les lectures passent par le format de lecture I2C basé registre,
que StandardFirmata sert sans toucher à l'état du port.

## 2. Données techniques

- 16 broches d'E/S sur deux ports de 8 bits : GPIOA (broches 0–7) et GPIOB
  (broches 8–15).
- Direction via IODIRA/IODIRB : un bit à `0` sélectionne la sortie, un bit à
  `1` sélectionne l'entrée.
- Pull-ups internes (≈100 kΩ) par broche via GPPUA/GPPUB.
- Tension de fonctionnement : **1,8 V – 5,5 V**.
- Courant sink/source : **25 mA par broche**.
- Plage d'adresses I2C : **0x20 – 0x27** (3 broches d'adresse A0–A2 ; tout à
  la masse = 0x20).
- Défaut à la mise sous tension : toutes les broches en entrée, pull-ups
  désactivés, verrous de sortie lus à `1`.
- Sortie INT : drain ouvert, active au niveau bas (non utilisée dans ce
  paquet).

## 3. Câblage

| MCP23017 | Arduino Uno |
| --- | --- |
| VCC | 5 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| A0 | GND (adresse 0x20) |
| A1 | GND (adresse 0x20) |
| A2 | GND (adresse 0x20) |
| GPA0–GPA7 | broches GPIOA |
| GPB0–GPB7 | broches GPIOB |

Pour un second expandeur sur le même bus, réglez les broches d'adresse en
conséquence, p. ex. A0 → VCC pour 0x21. Utilisez des résistances pull-up de
4,7 kΩ sur SDA/SCL vers VCC si le module ne les possède pas.

## 4. Classe et API

`FirmataMCP23017` étend `FirmataI2CDevice` (paquet `Firmata-I2C`).

- Initialisation : `initializeDevice` (écrit IODIRA/B = 0xFF et GPPUA/B =
  0x00), `registerWithFirmata` (après câblage !), `addressWithAddressPins:`.
- Opérations broches : `setPinMode:value:` (broche 0–15 ; `true` = sortie),
  `digitalWritePin:value:` (broche de sortie), `digitalReadPin:` (broche
  d'entrée), `setPullUpPin:value:` (pull-up interne on/off).
- Opérations port : `writePort:value:` (8 broches GPIOA ou GPIOB d'un coup),
  `readPort:` (0 = GPIOA, 1 = GPIOB), `startReadingPort:` (interrogation
  continue), `stopReading` (arrête le flux).
- Callback : `handleI2CReply:data:` (traite les données `I2C_REPLY` entrantes
  et met à jour les valeurs d'entrée du port).
- Accès : `inputValueForPort:`, `outputValueForPort:`, `directionA`,
  `directionB`.

`FirmataMCP23017Constants` (côté classe) contient la carte des registres
(`iodirARegister` 0x00, `iodirBRegister` 0x01, `gppuARegister` 0x0C,
`gppuBRegister` 0x0D, `gpioARegister` 0x12, `gpioBRegister` 0x13) et la
spécification (`pinCount` 16, `portPinCount` 8, `portCount` 2,
`baseAddress`/`defaultAddress` 0x20, `addressCount` 8).

## 5. Exemple

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

"Broche 0 de GPIOA en sortie, maintenue basse"
expander setPinMode: 0 value: true.
expander digitalWritePin: 0 value: false.

"Broche 8 (entrée GPIOB) avec pull-up interne"
expander setPinMode: 8 value: false.
expander setPullUpPin: 8 value: true.

"Écriture des huit broches GPIOA d'un coup"
expander writePort: 0 value: 16r55.

"Lecture de GPIOA et d'une broche"
expander readPort: 0.
expander inputValueForPort: 0.      "dernier octet GPIOA lu"
expander digitalReadPin: 1.         "true si la broche 1 est haute"

"Flux continu de GPIOB"
expander startReadingPort: 1.
expander stopReading.
```

## 6. Remarques

- **Signification des bits de direction :** dans les registres IODIR, un bit
  à `0` signifie sortie et un bit à `1` signifie entrée. `setPinMode:value:`
  le masque : passez `true` pour une sortie et `false` pour une entrée.
- **Octets d'ombre :** `directionA/B` et les verrous de sortie sont
  conservés en octets dans l'image. `setPinMode:`, `digitalWritePin:` et
  `setPullUpPin:` ne modifient que le bit concerné puis réécrivent l'octet de
  port entier, si bien que les configurations mixtes restent cohérentes sans
  relire le circuit.
- **Numérotation des broches :** les broches 0–7 sont dans GPIOA, les
  broches 8–15 dans GPIOB. Les aides privées `portForPin:` et `bitForPin:`
  associent un index de broche à son port et à son bit.
- **Lecture GPIO :** `readPort:` lit le registre GPIOA/GPIOB via le format
  de lecture I2C basé registre (StandardFirmata ≥ 2.5), qui ne modifie pas
  l'état du port. Pour les entrées, la valeur reflète le niveau de la
  broche ; pour les sorties, la valeur du verrou piloté.
- **Plusieurs circuits :** jusqu'à 8 MCP23017 sur le même bus I2C via les
  broches d'adresse. Enregistrez une instance `FirmataMCP23017` distincte par
  circuit et calculez l'adresse avec `FirmataMCP23017 addressWithAddressPins:`.
- **Alimentation :** 25 mA par broche est la limite du circuit ; pilotez de
  plus fortes charges via des étages de sortie ou des transistors externes.
