'From Cuis7.8 [latest update: #7977] on 3 October 2026 at 5:23:50 pm'!
'Description '!
!provides: 'Tests-Firmata-MPU6050' 1 1!
!requires: 'Firmata-MPU6050' 1 1 nil!
SystemOrganization addCategory: #'Tests-Firmata-MPU6050'!


!classDefinition: #FirmataMPU6050PortMock category: #'Tests-Firmata-MPU6050'!
Object subclass: #FirmataMPU6050PortMock
	instanceVariableNames: 'written buffer closed'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-MPU6050'!
!classDefinition: 'FirmataMPU6050PortMock class' category: #'Tests-Firmata-MPU6050'!
FirmataMPU6050PortMock class
	instanceVariableNames: ''!

!classDefinition: #FirmataMPU6050Test category: #'Tests-Firmata-MPU6050'!
TestCase subclass: #FirmataMPU6050Test
	instanceVariableNames: 'device port bus'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-MPU6050'!
!classDefinition: 'FirmataMPU6050Test class' category: #'Tests-Firmata-MPU6050'!
FirmataMPU6050Test class
	instanceVariableNames: ''!


!FirmataMPU6050PortMock commentStamp: 'sf 12/Sep/2026' prior: 0!
I play the role of a serial port for Firmata-MPU6050 tests. Incoming bytes are queued in my buffer and answered by #readByteArray. Writes are recorded in #written.!

!FirmataMPU6050Test commentStamp: 'sf 12/Sep/2026' prior: 0!
I test Firmata-MPU6050 without hardware. Every I2C request produced by the sensor driver is asserted byte-exactly and synthetic replies are fed through the mock port to check the raw and scaled value parsing.!

!FirmataMPU6050PortMock methodsFor: 'initialize-release' stamp: 'sf 12/Sep/2026 00:00:00'!
initialize
	written := ByteArray new.
	buffer := ByteArray new.
	closed := false! !

!FirmataMPU6050PortMock methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
data: aByteArray
	"Bytes the next #readByteArray answers"
	buffer := aByteArray! !

!FirmataMPU6050PortMock methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
isClosed
	^ closed! !

!FirmataMPU6050PortMock methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
written
	^ written! !

!FirmataMPU6050PortMock methodsFor: 'serial protocol' stamp: 'sf 12/Sep/2026 00:00:00'!
close
	closed := true! !

!FirmataMPU6050PortMock methodsFor: 'serial protocol' stamp: 'sf 12/Sep/2026 00:00:00'!
nextPutAll: aByteArray
	written := written , aByteArray! !

!FirmataMPU6050PortMock methodsFor: 'serial protocol' stamp: 'sf 12/Sep/2026 00:00:00'!
readByteArray
	buffer size > 0
		ifTrue: [ | result |
			result := buffer.
			buffer := ByteArray new.
			^ result ].
	^ ByteArray new! !

!FirmataMPU6050Test methodsFor: 'support' stamp: 'sf 12/Sep/2026 00:00:00'!
replyMessageForRegister: aRegister data: aByteArray
	"Build an I2C_REPLY sysex for the MPU6050 at 0x68 where every data
	byte travels as a 7-bit LSB/MSB pair."
	| message |
	message := ByteArray new: 7 + (aByteArray size * 2).
	message at: 1 put: 16rF0.
	message at: 2 put: 16r77.
	message at: 3 put: 16r68.
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

!FirmataMPU6050Test methodsFor: 'support' stamp: 'sf 12/Sep/2026 00:00:00'!
sensorOutputReply
	"14 bytes covering all output registers: Z acceleration of one g
	with the default range, temperature raw 3000, X rotation -1000,
	Y rotation 500 and Z rotation -32768 in raw 16-bit counts."
	^ self replyMessageForRegister: FirmataMPU6050Constants accelXHighRegister
		data: #[0 0 0 0 64 0 11 184 252 24 1 244 128 0]! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
