# Firmata para Cuis-Smalltalk

Contenido:
1. ¿Qué es Firmata?
2. Requisitos e instalación
3. Conexión y procesamiento en segundo plano
4. Resumen de la API
5. Guía de uso con ejemplos
6. Cómo añadir un nuevo dispositivo I2C
7. Notas y trampas específicas de Cuis

---

## 1. ¿Qué es Firmata?

Firmata es un método abierto, basado en protocolo, para controlar un
microcontrolador (por ejemplo, una placa Arduino) desde un ordenador anfitrión.
En el Arduino se ejecuta el firmware **StandardFirmata**; el anfitrión (aquí una
imagen de Cuis-Smalltalk) envía comandos compactos de bytes a través de una
conexión serie (USB) o una red TCP/IP, y el Arduino responde con lecturas y
mensajes de estado. La interfaz es siempre la misma, independientemente de qué
pines o dispositivos I2C estén conectados.

El protocolo trabaja con valores de 7 bits: cada número se transmite como un par
LSB/MSB. Las extensiones complejas (como I2C) usan el mecanismo SYSEX: un mensaje
empieza con `START_SYSEX` (`0xF0`) y termina con `END_SYSEX` (`0xF7`). Este
paquete implementa el estándar completo, incluidos los comandos I2C SYSEX.

## 2. Requisitos e instalación

**En el Arduino** (IDE de Arduino, biblioteca *Firmata* de la comunidad de
Smalltalk):

- `StandardFirmata` para USB/serie.
- `StandardFirmataEthernet` o `StandardFirmataWiFi` para funcionamiento por red.
- Para lógica de firmware propia: `ConfigurableFirmata` (todos los ejemplos y
  pruebas de este proyecto están ajustados byte a byte a estos bocetos).

**En Cuis-Smalltalk**, carga los paquetes con el navegador de paquetes o con:

```smalltalk
Feature require: #'Firmata'.            "protocolo básico (puerto serie)"
Feature require: #'Firmata-I2C'.        "soporte I2C"
Feature require: #'Firmata-PCA9685'.    "driver PWM/servo de 16 canales PCA9685"
Feature require: #'Firmata-MPU6050'.    "IMU MPU6050"
Feature require: #'Firmata-Servo'.      "control de servos de alto nivel (velocidad, rangos)"
Feature require: #'Firmata-Net'.        "transporte TCP/IP (requiere Network-Kernel)"
```

Las dependencias se resuelven automáticamente. Para `Firmata-Net` debe estar
instalado el paquete `Network-Kernel` (secuencia anterior: primero
`Network-Kernel`, después `Firmata-Net`).

**Cableado básico:** masa común para todas las señales; para I2C además
resistencias pull-up (típicamente 4,7 kΩ) de `SDA`/`SCL` a `VCC` — la mayoría de
las placas de expansión ya las traen.

## 3. Conexión y procesamiento en segundo plano

Cada clase de conexión (`Firmata`, `FirmataI2C`, `FirmataNet`, `FirmataNetI2C`)
contiene un `port` (el transporte de bytes) y un proceso en segundo plano que
consulta la conexión continuamente:

- `connectOnPort:baudRate:` — conexión serie (clases `Firmata`, `FirmataI2C`).
- `connectToHost:port:` — conexión TCP/IP (clases `FirmataNet`, `FirmataNetI2C`).
- `startSteppingProcess` — inicia el consultador; se llama automáticamente al
  conectar.
- `step` / `stepTime` — un paso de consulta, respectivamente su intervalo en
  milisegundos. `step` lee todos los bytes pendientes mediante `processInput`.
  Un error de lectura establece `port := nil`, lo que marca la conexión como
  cerrada y detiene el proceso en segundo plano por sí mismo.
- `stopSteppingProcess` — detiene el consultador (lo llama `disconnect`).
- `disconnect` — detiene el consultador, cierra el puerto, pone `port := nil` y
  restablece el estado del protocolo. Es seguro llamarlo varias veces.
- `isConnected` — `^port notNil`.
- `isFirmataInstalled` — envía consultas de versión hasta que llega una respuesta
  (máximo 5 segundos).

## 4. Resumen de la API

### `Firmata` — protocolo básico (paquete `Firmata`)

- Ciclo de vida/conexión: `connectOnPort:baudRate:`, `disconnect`, `isConnected`,
  `controlConnection`, `controlFirmataInstallation`.
- Proceso en segundo plano: `startSteppingProcess`, `step`, `stepTime`,
  `stopSteppingProcess`.
- Recepción: `processInput`, `parseCommandHeader:`, `parseData:`, `parseSysex:`,
  `parsingSysex`.
- Estado: `isFirmataInstalled`, `version`, `majorVersion`, `minorVersion`,
  `nameSymbol`, `port`.
- Modos de pin: `pin:mode:` (y `valueForInputMode`, `valueForOutputMode`,
  `valueForPwmMode`, `valueForServoMode`), `digitalPin:mode:`.
