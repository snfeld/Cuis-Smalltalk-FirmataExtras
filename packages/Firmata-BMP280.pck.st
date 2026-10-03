'From Cuis7.8 [latest update: #7977] on 3 October 2026 at 5:00:54 pm'!
'Description '!
!provides: 'Firmata-BMP280' 1 1!
!requires: 'Firmata-I2C' 1 1 nil!
SystemOrganization addCategory: #'Firmata-BMP280'!


!classDefinition: #FirmataBMP280Constants category: #'Firmata-BMP280'!
Object subclass: #FirmataBMP280Constants
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-BMP280'!
!classDefinition: 'FirmataBMP280Constants class' category: #'Firmata-BMP280'!
FirmataBMP280Constants class
	instanceVariableNames: ''!

!classDefinition: #FirmataBMP280 category: #'Firmata-BMP280'!
FirmataI2CDevice subclass: #FirmataBMP280
	instanceVariableNames: 'calibrationData rawTemperature rawPressure chipId'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-BMP280'!
!classDefinition: 'FirmataBMP280 class' category: #'Firmata-BMP280'!
FirmataBMP280 class
	instanceVariableNames: ''!


!FirmataBMP280Constants commentStamp: 'sf 17/Sep/2026' prior: 0!
See class side. I collect the BMP280 register map, configuration values and specification constants from the Bosch BMP280 datasheet.!

!FirmataBMP280 commentStamp: 'sf 17/Sep/2026' prior: 0!
I control a Bosch BMP280 barometric pressure and temperature sensor through a FirmataI2C connection. The chip exposes a 20 bit pressure and a 20 bit temperature measurement and a block of factory calibration coefficients.

Typical use:
	bus := FirmataI2C new.
	bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
	sensor := FirmataBMP280 new.
	sensor firmata: bus address: FirmataBMP280Constants defaultAddress.
	sensor initializeDevice.
	sensor registerWithFirmata.
	sensor startReadingPort.
	sensor rawPressure        "raw 20 bit pressure count"
	sensor temperatureCelsius "compensated temperature in C"
	sensor pressureHectoPascal "compensated pressure in hPa"

#initializeDevice sets the oversampling and normal mode and reads the calibration block. Start the stream with #startReadingPort (or do a single #readOnce) and read the values afterwards; every incoming I2C_REPLY overwrites the last sample via #handleI2CReply:data:. The raw counts and the compensation are integer arithmetic following the reference driver from Bosch Sensortec, so the scaled values match the datasheet formulas. #temperatureCelsius answers a Float in degrees Celsius, #pressurePascal an Integer in Pascal and #pressureHectoPascal a Float in hPa. Before the calibration is loaded the compensated values answer nil.

The 20 bit output registers are big-endian (MSB first) and are assembled by shifting the three output bytes right by four bits.!

!FirmataBMP280Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
calibrationRegister
	"0x88 first byte of the 24 byte temperature and pressure calibration block"
	^ 16r88! !

!FirmataBMP280Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
chipIdRegister
	"0xD0 chip identification register answering 0x58"
	^ 16rD0! !

!FirmataBMP280Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
configRegister
	"0xF5 configuration register (standby time, IIR filter, SPI mode)"
	^ 16rF5! !

!FirmataBMP280Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
ctrlMeasRegister
	"0xF4 pressure and temperature measurement control register"
	^ 16rF4! !

!FirmataBMP280Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
dataRegister
	"0xF7 first of the six output bytes: pressure MSB, LSB, XLSB, temperature MSB, LSB, XLSB"
	^ 16rF7! !

!FirmataBMP280Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
resetRegister
	"0xE0 soft reset register"
	^ 16rE0! !

!FirmataBMP280Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
statusRegister
	"0xF3 status register"
	^ 16rF3! !

!FirmataBMP280Constants class methodsFor: 'configuration' stamp: 'sf 17/Sep/2026 00:00:00'!
configValue
	"Configuration register value: standby 0.5 ms, IIR filter off, 4-wire SPI"
	^ 0! !

!FirmataBMP280Constants class methodsFor: 'configuration' stamp: 'sf 17/Sep/2026 00:00:00'!
ctrlMeasValue
	"Oversampling x1 for temperature and pressure, normal mode"
	^ 16r27! !

!FirmataBMP280Constants class methodsFor: 'configuration' stamp: 'sf 17/Sep/2026 00:00:00'!
modeNormal
	"Normal measurement mode value of the mode field"
	^ 3! !

