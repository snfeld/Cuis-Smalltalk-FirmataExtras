'From Cuis7.8 [latest update: #7977] on 28 September 2026 at 8:00:19 am'!
'Description '!
!provides: 'Tests-Firmata-ADXL345' 1 1!
!requires: 'Firmata-ADXL345' 1 1 nil!
SystemOrganization addCategory: #'Tests-Firmata-ADXL345'!


!classDefinition: #FirmataADXL345PortMock category: #'Tests-Firmata-ADXL345'!
Object subclass: #FirmataADXL345PortMock
	instanceVariableNames: 'written buffer closed'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-ADXL345'!
!classDefinition: 'FirmataADXL345PortMock class' category: #'Tests-Firmata-ADXL345'!
FirmataADXL345PortMock class
	instanceVariableNames: ''!

!classDefinition: #FirmataADXL345Test category: #'Tests-Firmata-ADXL345'!
TestCase subclass: #FirmataADXL345Test
	instanceVariableNames: 'device port bus'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-ADXL345'!
!classDefinition: 'FirmataADXL345Test class' category: #'Tests-Firmata-ADXL345'!
FirmataADXL345Test class
	instanceVariableNames: ''!


!FirmataADXL345PortMock commentStamp: 'sf 16/Sep/2026' prior: 0!
I play the role of a serial port for Firmata-ADXL345 tests. Incoming bytes are queued in my buffer and answered by #readByteArray. Writes are recorded in #written.!

!FirmataADXL345Test commentStamp: 'sf 16/Sep/2026' prior: 0!
I test Firmata-ADXL345 without hardware. Every I2C request produced by the sensor driver is asserted byte-exactly and synthetic little-endian replies are fed through the mock port to check the raw and scaled value parsing.!

!FirmataADXL345PortMock methodsFor: 'initialize-release' stamp: 'sf 16/Sep/2026 00:00:00'!
initialize
	written := ByteArray new.
	buffer := ByteArray new.
	closed := false! !

!FirmataADXL345PortMock methodsFor: 'accessing' stamp: 'sf 16/Sep/2026 00:00:00'!
data: aByteArray
	"Bytes the next #readByteArray answers"
	buffer := aByteArray! !

!FirmataADXL345PortMock methodsFor: 'accessing' stamp: 'sf 16/Sep/2026 00:00:00'!
isClosed
	^ closed! !

!FirmataADXL345PortMock methodsFor: 'accessing' stamp: 'sf 16/Sep/2026 00:00:00'!
written
	^ written! !

!FirmataADXL345PortMock methodsFor: 'serial protocol' stamp: 'sf 16/Sep/2026 00:00:00'!
close
	closed := true! !

!FirmataADXL345PortMock methodsFor: 'serial protocol' stamp: 'sf 16/Sep/2026 00:00:00'!
nextPutAll: aByteArray
	written := written , aByteArray! !

!FirmataADXL345PortMock methodsFor: 'serial protocol' stamp: 'sf 16/Sep/2026 00:00:00'!
readByteArray
	buffer size > 0
		ifTrue: [ | result |
			result := buffer.
			buffer := ByteArray new.
			^ result ].
	^ ByteArray new! !

!FirmataADXL345Test methodsFor: 'support' stamp: 'sf 16/Sep/2026 00:00:00'!
replyMessageForRegister: aRegister data: aByteArray
	"Build an I2C_REPLY sysex for the ADXL345 at 0x53 where every data
	byte travels as a 7-bit LSB/MSB pair."
	| message |
	message := ByteArray new: 7 + (aByteArray size * 2).
	message at: 1 put: 16rF0.
	message at: 2 put: 16r77.
	message at: 3 put: 16r53.
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

!FirmataADXL345Test methodsFor: 'support' stamp: 'sf 16/Sep/2026 00:00:00'!
sensorOutputReply
	"6 bytes little-endian: X=0, Y=0, Z=256 (one g at 256 LSB/g).
	256 LE = [0, 1]."
	^ self replyMessageForRegister: FirmataADXL345Constants dataX0Register
		data: #[0 0 0 0 0 1]! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