- Pines digitales: `digitalWrite:value:`, `digitalRead:`, `analogWrite:value:`,
  `digitalPortReport:onOff:`, `activateDigitalPort:`, `deactivateDigitalPort:`,
  `setDigitalInputs:data:`.
- Pines analógicos: `analogRead:`, `analogPinReport:onOff:`,
  `activateAnalogPin:`, `deactivateAnalogPin:`, `setAnalogInput:value:`.
- Servos: `attachServoToPin:`, `detachServoFromPin:`, `servoOnPin:angle:`,
  `servoConfig:minPulse:maxPulse:angle:`.
- Otros comandos: `queryVersion`, `queryFirmware`, `reportFirmware`,
  `systemReset`, `startSysex`, `endSysex`, `firmataString`, `sysexNonRealtime`,
  `sysexRealtime`.
- Inicialización: `initialize`, `initializeVariables`.

### `FirmataConstants` (paquete `Firmata`)

Métodos de clase para los números del protocolo: `analogMessage`,
`digitalMessage`, `reportAnalog`, `reportDigital`, `reportVersion`,
`setPinMode`, `startSysex`, `endSysex`, `systemReset`, `maxDataBytes`, etc.

### `FirmataI2C` — capa I2C (paquete `Firmata-I2C`)

Extiende `Firmata` con los mensajes I2C SYSEX:

- `i2cConfig` / `i2cConfigDelay:` — fija el retardo entre una petición I2C y la
  interrupción de respuesta (por defecto 0 µs).
- `i2cRequestWrite:register:data:` — escribe datos a un registro del esclavo.
- `i2cRequestRead:register:byteCount:` — lee una vez.
- `i2cRequestReadContinuously:register:byteCount:` — lectura continua (el Arduino
  envía automáticamente en cada cambio).
- `i2cStopReading:` — detiene la lectura continua.
- Registro de dispositivos: `registerI2CDevice:`, `registeredDeviceFor:`.
- Procesamiento SYSEX: `parseSysex:`, `dispatchSysexMessageOfLength:`,
  `parseI2CReplyOfLength:`.

### `FirmataI2CDevice` — base abstracta de dispositivos (paquete `Firmata-I2C`)

- Cableado: `firmata:address:`, `registerWithFirmata`.
- Operaciones I2C: `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.
- Acceso: `address`, `address:`, `firmata`, `firmata:`.
- Responsabilidad de las subclases: `initializeDevice` (configurar el dispositivo
  en el bus) y `handleI2CReply:data:` (procesar respuestas).

### `FirmataNet` / `FirmataNetI2C` — TCP/IP (paquete `Firmata-Net`)

- `connectToHost:` / `connectToHost:port:` — conexión a un Arduino
  StandardFirmataEthernet/-WiFi; `defaultPort` (por defecto 3030).
- `FirmataNetI2C` combina capacidad de red e I2C (para las clases de dispositivos
  I2C en modo red).
- `FirmataNetPort` envuelve un `SocketStream` como transporte de bytes y conoce
  `readByteArray`, `nextPutAll:`, `close`, `isConnected`.
- `FirmataNetConstants` — valores por defecto de red (puerto por defecto).

## 5. Guía de uso con ejemplos

### 5.1 Conexión serie y comprobación de versión

```smalltalk
| firmata |
firmata := Firmata new.
firmata connectOnPort: '/dev/ttyACM0' baudRate: 57600.
firmata isFirmataInstalled.          "true cuando el intercambio funciona"
firmata version.                     "por ejemplo 2.5 (StandardFirmata)"
```

### 5.2 Salidas digitales (LED)

```smalltalk
"Pin 13 como salida y encenderlo"
firmata digitalPin: 13 mode: 1.      "OUTPUT = 1"
firmata digitalWrite: 13 value: 1.
```

> El valor del modo de pin es un byte del protocolo. Los ayudantes de alto nivel
> `pin:mode:` aceptan el modo numérico del boceto de Arduino (`INPUT = 0`,
> `OUTPUT = 1`, `ANALOG = 2`, `PWM = 3`, `SERVO = 4`).

### 5.3 Entradas digitales (botón) y lecturas analógicas

```smalltalk
firmata digitalRead: 2.                  "0 o 1"
firmata analogRead: 0.                   "valor de 10 bits 0..1023"
firmata analogPinReport: 0 onOff: 1.     "activa el informe analógico"
firmata digitalPortReport: 0 onOff: 1.   "activa el informe digital"
```

### 5.4 Servos

```smalltalk
firmata attachServoToPin: 9.
firmata servoOnPin: 9 angle: 90.
firmata servoOnPin: 9 angle: 45.
firmata detachServoFromPin: 9.
```

Para el control de alto nivel con velocidad, rangos de montaje y servos de
180°/270° (pin o PCA9685), usa el paquete `Firmata-Servo`, véase
[Servo-Documentación-es.md](Servo-Documentación-es.md).

### 5.5 Uso de un dispositivo I2C (ejemplo PCA9685)

```smalltalk
| firmata pwm |
firmata := FirmataI2C new.
firmata connectOnPort: '/dev/ttyACM0' baudRate: 57600.
firmata isFirmataInstalled.
firmata i2cConfig.
pwm := FirmataPCA9685 new firmata: firmata address: 0x40.
pwm registerWithFirmata.                "registra el dispositivo en el bus"
pwm setFrequency: 50.                   "50 Hz (20 ms por canal)"
pwm setPWMOnChannel: 0 value: 128.      "ciclo de trabajo 128/4096"
pwm setServoOnChannel: 1 angle: 90.     "servo en el canal 1 a 90°"
```

### 5.6 Conexión por red

```smalltalk
| firmataNet |
firmataNet := FirmataNet new.
firmataNet connectToHost: '192.168.1.100' port: 3030.
firmataNet isFirmataInstalled.
firmataNet digitalWrite: 13 value: 1.
```

### 5.7 Limpieza

```smalltalk
firmata disconnect.       "detiene el consultador y cierra el puerto"
```

## 6. Cómo añadir un nuevo dispositivo I2C

Así se integra otro componente I2C (los dos ejemplos existentes son
`FirmataPCA9685` y `FirmataMPU6050`):

1. **Crea un paquete nuevo** `Firmata-<Dispositivo>` (fuente: `.pck.st`, cargada
   con `Feature require:`), con `!requires: 'Firmata-I2C' 1 nil 1!` y una
   categoría `'Firmata-<Dispositivo>'`.

2. **Modela la clase del dispositivo:** subclase de `FirmataI2CDevice`
   (`FirmataI2CDevice subclass: #Firmata<Dispositivo> ...`) con las variables de
   instancia necesarias, más una clase de constantes
   `Firmata<Dispositivo>Constants` para direcciones de registro, valores por
   defecto y bits de modo.