!FirmataBMP280Constants class methodsFor: 'configuration' stamp: 'sf 17/Sep/2026 00:00:00'!
oversamplingX1
	"Oversampling x1 code of the osrs_t, osrs_p and osrs_h fields"
	^ 1! !

!FirmataBMP280Constants class methodsFor: 'specification' stamp: 'sf 17/Sep/2026 00:00:00'!
calibrationByteCount
	"Temperature and pressure calibration bytes (0x88..0x9F)"
	^ 24! !

!FirmataBMP280Constants class methodsFor: 'specification' stamp: 'sf 17/Sep/2026 00:00:00'!
chipIdValue
	"Value returned by the chip identification register"
	^ 16r58! !

!FirmataBMP280Constants class methodsFor: 'specification' stamp: 'sf 17/Sep/2026 00:00:00'!
sensorOutputByteCount
	"Three pressure bytes plus three temperature bytes"
	^ 6! !

!FirmataBMP280Constants class methodsFor: 'defaults' stamp: 'sf 17/Sep/2026 00:00:00'!
defaultAddress
	"I2C slave address 0x76 with the SDO pin low"
	^ 16r76! !

!FirmataBMP280 methodsFor: 'device initialization' stamp: 'sf 17/Sep/2026 00:00:00'!
calibrationByteCount
	"BMP280 reads 24 bytes of temperature and pressure calibration data."
	^ FirmataBMP280Constants calibrationByteCount! !

!FirmataBMP280 methodsFor: 'device initialization' stamp: 'sf 17/Sep/2026 00:00:00'!
initializeDevice
	"Set the configuration and normal measurement mode, then read the calibration block."
	self writeRegister: FirmataBMP280Constants configRegister
		data: (ByteArray with: FirmataBMP280Constants configValue).
	self writeRegister: FirmataBMP280Constants ctrlMeasRegister
		data: (ByteArray with: FirmataBMP280Constants ctrlMeasValue).
	self readCalibration.
	^ self! !

!FirmataBMP280 methodsFor: 'device initialization' stamp: 'sf 17/Sep/2026 00:00:00'!
readCalibration
	"Read the factory calibration coefficients once."
	self readRegister: FirmataBMP280Constants calibrationRegister
		byteCount: self calibrationByteCount.
	^ self! !

!FirmataBMP280 methodsFor: 'device initialization' stamp: 'sf 17/Sep/2026 00:00:00'!
readChipId
	"Read the chip identification register."
	self readRegister: FirmataBMP280Constants chipIdRegister byteCount: 1.
	^ self! !

!FirmataBMP280 methodsFor: 'reading' stamp: 'sf 17/Sep/2026 00:00:00'!
readOnce
	"Read the current pressure and temperature output with a single request."
	self readRegister: FirmataBMP280Constants dataRegister
		byteCount: FirmataBMP280Constants sensorOutputByteCount.
	^ self! !

!FirmataBMP280 methodsFor: 'reading' stamp: 'sf 17/Sep/2026 00:00:00'!
startReadingPort
	"Ask the board to keep streaming the output registers."
	self readRegisterContinuously: FirmataBMP280Constants dataRegister
		byteCount: FirmataBMP280Constants sensorOutputByteCount.
	^ self! !

!FirmataBMP280 methodsFor: 'reply handling' stamp: 'sf 17/Sep/2026 00:00:00'!
handleI2CReply: aRegister data: aByteArray
	"Dispatch an incoming I2C reply to the matching register handler."
	aRegister = FirmataBMP280Constants chipIdRegister
		ifTrue: [ ^ self storeChipId: aByteArray ].
	aRegister = FirmataBMP280Constants calibrationRegister
		ifTrue: [ ^ self storeCalibration: aByteArray ].
	aRegister = FirmataBMP280Constants dataRegister
		ifTrue: [ ^ self storeSensorOutput: aByteArray ]! !

!FirmataBMP280 methodsFor: 'reply handling - private' stamp: 'sf 17/Sep/2026 00:00:00'!
signed16LittleEndianAt: index in: aByteArray
	| value |
	value := self unsigned16LittleEndianAt: index in: aByteArray.
	value >= 16r8000 ifTrue: [ ^ value - 16r10000 ].
	^ value! !

