# BMP280 – Sensor de presión y temperatura barométrica

Contenido:
1. Resumen
2. Datos técnicos
3. Cableado
4. Clase y API
5. Ejemplo
6. Notas

---

## 1. Resumen

El **BMP280** (Bosch Sensortec) es un sensor barométrico de presión y
temperatura. Mide la presión absoluta en el rango de 300–1100 hPa y entrega
el resultado en tres registros de salida de 20 bits big-endian a partir de
`0xF7` (presión MSB, LSB, XLSB), seguidos de los tres registros de
temperatura en `0xFA`. Los contadores brutos de 20 bits se compensan con los
coeficientes de calibración de fábrica almacenados en un bloque de 24 bytes
en `0x88`.

El paquete `Firmata-BMP280` encapsula el sensor detrás de una conexión
`FirmataI2C`. `initializeDevice` escribe una vez la configuración y el
registro de control de medición (sobremuestreo x1, modo normal) y lee el
bloque de calibración. Con `startReadingPort` el Arduino transmite en
continuo los seis bytes de salida; cada `I2C_REPLY` entrante sobrescribe la
última muestra. Los valores escalados quedan disponibles directamente.

La compensación sigue las fórmulas enteras del controlador de referencia de
Bosch (división entera en C, limitada al rango del sensor), de modo que los
resultados coinciden exactamente con los cálculos de la hoja de datos.

## 2. Datos técnicos

- Sensor combinado de presión barométrica y temperatura.
- Rango de presión: 300–1100 hPa; salida de hasta 20 bits, big-endian (MSB
  primero).
- Precisión absoluta de temperatura: ±1,0 °C; resolución 0,01 °C.
- Resolución de presión: 0,01 hPa (unidad de salida); ruido RMS típico muy
  inferior a 1 hPa.
- Dirección I2C: **0x76** (SDO bajo) o **0x77** (SDO alto).
- Tensión de alimentación: 1,71–3,6 V.
- El registro de identificación (`0xD0`) devuelve **0x58**.
- 24 bytes de calibración en `0x88` (dig_T1..T3, dig_P1..P9).

## 3. Cableado

| BMP280 | Arduino Uno |
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

`FirmataBMP280` hereda de `FirmataI2CDevice` (paquete `Firmata-I2C`).

- Inicialización: `initializeDevice` (escribe `config` 0x00 y `ctrl_meas`
  0x27, luego lee los 24 bytes de calibración), `registerWithFirmata`
  (¡después del cableado!), `readChipId` opcional.
- Lectura: `startReadingPort` (continuo) o `readOnce` (una muestra de los
  seis bytes de salida en `0xF7`).
- Salidas brutas: `rawPressure`/`rawTemperature` (contadores enteros de 20
  bits big-endian), `chipId` (tras `readChipId`).
- Salidas compensadas:
  - `compensatedTemperature` — 0,01 °C como entero, limitado a
    [-4000, 8500] (−40,00 °C a 85,00 °C).
  - `temperatureCelsius` — grados Celsius como Float.
  - `compensatedPressure` — presión en pascales como entero, limitada a
    [30000, 110000].
  - `pressurePascal` — igual que `compensatedPressure`.
  - `pressureHectoPascal` — presión en hPa como Float.
- Calibración: `calibrationData` (24 bytes), `isCalibrationLoaded`.
- Interno: `tFine` (temperatura fina compartida por ambas fórmulas).
- Recepción: `handleI2CReply:data:` distribuye las respuestas de
  identificación, calibración y salida.
- Ayudantes heredados (`FirmataI2CDevice`): `firmata:address:`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataBMP280Constants` (lado de clase) contiene los registros
(`calibrationRegister` 0x88, `chipIdRegister` 0xD0, `configRegister` 0xF5,
`ctrlMeasRegister` 0xF4, `dataRegister` 0xF7, `resetRegister` 0xE0,
`statusRegister` 0xF3), la configuración (`configValue` 0x00,
`ctrlMeasValue` 0x27), la especificación (`chipIdValue` 0x58,
`calibrationByteCount` 24, `sensorOutputByteCount` 6) y el valor por defecto
(`defaultAddress` 0x76).

## 5. Ejemplo

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

"Opcional: identificación del chip"
sensor readChipId.
sensor chipId.                          "16r58"

"Iniciar transmisión continua"
sensor startReadingPort.

"... tras unos pasos:"
sensor temperatureCelsius.              "temperatura en C"
sensor pressureHectoPascal.             "presión en hPa"

"Leer una única muestra:"
sensor readOnce.

"Detener la transmisión:"
sensor stopReading.
```

## 6. Notas

- **Los valores de 20 bits son big-endian:** presión = MSB, LSB, XLSB, MSB
  primero; el nibble bajo del byte XLSB es siempre cero. El entero bruto es
  `((MSB << 16) + (LSB << 8) + XLSB) >> 4`.
- **Orden de salida:** los seis bytes de salida en `0xF7` son presión MSB,
  LSB, XLSB, y después temperatura MSB, LSB, XLSB. `rawPressure` y
  `rawTemperature` los desempaquetan en consecuencia (índices 1 y 4).
- **La compensación es aritmética entera** según el controlador de referencia
  de Bosch: división truncada hacia cero (`quo:`), el mismo `t_fine` para las
  fórmulas de temperatura y presión, y límites al rango del sensor.
- **nil antes de la calibración:** `temperatureCelsius`,
  `compensatedPressure` y `tFine` responden nil hasta que se reciba el bloque
  de calibración. Tras un reset, vuelva a llamar a `initializeDevice` o
  espere la siguiente respuesta.
- **Comprobación de identificación:** `readChipId` + `chipId` debe responder
  `0x58`. De lo contrario, hay un error de comunicación.
- **Registro `0xF7` vs. fin de Sysex de Firmata** `0xF7`: en las pruebas
  ambos aparecen en arrays de bytes; son independientes. El registro de
  salida `0xF7` es solo una dirección de registro del chip en el bus I2C.
- **Varios sensores:** ponga SDO a VCC para la dirección 0x77 y registre una
  segunda instancia `FirmataBMP280` en la misma conexión `FirmataI2C`.
