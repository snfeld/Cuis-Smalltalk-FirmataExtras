'From Cuis7.8 [latest update: #7977] on 28 September 2026 at 8:00:06 am'!
'Description '!
!provides: 'Firmata-ADXL345' 1 1!
!requires: 'Firmata-I2C' 1 1 nil!
SystemOrganization addCategory: #'Firmata-ADXL345'!


!classDefinition: #FirmataADXL345Constants category: #'Firmata-ADXL345'!
Object subclass: #FirmataADXL345Constants
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-ADXL345'!
!classDefinition: 'FirmataADXL345Constants class' category: #'Firmata-ADXL345'!
FirmataADXL345Constants class
	instanceVariableNames: ''!

!classDefinition: #FirmataADXL345 category: #'Firmata-ADXL345'!
FirmataI2CDevice subclass: #FirmataADXL345
	instanceVariableNames: 'accelX accelY accelZ accelRange sampleRate'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-ADXL345'!
!classDefinition: 'FirmataADXL345 class' category: #'Firmata-ADXL345'!
FirmataADXL345 class
	instanceVariableNames: ''!


!FirmataADXL345Constants commentStamp: 'sf 16/Sep/2026' prior: 0!
See class side. I collect the ADXL345 register map, configuration bits and specification constants from the Analog Devices ADXL345 datasheet.!

!FirmataADXL345 commentStamp: 'sf 16/Sep/2026' prior: 0!
I control an Analog Devices ADXL345 three-axis digital accelerometer through a FirmataI2C connection. The chip has a 13-bit output with a fixed 4 mg/LSB sensitivity in full-resolution mode.

Typical use:
	bus := FirmataI2C new.
	bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
	sensor := FirmataADXL345 new.
	sensor firmata: bus address: FirmataADXL345Constants defaultAddress.
	sensor initializeDevice.
	sensor registerWithFirmata.
	sensor startReadingPort.
	sensor accelZ       "raw signed count on Z"
	sensor scaledAccelZ "Z acceleration in g"

Start the stream with #startReadingPort (or do a single #readOnce) and read the raw or scaled values afterwards; each incoming I2C_REPLY overwrites the last sample via #handleI2CReply:data:. The output data format is little-endian (LSB first). The full-resolution mode keeps a fixed sensitivity of 256 LSB/g regardless of the selected g-range, so #scaledAccelX divides the raw count by 256.!

!FirmataADXL345Constants class methodsFor: 'registers' stamp: 'sf 16/Sep/2026 00:00:00'!
bandwidthRateRegister
	"0x2C data rate and power mode register"
	^ 16r2C! !

!FirmataADXL345Constants class methodsFor: 'registers' stamp: 'sf 16/Sep/2026 00:00:00'!
dataFormatRegister
	"0x31 data format control register"
	^ 16r31! !

!FirmataADXL345Constants class methodsFor: 'registers' stamp: 'sf 16/Sep/2026 00:00:00'!
dataX0Register
	"0x32 low byte of the X accelerometer output, first of the 6 output registers"
	^ 16r32! !

!FirmataADXL345Constants class methodsFor: 'registers' stamp: 'sf 16/Sep/2026 00:00:00'!
deviceIdRegister
	"0x00 device ID register answering 0xE5"
	^ 0! !

!FirmataADXL345Constants class methodsFor: 'registers' stamp: 'sf 16/Sep/2026 00:00:00'!
fifoControlRegister
	"0x38 FIFO control register"
	^ 16r38! !

!FirmataADXL345Constants class methodsFor: 'registers' stamp: 'sf 16/Sep/2026 00:00:00'!
powerControlRegister
	"0x2D power control register"
	^ 16r2D! !

!FirmataADXL345Constants class methodsFor: 'configuration bits' stamp: 'sf 16/Sep/2026 00:00:00'!
fullResolutionBit
	"Bit 3 of the data format register enabling full-resolution mode (4 mg/LSB for all ranges)"
	^ 16r08! !

!FirmataADXL345Constants class methodsFor: 'configuration bits' stamp: 'sf 16/Sep/2026 00:00:00'!
measureBit
	"Bit 3 of the power control register starting measurement mode"
	^ 16r08! !