!FirmataBMP280 methodsFor: 'reply handling - private' stamp: 'sf 17/Sep/2026 00:00:00'!
signed8At: index in: aByteArray
	| value |
	value := aByteArray at: index.
	value >= 16r80 ifTrue: [ ^ value - 16r100 ].
	^ value! !

!FirmataBMP280 methodsFor: 'reply handling - private' stamp: 'sf 17/Sep/2026 00:00:00'!
storeCalibration: aByteArray
	"Keep the calibration bytes; shorter answers are ignored."
	aByteArray size >= self calibrationByteCount
		ifFalse: [ ^ self ].
	calibrationData := aByteArray copyFrom: 1 to: self calibrationByteCount! !

!FirmataBMP280 methodsFor: 'reply handling - private' stamp: 'sf 17/Sep/2026 00:00:00'!
storeChipId: aByteArray
	aByteArray isEmpty ifTrue: [ ^ self ].
	chipId := aByteArray first! !

!FirmataBMP280 methodsFor: 'reply handling - private' stamp: 'sf 17/Sep/2026 00:00:00'!
storeSensorOutput: aByteArray
	"Parse pressure and temperature output, overwriting the last sample.
	Replies shorter than the output block are ignored."
	aByteArray size >= FirmataBMP280Constants sensorOutputByteCount
		ifFalse: [ ^ self ].
	rawPressure := self twentyBitValueAt: 1 in: aByteArray.
	rawTemperature := self twentyBitValueAt: 4 in: aByteArray! !

!FirmataBMP280 methodsFor: 'reply handling - private' stamp: 'sf 17/Sep/2026 00:00:00'!
twentyBitValueAt: index in: aByteArray
	"20 bit big-endian value from three bytes: MSB, LSB, XLSB (low nibble)."
	| value |
	value := ((aByteArray at: index) bitShift: 16)
		bitOr: (((aByteArray at: index + 1) bitShift: 8)
			bitOr: (aByteArray at: index + 2)).
	^ value bitShift: -4! !

!FirmataBMP280 methodsFor: 'reply handling - private' stamp: 'sf 17/Sep/2026 00:00:00'!
unsigned16LittleEndianAt: index in: aByteArray
	^ ((aByteArray at: index + 1) bitShift: 8)
		bitOr: (aByteArray at: index)! !

!FirmataBMP280 methodsFor: 'reply handling - private' stamp: 'sf 17/Sep/2026 00:00:00'!
unsigned8At: index in: aByteArray
	^ aByteArray at: index! !

!FirmataBMP280 methodsFor: 'calibration' stamp: 'sf 17/Sep/2026 00:00:00'!
calibrationData
	^ calibrationData! !

!FirmataBMP280 methodsFor: 'calibration' stamp: 'sf 17/Sep/2026 00:00:00'!
isCalibrationLoaded
	^ calibrationData notNil! !

!FirmataBMP280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digP1
	^ self unsigned16LittleEndianAt: 7 in: calibrationData! !

!FirmataBMP280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digP2
	^ self signed16LittleEndianAt: 9 in: calibrationData! !

!FirmataBMP280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digP3
	^ self signed16LittleEndianAt: 11 in: calibrationData! !

!FirmataBMP280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digP4
	^ self signed16LittleEndianAt: 13 in: calibrationData! !

!FirmataBMP280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digP5
	^ self signed16LittleEndianAt: 15 in: calibrationData! !

!FirmataBMP280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digP6
	^ self signed16LittleEndianAt: 17 in: calibrationData! !

!FirmataBMP280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digP7
	^ self signed16LittleEndianAt: 19 in: calibrationData! !

!FirmataBMP280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digP8
	^ self signed16LittleEndianAt: 21 in: calibrationData! !

!FirmataBMP280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digP9
	^ self signed16LittleEndianAt: 23 in: calibrationData! !

!FirmataBMP280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digT1
	^ self unsigned16LittleEndianAt: 1 in: calibrationData! !

!FirmataBMP280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digT2
	^ self signed16LittleEndianAt: 3 in: calibrationData! !

!FirmataBMP280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digT3
	^ self signed16LittleEndianAt: 5 in: calibrationData! !

!FirmataBMP280 methodsFor: 'sensor output' stamp: 'sf 17/Sep/2026 00:00:00'!
chipId
	^ chipId! !

!FirmataBMP280 methodsFor: 'sensor output' stamp: 'sf 17/Sep/2026 00:00:00'!
rawPressure
	^ rawPressure! !

