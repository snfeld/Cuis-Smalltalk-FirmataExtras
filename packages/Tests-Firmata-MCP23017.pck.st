'From Cuis7.8 [latest update: #7977] on 3 October 2026 at 5:23:41 pm'!
'Description '!
!provides: 'Tests-Firmata-MCP23017' 1 1!
!requires: 'Firmata-MCP23017' 1 1 nil!
SystemOrganization addCategory: #'Tests-Firmata-MCP23017'!


!classDefinition: #FirmataMCP23017PortMock category: #'Tests-Firmata-MCP23017'!
Object subclass: #FirmataMCP23017PortMock
	instanceVariableNames: 'written buffer closed'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-MCP23017'!
!classDefinition: 'FirmataMCP23017PortMock class' category: #'Tests-Firmata-MCP23017'!
FirmataMCP23017PortMock class
	instanceVariableNames: ''!

!classDefinition: #FirmataMCP23017Test category: #'Tests-Firmata-MCP23017'!
TestCase subclass: #FirmataMCP23017Test
	instanceVariableNames: 'device port bus'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-MCP23017'!
!classDefinition: 'FirmataMCP23017Test class' category: #'Tests-Firmata-MCP23017'!
FirmataMCP23017Test class
	instanceVariableNames: ''!


!FirmataMCP23017PortMock commentStamp: 'sf 17/Sep/2026' prior: 0!
I play the role of a serial port for Firmata-MCP23017 tests. Incoming bytes are queued in my buffer and answered by #readByteArray. Writes are recorded in #written.!

!FirmataMCP23017Test commentStamp: 'sf 17/Sep/2026' prior: 0!
I test Firmata-MCP23017 without hardware. Every I2C request produced by the expander driver is asserted byte-exactly and synthetic replies are fed through the mock port to check the port and pin level parsing.!

!FirmataMCP23017PortMock methodsFor: 'initialize-release' stamp: 'sf 17/Sep/2026 00:00:00'!
initialize
	written := ByteArray new.
	buffer := ByteArray new.
	closed := false! !

!FirmataMCP23017PortMock methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
clearWritten
	written := ByteArray new! !

!FirmataMCP23017PortMock methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
data: aByteArray
	"Bytes the next #readByteArray answers"
	buffer := aByteArray! !

!FirmataMCP23017PortMock methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
isClosed
	^ closed! !

!FirmataMCP23017PortMock methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
written
	^ written! !

!FirmataMCP23017PortMock methodsFor: 'serial protocol' stamp: 'sf 17/Sep/2026 00:00:00'!
close
	closed := true! !

!FirmataMCP23017PortMock methodsFor: 'serial protocol' stamp: 'sf 17/Sep/2026 00:00:00'!
nextPutAll: aByteArray
	written := written , aByteArray! !

!FirmataMCP23017PortMock methodsFor: 'serial protocol' stamp: 'sf 17/Sep/2026 00:00:00'!
readByteArray
	buffer size > 0
		ifTrue: [ | result |
			result := buffer.
			buffer := ByteArray new.
			^ result ].
	^ ByteArray new! !

!FirmataMCP23017Test methodsFor: 'support' stamp: 'sf 17/Sep/2026 00:00:00'!
replyMessageForRegister: aRegister data: aByteArray
	"Build an I2C_REPLY sysex for the MCP23017 at 0x20 where every
	value byte travels as a 7-bit LSB/MSB pair."
	| message |
	message := ByteArray new: 7 + (aByteArray size * 2).
	message at: 1 put: 16rF0.
	message at: 2 put: 16r77.
	message at: 3 put: 16r20.
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

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
setUp
	port := FirmataMCP23017PortMock new.
	bus := FirmataI2C new.
	bus instVarNamed: 'port' put: port.
	device := FirmataMCP23017 new.
	device firmata: bus address: FirmataMCP23017Constants defaultAddress.
	device registerWithFirmata! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