3. **Implementa los métodos obligatorios:**
   - `defaultAddress` — la dirección esclava I2C (lado de clase `defaults`).
   - `initializeDevice` — configuración del chip mediante escrituras de registro
     (`writeRegister:data:`).
   - `handleI2CReply:data:` — interpretar las lecturas entrantes y guardarlas en
     las variables de instancia del dispositivo.
   - `registerWithFirmata` se llama tras el cableado y registra el dispositivo
     para su dirección mediante `firmata registerI2CDevice: self`.

4. **Añade la interfaz pública**, por ejemplo `setPWMOnChannel:value:`,
   `setServoOnChannel:angle:`, `readOnce`, `startReading`, `scaledAccelX`, etc.

5. **Opciones de configuración como valores por defecto de clase** (`defaults`).

6. **Escribe las pruebas** (paquete `Tests-Firmata-<Dispositivo>`) — convenciones
   de este proyecto:
   - Un `FirmataNetStreamMock`/mock serie alimenta al analizador exactamente con
     los bytes que envía un Arduino real (pares de 7 bits LSB/MSB, SYSEX).
   - Aserciones byte a byte: se compara el array de bytes (SYSEX) enviado.
   - `TestCase` usa la categoría `'testing'` para los métodos de prueba; los
     ayudantes van a `'support'`.
   - Ejecuta la suite en el ejecutor sin cabecera (headless).

7. **Amplía la documentación** en la carpeta `docs/` (véase README).

## 7. Notas y trampas específicas de Cuis

- **Convención del par de 7 bits:** los números viajan como pares LSB/MSB (byte
  bajo primero). `parseData` guarda el byte 1 en la ranura 2 y el byte 2 en la
  ranura 1 (índice 1 = primer byte leído). No intercambies nunca el orden al
  analizar manualmente — un error antiguo leía `REPORT_VERSION` al revés (la
  versión 2.5 aparecía como 5.2).
- **Pruebas sin cabecera (`-vm-display-null`):** `FileEntry>>writeStreamDo:`
  pregunta (“Overwrite?”) cuando el archivo ya existe y cuelga la ejecución.
  Usa `forceWriteStreamDo:` para las salidas. Además, las clases no deben
  referenciarse antes de instalarse (Undeclared → `UndefinedObject>>new`); en los
  scripts que instalan, usa `Smalltalk classNamed:`.
- **Registro de dispositivos:** un dispositivo I2C solo es direccionable después
  de `registerWithFirmata`; las respuestas sin registro se descartan.
- **Comportamiento ante errores:** un error de lectura en el consultador pone
  `port := nil`; cualquier llamada posterior a través del acceso `port` lanzará
  “Serial port is not connected”. Llama de nuevo a `connectOnPort:...` (o
  `connectToHost:port:`) antes de reutilizarlo.

Estado de las pruebas: las 15 suites en verde sin cabecera
(`passed=221 failures=0 errors=0`, 2026-09-24, Cuis 7.8 #7977).