!FirmataADXL345Constants class methodsFor: 'specification' stamp: 'sf 16/Sep/2026 00:00:00'!
accelSensitivity
	"Raw counts per g in full-resolution mode (4 mg/LSB)"
	^ 256! !

!FirmataADXL345Constants class methodsFor: 'specification' stamp: 'sf 16/Sep/2026 00:00:00'!
deviceIdValue
	"Value returned by the DEVID register"
	^ 16rE5! !

!FirmataADXL345Constants class methodsFor: 'specification' stamp: 'sf 16/Sep/2026 00:00:00'!
sensorOutputByteCount
	"Three axes, two bytes each, little-endian"
	^ 6! !

!FirmataADXL345Constants class methodsFor: 'defaults' stamp: 'sf 16/Sep/2026 00:00:00'!
defaultAccelRange
	"Full-scale range index for +/-2g"
	^ 0! !

!FirmataADXL345Constants class methodsFor: 'defaults' stamp: 'sf 16/Sep/2026 00:00:00'!
defaultAddress
	"I2C slave address 0x53 with the ALT ADDRESS pin high"
	^ 16r53! !

!FirmataADXL345Constants class methodsFor: 'defaults' stamp: 'sf 16/Sep/2026 00:00:00'!
defaultSampleRate
	"Output data rate code for 100 Hz"
	^ 16r0A! !

!FirmataADXL345 methodsFor: 'initialize-release' stamp: 'sf 16/Sep/2026 00:00:00'!
initialize
	super initialize.
	accelRange := self class defaultAccelRange.
	sampleRate := self class defaultSampleRate! !

!FirmataADXL345 methodsFor: 'device initialization' stamp: 'sf 16/Sep/2026 00:00:00'!
initializeDevice
	"Set the data format, output data rate and start measurement."
	self writeRegister: FirmataADXL345Constants dataFormatRegister
		data: (ByteArray with: (accelRange bitOr: FirmataADXL345Constants fullResolutionBit)).
	self writeRegister: FirmataADXL345Constants bandwidthRateRegister
		data: (ByteArray with: sampleRate).
	self writeRegister: FirmataADXL345Constants powerControlRegister
		data: (ByteArray with: FirmataADXL345Constants measureBit).
	^ self! !

!FirmataADXL345 methodsFor: 'sensor configuration' stamp: 'sf 16/Sep/2026 00:00:00'!
setAccelerationRange: anIndex
	"Set the accelerometer full-scale range: 0 is +/-2g, 1 +/-4g, 2 +/-8g, 3 +/-16g."
	self checkRangeIndex: anIndex.
	self writeRegister: FirmataADXL345Constants dataFormatRegister
		data: (ByteArray with: (anIndex bitOr: FirmataADXL345Constants fullResolutionBit)).
	accelRange := anIndex.
	^ self! !

!FirmataADXL345 methodsFor: 'sensor configuration' stamp: 'sf 16/Sep/2026 00:00:00'!
setSampleRate: aCode
	"Set the output data rate using the BW_RATE register code.
	0x0A is 100 Hz, 0x0B is 200 Hz, 0x0C is 400 Hz, 0x0D is 800 Hz, 0x0E is 1600 Hz, 0x0F is 3200 Hz."
	self writeRegister: FirmataADXL345Constants bandwidthRateRegister
		data: (ByteArray with: aCode).
	sampleRate := aCode.
	^ self! !

!FirmataADXL345 methodsFor: 'sensor configuration - private' stamp: 'sf 16/Sep/2026 00:00:00'!
checkRangeIndex: anIndex
	"Guard against a full-scale range index that the register cannot encode."
	(anIndex between: 0 and: 3)
		ifFalse: [ self error: 'ADXL345 range index out of range' ]! !

!FirmataADXL345 methodsFor: 'reading' stamp: 'sf 16/Sep/2026 00:00:00'!
readOnce
	"Read the current sensor output with a single request."
	self readRegister: FirmataADXL345Constants dataX0Register
		byteCount: FirmataADXL345Constants sensorOutputByteCount.
	^ self! !

