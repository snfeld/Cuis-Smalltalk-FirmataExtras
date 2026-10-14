'From Cuis7.8 [latest update: #7977] on 3 October 2026 at 5:01:16 pm'!
'Description '!
!provides: 'Tests-Firmata-BMP280' 1 1!
!requires: 'Firmata-BMP280' 1 1 nil!
SystemOrganization addCategory: #'Tests-Firmata-BMP280'!


!classDefinition: #FirmataBMP280PortMock category: #'Tests-Firmata-BMP280'!
Object subclass: #FirmataBMP280PortMock
	instanceVariableNames: 'written buffer closed'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-BMP280'!
!classDefinition: 'FirmataBMP280PortMock class' category: #'Tests-Firmata-BMP280'!
FirmataBMP280PortMock class
	instanceVariableNames: ''!

!classDefinition: #FirmataBMP280Test category: #'Tests-Firmata-BMP280'!
TestCase subclass: #FirmataBMP280Test
	instanceVariableNames: 'device port bus'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-BMP280'!
!classDefinition: 'FirmataBMP280Test class' category: #'Tests-Firmata-BMP280'!
FirmataBMP280Test class
	instanceVariableNames: ''!


!FirmataBMP280PortMock commentStamp: 'sf 17/Sep/2026' prior: 0!
I play the role of a serial port for Firmata-BMP280 tests. Incoming bytes are queued in my buffer and answered by #readByteArray. Writes are recorded in #written.!

!FirmataBMP280Test commentStamp: 'sf 17/Sep/2026' prior: 0!
I test Firmata-BMP280 without hardware. Every I2C request produced by the sensor driver is asserted byte-exactly and synthetic replies are fed through the mock port to check the raw parsing and the integer compensation. The calibration bytes and the expected compensated values come from a fixed synthetic sensor computed with the Bosch Sensortec reference driver.!

!FirmataBMP280PortMock methodsFor: 'initialize-release' stamp: 'sf 17/Sep/2026 00:00:00'!
initialize
	written := ByteArray new.
	buffer := ByteArray new.
	closed := false! !

!FirmataBMP280PortMock methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
data: aByteArray
	"Bytes the next #readByteArray answers"
	buffer := aByteArray! !

!FirmataBMP280PortMock methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
isClosed
	^ closed! !

!FirmataBMP280PortMock methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
written
	^ written! !

!FirmataBMP280PortMock methodsFor: 'serial protocol' stamp: 'sf 17/Sep/2026 00:00:00'!
close
	closed := true! !

!FirmataBMP280PortMock methodsFor: 'serial protocol' stamp: 'sf 17/Sep/2026 00:00:00'!
nextPutAll: aByteArray
	written := written , aByteArray! !

!FirmataBMP280PortMock methodsFor: 'serial protocol' stamp: 'sf 17/Sep/2026 00:00:00'!
readByteArray
	buffer size > 0
		ifTrue: [ | result |
			result := buffer.
			buffer := ByteArray new.
			^ result ].
	^ ByteArray new! !

!FirmataBMP280Test methodsFor: 'support' stamp: 'sf 17/Sep/2026 00:00:00'!
calibrationReply
	"24 calibration bytes 0x88..0x9F of the fixed synthetic sensor."
	^ self replyMessageForRegister: FirmataBMP280Constants calibrationRegister
		data: #[16r4F 16r6C 16r7B 16r67 16r68 16rFC 16r4F 16r8B
		        16rC6 16rD5 16rD0 16r0B 16r1F 16r23 16r21 16rFF
		        16rF2 16rD4 16r84 16r1C 16rA4 16rF2 16rD2 16r0F]! !

!FirmataBMP280Test methodsFor: 'support' stamp: 'sf 17/Sep/2026 00:00:00'!
replyMessageForRegister: aRegister data: aByteArray
	"Build an I2C_REPLY sysex for the BMP280 at 0x76 where every data
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

!FirmataBMP280Test methodsFor: 'support' stamp: 'sf 17/Sep/2026 00:00:00'!
secondSensorOutputReply
	"6 bytes: pressure 480000 then temperature 450000 (20 bit big-endian)."
	^ self replyMessageForRegister: FirmataBMP280Constants dataRegister
		data: #[16r75 16r30 0 16r6D 16rDD 0]! !