tearDown
	bus disconnect.
	(Delay forMilliseconds: 50) wait! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testAddressWithAddressPins
	self assert: (FirmataMCP23017 addressWithAddressPins: 0) equals: 16r20.
	self assert: (FirmataMCP23017 addressWithAddressPins: 5) equals: 16r25.
	self assert: (FirmataMCP23017 addressWithAddressPins: 7) equals: 16r27! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testDefaultAddressIs0x20
	self assert: device address equals: 16r20! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testDigitalWriteOnPortB
	"Pin 9 low clears bit one of the GPIOB latch: 0xFF -> 0xFD."
	device digitalWritePin: 9 value: false.
	self assert: (device outputValueForPort: 1) equals: 16rFD.
	self assert: port written equals: #[16rF0 16r76 16r20 0 16r13 0 16r7D 1 16rF7]! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testDigitalWriteSetsPortLatch
	"Pin 0 low clears the GPIOA output latch: 0xFF -> 0xFE."
	device digitalWritePin: 0 value: false.
	self assert: (device outputValueForPort: 0) equals: 16rFE.
	self assert: port written equals: #[16rF0 16r76 16r20 0 16r12 0 16r7E 1 16rF7]! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testEmptyReplyIsIgnored
	port data: (self replyMessageForRegister: FirmataMCP23017Constants gpioARegister data: #[]).
	bus processInput.
	self assert: (device inputValueForPort: 0) isNil! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testInitialStateIsAllInputs
	self assert: device directionA equals: 16rFF.
	self assert: device directionB equals: 16rFF.
	self assert: (device outputValueForPort: 0) equals: 16rFF.
	self assert: (device outputValueForPort: 1) equals: 16rFF! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testInitializeWritesDirectionAndPullUpRegisters
	"All pins input, no pull-ups, on both paired banks."
	device initializeDevice.
	self assert: port written equals: #[16rF0 16r76 16r20 0 0 0 16r7F 1 16rF7
		16rF0 16r76 16r20 0 1 0 16r7F 1 16rF7
		16rF0 16r76 16r20 0 16r0C 0 0 0 16rF7
		16rF0 16r76 16r20 0 16r0D 0 0 0 16rF7]! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testPinIndexOutOfRangeFails
	self should: [ device setPinMode: 16 value: true ] raise: Error.
	self should: [ device setPinMode: -1 value: true ] raise: Error.
	self should: [ device digitalWritePin: 20 value: true ] raise: Error.
	self should: [ device digitalReadPin: 16 ] raise: Error! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testPortIndexOutOfRangeFails
	self should: [ device readPort: 2 ] raise: Error.
	self should: [ device readPort: -1 ] raise: Error! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testReadPortBRequestsSingleRead
	device readPort: 1.
	self assert: port written equals: #[16rF0 16r76 16r20 16r08 16r13 0 1 0 16rF7]! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testReadPortRequestsSingleRead
	device readPort: 0.
	self assert: port written equals: #[16rF0 16r76 16r20 16r08 16r12 0 1 0 16rF7]! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testReplyUpdatesPortAValue
	"A GPIOA value of 0x05 means pins 0 and 2 are high."
	port data: (self replyMessageForRegister: FirmataMCP23017Constants gpioARegister data: #[16r05]).
	bus processInput.
	self assert: (device inputValueForPort: 0) equals: 16r05.
	self assert: (device digitalReadPin: 0).
	self assert: (device digitalReadPin: 1) not.
	self assert: (device digitalReadPin: 2)! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testReplyUpdatesPortBValue
	"A GPIOB value of 0x01 means pin 8 is high."
	port data: (self replyMessageForRegister: FirmataMCP23017Constants gpioBRegister data: #[16r01]).
	bus processInput.
	self assert: (device inputValueForPort: 1) equals: 16r01.
	self assert: (device digitalReadPin: 8).
	self assert: (device digitalReadPin: 9) not! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testSetPinModeInputRevertsDirectionBit
	"Pin 3 back to input sets the GPIOA direction bit again."
	device setPinMode: 3 value: true.
	port clearWritten.
	device setPinMode: 3 value: false.
	self assert: device directionA equals: 16rFF.
	self assert: port written equals: #[16rF0 16r76 16r20 0 0 0 16r7F 1 16rF7]! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testSetPinModeOutputOnPortB
	"Pin 10 lives in GPIOB; output clears its bit two: 0xFF -> 0xFB."
	device setPinMode: 10 value: true.
	self assert: device directionB equals: 16rFB.
	self assert: port written equals: #[16rF0 16r76 16r20 0 1 0 16r7B 1 16rF7]! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testSetPinModeOutputWritesDirectionRegister
	"Pin 5 to output clears the GPIOA direction bit: 0xFF -> 0xDF."
	device setPinMode: 5 value: true.
	self assert: device directionA equals: 16rDF.
	self assert: port written equals: #[16rF0 16r76 16r20 0 0 0 16r5F 1 16rF7]! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testSetPullUpWritesRegister
	device setPullUpPin: 3 value: true.
	self assert: port written equals: #[16rF0 16r76 16r20 0 16r0C 0 8 0 16rF7]! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testStartReadingPortRequestsContinuousRead
	device startReadingPort: 0.
	self assert: port written equals: #[16rF0 16r76 16r20 16r10 16r12 0 1 0 16rF7]! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testStopReadingStopsContinuousReads
	device stopReading.
	self assert: port written equals: #[16rF0 16r76 16r20 16r18 16rF7]! !

!FirmataMCP23017Test methodsFor: 'testing' stamp: 'sf 17/Sep/2026 00:00:00'!
testWritePortSetsWholeLatch
	device writePort: 0 value: 16r55.
	self assert: (device outputValueForPort: 0) equals: 16r55.
	self assert: port written equals: #[16rF0 16r76 16r20 0 16r12 0 16r55 0 16rF7]! !