setUp
	port := FirmataADXL345PortMock new.
	bus := FirmataI2C new.
	bus instVarNamed: 'port' put: port.
	device := FirmataADXL345 new.
	device firmata: bus address: FirmataADXL345Constants defaultAddress.
	device registerWithFirmata! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
tearDown
	bus disconnect.
	(Delay forMilliseconds: 50) wait! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testDefaultAddressIs0x53
	self assert: device address equals: 16r53! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testDefaultRangeAndSampleRate
	self assert: device accelRange equals: 0.
	self assert: device sampleRate equals: 16r0A! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testInitializeDeviceReturnsSelf
	self assert: (device initializeDevice) == device! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testInitializeDeviceWritesFormatRateMeasure
	"DATA_FORMAT 0x31 = 0x08, BW_RATE 0x2C = 0x0A, POWER_CTL 0x2D = 0x08."
	device initializeDevice.
	self assert: port written equals:
		#[16rF0 16r76 16r53 0 16r31 0 16r08 0 16rF7
		  16rF0 16r76 16r53 0 16r2C 0 16r0A 0 16rF7
		  16rF0 16r76 16r53 0 16r2D 0 16r08 0 16rF7]! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testMultiAxisScaling
	"X=128 (0.5 g), Y=64 (0.25 g), Z=256 (1 g) — LE pairs."
	port data: (self replyMessageForRegister: FirmataADXL345Constants dataX0Register
		data: #[128 0 64 0 0 1]).
	bus processInput.
	self assert: device scaledAccelX equals: 0.5.
	self assert: device scaledAccelY equals: 0.25.
	self assert: device scaledAccelZ equals: 1.0! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testReadOnceRequestsSingleOutput
	device readOnce.
	self assert: port written equals:
		#[16rF0 16r76 16r53 16r08 16r32 0 6 0 16rF7]! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testReplyDecodesNegativeZ
	"Z = -256 = 0xFF00 LE = [0, 0xFF]."
	port data: (self replyMessageForRegister: FirmataADXL345Constants dataX0Register
		data: #[0 0 0 0 0 16rFF]).
	bus processInput.
	self assert: device accelZ equals: -256! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testReplyUpdatesAccelerometer
	port data: self sensorOutputReply.
	bus processInput.
	self assert: device accelX equals: 0.
	self assert: device accelY equals: 0.
	self assert: device accelZ equals: 256! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testScaledAccelFollowsConfiguredRange
	"In full-resolution mode the sensitivity stays at 256 LSB/g regardless
	of the selected range, so 256 raw counts still equals one g."
	device setAccelerationRange: 2.
	port data: self sensorOutputReply.
	bus processInput.
	self assert: device scaledAccelZ equals: 1.0! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testScaledAccelUsesDefaultRange
	"256 raw counts = one g at 256 LSB/g."
	port data: self sensorOutputReply.
	bus processInput.
	self assert: device scaledAccelZ equals: 1.0! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testSetAccelerationRangeOutOfRangeFails
	self should: [ device setAccelerationRange: 4 ] raise: Error.
	self should: [ device setAccelerationRange: -1 ] raise: Error! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testSetAccelerationRangeWritesFormatRegister
	"Range 2 = 0x0A with full-res bit."
	device setAccelerationRange: 2.
	self assert: device accelRange equals: 2.
	self assert: port written equals:
		#[16rF0 16r76 16r53 0 16r31 0 16r0A 0 16rF7]! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testSetSampleRateWritesBandwidthRate
	device setSampleRate: 16r0C.
	self assert: device sampleRate equals: 16r0C.
	self assert: port written equals:
		#[16rF0 16r76 16r53 0 16r2C 0 16r0C 0 16rF7]! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testShortReplyIsIgnored
	port data: (self replyMessageForRegister: FirmataADXL345Constants dataX0Register data: #[0 0]).
	bus processInput.
	self assert: device accelZ isNil! !

!FirmataADXL345Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testStartReadingRequestsContinuousOutput
	device startReadingPort.
	self assert: port written equals:
		#[16rF0 16r76 16r53 16r10 16r32 0 6 0 16rF7]! !