!FirmataBMP280Test methodsFor: 'support' stamp: 'sf 17/Sep/2026 00:00:00'!
sensorOutputReply
	"6 bytes: pressure 502000 then temperature 519000 (20 bit big-endian)."
	^ self replyMessageForRegister: FirmataBMP280Constants dataRegister
		data: #[16r7A 16r8F 0 16r7E 16rB5 16r80]! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
setUp
	port := FirmataBMP280PortMock new.
	bus := FirmataI2C new.
	bus instVarNamed: 'port' put: port.
	device := FirmataBMP280 new.
	device firmata: bus address: FirmataBMP280Constants defaultAddress.
	device registerWithFirmata! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
tearDown
	bus disconnect.
	(Delay forMilliseconds: 50) wait! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testCalibrationIsLoadedFromReply
	port data: self calibrationReply.
	bus processInput.
	self assert: device isCalibrationLoaded.
	self assert: device calibrationData size equals: 24! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testChipIdStored
	self assert: device chipId isNil.
	port data: (self replyMessageForRegister: FirmataBMP280Constants chipIdRegister data: #[16r58]).
	bus processInput.
	self assert: device chipId equals: 16r58! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testCompensatedPressureMatchesReference
	port data: self calibrationReply.
	bus processInput.
	port data: self sensorOutputReply.
	bus processInput.
	self assert: device compensatedPressure equals: 71039.
	self assert: device pressurePascal equals: 71039.
	self assert: device pressureHectoPascal equals: 710.39! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testCompensatedTemperatureMatchesReference
	port data: self calibrationReply.
	bus processInput.
	port data: self sensorOutputReply.
	bus processInput.
	self assert: device compensatedTemperature equals: 2374.
	self assert: device temperatureCelsius equals: 23.74! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testCompensatedValuesNeedCalibration
	port data: self sensorOutputReply.
	bus processInput.
	self assert: device temperatureCelsius isNil.
	self assert: device compensatedPressure isNil! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testCompensationForSecondSample
	port data: self calibrationReply.
	bus processInput.
	port data: self secondSensorOutputReply.
	bus processInput.
	self assert: device compensatedTemperature equals: 201.
	self assert: device compensatedPressure equals: 84161! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testDefaultAddressIs0x76
	self assert: device address equals: 16r76! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testInitializeDeviceReturnsSelf
	self assert: (device initializeDevice) == device! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testInitializeDeviceWritesConfigurationAndReadsCalibration
	"CONFIG 0xF5 = 0x00, CTRL_MEAS 0xF4 = 0x27, read 24 calibration bytes at 0x88."
	device initializeDevice.
	self assert: port written equals:
		#[16rF0 16r76 16r76 0 16r75 1 0 0 16rF7
		  16rF0 16r76 16r76 0 16r74 1 16r27 0 16rF7
		  16rF0 16r76 16r76 8 16r08 1 16r18 0 16rF7]! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testRawValuesAreParsedFromOutputReply
	port data: self sensorOutputReply.
	bus processInput.
	self assert: device rawPressure equals: 502000.
	self assert: device rawTemperature equals: 519000! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testReadChipIdRequestsChipId
	device readChipId.
	self assert: port written equals:
		#[16rF0 16r76 16r76 8 16r50 1 1 0 16rF7]! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testReadOnceRequestsSensorOutput
	device readOnce.
	self assert: port written equals:
		#[16rF0 16r76 16r76 8 16r77 1 6 0 16rF7]! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testShortCalibrationReplyIsIgnored
	port data: (self replyMessageForRegister: FirmataBMP280Constants calibrationRegister data: #[1 2 3]).
	bus processInput.
	self deny: device isCalibrationLoaded! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testShortOutputReplyIsIgnored
	port data: (self replyMessageForRegister: FirmataBMP280Constants dataRegister data: #[1 2]).
	bus processInput.
	self assert: device rawPressure isNil.
	self assert: device rawTemperature isNil! !

!FirmataBMP280Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testStartReadingPortRequestsContinuousOutput
	device startReadingPort.
	self assert: port written equals:
		#[16rF0 16r76 16r76 16r10 16r77 1 6 0 16rF7]! !
