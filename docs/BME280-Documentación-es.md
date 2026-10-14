# BME280 – Sensor de humedad, presión y temperatura

Contenido:
1. Resumen
2. Datos técnicos
3. Cableado
4. Clase y API
5. Ejemplo
6. Notas

---

## 1. Resumen

El **BME280** (Bosch Sensortec) es un sensor combinado de humedad relativa,
presión barométrica y temperatura. Entrega la misma salida de presión y
temperatura que el BMP280 (registros de 20 bits big-endian en `0xF7` y
`0xFA`), más una salida de humedad relativa de 16 bits en `0xFD`. Los datos
se compensan con dos bloques de calibración: el bloque de 26 bytes de
temperatura/presión en `0x88` (el byte 26, es decir `0xA1`, es el coeficiente
de humedad sin signo `dig_H1`) y el bloque de 7 bytes en `0xE1`.

El paquete `Firmata-BME280` extiende `Firmata-BMP280` detrás de una conexión
`FirmataI2C`. `initializeDevice` escribe `CTRL_HUM` (`0xF2`) *antes* de
`CTRL_MEAS` (requisito del circuito), luego la configuración y el registro de
control de medición, y por último lee ambos bloques de calibración.
`startReadingPort` pide al Arduino que transmita en continuo los seis bytes de
presión/temperatura en `0xF7` y los dos bytes de humedad en `0xFD`; cada
`I2C_REPLY` entrante sobrescribe la última muestra.

Los seis coeficientes (`dig_H1`..`dig_H6`) se extraen del bloque 0xE1
empaquetado en nibbles, y la humedad se compensa con las fórmulas enteras del
controlador de referencia de Bosch (división truncada, limitada al rango del
sensor). La compensación de temperatura y presión se hereda de
`FirmataBMP280`.

## 2. Datos técnicos

- Sensor combinado de humedad relativa, presión barométrica y temperatura.
- Rango de humedad: 0–100 % HR; resolución 0,008 % HR (salida en Q10, por
  tanto 102400 = 100 %).
- Rango de presión: 300–1100 hPa; resolución de temperatura 0,01 °C.
- Dirección I2C: **0x76** (SDO bajo) o **0x77** (SDO alto).
- Tensión de alimentación: 1,71–3,6 V.
- El registro de identificación (`0xD0`) devuelve **0x60** (a diferencia del
  BMP280: 0x58).
- Calibración: 26 bytes en `0x88` (dig_T1..T3, dig_P1..P9, dig_H1) y 7 bytes
  en `0xE1` (dig_H2..dig_H6 en forma empaquetada en nibbles).

## 3. Cableado

| BME280 | Arduino Uno |
| --- | --- |
| VCC | 3,3 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| SDO | GND (para la dirección 0x76) |

Las resistencias de pull-up de I2C suelen estar presentes en las placas
comunes; en caso contrario, 4,7 kΩ en SDA/SCL hacia VCC. SDO determina la
dirección: GND → 0x76, VCC → 0x77.

## 4. Clase y API

`FirmataBME280` hereda de `FirmataBMP280` (paquete `Firmata-BMP280`).

- Inicialización: `initializeDevice` (escribe primero `CTRL_HUM` 0x01, luego
  `config` 0x00 y `ctrl_meas` 0x27, después lee los 26 bytes de calibración
  en `0x88` y los 7 bytes de calibración de humedad en `0xE1`),
  `registerWithFirmata` (¡después del cableado!), `readChipId` opcional.
- Lectura: `startReadingPort` (flujo continuo de `0xF7` y `0xFD`) o
  `readOnce` (una muestra de ambos).
- Salidas brutas: `rawPressure`/`rawTemperature` (20 bits), `rawHumidity`
  (16 bits big-endian), `chipId`.
- Salidas compensadas:
  - `temperatureCelsius`, `compensatedTemperature`, `pressureHectoPascal`,
    `pressurePascal`, `compensatedPressure` — heredadas de `FirmataBMP280`.
  - `compensatedHumidity` — humedad relativa como entero Q10, limitada a
    [0, 102400] (102400 = 100 %).
  - `humidityPercent` — humedad relativa en porcentaje como Float
    (`compensatedHumidity / 1024.0`).
- Calibración: `calibrationData` (26 bytes), `humidityCalibration`
  (7 bytes), `isCalibrationLoaded`, `isHumidityCalibrationLoaded`, y los
  coeficientes `digH1`..`digH6` (accesibles para pruebas).
- Recepción: `handleI2CReply:data:` distribuye las respuestas de
  calibración y salida de humedad antes de delegar en `FirmataBMP280`.
- Ayudantes heredados (`FirmataI2CDevice`): `firmata:address:`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataBME280Constants` extiende `FirmataBMP280Constants` y añade
(`ctrlHumRegister` 0xF2, `humidityCalibrationRegister` 0xE1,
`humidityDataRegister` 0xFD), la especificación (`calibrationByteCount` 26,
`humidityCalibrationByteCount` 7, `humidityOutputByteCount` 2,
`chipIdValue` 0x60) y el valor por defecto (`defaultAddress` 0x76).

## 5. Ejemplo

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

"Opcional: identificación del chip"
sensor readChipId.
sensor chipId.                          "16r60"

"Iniciar transmisión continua"
sensor startReadingPort.

"... tras unos pasos:"
sensor temperatureCelsius.              "temperatura en C"
sensor pressureHectoPascal.             "presión en hPa"
sensor humidityPercent.                 "humedad relativa en %"

"Leer una única muestra:"
sensor readOnce.

"Detener la transmisión:"
sensor stopReading.
```

## 6. Notas

- **`CTRL_HUM` antes de `CTRL_MEAS`:** el BME280 solo toma el
  sobremuestreo de humedad de `CTRL_HUM` (`0xF2`) si este se escribe antes
  que el registro de control de medición. `initializeDevice` lo hace en el
  orden correcto.
- **26 bytes de calibración:** el BME280 necesita los 26 bytes del bloque
  0x88; el byte 26 (registro `0xA1`) contiene `dig_H1` sin signo. El BMP280
  solo necesita los 24 primeros.
- **Disposición de la calibración de humedad (`0xE1`..`0xE7`):** `dig_H2` es
  un valor con signo de 16 bits little-endian en `0xE1`, `dig_H3` sin signo
  en `0xE3`, `dig_H4` y `dig_H5` se reparten entre bytes MSB con signo
  (`0xE4`/`0xE6`) y un nibble del byte `0xE5` (`dig_H4` usa el nibble bajo,
  `dig_H5` el alto), y `dig_H6` es el byte con signo en `0xE7`. Los
  coeficientes `digH1`..`digH6` se extraen en consecuencia.
- **La salida de humedad es de 16 bits big-endian** en `0xFD` (MSB primero).
- **La compensación es aritmética entera** según el controlador de referencia
  de Bosch: división truncada hacia cero (`quo:`), el mismo `t_fine` para las
  fórmulas de temperatura, presión y humedad, y límites al rango del sensor.
- **nil antes de la calibración:** los valores compensados responden nil
  hasta que se reciban ambos bloques de calibración.
- **Comprobación de identificación:** `readChipId` + `chipId` debe responder
  `0x60`. De lo contrario, hay un error de comunicación.
- **Varios sensores:** ponga SDO a VCC para la dirección 0x77 y registre una
  segunda instancia `FirmataBME280` en la misma conexión `FirmataI2C`.
