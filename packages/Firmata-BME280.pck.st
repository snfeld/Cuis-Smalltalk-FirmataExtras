'From Cuis7.8 [latest update: #7977] on 3 October 2026 at 5:01:05 pm'!
'Description '!
!provides: 'Firmata-BME280' 1 1!
!requires: 'Firmata-BMP280' 1 1 nil!
SystemOrganization addCategory: #'Firmata-BME280'!


!classDefinition: #FirmataBME280Constants category: #'Firmata-BME280'!
FirmataBMP280Constants subclass: #FirmataBME280Constants
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-BME280'!
!classDefinition: 'FirmataBME280Constants class' category: #'Firmata-BME280'!
FirmataBME280Constants class
	instanceVariableNames: ''!

!classDefinition: #FirmataBME280 category: #'Firmata-BME280'!
FirmataBMP280 subclass: #FirmataBME280
	instanceVariableNames: 'humidityCalibration rawHumidity'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-BME280'!
!classDefinition: 'FirmataBME280 class' category: #'Firmata-BME280'!
FirmataBME280 class
	instanceVariableNames: ''!


!FirmataBME280Constants commentStamp: 'sf 17/Sep/2026' prior: 0!
See class side. I add the BME280 humidity registers and configuration to Firmata-BMP280 constants.!

!FirmataBME280 commentStamp: 'sf 17/Sep/2026' prior: 0!
I control a Bosch BME280 humidity, pressure and temperature sensor through a FirmataI2C connection. Like the BMP280 I stream the 20 bit pressure and temperature output, but additionally I read the 16 bit humidity output and both the 26 byte temperature/pressure calibration and the 7 byte humidity calibration, and I compensate the humidity with the integer formulas of the Bosch reference driver.

Typical use:
	bus := FirmataI2C new.
	bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
	sensor := FirmataBME280 new.
	sensor firmata: bus address: FirmataBME280Constants defaultAddress.
	sensor initializeDevice.
	sensor registerWithFirmata.
	sensor startReadingPort.
	sensor temperatureCelsius     "compensated temperature in C"
	sensor pressureHectoPascal    "compensated pressure in hPa"
	sensor humidityPercent         "compensated relative humidity in %"

#initializeDevice writes CTRL_HUM before CTRL_MEAS, then reads both calibration blocks. #startReadingPort asks the board to stream the six pressure/temperature bytes at 0xF7 and the two humidity bytes at 0xFD. Every incoming I2C_REPLY overwrites the last sample via #handleI2CReply:data:. Compensated values answer nil until calibration is loaded.!

!FirmataBME280Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
ctrlHumRegister
	"0xF2 humidity control register; must be written before CTRL_MEAS"
	^ 16rF2! !

!FirmataBME280Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
humidityCalibrationRegister
	"0xE1 first of the seven humidity calibration bytes"
	^ 16rE1! !

!FirmataBME280Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
humidityDataRegister
	"0xFD first of the two 16 bit humidity output bytes"
	^ 16rFD! !

!FirmataBME280Constants class methodsFor: 'specification' stamp: 'sf 17/Sep/2026 00:00:00'!
calibrationByteCount
	"BME280 calibration is 26 bytes; byte 26 (0xA1) holds dig_H1"
	^ 26! !

!FirmataBME280Constants class methodsFor: 'specification' stamp: 'sf 17/Sep/2026 00:00:00'!
chipIdValue
	"Value returned by the chip identification register"
	^ 16r60! !

!FirmataBME280Constants class methodsFor: 'specification' stamp: 'sf 17/Sep/2026 00:00:00'!
humidityCalibrationByteCount
	"Seven humidity calibration bytes starting at 0xE1"
	^ 7! !

!FirmataBME280Constants class methodsFor: 'specification' stamp: 'sf 17/Sep/2026 00:00:00'!
humidityOutputByteCount
	"Two bytes for the 16 bit humidity output"
	^ 2! !

