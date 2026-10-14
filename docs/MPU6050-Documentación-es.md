# MPU6050 — IMU de 6 ejes

Contenido:
1. Resumen
2. Datos técnicos
3. Cableado
4. Clases y API
5. Ejemplo
6. Notas

---

## 1. Resumen

El **MPU6050** (InvenSense) es un sensor de movimiento de 6 ejes: un
acelerómetro de 3 ejes, un giroscopio de 3 ejes y un sensor de temperatura.
Todas las lecturas se concentran en 14 registros consecutivos a partir de
`ACCEL_XOUT_H` (`0x3B`), transmitidos con una única lectura I2C continua.

El paquete `Firmata-MPU6050` envuelve el sensor tras una conexión `FirmataI2C`.
Con `startReading`, el Arduino transmite los registros de salida de forma
continua; cada `I2C_REPLY` entrante sobrescribe la última muestra. Los valores en
crudo y escalados (g y grados por segundo) quedan entonces disponibles
directamente.

En resumen: `accelX` = cuenta en crudo ±32767, `scaledAccelX` = aceleración en g,
`scaledGyroX` = velocidad angular en grados por segundo.

## 2. Datos técnicos

- Acelerómetro: 3 ejes, 16 bits, fondo de escala seleccionable
  **±2 g / ±4 g / ±8 g / ±16 g** (sensibilidad 16384/8192/4096/2048 LSB/g).
- Giroscopio: 3 ejes, 16 bits, fondo de escala seleccionable
  **±250 / ±500 / ±1000 / ±2000 °/s** (sensibilidad 131/65,5/32,8/16,4 LSB/(°/s)).
- Temperatura: 16 bits, escala 340 LSB/°C, offset 36,53 °C.
- 14 registros de salida consecutivos desde 0x3B (aceleración, temperatura y giro
  en crudo, big-endian, con signo de 16 bits).
- Dirección esclava I2C: **0x68** con el pin AD0 a masa (si no, 0x69);
  `whoAmI` responde 0x68.
- Reloj interno de 8 MHz; el sensor arranca en modo de suspensión
  (`initializeDevice` lo despierta).

## 3. Cableado

| MPU6050 | Arduino |
| --- | --- |
| VCC | 3,3 V (las placas con adaptación de nivel a menudo también 5 V) |
| GND | GND |
| SDA | A4 (Uno) / 20 (Mega) |
| SCL | A5 (Uno) / 21 (Mega) |
| AD0 | masa para la dirección 0x68, VCC para 0x69 |
| INT (opcional) | dejarlo sin conectar (el sondeo se hace en el paso de Firmata) |

Los pull-ups I2C están en las placas de expansión habituales; si no, 4,7 kΩ en
SDA/SCL hacia VCC.

## 4. Clases y API

`FirmataMPU6050` hereda de `FirmataI2CDevice` (paquete `Firmata-I2C`).

- Inicialización: `initialize`, `initializeDevice` (activa el sensor borrando el
  bit de suspensión), `registerWithFirmata` (¡tras el cableado!).
- Configuración del sensor: `setAccelerationRange:` (0–3 ↔ ±2/4/8/16 g),
  `setGyroRange:` (0–3 ↔ ±250/500/1000/2000 °/s).
- Lectura: `startReading` (continua) o `readOnce` (una única muestra). Detener con
  `stopReading`.
- Salidas en crudo: `accelX`/`accelY`/`accelZ`, `gyroX`/`gyroY`/`gyroZ`,
  `temperature` (en °C).
- Salidas escaladas: `scaledAccelX`/`scaledAccelY`/`scaledAccelZ` (en g),
  `scaledGyroX`/`scaledGyroY`/`scaledGyroZ` (en °/s) — según el fondo de escala
  configurado.
- Sensibilidades: `accelSensitivity` (LSB/g), `gyroSensitivity`
  (LSB/(°/s)); se reducen a la mitad por cada paso de rango.
- Índice de rango: `accelRange`, `gyroRange`.
- Ayudantes heredados (`FirmataI2CDevice`): `firmata:address:`,
  `registerWithFirmata`, `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataMPU6050Constants` (lado de clase) contiene los registros
(`accelXHighRegister` 0x3B, `gyroXHighRegister` 0x43,
`temperatureHighRegister` 0x41, `accelConfigRegister` 0x1C,
`gyroConfigRegister` 0x1B, `configRegister` 0x1A, `smplrtDivRegister` 0x19,
`powerManagement1Register` 0x6B, `powerManagement2Register` 0x6C,
`whoAmIRegister` 0x75), los bits de alimentación (`awakeValue` 0,
`deviceResetBit`, `sleepBit`, `temperatureDisableBit`), la especificación
(`accelSensitivity` 16384, `gyroSensitivity` 131,0, `sensorOutputByteCount` 14,
`temperatureScaleFactor` 340,0, `temperatureOffset` 36,53) y los valores por
defecto (`defaultAddress` 0x68, `defaultAccelRange` 0, `defaultGyroRange` 0).

## 5. Ejemplo

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

"Elegir rangos más sensibles (opcional)"
sensor setAccelerationRange: 1.    "+/-4 g"
sensor setGyroRange: 1.            "+/-500 °/s"

"Iniciar la transmisión continua"
sensor startReading.

"... después de unos pasos:"
sensor accelZ.                     "cuenta en crudo Z de 16 bits"
sensor scaledAccelZ.               "aceleración Z en g"
sensor scaledGyroX.                "velocidad angular X en °/s"
sensor temperature.                "temperatura en °C"

"Alternativamente, una única muestra:"
sensor readOnce.

"Detener la transmisión:"
sensor stopReading.
```

## 6. Notas

- **Los valores en crudo son big-endian y con signo** (16 bits). Una muestra solo
  está disponible tras un `I2C_REPLY`; los accesores son inicialmente `nil` hasta
  que se procesa la primera respuesta.
- **Escalado:** `scaled*` = crudo / sensibilidad del rango configurado. Ejemplo:
  `scaledAccelX := accelX / 16384.0` a ±2 g.
- **Cambio de rango** (`setAccelerationRange:`/`setGyroRange:`) escribe el
  registro de configuración; índices válidos 0–3, si no `error:`.
- **Fórmula de la temperatura:** `crudo/340,0 + 36,53` en °C.
- **Estabilización:** deja que el sensor se asiente brevemente tras despertar; en
  la primera puesta en marcha lee `whoAmI` (0x68) como comprobación de cordura.
- **Varios sensores:** pon AD0 a 0x69 y registra una segunda instancia
  `FirmataMPU6050` en la misma conexión `FirmataI2C`.