!FirmataADXL345 methodsFor: 'reading' stamp: 'sf 16/Sep/2026 00:00:00'!
startReadingPort
	"Ask the board to keep streaming the sensor output registers."
	self readRegisterContinuously: FirmataADXL345Constants dataX0Register
		byteCount: FirmataADXL345Constants sensorOutputByteCount.
	^ self! !

!FirmataADXL345 methodsFor: 'reply handling' stamp: 'sf 16/Sep/2026 00:00:00'!
handleI2CReply: aRegister data: aByteArray
	"Parse a sensor output reply into raw counts, overwriting the last sample.
	Replies shorter than the sensor output block are ignored.
	Data is little-endian (LSB first)."
	aByteArray size >= FirmataADXL345Constants sensorOutputByteCount
		ifFalse: [ ^ self ].
	accelX := self signed16LittleEndianAt: 1 in: aByteArray.
	accelY := self signed16LittleEndianAt: 3 in: aByteArray.
	accelZ := self signed16LittleEndianAt: 5 in: aByteArray! !

!FirmataADXL345 methodsFor: 'reply handling - private' stamp: 'sf 16/Sep/2026 00:00:00'!
signed16LittleEndianAt: index in: aByteArray
	"16-bit signed value read little-endian from aByteArray at index (1-based, LSB first)."
	| value |
	value := ((aByteArray at: index + 1) bitShift: 8)
		bitOr: (aByteArray at: index).
	value >= 16r8000 ifTrue: [ ^ value - 16r10000 ].
	^ value! !

!FirmataADXL345 methodsFor: 'sensor output' stamp: 'sf 16/Sep/2026 00:00:00'!
accelRange
	^ accelRange! !

!FirmataADXL345 methodsFor: 'sensor output' stamp: 'sf 16/Sep/2026 00:00:00'!
accelSensitivity
	"Fixed LSB per g in full-resolution mode (4 mg/LSB)."
	^ FirmataADXL345Constants accelSensitivity! !

!FirmataADXL345 methodsFor: 'sensor output' stamp: 'sf 16/Sep/2026 00:00:00'!
accelX
	^ accelX! !

!FirmataADXL345 methodsFor: 'sensor output' stamp: 'sf 16/Sep/2026 00:00:00'!
accelY
	^ accelY! !

!FirmataADXL345 methodsFor: 'sensor output' stamp: 'sf 16/Sep/2026 00:00:00'!
accelZ
	^ accelZ! !

!FirmataADXL345 methodsFor: 'sensor output' stamp: 'sf 16/Sep/2026 00:00:00'!
sampleRate
	^ sampleRate! !

!FirmataADXL345 methodsFor: 'sensor output' stamp: 'sf 16/Sep/2026 00:00:00'!
scaledAccelX
	"X acceleration in g using the full-resolution fixed scale of 256 LSB/g."
	^ self accelX / self accelSensitivity! !

!FirmataADXL345 methodsFor: 'sensor output' stamp: 'sf 16/Sep/2026 00:00:00'!
scaledAccelY
	"Y acceleration in g using the full-resolution fixed scale of 256 LSB/g."
	^ self accelY / self accelSensitivity! !

!FirmataADXL345 methodsFor: 'sensor output' stamp: 'sf 16/Sep/2026 00:00:00'!
scaledAccelZ
	"Z acceleration in g using the full-resolution fixed scale of 256 LSB/g."
	^ self accelZ / self accelSensitivity! !

!FirmataADXL345 class methodsFor: 'defaults' stamp: 'sf 16/Sep/2026 00:00:00'!
defaultAccelRange
	"Fallback accelerometer full-scale range index (+/-2g)."
	^ FirmataADXL345Constants defaultAccelRange! !

!FirmataADXL345 class methodsFor: 'defaults' stamp: 'sf 16/Sep/2026 00:00:00'!
defaultAddress
	"Typical ADXL345 slave address with the ALT ADDRESS pin high."
	^ FirmataADXL345Constants defaultAddress! !

!FirmataADXL345 class methodsFor: 'defaults' stamp: 'sf 16/Sep/2026 00:00:00'!
defaultSampleRate
	"Fallback output data rate code (100 Hz)."
	^ FirmataADXL345Constants defaultSampleRate! !
