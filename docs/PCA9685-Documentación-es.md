# PCA9685 — driver PWM/servo de 16 canales

Contenido:
1. Resumen
2. Datos técnicos
3. Cableado
4. Clases y API
5. Ejemplo
6. Notas

---

## 1. Resumen

El **PCA9685** (NXP) es un driver PWM de 16 canales en el bus I2C. Cada uno de
los 16 canales produce una señal PWM de 12 bits (4096 pasos por período) y puede
manejar servos, LED, controladores de motor u otras cargas controladas por
pulsos. Con varios circuitos en cascada puede incluso manejar hasta 64 salidas.

El paquete `Firmata-PCA9685` envuelve el circuito tras una conexión `FirmataI2C`:
el acceso a los registros pasa por el Arduino (I2C SYSEX), y el helper de servos
`setServoOnChannel:angle:` convierte ángulos en anchos de pulso.

## 2. Datos técnicos

- 16 canales PWM independientes, resolución de 12 bits (0–4095).
- Oscilador interno: 25 MHz; frecuencia PWM programable (típicamente 40–1000 Hz,
  valor por defecto 50 Hz; el rango útil lo fija la resolución del prescaler).
- Dirección esclava I2C: **0x40** con los pines de dirección A0–A5 a masa (vía
  `FirmataPCA9685Constants defaultAddress`), hasta 62 direcciones.
- Los valores desde **4096** en adelante fuerzan «totalmente encendido»; los
  valores negativos apagan el canal.
- Canales individuales: registros de fase ON/OFF (4 registros por canal desde 0x06).

## 3. Cableado

| PCA9685 | Arduino |
| --- | --- |
| VCC | 3,3 V (o 5 V en placas compatibles con niveles lógicos) |
| GND | GND (común con Arduino y con la alimentación de salidas) |
| SDA | A4 (Uno) / 20 (Mega) — el pin de la placa StandardFirmata |
| SCL | A5 (Uno) / 21 (Mega) |
| V+ (si existe) | alimentación externa para las salidas (¡servos!) |
| A0–A5 | masa para la dirección 0x40; si no, otra dirección |

Para servos, alimenta la **tensión de servos por separado** (5 V, ¡suficiente
corriente!) y conecta todas las masas. Los pull-ups I2C están presentes en la
mayoría de las placas de expansión.

## 4. Clases y API

`FirmataPCA9685` hereda de `FirmataI2CDevice` (paquete `Firmata-I2C`).

- Inicialización: `initialize`, `initializeDevice` (define Mode1/Mode2, activa el
  autoincremento de registros, programa la frecuencia PWM según `frequency` y
  apaga todas las salidas).
- PWM: `setPWMOnChannel:value:`, `setAllPWM:`, `setFrequency:`,
  `prescaleForFrequency:`.
- Servos: `setServoOnChannel:angle:`,
  `setServoOnChannel:angle:minPulse:maxPulse:`,
  `pwmCountsForServoAngle:minPulse:maxPulse:`, `pwmCountsForMicroseconds:`.
- Acceso: `frequency` / `frequency:`, `numberOfChannels`.
- Ayudantes heredados (`FirmataI2CDevice`): `firmata:address:`,
  `registerWithFirmata`, `writeRegister:data:`, `readRegister:byteCount:`,
  `readRegisterContinuously:byteCount:`, `stopReading`.
- `handleI2CReply:data:` está deliberadamente vacío aquí (circuito de solo
  escritura).

`FirmataPCA9685Constants` (lado de clase) contiene los registros (p. ej.
`mode1Register`, `mode2Register`, `preScaleRegister`, `led0OnLowRegister`,
`allLedOnLowRegister`, `allLedOffLowRegister`), los bits de modo (`sleepBit`,
`restartBit`, `mode1Default` = 0x20 autoincremento, `mode2Default`) y la
especificación
(`numberOfChannels` = 16, `resolutionSteps` = 4096,
`oscillatorFrequency` = 25 MHz, `channelRegisterStep` = 4) además de los valores
por defecto (`defaultAddress` = 0x40, `defaultFrequency` = 50 Hz,
`defaultMinPulseMicroseconds` = 544, `defaultMaxPulseMicroseconds` = 2400).

## 5. Ejemplo

```smalltalk
| bus driver |
bus := FirmataI2C new.
bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
bus isFirmataInstalled.
bus i2cConfig.

driver := FirmataPCA9685 new.
driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
driver initializeDevice.                     "modos, autoincremento, 50 Hz"

driver setPWMOnChannel: 0 value: 2048.      "LED canal 0: media intensidad"
driver setPWMOnChannel: 1 value: -1.        "canal 1 apagado"
driver setAllPWM: 0.                        "todo apagado"

"Servo en el canal 2 a 90 grados"
driver setServoOnChannel: 2 angle: 90.

"Servo con rango de pulso personalizado (500 us .. 2500 us)"
driver setServoOnChannel: 3 angle: 30 minPulse: 500 maxPulse: 2500.

"Una frecuencia PWM distinta (60 Hz) se programa igual"
driver setFrequency: 60.
```

## 6. Notas

- **`initializeDevice` es necesario una vez:** sin él, el bit de autoincremento
  de MODE1 está apagado, de modo que una escritura de registro que lleva el byte
  de fase bajo *y* alto (cada `setPWMOnChannel:value:` y
  `setServoOnChannel:angle:`) pierde su byte alto en el circuito y el canal recibe
  un pulso demasiado corto — los servos simplemente no se mueven. También
  programa el oscilador, porque el chip arranca con prescaler 30 (~196,9 Hz)
  mientras los recuentos se calculan para `frequency`.
- **Rango de valores:** 0–4095 fija el par de fases ON/OFF; ≥ 4096 = totalmente
  encendido, < 0 = totalmente apagado.
- **Cambio de frecuencia** pasa por dormir–prescaler–despertar–reiniciar; usa
  `setFrequency:` en lugar del acceso directo a registros. Entre
  `initializeDevice` y la primera llamada a `setFrequency:` el servo no se mueve
  correctamente; llama a `setFrequency:` solo para cambiar la frecuencia después.
- **Limitación de ángulo:** `setServoOnChannel:angle:` limita a 0–180°; el ancho
  de pulso sigue linealmente entre `minPulse` y `maxPulse` (por defecto
  544/2400 µs, la convención de servos de StandardFirmata).
- **Solo escritura:** el circuito solo se escribe; `handleI2CReply:data:`
  permanece vacío y no se lee nada.
- **Varios circuitos:** configura los pines de dirección A0–A5; registra una
  instancia `FirmataPCA9685` por circuito en la misma conexión `FirmataI2C`.