!FirmataBMP280 methodsFor: 'sensor output' stamp: 'sf 17/Sep/2026 00:00:00'!
rawTemperature
	^ rawTemperature! !

!FirmataBMP280 methodsFor: 'compensation' stamp: 'sf 17/Sep/2026 00:00:00'!
compensatedPressure
	"Compensated pressure in Pascal as an Integer, clamped to the sensor range.
	Answers nil until the calibration and a temperature sample are available."
	| tFine var1 var2 var3 var4 pressure |
	tFine := self tFine.
	tFine isNil ifTrue: [ ^ nil ].
	var1 := (tFine quo: 2) - 64000.
	var2 := ((var1 quo: 4) squared quo: 2048) * self digP6.
	var2 := var2 + (var1 * self digP5 * 2).
	var2 := (var2 quo: 4) + (self digP4 * 65536).
	var3 := self digP3 * ((var1 quo: 4) squared quo: 8192) quo: 8.
	var4 := self digP2 * var1 quo: 2.
	var1 := (var3 + var4) quo: 262144.
	var1 := ((32768 + var1) * self digP1) quo: 32768.
	var1 = 0 ifTrue: [ ^ 30000 ].
	pressure := (1048576 - rawPressure - (var2 quo: 4096)) * 3125.
	pressure < 16r80000000
		ifTrue: [ pressure := (pressure * 2) quo: var1 ]
		ifFalse: [ pressure := (pressure quo: var1) * 2 ].
	var1 := self digP9 * ((pressure quo: 8) squared quo: 8192) quo: 4096.
	var2 := (pressure quo: 4) * self digP8 quo: 8192.
	pressure := pressure + ((var1 + var2 + self digP7) quo: 16).
	pressure < 30000 ifTrue: [ ^ 30000 ].
	pressure > 110000 ifTrue: [ ^ 110000 ].
	^ pressure! !

!FirmataBMP280 methodsFor: 'compensation' stamp: 'sf 17/Sep/2026 00:00:00'!
compensatedTemperature
	"Compensated temperature in 0.01 degrees Celsius, clamped to the sensor range.
	Answers nil until the calibration and a temperature sample are available."
	| tFine temperature |
	tFine := self tFine.
	tFine isNil ifTrue: [ ^ nil ].
	temperature := (tFine * 5 + 128) quo: 256.
	temperature < -4000 ifTrue: [ ^ -4000 ].
	temperature > 8500 ifTrue: [ ^ 8500 ].
	^ temperature! !

!FirmataBMP280 methodsFor: 'compensation' stamp: 'sf 17/Sep/2026 00:00:00'!
pressureHectoPascal
	"Compensated pressure in hectopascal as a Float."
	^ self compensatedPressure ifNotNil: [ :value | value / 100.0 ]! !

!FirmataBMP280 methodsFor: 'compensation' stamp: 'sf 17/Sep/2026 00:00:00'!
pressurePascal
	"Compensated pressure in Pascal as an Integer."
	^ self compensatedPressure! !

!FirmataBMP280 methodsFor: 'compensation' stamp: 'sf 17/Sep/2026 00:00:00'!
tFine
	"Fine temperature value shared between the temperature and pressure formulas.
	Answers nil until both the calibration and a temperature sample are available."
	| adcT var1 var2 |
	calibrationData isNil ifTrue: [ ^ nil ].
	adcT := rawTemperature.
	adcT isNil ifTrue: [ ^ nil ].
	var1 := ((adcT quo: 8) - (self digT1 * 2)) * self digT2.
	var1 := var1 quo: 2048.
	var2 := ((adcT quo: 16) - self digT1) squared.
	var2 := (var2 quo: 4096) * self digT3.
	var2 := var2 quo: 16384.
	^ var1 + var2! !

!FirmataBMP280 methodsFor: 'compensation' stamp: 'sf 17/Sep/2026 00:00:00'!
temperatureCelsius
	"Compensated temperature in degrees Celsius as a Float."
	^ self compensatedTemperature ifNotNil: [ :value | value / 100.0 ]! !

!FirmataBMP280 class methodsFor: 'defaults' stamp: 'sf 17/Sep/2026 00:00:00'!
defaultAddress
	"Typical BMP280 slave address with the SDO pin low."
	^ FirmataBMP280Constants defaultAddress! !
