# Firmata-Servo – Control de servos de alto nivel

Contenido:
1. Resumen
2. Conceptos básicos
3. Clase y API
4. Transportes (pin y PCA9685)
5. Ejemplos
6. Notas

---

## 1. Resumen

El paquete `Firmata-Servo` eleva el control de servos del protocolo Firmata base a
un nivel más cómodo. En lugar de enviar ángulos de protocolo en bruto, una
instancia de servo modela un único servo con su situación de montaje fija:

- **Velocidad** en grados por segundo: el servo se aproxima con suavidad al destino
  en pequeños pasos desde un proceso en segundo plano en lugar de saltar.
- **Servos de 180° y 270°**: el recorrido mecánico se tiene en cuenta al escalar al
  ángulo de protocolo de 0–180°.
- **Rangos de montaje restringidos e invertidos**: los valores de entrada (p. ej.
  0–100) se asignan linealmente a un rango de ángulos arbitrario, incluidos servos
  montados al revés (p. ej. 180° → 0°).
- **Dos transportes**: directamente en un pin de Arduino (`FirmataPinServo`) o en un
  canal PCA9685 por I2C (`FirmataPCA9685Servo`).

## 2. Conceptos básicos

Un servo trabaja entre un **rango de montaje** (ángulos físicos; véase
`minAngle`/`maxAngle`). Su entrada es un **valor de posición** abstracto,
normalmente un porcentaje entre 0 y 100 (`minPosition`/`maxPosition`). `moveTo:`
asigna el valor linealmente al rango de ángulos — los rangos invertidos están
permitidos para servos montados al revés — lo limita y mueve el servo hasta allí.

La **velocidad angular** (`speedDegreesPerSecond`) controla la rapidez con que
cambia el ángulo: con velocidad cero el servo salta directamente al destino; con
velocidad positiva se aproxima en pequeños pasos. El proceso en segundo plano
(`startMovingProcess`) se detiene solo cuando se alcanza el destino. El ángulo
actual y el objetivo se mantienen como estado (`currentAngle`, `targetAngle`).

**Nunca dos procesos en competencia:** `moveTo:` durante un movimiento en curso
finaliza primero el proceso antiguo (internamente `stopMovingProcess`) y luego
inicia el movimiento nuevo desde la posición actual. Un servo es conducido, por
tanto, por a lo sumo un proceso de movimiento en cada momento. Si la velocidad se
pone a 0 en plena marcha, el siguiente paso termina el movimiento regularmente en
el destino en lugar de seguir avanzando indefinidamente.

El **rango mecánico** (`rangeDegrees`, 180 o 270) junto con la **calibración de
ancho de pulso** (`minPulseMicroseconds`/`maxPulseMicroseconds`) escala el ángulo
físico al ángulo de protocolo. El transporte real está delegado en las subclases
(`writeAngle:`).

## 3. Clase y API

`FirmataServo` es la base abstracta (paquete `Firmata-Servo`).

Ajustes (accessing):

- `minPosition:`/`maxPosition:` o `setPositionRangeFrom:to:` — rango de entrada
  (por defecto 0–100).
- `minAngle:`/`maxAngle:` o `setAngleRangeFrom:to:` — rango de montaje en grados
  físicos; se permiten rangos invertidos.
- `rangeDegrees:` — recorrido mecánico (por defecto 180; p. ej. 270 para servos
  pan-tilt).
- `minPulseMicroseconds:`/`maxPulseMicroseconds:` — calibración de ancho de pulso
  (por defecto 544/2400 µs, la convención StandardFirmata).
- `speedDegreesPerSecond:` — velocidad en grados por segundo (0 = saltar
  directamente).
- `stepIntervalMilliseconds:` — intervalo de paso del proceso en segundo plano
  (por defecto 20 ms).

Movimiento (moving):

- `moveTo: aPosition` — dar una posición (p. ej. 0–100); se asigna al rango de
  ángulos y se conduce hasta ella.
- `moveToAngle: degrees` — mover a un ángulo físico directamente.
- `currentAngle`, `targetAngle` — consultas de estado; `isMoving` — ¿hay un
  movimiento en curso?
- `step` — un único paso (usado por el proceso en segundo plano).
- `startMovingProcess` / `stopMovingProcess` — iniciar/detener el proceso de
  aproximación; cada `moveTo:` finaliza antes un proceso en curso de forma regular.

Mapeos (mapping):

