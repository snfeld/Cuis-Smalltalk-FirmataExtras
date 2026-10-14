'From Cuis7.8 [latest update: #7977] on 3 October 2026 at 5:01:27 pm'!
'Description '!
!provides: 'Tests-Firmata-BME280' 1 1!
!requires: 'Firmata-BME280' 1 1 nil!
SystemOrganization addCategory: #'Tests-Firmata-BME280'!


!classDefinition: #FirmataBME280PortMock category: #'Tests-Firmata-BME280'!
Object subclass: #FirmataBME280PortMock
	instanceVariableNames: 'written buffer'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-BME280'!
!classDefinition: 'FirmataBME280PortMock class' category: #'Tests-Firmata-BME280'!
FirmataBME280PortMock class
	instanceVariableNames: ''!

!classDefinition: #FirmataBME280Test category: #'Tests-Firmata-BME280'!
TestCase subclass: #FirmataBME280Test
	instanceVariableNames: 'device port bus'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-BME280'!
!classDefinition: 'FirmataBME280Test class' category: #'Tests-Firmata-BME280'!
FirmataBME280Test class
	instanceVariableNames: ''!


!FirmataBME280PortMock commentStamp: 'sf 17/Sep/2026' prior: 0!
I play the role of a serial port for Firmata-BME280 tests. Incoming bytes are queued in my buffer and answered by #readByteArray. Writes are recorded in #written.!

!FirmataBME280Test commentStamp: 'sf 17/Sep/2026' prior: 0!
I test Firmata-BME280 without hardware. Every I2C request of the sensor driver is asserted byte-exactly and synthetic calibration and output replies are fed through the mock port to check the raw parsing and the integer compensation of temperature, pressure and humidity. The calibration bytes and the expected compensated values come from a fixed synthetic sensor computed with the Bosch Sensortec reference driver.!

!FirmataBME280PortMock methodsFor: 'initialize-release' stamp: 'sf 17/Sep/2026 00:00:00'!
initialize
	written := ByteArray new.
	buffer := ByteArray new! !

!FirmataBME280PortMock methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
data: aByteArray
	"Bytes the next #readByteArray answers"
	buffer := aByteArray! !

!FirmataBME280PortMock methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
written
	^ written! !

!FirmataBME280PortMock methodsFor: 'serial protocol' stamp: 'sf 17/Sep/2026 00:00:00'!
nextPutAll: aByteArray
	written := written , aByteArray! !

!FirmataBME280PortMock methodsFor: 'serial protocol' stamp: 'sf 17/Sep/2026 00:00:00'!
readByteArray
	buffer size > 0
		ifTrue: [ | result |
			result := buffer.
			buffer := ByteArray new.
			^ result ].
	^ ByteArray new! !

!FirmataBME280Test methodsFor: 'support' stamp: 'sf 17/Sep/2026 00:00:00'!
calibrationReply
	"26 calibration bytes 0x88..0xA1 of the fixed synthetic sensor; byte 26 is dig_H1."
	^ self replyMessageForRegister: FirmataBMP280Constants calibrationRegister
		data: #[16r4F 16r6C 16r7B 16r67 16r68 16rFC 16r4F 16r8B
		        16rC6 16rD5 16rD0 16r0B 16r1F 16r23 16r21 16rFF
		        16rF2 16rD4 16r84 16r1C 16rA4 16rF2 16rD2 16r0F 0 16r4C]! !

!FirmataBME280Test methodsFor: 'support' stamp: 'sf 17/Sep/2026 00:00:00'!
humidityCalibrationReply
	"7 humidity calibration bytes 0xE1..0xE7 of the fixed synthetic sensor."
	^ self replyMessageForRegister: FirmataBME280Constants humidityCalibrationRegister
		data: #[16r63 16r01 16r0E 16r15 16r8C 16rFF 16r1C]! !

!FirmataBME280Test methodsFor: 'support' stamp: 'sf 17/Sep/2026 00:00:00'!
humidityOutputReply
	"2 bytes: humidity 30000 (16 bit big-endian)."
	^ self replyMessageForRegister: FirmataBME280Constants humidityDataRegister
		data: #[16r75 16r30]! !

!FirmataBME280Test methodsFor: 'support' stamp: 'sf 17/Sep/2026 00:00:00'!
replyMessageForRegister: aRegister data: aByteArray
	"Build an I2C_REPLY sysex for the BME280 at 0x76 where every data
	byte travels as a 7-bit LSB/MSB pair."
	| message |
	message := ByteArray new: 7 + (aByteArray size * 2).
	message at: 1 put: 16rF0.
	message at: 2 put: 16r77.
	message at: 3 put: 16r76.
	message at: 4 put: 0.
	message at: 5 put: (aRegister bitAnd: 127).
	message at: 6 put: ((aRegister bitShift: -7) bitAnd: 127).
	1 to: aByteArray size do: [ :i |
		| value |
		value := aByteArray at: i.
		message at: 6 + ((i - 1) * 2) + 1 put: (value bitAnd: 127).
		message at: 6 + ((i - 1) * 2) + 2 put: ((value bitShift: -7) bitAnd: 127) ].
	message at: message size put: 16rF7.
	^ message! !

!FirmataBME280Test methodsFor: 'support' stamp: 'sf 17/Sep/2026 00:00:00'!
secondHumidityOutputReply
	"2 bytes: humidity 25000 (16 bit big-endian)."
	^ self replyMessageForRegister: FirmataBME280Constants humidityDataRegister
		data: #[16r61 16rA8]! !

