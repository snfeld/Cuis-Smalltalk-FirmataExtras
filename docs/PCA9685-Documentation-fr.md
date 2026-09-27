# PCA9685 — driver PWM/servo à 16 canaux

Sommaire :
1. Aperçu
2. Caractéristiques techniques
3. Câblage
4. Classes et API
5. Exemple
6. Remarques

---

## 1. Aperçu

Le **PCA9685** (NXP) est un driver PWM à 16 canaux sur le bus I2C. Chacun des 16
canaux produit un signal PWM sur 12 bits (4096 pas par période) et peut piloter
des servos, des LED, des contrôleurs de moteur ou d'autres charges pilotées par
impulsions. Avec plusieurs circuits en cascade, il peut même piloter jusqu'à 64
sorties.

Le paquet `Firmata-PCA9685` encapsule le circuit derrière une connexion
`FirmataI2C` : l'accès aux registres passe par l'Arduino (I2C SYSEX), et le helper
de servos `setServoOnChannel:angle:` convertit les angles en largeurs d'impulsion.

## 2. Caractéristiques techniques

- 16 canaux PWM indépendants, résolution 12 bits (0–4095).
- Oscillateur interne : 25 MHz ; fréquence PWM programmable (typiquement
  40–1000 Hz, par défaut 50 Hz ; la plage utile est fixée par la résolution du
  prédiviseur).
- Adresse esclave I2C : **0x40** avec les broches d'adresse A0–A5 à la masse
  (via `FirmataPCA9685Constants defaultAddress`), jusqu'à 62 adresses.
- Les valeurs supérieures ou égales à **4096** forcent « entièrement allumé » ;
  les valeurs négatives éteignent la voie.
- Voies individuelles : registres de phase ON/OFF (4 registres par voie à partir
  de 0x06).

## 3. Câblage

| PCA9685 | Arduino |
| --- | --- |
| VCC | 3,3 V (ou 5 V sur les cartes compatibles en niveaux logiques) |
| GND | GND (commun avec Arduino et l'alimentation des sorties) |
| SDA | A4 (Uno) / 20 (Mega) — la broche de la carte StandardFirmata |
| SCL | A5 (Uno) / 21 (Mega) |
| V+ (si présent) | alimentation externe pour les sorties (servos !) |
| A0–A5 | masse pour l'adresse 0x40, sinon une autre adresse |

Pour les servos, alimentez **l'alimentation des servos séparément** (5 V,
suffisamment de courant !) et reliez toutes les masses. Les résistances de tirage
I2C sont présentes sur la plupart des cartes de dérivation.

## 4. Classes et API

`FirmataPCA9685` hérite de `FirmataI2CDevice` (paquet `Firmata-I2C`).

- Initialisation : `initialize`, `initializeDevice` (définit Mode1/Mode2, active
  l'auto-incrémentation des registres, programme la fréquence PWM en accord
  avec `frequency` et éteint toutes les sorties).
- PWM : `setPWMOnChannel:value:`, `setAllPWM:`, `setFrequency:`,
  `prescaleForFrequency:`.
- Servos : `setServoOnChannel:angle:`,
  `setServoOnChannel:angle:minPulse:maxPulse:`,
  `pwmCountsForServoAngle:minPulse:maxPulse:`, `pwmCountsForMicroseconds:`.
- Accès : `frequency` / `frequency:`, `numberOfChannels`.
- Helpers hérités (`FirmataI2CDevice`) : `firmata:address:`,
  `registerWithFirmata`, `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.
- `handleI2CReply:data:` est volontairement vide ici (circuit en écriture
  seule).

`FirmataPCA9685Constants` (côté classe) contient les registres (p. ex.
`mode1Register`, `mode2Register`, `preScaleRegister`, `led0OnLowRegister`,
`allLedOnLowRegister`, `allLedOffLowRegister`), les bits de mode (`sleepBit`,
`restartBit`, `mode1Default` = 0x20 auto-incrémentation, `mode2Default`) et la
spécification
(`numberOfChannels` = 16, `resolutionSteps` = 4096,
`oscillatorFrequency` = 25 MHz, `channelRegisterStep` = 4) ainsi que les valeurs
par défaut (`defaultAddress` = 0x40, `defaultFrequency` = 50 Hz,
`defaultMinPulseMicroseconds` = 544, `defaultMaxPulseMicroseconds` = 2400).

## 5. Exemple

```smalltalk
| bus driver |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

driver := FirmataPCA9685 new.
driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
driver initializeDevice.                     "modes, auto-incrément, 50 Hz"

driver setPWMOnChannel: 0 value: 2048.      "LED canal 0 : demi-luminosité"
driver setPWMOnChannel: 1 value: -1.        "canal 1 éteint"
driver setAllPWM: 0.                        "tout éteint"

"Servo sur le canal 2 à 90 degrés"
driver setServoOnChannel: 2 angle: 90.

"Servo avec un intervalle d'impulsion personnalisé (500 µs .. 2500 µs)"
driver setServoOnChannel: 3 angle: 30 minPulse: 500 maxPulse: 2500.

"Une autre fréquence PWM (60 Hz) se programme de la même façon"
driver setFrequency: 60.
```

## 6. Remarques

- **`initializeDevice` est nécessaire une fois :** sans lui, le bit
  d'auto-incrémentation de MODE1 est désactivé, si bien qu'une écriture de
  registre portant l'octet bas *et* haut de phase (chaque
  `setPWMOnChannel:value:` et `setServoOnChannel:angle:`) perd son octet haut
  dans le circuit et la voie reçoit une impulsion bien trop courte — les servos
  ne bougent alors tout simplement pas. Il programme aussi l'oscillateur, car
  le circuit démarre au prédiviseur 30 (~196,9 Hz) alors que les comptes sont
  calculés pour `frequency`.
- **Plage de valeurs :** 0–4095 règle la paire de phases ON/OFF ; ≥ 4096 =
  entièrement allumé, < 0 = entièrement éteint.
- **Changement de fréquence** passe par sommeil–prédiviseur–réveil–redémarrage ;
  utilisez `setFrequency:` plutôt que l'accès direct aux registres. Entre
  `initializeDevice` et le premier `setFrequency:`, un servo ne se déplace pas
  correctement ; n'appelez `setFrequency:` que pour changer la fréquence
  ensuite.
- **Limitation d'angle :** `setServoOnChannel:angle:` limite à 0–180° ; la
  largeur d'impulsion suit linéairement entre `minPulse` et `maxPulse` (par
  défaut 544/2400 µs, la convention servo de StandardFirmata).
- **Écriture seule :** le circuit est uniquement écrit ; `handleI2CReply:data:`
  reste vide et rien n'est lu.
- **Plusieurs circuits :** configurez les broches d'adresse A0–A5 ; enregistrez
  une instance `FirmataPCA9685` par circuit sur la même connexion `FirmataI2C`.