!FirmataBME280Constants class methodsFor: 'defaults' stamp: 'sf 17/Sep/2026 00:00:00'!
defaultAddress
	"I2C slave address 0x76 with the SDO pin low"
	^ 16r76! !

!FirmataBME280 methodsFor: 'device initialization' stamp: 'sf 17/Sep/2026 00:00:00'!
calibrationByteCount
	"BME280 needs the 26 byte calibration block; byte 26 carries dig_H1."
	^ FirmataBME280Constants calibrationByteCount! !

!FirmataBME280 methodsFor: 'device initialization' stamp: 'sf 17/Sep/2026 00:00:00'!
initializeDevice
	"Set the humidity oversampling first, then configuration and measurement mode,
	and read both calibration blocks."
	self writeRegister: FirmataBME280Constants ctrlHumRegister
		data: (ByteArray with: FirmataBME280Constants oversamplingX1).
	self writeRegister: FirmataBMP280Constants configRegister
		data: (ByteArray with: FirmataBMP280Constants configValue).
	self writeRegister: FirmataBMP280Constants ctrlMeasRegister
		data: (ByteArray with: FirmataBMP280Constants ctrlMeasValue).
	self readCalibration.
	self readHumidityCalibration.
	^ self! !

!FirmataBME280 methodsFor: 'device initialization' stamp: 'sf 17/Sep/2026 00:00:00'!
readHumidityCalibration
	"Read the seven humidity calibration bytes starting at 0xE1."
	self readRegister: FirmataBME280Constants humidityCalibrationRegister
		byteCount: FirmataBME280Constants humidityCalibrationByteCount.
	^ self! !

!FirmataBME280 methodsFor: 'reading' stamp: 'sf 17/Sep/2026 00:00:00'!
readOnce
	"Read the pressure/temperature and the humidity output with single requests."
	super readOnce.
	self readRegister: FirmataBME280Constants humidityDataRegister
		byteCount: FirmataBME280Constants humidityOutputByteCount.
	^ self! !

!FirmataBME280 methodsFor: 'reading' stamp: 'sf 17/Sep/2026 00:00:00'!
startReadingPort
	"Ask the board to keep streaming pressure/temperature and humidity output."
	super startReadingPort.
	self readRegisterContinuously: FirmataBME280Constants humidityDataRegister
		byteCount: FirmataBME280Constants humidityOutputByteCount.
	^ self! !

!FirmataBME280 methodsFor: 'reply handling' stamp: 'sf 17/Sep/2026 00:00:00'!
handleI2CReply: aRegister data: aByteArray
	"Dispatch an incoming I2C reply; humidity replies are added to the BMP280 handling."
	aRegister = FirmataBME280Constants humidityCalibrationRegister
		ifTrue: [ ^ self storeHumidityCalibration: aByteArray ].
	aRegister = FirmataBME280Constants humidityDataRegister
		ifTrue: [ ^ self storeHumidityOutput: aByteArray ].
	^ super handleI2CReply: aRegister data: aByteArray! !

!FirmataBME280 methodsFor: 'reply handling - private' stamp: 'sf 17/Sep/2026 00:00:00'!
storeHumidityCalibration: aByteArray
	"Keep the humidity calibration bytes; shorter answers are ignored."
	aByteArray size >= FirmataBME280Constants humidityCalibrationByteCount
		ifFalse: [ ^ self ].
	humidityCalibration := aByteArray copyFrom: 1
		to: FirmataBME280Constants humidityCalibrationByteCount! !

!FirmataBME280 methodsFor: 'reply handling - private' stamp: 'sf 17/Sep/2026 00:00:00'!
storeHumidityOutput: aByteArray
	"Parse the 16 bit big-endian humidity output, overwriting the last sample."
	aByteArray size >= FirmataBME280Constants humidityOutputByteCount
		ifFalse: [ ^ self ].
	rawHumidity := ((aByteArray at: 1) bitShift: 8)
		bitOr: (aByteArray at: 2)! !

