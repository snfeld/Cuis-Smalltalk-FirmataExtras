# Firmata-Servo – Pilotage de servos de haut niveau

Sommaire :
1. Vue d'ensemble
2. Concepts de base
3. Classe et API
4. Transports (broche et PCA9685)
5. Exemples
6. Remarques

---

## 1. Vue d'ensemble

Le paquet `Firmata-Servo` amène le pilotage des servos du protocole Firmata de base
à un niveau confortable. Plutôt que d'envoyer des angles de protocole bruts, une
instance de servo modélise un seul servo avec sa situation de montage fixe :

- **Vitesse** en degrés par seconde — le servo se déplace doucement vers la cible
  par petits pas depuis un processus d'arrière-plan au lieu de sauter.
- **Servos 180° et 270°** — le débattement mécanique est pris en compte lors de la
  conversion vers l'angle de protocole 0–180°.
- **Plages de montage restreintes et inversées** — les valeurs d'entrée (p. ex.
  0–100) sont appliquées linéairement sur une plage d'angles quelconque, y compris
  des servos montés à l'envers (p. ex. 180° → 0°).
- **Deux transports** — directement sur une broche Arduino (`FirmataPinServo`) ou
  sur un canal PCA9685 via I2C (`FirmataPCA9685Servo`).

## 2. Concepts de base

Un servo travaille entre une **plage de montage** (angles physiques ; voir
`minAngle`/`maxAngle`). Son entrée est une **valeur de position** abstraite,
généralement un pourcentage entre 0 et 100 (`minPosition`/`maxPosition`). `moveTo:`
projette la valeur linéairement sur la plage d'angles — les plages inversées sont
permises pour les servos montés à l'envers — la limite et pilote le servo jusqu'à
l'angle correspondant.

La **vitesse angulaire** (`speedDegreesPerSecond`) contrôle la rapidité du
changement d'angle : à vitesse nulle le servo saute directement à la cible ; à
vitesse positive il s'y rend par petits pas. Le processus d'arrière-plan
(`startMovingProcess`) s'arrête de lui-même une fois la cible atteinte. L'angle
courant et l'angle cible sont conservés comme état (`currentAngle`, `targetAngle`).

**Jamais deux processus concurrents :** `moveTo:` pendant un mouvement en cours
termine d'abord l'ancien processus (en interne `stopMovingProcess`) puis lance le
nouveau mouvement depuis la position courante. Un servo est donc piloté par au plus
un processus de mouvement à tout instant. Si la vitesse passe à 0 en pleine course,
le pas suivant termine le mouvement régulièrement à la cible au lieu d'avancer sans
fin.

La **plage mécanique** (`rangeDegrees`, 180 ou 270) associée à la **calibration de
largeur d'impulsion** (`minPulseMicroseconds`/`maxPulseMicroseconds`) convertit
l'angle physique en angle de protocole. Le transport réel est délégué aux
sous-classes (`writeAngle:`).

## 3. Classe et API

`FirmataServo` est la base abstraite (paquet `Firmata-Servo`).

Réglages (accessing) :

- `minPosition:`/`maxPosition:` ou `setPositionRangeFrom:to:` — plage d'entrée
  (défaut 0–100).
- `minAngle:`/`maxAngle:` ou `setAngleRangeFrom:to:` — plage de montage en degrés
  physiques ; plages inversées permises.
- `rangeDegrees:` — débattement mécanique (défaut 180 ; p. ex. 270 pour les servos
  pan-tilt).
- `minPulseMicroseconds:`/`maxPulseMicroseconds:` — calibration de largeur
  d'impulsion (défaut 544/2400 µs, la convention StandardFirmata).
- `speedDegreesPerSecond:` — vitesse en degrés par seconde (0 = sauter directement).
- `stepIntervalMilliseconds:` — intervalle de pas du processus d'arrière-plan
  (défaut 20 ms).

Mouvement (moving) :

- `moveTo: aPosition` — donner une position (p. ex. 0–100) ; elle est projetée sur
  la plage d'angles et pilotée.
- `moveToAngle: degrees` — se déplacer directement vers un angle physique.
- `currentAngle`, `targetAngle` — consultation d'état ; `isMoving` — un mouvement
  est-il en cours ?
