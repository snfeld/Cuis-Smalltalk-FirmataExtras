# PCF8574 – Expansor de E/S de 8 bits

Contenido:
1. Resumen
2. Datos técnicos
3. Conexiones
4. Clase y API
5. Ejemplo
6. Notas

---

## 1. Resumen

El **PCF8574** (NXP/Texas Instruments) es un expansor de E/S de 8 bits
cuasi-bidireccional comunicado por I2C. A diferencia de sensores basados en
registros, **no hay direccionamiento de registros** — una única operación de
escritura o lectura de un byte controla todo el puerto (8 pines).

Cada pin es cuasi-bidireccional: escribir `1` configura el pin como entrada
con pull-up interno débil; escribir `0` activa el pin como salida en nivel
bajo. Para leer entradas, primero se deben establecer todos los pines en `1`
antes de leer el puerto.

El paquete `Firmata-PCF8574` encapsula el expansor detrás de una conexión
`FirmataI2C`. El método `readPort` utiliza un formato de lectura I2C sin
registro (StandardFirmata ≥ 2.5) para evitar corromper el estado del puerto.

## 2. Datos técnicos

- Pines E/S cuasi-bidireccionales de 8 bits: sin direccionamiento de
  registros, un solo byte controla todo el puerto.
- Voltaje de operación: **2,6 V – 6 V**.
- Consumo de energía: **100 µA** máx.
- Corriente de sink: **25 mA por pin**.
- Rango de dirección I2C: **0x20 – 0x27** (3 pines de dirección A0–A2;
  todos en bajo = 0x20).
- Valor por defecto al encender: todos los pines en alto (modo entrada).
- Salida INT: open-drain, activo en bajo (no se utiliza en este paquete).

## 3. Conexiones

| PCF8574 | Arduino Uno |
| --- | --- |
| VCC | 5 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| A0 | GND (dirección 0x20) |
| A1 | GND (dirección 0x20) |
| A2 | GND (dirección 0x20) |
| P0–P7 | Pines de E/S |

Para un segundo expansor en el mismo bus I2C, conectar A0 a VCC (dirección
0x21). Usar pull-ups de 4,7 kΩ en SDA/SCL a VCC si no están presentes en
la placa de breakout.

## 4. Clase y API

`FirmataPCF8574` hereda de `FirmataI2CDevice` (paquete `Firmata-I2C`).

- Inicialización: `initializeDevice` (configura los ajustes I2C),
  `registerWithFirmata` (¡después de las conexiones!).
- Escritura: `writePort:` (envía un byte de 8 bits a todo el puerto),
  `digitalWritePin:value:` (establece un pin individual; lee el estado
  actual del puerto y modifica solo el bit afectado).
- Lectura: `readPort` (lectura I2C sin registro; resultado en `inputValue`),
  `digitalReadPin:` (devuelve `true`/`false` para el pin especificado).
- Streaming: `startReadingPort` (inicia sondeo continuo a través del paso
  Firmata), `stopReading` (detiene el stream).
- Callback: `handleI2CReply:data:` (procesa los datos entrantes de
  `I2C_REPLY` y actualiza `inputValue`/`outputValue`).

`FirmataPCF8574Constants` (lado de clase) contiene `portRegister` (0),
`pinCount` (8), `defaultAddress` (0x20), `allPinsHigh` (0xFF).

## 5. Ejemplo

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

"Configurar todos los pines como entradas"
expander writePort: 16rFF.

"Pins 0–3 como salidas (bajo), pins 4–7 como entradas"
expander writePort: 16r0F.

"Establecer un pin individual"
expander digitalWritePin: 0 value: true.

"Leer el puerto"
expander readPort.
expander inputValue.               "último byte leído del puerto"

"Leer un pin individual"
expander digitalReadPin: 4.         "true si el pin 4 está en alto"

"Iniciar / detener sondeo continuo"
expander startReadingPort.
expander stopReading.
```

## 6. Notas

- **Pines cuasi-bidireccionales:** Escribir `1` configura un pin como
  entrada con pull-up interno débil. Escribir `0` activa el pin como salida
  en nivel bajo. No hay registros de dirección o configuración como en otros
  expansores de E/S.
- **Lectura de entradas:** Antes de leer, todos los pines deben establecerse
  en `1` (`writePort: 16rFF`), de lo contrario los pines mantendrán el nivel
  bajo del último valor de salida y no será posible obtener una señal de
  entrada correcta.
- **Lectura sin registro:** El método `readPort` utiliza un formato de
  lectura I2C sin registro (StandardFirmata ≥ 2.5, argc ≠ 6). Esto evita
  que un byte de registro enviado accidentalmente corrompa el estado del
  puerto.
- **Múltiples dispositivos:** Hasta 8 PCF8574 en el mismo bus I2C mediante
  diferentes direcciones (A0–A2). Registrar una instancia separada de
  `FirmataPCF8574` para cada dispositivo.
- **Sin mapa de registros internos:** No hay mapa de registros como en
  dispositivos I2C basados en registros. Cada operación de escritura/lectura
  actúa directamente sobre los 8 pines de E/S.
- **Alimentación:** El PCF8574 consume máximo 100 µA; para cargas más altas
  (hasta 25 mA de sink) usar etapas de driver externas.