!FirmataBME280 methodsFor: 'calibration' stamp: 'sf 17/Sep/2026 00:00:00'!
humidityCalibration
	^ humidityCalibration! !

!FirmataBME280 methodsFor: 'calibration' stamp: 'sf 17/Sep/2026 00:00:00'!
isHumidityCalibrationLoaded
	^ humidityCalibration notNil! !

!FirmataBME280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digH1
	"Unsigned, stored as byte 26 (0xA1) of the temperature/pressure block."
	^ self unsigned8At: 26 in: calibrationData! !

!FirmataBME280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digH2
	"Signed 16 bit, little-endian at the start of the 0xE1 block."
	^ self signed16LittleEndianAt: 1 in: humidityCalibration! !

!FirmataBME280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digH3
	^ self unsigned8At: 3 in: humidityCalibration! !

!FirmataBME280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digH4
	"Signed nibble pair: byte 4 is the MSB, the low nibble of byte 5 the LSB."
	^ ((self signed8At: 4 in: humidityCalibration) * 16
		+ ((self unsigned8At: 5 in: humidityCalibration) bitAnd: 16r0F))! !

!FirmataBME280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digH5
	"Signed nibble pair: byte 6 is the MSB, the high nibble of byte 5 the LSB."
	^ ((self signed8At: 6 in: humidityCalibration) * 16
		+ (((self unsigned8At: 5 in: humidityCalibration) bitShift: -4) bitAnd: 16r0F))! !

!FirmataBME280 methodsFor: 'calibration - private' stamp: 'sf 17/Sep/2026 00:00:00'!
digH6
	^ self signed8At: 7 in: humidityCalibration! !

!FirmataBME280 methodsFor: 'sensor output' stamp: 'sf 17/Sep/2026 00:00:00'!
rawHumidity
	^ rawHumidity! !

!FirmataBME280 methodsFor: 'compensation' stamp: 'sf 17/Sep/2026 00:00:00'!
compensatedHumidity
	"Compensated relative humidity as a Q10 Integer, clamped to the sensor range.
	Answers nil until the calibration and a humidity sample are available."
	| tFine var1 var2 var3 var4 var5 |
	tFine := self tFine.
	tFine isNil ifTrue: [ ^ nil ].
	humidityCalibration isNil ifTrue: [ ^ nil ].
	rawHumidity isNil ifTrue: [ ^ nil ].
	var1 := tFine - 76800.
	var2 := rawHumidity * 16384.
	var3 := self digH4 * 1048576.
	var4 := self digH5 * var1.
	var5 := ((var2 - var3 - var4) + 16384) quo: 32768.
	var2 := (var1 * self digH6) quo: 1024.
	var3 := (var1 * self digH3) quo: 2048.
	var4 := ((var2 * (var3 + 32768)) quo: 1024) + 2097152.
	var2 := ((var4 * self digH2) + 8192) quo: 16384.
	var3 := var5 * var2.
	var4 := ((var3 quo: 32768) squared quo: 128).
	var5 := var3 - ((var4 * self digH1) quo: 16).
	var5 < 0 ifTrue: [ var5 := 0 ].
	var5 > 419430400 ifTrue: [ var5 := 419430400 ].
	^ (var5 quo: 4096) min: 102400! !

!FirmataBME280 methodsFor: 'compensation' stamp: 'sf 17/Sep/2026 00:00:00'!
humidityPercent
	"Compensated relative humidity in percent as a Float (Q10/1024)."
	^ self compensatedHumidity ifNotNil: [ :value | value / 1024.0 ]! !

!FirmataBME280 class methodsFor: 'defaults' stamp: 'sf 17/Sep/2026 00:00:00'!
defaultAddress
	"Typical BME280 slave address with the SDO pin low."
	^ FirmataBME280Constants defaultAddress! !