- `positionToAngle:` — valor de posición → ángulo físico (lineal, limitado).
- `protocolAngleForDegrees:` — ángulo físico → ángulo de protocolo 0–180°.
- `clampAngle:` — limitar al rango de montaje.

Constantes en el lado de clase (`FirmataServo class`): `defaultRangeDegrees` (180),
`defaultMinPulseMicroseconds` (544), `defaultMaxPulseMicroseconds` (2400),
`defaultSpeedDegreesPerSecond` (0), `defaultStepIntervalMilliseconds` (20).

## 4. Transportes (pin y PCA9685)

`FirmataPinServo` (variable de instancia `pin`) conduce un servo conectado
directamente a un pin de Arduino:

- `attach` — poner el pin en modo servo y enviar la calibración de ancho de pulso
  una vez; el inicio del rango de montaje sirve como ángulo de reposo.
- Después, cada movimiento es un mensaje `servoOnPin:angle:` en la conexión Firmata.

`FirmataPCA9685Servo` (variable de instancia `channel`) conduce un servo en un canal
de un controlador PWM PCA9685 por el bus I2C:

- El controlador (`FirmataPCA9685`) debe inicializarse antes con `initializeDevice`;
  eso activa el autoincremento de registros y programa la frecuencia PWM, ambas
  cosas necesarias para el servo (véase
  [PCA9685-Documentación-es.md](PCA9685-Documentación-es.md)). Un `setFrequency:`
  aparte solo hace falta para cambiar la frecuencia después.
- Cada movimiento es un mensaje `setServoOnChannel:angle:minPulse:maxPulse:` al
  controlador.

## 5. Ejemplos

### 5.1 Servo directamente en un pin de Arduino

```smalltalk
| bus servo |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.

servo := FirmataPinServo on: bus pin: 9.
servo attach.
servo speedDegreesPerSecond: 45.   "45 grados por segundo"
servo moveTo: 50.                   "mover al 50% del rango de montaje"
```

### 5.2 Rangos de montaje restringidos e invertidos

```smalltalk
servo setAngleRangeFrom: 20 to: 160.  "solo se puede mover entre 20° y 160°"
servo moveTo: 0.                      "se mueve a 20°"
servo moveTo: 100.                    "se mueve a 160°"

servo setAngleRangeFrom: 160 to: 20.  "montado al revés"
servo moveTo: 100.                    "se mueve a 20°"
```

### 5.3 Servo de 270 grados

```smalltalk
servo rangeDegrees: 270.
servo setAngleRangeFrom: 0 to: 270.
servo moveTo: 50.                     "físicamente 135°, protocolo 90°"
```

### 5.4 Servo por PCA9685 (I2C)

```smalltalk
| bus driver servo |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

driver := FirmataPCA9685 new.
driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
driver initializeDevice.                     "modos, autoincremento, 50 Hz"

servo := FirmataPCA9685Servo on: driver channel: 0.
servo speedDegreesPerSecond: 30.
servo moveTo: 50.
```

### 5.5 Nuevo destino durante el movimiento

```smalltalk
servo speedDegreesPerSecond: 90.
servo moveTo: 100.              "se aproxima suavemente al 100%"
servo moveTo: 0.                "tras 5 segundos: el movimiento antiguo termina
                                 y el nuevo inicia desde la posición actual"
```

## 6. Notas

- **Sin procesos en competencia:** cada `moveTo:`/`moveToAngle:` finaliza primero un
  proceso de aproximación en curso. Si la velocidad se pone a 0, el servo salta al
  destino en el siguiente `step` y el proceso termina de forma regular.
- **Proceso en segundo plano:** corre en la prioridad activa del llamador y se llama
  `FirmataServo <clase>`. Termina solo al alcanzar el destino.
- **`targetAngle:` no inicia ningún proceso** — solo establece el estado objetivo
  (para aplicaciones que marcan `step` ellas mismas). El movimiento se inicia con
  `moveTo:` o `moveToAngle:`.
- **Calibración de pulso:** los valores por defecto 544/2400 µs siguen la convención
  StandardFirmata; si tus servos difieren, ajusta ambos valores por servo.
- **Recomendación de actualización:** para proyectos nuevos prefiere la API de alto
  nivel `FirmataServo` al uso en bruto de `servoOnPin:angle:` del protocolo base.

Estado de pruebas: la suite `Tests-Firmata-Servo` forma parte del recorrido general
headless (`passed=221 failures=0 errors=0`, 2026-09-24, Cuis 7.8 #7977).