setUp
	port := FirmataMPU6050PortMock new.
	bus := FirmataI2C new.
	bus instVarNamed: 'port' put: port.
	device := FirmataMPU6050 new.
	device firmata: bus address: FirmataMPU6050Constants defaultAddress.
	device registerWithFirmata! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
tearDown
	bus disconnect.
	(Delay forMilliseconds: 50) wait! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testDefaultAddressIs0x68
	self assert: device address equals: 16r68! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testDefaultRangesAreIndexZero
	self assert: device accelRange equals: 0.
	self assert: device gyroRange equals: 0! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testInitializeDeviceReturnsSelf
	self assert: (device initializeDevice) == device! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testInitializeDeviceWakesUpChip
	device initializeDevice.
	self assert: port written equals: #[16rF0 16r76 16r68 0 16r6B 0 0 0 16rF7]! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testPowerManagementRegistersMatchDatasheet
	"Regression: the wake write used to target the bus address 0x68, which is
	not a register on the chip. The real PWR_MGMT_1 register is 0x6B and
	PWR_MGMT_2 is 0x6C."
	self assert: FirmataMPU6050Constants powerManagement1Register equals: 16r6B.
	self assert: FirmataMPU6050Constants powerManagement2Register equals: 16r6C! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testReadOnceRequestsSingleOutput
	device readOnce.
	self assert: port written equals: #[16rF0 16r76 16r68 16r08 16r3B 0 14 0 16rF7]! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testReplyDecodesNegativeGyroValues
	port data: self sensorOutputReply.
	bus processInput.
	self assert: device gyroX equals: -1000.
	self assert: device gyroY equals: 500.
	self assert: device gyroZ equals: -32768! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testReplyUpdatesAccelerometer
	port data: self sensorOutputReply.
	bus processInput.
	self assert: device accelX equals: 0.
	self assert: device accelY equals: 0.
	self assert: device accelZ equals: 16384! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testReplyUpdatesTemperature
	port data: self sensorOutputReply.
	bus processInput.
	self assert: (device temperature - 45.35) abs < 0.01! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testScaledAccelFollowsConfiguredRange
	"16384 raw counts is two g at the +/-4g range."
	device setAccelerationRange: 1.
	port data: self sensorOutputReply.
	bus processInput.
	self assert: device scaledAccelZ equals: 2.0! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testScaledAccelUsesDefaultRange
	"16384 raw counts is one g at the default +/-2g range."
	port data: self sensorOutputReply.
	bus processInput.
	self assert: device scaledAccelZ equals: 1.0! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testScaledGyroFollowsConfiguredRange
	"At the +/-1000 dps range the sensitivity drops to a quarter."
	device setGyroRange: 2.
	port data: self sensorOutputReply.
	bus processInput.
	self assert: (device scaledGyroY - (500 / 32.75)) abs < 0.001! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testScaledGyroUsesDefaultRange
	port data: self sensorOutputReply.
	bus processInput.
	self assert: (device scaledGyroY - (500 / 131.0)) abs < 0.001! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetAccelerationRangeWritesConfigRegister
	device setAccelerationRange: 2.
	self assert: device accelRange equals: 2.
	self assert: port written equals: #[16rF0 16r76 16r68 0 16r1C 0 16 0 16rF7]! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetGyroRangeWritesConfigRegister
	device setGyroRange: 3.
	self assert: device gyroRange equals: 3.
	self assert: port written equals: #[16rF0 16r76 16r68 0 16r1B 0 24 0 16rF7]! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetRangeOutOfRangeFails
	self should: [ device setAccelerationRange: 4 ] raise: Error.
	self should: [ device setGyroRange: -1 ] raise: Error! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testShortReplyIsIgnored
	port data: (self replyMessageForRegister: FirmataMPU6050Constants accelXHighRegister data: #[0 0]).
	bus processInput.
	self assert: device accelZ isNil! !

!FirmataMPU6050Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testStartReadingRequestsContinuousOutput
	device startReading.
	self assert: port written equals: #[16rF0 16r76 16r68 16r10 16r3B 0 14 0 16rF7]! !