- `step` — un pas unique (utilisé par le processus d'arrière-plan).
- `startMovingProcess` / `stopMovingProcess` — démarrer/arrêter le processus de
  rampe ; chaque `moveTo:` termine d'abord régulièrement un processus en cours.

Projections (mapping) :

- `positionToAngle:` — valeur de position → angle physique (linéaire, limité).
- `protocolAngleForDegrees:` — angle physique → angle de protocole 0–180°.
- `clampAngle:` — limiter à la plage de montage.

Constantes côté classe (`FirmataServo class`) : `defaultRangeDegrees` (180),
`defaultMinPulseMicroseconds` (544), `defaultMaxPulseMicroseconds` (2400),
`defaultSpeedDegreesPerSecond` (0), `defaultStepIntervalMilliseconds` (20).

## 4. Transports (broche et PCA9685)

`FirmataPinServo` (variable d'instance `pin`) pilote un servo branché directement
sur une broche Arduino :

- `attach` — mettre la broche en mode servo et envoyer une fois la calibration de
  largeur d'impulsion ; le début de la plage de montage sert d'angle de repos.
- Ensuite chaque mouvement est un message `servoOnPin:angle:` sur la connexion
  Firmata.

`FirmataPCA9685Servo` (variable d'instance `channel`) pilote un servo sur un canal
d'un driver PWM PCA9685 via le bus I2C :

- Le driver (`FirmataPCA9685`) doit d'abord être initialisé avec
  `initializeDevice` ; cela active l'auto-incrémentation des registres et
  programme la fréquence PWM, dont le servo a besoin dans les deux cas (voir
  [PCA9685-Documentation-fr.md](PCA9685-Documentation-fr.md)). Un appel séparé à
  `setFrequency:` n'est nécessaire que pour changer la fréquence ensuite.
- Chaque mouvement est un message `setServoOnChannel:angle:minPulse:maxPulse:` vers
  le driver.

## 5. Exemples

### 5.1 Servo directement sur une broche Arduino

```smalltalk
| bus servo |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.

servo := FirmataPinServo on: bus pin: 9.
servo attach.
servo speedDegreesPerSecond: 45.   "45 degrés par seconde"
servo moveTo: 50.                   "aller à 50 % de la plage de montage"
```

### 5.2 Plages de montage restreintes et inversées

```smalltalk
servo setAngleRangeFrom: 20 to: 160.  "déplaçable seulement entre 20° et 160°"
servo moveTo: 0.                      "va à 20°"
servo moveTo: 100.                    "va à 160°"

servo setAngleRangeFrom: 160 to: 20.  "monté à l'envers"
servo moveTo: 100.                    "va à 20°"
```

### 5.3 Servo de 270 degrés

```smalltalk
servo rangeDegrees: 270.
servo setAngleRangeFrom: 0 to: 270.
servo moveTo: 50.                     "physiquement 135°, protocole 90°"
```

### 5.4 Servo via PCA9685 (I2C)

```smalltalk
| bus driver servo |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

driver := FirmataPCA9685 new.
driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
driver initializeDevice.                     "modes, auto-incrément, 50 Hz"

servo := FirmataPCA9685Servo on: driver channel: 0.
servo speedDegreesPerSecond: 30.
servo moveTo: 50.
```

### 5.5 Nouvelle cible en cours de mouvement

```smalltalk
servo speedDegreesPerSecond: 90.
servo moveTo: 100.              "se rend doucement à 100 %"
servo moveTo: 0.                "après 5 secondes : l'ancien mouvement se termine
                                 et le nouveau part de la position courante"
```

## 6. Remarques

- **Pas de processus concurrents :** chaque `moveTo:`/`moveToAngle:` termine d'abord
  un processus de rampe en cours. Si la vitesse passe à 0, le servo saute à la
  cible au pas suivant et le processus se termine régulièrement.
- **Processus d'arrière-plan :** il tourne à la priorité active de l'appelant et se
  nomme `FirmataServo <classe>`. Il se termine seul à l'atteinte de la cible.
- **`targetAngle:` ne démarre aucun processus** — il ne fait que poser l'état cible
  (pour les applications qui cadrent `step` elles-mêmes). Le mouvement se lance
  avec `moveTo:` ou `moveToAngle:`.
- **Calibration des impulsions :** les valeurs par défaut 544/2400 µs suivent la
  convention StandardFirmata ; si vos servos divergent, ajustez les deux valeurs
  par servo.
- **Recommandation de mise à niveau :** pour les nouveaux projets préférez l'API de
  haut niveau `FirmataServo` à l'usage brut de `servoOnPin:angle:` du protocole de
  base.

État des tests : la suite `Tests-Firmata-Servo` fait partie du parcours global
headless (`passed=221 failures=0 errors=0`, 2026-09-24, Cuis 7.8 #7977).
