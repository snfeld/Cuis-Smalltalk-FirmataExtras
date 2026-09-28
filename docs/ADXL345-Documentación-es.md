# ADXL345 – Acelerómetro de 3 ejes

Contenido:
1. Resumen
2. Datos técnicos
3. Conexiones
4. Clase y API
5. Ejemplo
6. Notas

---

## 1. Resumen

El **ADXL345** (Analog Devices) es un acelerómetro digital de 3 ejes con
resolución de 13 bits en modo de resolución completa. Mide aceleración
estática (gravedad) y dinámica (movimiento, vibración) y entrega los
resultados en registros consecutivos por eje (`DATAX0` a `DATAZ1`, 6 bytes)
como valores de 16 bits en formato little-endian.

El paquete `Firmata-ADXL345` encapsula el sensor detrás de una conexión
`FirmataI2C`. Con `startReadingPort`, el Arduino transmite los registros
de salida continuamente; cada `I2C_REPLY` entrante sobrescribe la última
muestra. Los valores brutos y escalados están disponibles inmediatamente.

El sensor funciona con una sensibilidad fija de 256 LSB/g en modo de
resolución completa, independientemente del rango seleccionado. El rango
solo afecta el alcance máximo, no la resolución por g.

## 2. Datos técnicos

- Acelerómetro de 3 ejes, 13 bits de resolución completa (4 mg/LSB,
  256 LSB/g) para todos los rangos.
- Rangos seleccionables: **±2 g** (índice 0), **±4 g** (índice 1),
  **±8 g** (índice 2), **±16 g** (índice 3).
- Tasas de muestreo vía registro `BW_RATE` (`0x2C`): códigos 0x00 (0,1 Hz)
  a 0x0F (3200 Hz), valor predeterminado 0x0A (100 Hz).
- 6 registros de salida desde `DATAX0` (`0x32`): X0, X1, Y0, Y1, Z0, Z1
  (little-endian, 16 bits con signo).
- Dirección I2C: **0x53** (ALT ADDRESS alto) o **0x1D** (ALT ADDRESS bajo).
- Voltaje de operación: 2,0–3,6 V. Consumo: 23 µA (medición), 0,1 µA
  (standby).
- Registro DEVID (`0x00`) devuelve 0xE5 para identificación del dispositivo.

## 3. Conexiones

| ADXL345 | Arduino Uno |
| --- | --- |
| VCC | 3,3 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| CS | VCC (para modo I2C) |
| SDO | GND (para dirección 0x53) |

Los pull-ups I2C suelen estar presentes en las placas de breakout comunes;
de lo contrario, usar 4,7 kΩ en SDA/SCL hacia VCC. El pin CS debe estar
en alto para activar el modo I2C. SDO determina la dirección: GND → 0x53,
VCC → 0x1D.

## 4. Clase y API

`FirmataADXL345` extiende `FirmataI2CDevice` (paquete `Firmata-I2C`).

- Inicialización: `initializeDevice` (establece el bit measure en el
  registro `POWER_CTL`), `registerWithFirmata` (¡después del cableado!).
- Configuración del sensor: `setAccelerationRange:` (0–3 ↔ ±2/4/8/16 g),
  `setSampleRate:` (0x00–0x0F para 0,1 Hz a 3200 Hz).
- Lectura: `startReadingPort` (continuo) o `readOnce` (muestra única).
- Salidas brutas: `accelX`/`accelY`/`accelZ` (16 bits little-endian con signo).
- Salidas escaladas: `scaledAccelX`/`scaledAccelY`/`scaledAccelZ` (en g)
  — valor bruto dividido por 256,0 (sensibilidad fija de resolución completa).
- Sensibilidad y rango: `accelSensitivity` (256 LSB/g, fija),
  `accelRange` (índice de rango actual), `sampleRate` (código actual).
- Recepción: `handleI2CReply:data:` procesa la respuesta de 6 bytes del Arduino.
- Helpers heredados (`FirmataI2CDevice`): `firmata:address:`,
  `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.

`FirmataADXL345Constants` (lado de clase) contiene los registros
(`dataFormatRegister` 0x31, `bandwidthRateRegister` 0x2C,
`powerControlRegister` 0x2D, `dataX0Register` 0x32, `deviceIdRegister` 0x00),
bits (`fullResolutionBit`, `measureBit`), especificación
(`accelSensitivity` 256, `deviceIdValue` 0xE5, `sensorOutputByteCount` 6)
y valores predeterminados (`defaultAddress` 0x53, `defaultAccelRange` 0,
`defaultSampleRate` 0x0A).

## 5. Ejemplo

```smalltalk
| bus sensor |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

sensor := FirmataADXL345 new.
sensor firmata: bus address: FirmataADXL345Constants defaultAddress.
sensor initializeDevice.
sensor registerWithFirmata.

"Configurar rango y tasa (opcional)"
sensor setAccelerationRange: 1.    "±4 g"
sensor setSampleRate: 16r0B.       "200 Hz"

"Iniciar transmisión continua"
sensor startReadingPort.

"... después de algunos pasos:"
sensor accelZ.                     "valor LE-16-bit Z bruto"
sensor scaledAccelZ.               "aceleración Z en g"

"Alternativamente leer una muestra individual:"
sensor readOnce.

"Detener transmisión:"
sensor stopReading.
```

## 6. Notas

- **Los valores brutos son little-endian y con signo** (16 bits). El LSB está
  en el primer registro (`DATAX0`), el MSB en el segundo (`DATAX1`). Esto
  difiere del MPU6050 (big-endian).
- **Modo de resolución completa (full_res):** Siempre activo — la sensibilidad
  permanece fija en 256 LSB/g sin importar el rango seleccionado. El rango
  solo determina el alcance máximo.
- **Escalado:** `scaled*` = bruto / 256,0. Ejemplo: `scaledAccelZ :=
  accelZ / 256.0`.
- **Cambio de rango** (`setAccelerationRange:`) escribe bits 0–1 del
  registro `DATA_FORMAT`. El bit de resolución completa (bit 3) permanece
  activo.
- **Estabilización tras activación:** Después de encender o ejecutar
  `initializeDevice`, esperar un momento; el sensor necesita unos
  milisegundos para estabilizarse.
- **Verificación DEVID:** El registro `DEVID` (`0x00`) debe devolver `0xE5`.
  Si no lo hace, hay un error de comunicación.
- **Varios sensores:** Conectar SDO a VCC para dirección 0x1D y registrar
  una segunda instancia de `FirmataADXL345` en la misma conexión
  `FirmataI2C`.