!FirmataBME280Test methodsFor: 'support' stamp: 'sf 17/Sep/2026 00:00:00'!
secondSensorOutputReply
	"6 bytes: pressure 480000 then temperature 450000 (20 bit big-endian)."
	^ self replyMessageForRegister: FirmataBMP280Constants dataRegister
		data: #[16r75 16r30 0 16r6D 16rDD 0]! !

!FirmataBME280Test methodsFor: 'support' stamp: 'sf 17/Sep/2026 00:00:00'!
sensorOutputReply
	"6 bytes: pressure 502000 then temperature 519000 (20 bit big-endian)."
	^ self replyMessageForRegister: FirmataBMP280Constants dataRegister
		data: #[16r7A 16r8F 0 16r7E 16rB5 16r80]! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
setUp
	port := FirmataBME280PortMock new.
	bus := FirmataI2C new.
	bus instVarNamed: 'port' put: port.
	device := FirmataBME280 new.
	device firmata: bus address: FirmataBME280Constants defaultAddress.
	device registerWithFirmata! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testCalibrationIsLoadedFromReplies
	port data: self calibrationReply.
	bus processInput.
	port data: self humidityCalibrationReply.
	bus processInput.
	self assert: device calibrationData size equals: 26.
	self assert: device humidityCalibration size equals: 7.
	self assert: device isHumidityCalibrationLoaded! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testCompensatedHumidityMatchesReference
	port data: self calibrationReply.
	bus processInput.
	port data: self humidityCalibrationReply.
	bus processInput.
	port data: self sensorOutputReply.
	bus processInput.
	port data: self humidityOutputReply.
	bus processInput.
	self assert: device compensatedTemperature equals: 2374.
	self assert: device compensatedPressure equals: 71039.
	self assert: device compensatedHumidity equals: 43526.
	self assert: device humidityPercent equals: 42.505859375! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testCompensatedHumidityNeedsCalibration
	port data: self sensorOutputReply.
	bus processInput.
	port data: self humidityOutputReply.
	bus processInput.
	self assert: device compensatedHumidity isNil! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testCompensationForSecondSample
	port data: self calibrationReply.
	bus processInput.
	port data: self humidityCalibrationReply.
	bus processInput.
	port data: self secondSensorOutputReply.
	bus processInput.
	port data: self secondHumidityOutputReply.
	bus processInput.
	self assert: device compensatedTemperature equals: 201.
	self assert: device compensatedPressure equals: 84161.
	self assert: device compensatedHumidity equals: 14515! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testDefaultAddressIs0x76
	self assert: device address equals: 16r76! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testHumidityCoefficientsAreParsed
	port data: self calibrationReply.
	bus processInput.
	port data: self humidityCalibrationReply.
	bus processInput.
	self assert: device digH1 equals: 76.
	self assert: device digH2 equals: 355.
	self assert: device digH3 equals: 14.
	self assert: device digH4 equals: 348.
	self assert: device digH5 equals: -8.
	self assert: device digH6 equals: 28! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testInitializeDeviceReturnsSelf
	self assert: (device initializeDevice) == device! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testInitializeDeviceWritesConfigurationAndReadsCalibration
	"CTRL_HUM 0xF2 = 0x01 first, then CONFIG 0xF5 = 0x00, CTRL_MEAS 0xF4 = 0x27,
	then read 26 calibration bytes at 0x88 and 7 humidity calibration bytes at 0xE1."
	device initializeDevice.
	self assert: port written equals:
		#[16rF0 16r76 16r76 0 16r72 1 1 0 16rF7
		  16rF0 16r76 16r76 0 16r75 1 0 0 16rF7
		  16rF0 16r76 16r76 0 16r74 1 16r27 0 16rF7
		  16rF0 16r76 16r76 8 16r08 1 16r1A 0 16rF7
		  16rF0 16r76 16r76 8 16r61 1 7 0 16rF7]! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testIsBMP280Subclass
	self assert: device class superclass equals: FirmataBMP280! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testRawHumidityIsParsedFromOutputReply
	port data: self sensorOutputReply.
	bus processInput.
	port data: self humidityOutputReply.
	bus processInput.
	self assert: device rawPressure equals: 502000.
	self assert: device rawTemperature equals: 519000.
	self assert: device rawHumidity equals: 30000! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testReadOnceRequestsBothOutputs
	device readOnce.
	self assert: port written equals:
		#[16rF0 16r76 16r76 8 16r77 1 6 0 16rF7
		  16rF0 16r76 16r76 8 16r7D 1 2 0 16rF7]! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testShortHumidityCalibrationReplyIsIgnored
	port data: self calibrationReply.
	bus processInput.
	port data: (self replyMessageForRegister: FirmataBME280Constants humidityCalibrationRegister data: #[1 2]).
	bus processInput.
	self deny: device isHumidityCalibrationLoaded! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testShortHumidityOutputReplyIsIgnored
	port data: (self replyMessageForRegister: FirmataBME280Constants humidityDataRegister data: #[1]).
	bus processInput.
	self assert: device rawHumidity isNil! !

!FirmataBME280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testStartReadingPortRequestsBothOutputsContinuously
	device startReadingPort.
	self assert: port written equals:
		#[16rF0 16r76 16r76 16r10 16r77 1 6 0 16rF7
		  16rF0 16r76 16r76 16r10 16r7D 1 2 0 16rF7]! !
