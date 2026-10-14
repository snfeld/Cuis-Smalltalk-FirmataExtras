# MCP23017 – Expansor de E/S de 16 bits

Contenido:
1. Descripción general
2. Datos técnicos
3. Cableado
4. Clase y API
5. Ejemplo
6. Notas

---

## 1. Descripción general

El **MCP23017** (Microchip) es un expansor de E/S de 16 bits por I2C con dos
puertos de 8 bits, GPIOA (pines 0–7) y GPIOB (pines 8–15). Cada pin se
configura individualmente como entrada o salida mediante los registros de
dirección IODIR, dispone de una resistencia de pull-up interna opcional a
través de GPPU y se escribe o lee mediante los registros de enganche GPIO.

El paquete `Firmata-MCP23017` envuelve el expansor detrás de una conexión
`FirmataI2C`. Los ajustes de dirección, pull-up y salida se mantienen en
bytes espejo en el lado Smalltalk, de modo que las operaciones por pin solo
modifican el bit afectado y luego reescriben el byte de puerto completo al
chip. Las lecturas usan el formato de lectura I2C basado en registros, que
StandardFirmata atiende sin tocar el estado del puerto.

## 2. Datos técnicos

- 16 pines de E/S en dos puertos de 8 bits: GPIOA (pines 0–7) y GPIOB
  (pines 8–15).
- Dirección mediante IODIRA/IODIRB: un bit a `0` selecciona salida, un bit a
  `1` selecciona entrada.
- Pull-ups internos (≈100 kΩ) por pin mediante GPPUA/GPPUB.
- Tensión de alimentación: **1,8 V – 5,5 V**.
- Corriente sink/source: **25 mA por pin**.
- Rango de direcciones I2C: **0x20 – 0x27** (3 pines de dirección A0–A2;
  todos a masa = 0x20).
- Valor por defecto de arranque: todos los pines en entrada, pull-ups
  desactivados y enganches de salida leyendo `1`.
- Salida INT: drenador abierto, activa en nivel bajo (no usada en este
  paquete).

## 3. Cableado

| MCP23017 | Arduino Uno |
| --- | --- |
| VCC | 5 V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |
| A0 | GND (dirección 0x20) |
| A1 | GND (dirección 0x20) |
| A2 | GND (dirección 0x20) |
| GPA0–GPA7 | pines GPIOA |
| GPB0–GPB7 | pines GPIOB |

Para un segundo expansor en el mismo bus, ajuste los pines de dirección en
consecuencia, p. ej. A0 → VCC para 0x21. Utilice resistencias de pull-up de
4,7 kΩ en SDA/SCL hacia VCC si la placa no las incluye.

## 4. Clase y API

`FirmataMCP23017` extiende `FirmataI2CDevice` (paquete `Firmata-I2C`).

- Inicialización: `initializeDevice` (escribe IODIRA/B = 0xFF y GPPUA/B =
  0x00), `registerWithFirmata` (¡después de cablear!), `addressWithAddressPins:`.
- Operaciones de pin: `setPinMode:value:` (pin 0–15; `true` = salida),
  `digitalWritePin:value:` (pin de salida), `digitalReadPin:` (pin de
  entrada), `setPullUpPin:value:` (pull-up interno on/off).
- Operaciones de puerto: `writePort:value:` (8 pines GPIOA o GPIOB a la vez),
  `readPort:` (0 = GPIOA, 1 = GPIOB), `startReadingPort:` (sondeo continuo),
  `stopReading` (detiene el flujo).
- Callback: `handleI2CReply:data:` (procesa los datos `I2C_REPLY` entrantes y
  actualiza los valores de entrada del puerto).
- Acceso: `inputValueForPort:`, `outputValueForPort:`, `directionA`,
  `directionB`.

`FirmataMCP23017Constants` (lado de clase) contiene el mapa de registros
(`iodirARegister` 0x00, `iodirBRegister` 0x01, `gppuARegister` 0x0C,
`gppuBRegister` 0x0D, `gpioARegister` 0x12, `gpioBRegister` 0x13) y la
especificación (`pinCount` 16, `portPinCount` 8, `portCount` 2,
`baseAddress`/`defaultAddress` 0x20, `addressCount` 8).

## 5. Ejemplo

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

"Pin 0 de GPIOA como salida, mantenido bajo"
expander setPinMode: 0 value: true.
expander digitalWritePin: 0 value: false.

"Pin 8 (entrada GPIOB) con pull-up interno"
expander setPinMode: 8 value: false.
expander setPullUpPin: 8 value: true.

"Escribir los ocho pines GPIOA de una vez"
expander writePort: 0 value: 16r55.

"Leer GPIOA y un pin individual"
expander readPort: 0.
expander inputValueForPort: 0.      "último byte GPIOA leído"
expander digitalReadPin: 1.         "true si el pin 1 está alto"

"Flujo continuo de GPIOB"
expander startReadingPort: 1.
expander stopReading.
```

## 6. Notas

- **Significado de los bits de dirección:** en los registros IODIR, un bit a
  `0` significa salida y un bit a `1` significa entrada. `setPinMode:value:`
  lo oculta: pase `true` para salida y `false` para entrada.
- **Bytes espejo:** `directionA/B` y los enganches de salida se mantienen
  como bytes en la imagen. `setPinMode:`, `digitalWritePin:` y
  `setPullUpPin:` solo modifican el bit afectado y reescriben el byte de
  puerto completo, de modo que las configuraciones mixtas siguen siendo
  coherentes sin releer el chip.
- **Numeración de pines:** los pines 0–7 están en GPIOA, los pines 8–15 en
  GPIOB. Las ayudas privadas `portForPin:` y `bitForPin:` asignan un índice
  de pin a su puerto y bit.
- **Lectura de GPIO:** `readPort:` lee el registro GPIOA/GPIOB mediante el
  formato de lectura I2C basado en registros (StandardFirmata ≥ 2.5), que no
  altera el estado del puerto. En las entradas, el valor refleja el nivel del
  pin; en las salidas, el valor del enganche pilotado.
- **Varios chips:** hasta 8 MCP23017 en el mismo bus I2C mediante los pines
  de dirección. Registre una instancia `FirmataMCP23017` distinta por chip y
  calcule la dirección con `FirmataMCP23017 addressWithAddressPins:`.
- **Alimentación:** 25 mA por pin es el límite del chip; pilote cargas
  mayores mediante etapas de salida o transistores externos.
