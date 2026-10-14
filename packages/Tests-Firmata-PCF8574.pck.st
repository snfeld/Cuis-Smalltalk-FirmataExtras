'From Cuis7.8 [latest update: #7977] on 3 October 2026 at 5:47:49 pm'!
'Description '!
!provides: 'Tests-Firmata-PCF8574' 1 1!
!requires: 'Firmata-PCF8574' 1 1 nil!
SystemOrganization addCategory: #'Tests-Firmata-PCF8574'!


!classDefinition: #FirmataPCF8574PortMock category: #'Tests-Firmata-PCF8574'!
Object subclass: #FirmataPCF8574PortMock
	instanceVariableNames: 'written buffer closed'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-PCF8574'!
!classDefinition: 'FirmataPCF8574PortMock class' category: #'Tests-Firmata-PCF8574'!
FirmataPCF8574PortMock class
	instanceVariableNames: ''!

!classDefinition: #FirmataPCF8574Test category: #'Tests-Firmata-PCF8574'!
TestCase subclass: #FirmataPCF8574Test
	instanceVariableNames: 'device port bus'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-PCF8574'!
!classDefinition: 'FirmataPCF8574Test class' category: #'Tests-Firmata-PCF8574'!
FirmataPCF8574Test class
	instanceVariableNames: ''!


!FirmataPCF8574PortMock commentStamp: 'sf 16/Sep/2026' prior: 0!
I play the role of a serial port for Firmata-PCF8574 tests. Incoming bytes are queued in my buffer and answered by #readByteArray. Writes are recorded in #written.!

!FirmataPCF8574Test commentStamp: 'sf 16/Sep/2026' prior: 0!
I test Firmata-PCF8574 without hardware. Port writes and register-less read requests are asserted byte-exactly against the mock port. Synthetic replies are fed through the mock to check input value parsing.!

!FirmataPCF8574PortMock methodsFor: 'initialize-release' stamp: 'sf 16/Sep/2026 00:00:00'!
initialize
	written := ByteArray new.
	buffer := ByteArray new.
	closed := false! !

!FirmataPCF8574PortMock methodsFor: 'accessing' stamp: 'sf 16/Sep/2026 00:00:00'!
data: aByteArray
	"Bytes the next #readByteArray answers"
	buffer := aByteArray! !

!FirmataPCF8574PortMock methodsFor: 'accessing' stamp: 'sf 16/Sep/2026 00:00:00'!
isClosed
	^ closed! !

!FirmataPCF8574PortMock methodsFor: 'accessing' stamp: 'sf 16/Sep/2026 00:00:00'!
written
	^ written! !

!FirmataPCF8574PortMock methodsFor: 'serial protocol' stamp: 'sf 16/Sep/2026 00:00:00'!
close
	closed := true! !

!FirmataPCF8574PortMock methodsFor: 'serial protocol' stamp: 'sf 16/Sep/2026 00:00:00'!
nextPutAll: aByteArray
	written := written , aByteArray! !

!FirmataPCF8574PortMock methodsFor: 'serial protocol' stamp: 'sf 16/Sep/2026 00:00:00'!
readByteArray
	buffer size > 0
		ifTrue: [ | result |
			result := buffer.
			buffer := ByteArray new.
			^ result ].
	^ ByteArray new! !

!FirmataPCF8574Test methodsFor: 'support' stamp: 'sf 16/Sep/2026 00:00:00'!
replyForPortValue: aByte
	"Build an I2C_REPLY sysex for the PCF8574 at 0x20 with one data byte.
	Register is 0 (dummy from register-less read)."
	| message |
	message := ByteArray new: 9.
	message at: 1 put: 16rF0.
	message at: 2 put: 16r77.
	message at: 3 put: 16r20.
	message at: 4 put: 0.
	message at: 5 put: 0.
	message at: 6 put: 0.
	message at: 7 put: (aByte bitAnd: 127).
	message at: 8 put: ((aByte bitShift: -7) bitAnd: 127).
	message at: 9 put: 16rF7.
	^ message! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
setUp
	port := FirmataPCF8574PortMock new.
	bus := FirmataI2C new.
	bus instVarNamed: 'port' put: port.
	device := FirmataPCF8574 new.
	device firmata: bus address: FirmataPCF8574Constants defaultAddress.
	device registerWithFirmata! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
tearDown
	bus disconnect.
	(Delay forMilliseconds: 50) wait! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testDefaultAddressIs0x20
	self assert: device address equals: 16r20! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testDefaultOutputIsAllHigh
	self assert: device outputValue equals: 16rFF! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testDigitalReadPinBeforeAnyReadIsNil
	"inputValue is nil until a reply arrives."
	self should: [ device digitalReadPin: 0 ] raise: Error! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testDigitalReadPinReturnsFalse
	port data: (self replyForPortValue: 16r55).
	bus processInput.
	self deny: (device digitalReadPin: 1).
	self deny: (device digitalReadPin: 3).
	self deny: (device digitalReadPin: 5).
	self deny: (device digitalReadPin: 7)! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testDigitalReadPinReturnsTrue
	port data: (self replyForPortValue: 16r55).
	bus processInput.
	self assert: (device digitalReadPin: 0).
	self assert: (device digitalReadPin: 2).
	self assert: (device digitalReadPin: 4).
	self assert: (device digitalReadPin: 6)! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testDigitalWritePinClearsBit
	device writePort: 16rFF.
	device digitalWritePin: 4 value: false.
	self assert: device outputValue equals: 16rEF.
	self assert: port written equals:
		#[16rF0 16r76 16r20 0 0 0 16r7F 1 16rF7
		  16rF0 16r76 16r20 0 0 0 16r6F 1 16rF7]! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testDigitalWritePinOutOfRangeFails
	self should: [ device digitalWritePin: 8 value: true ] raise: Error.
	self should: [ device digitalWritePin: -1 value: false ] raise: Error! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testDigitalWritePinSetsBit
	device writePort: 0.
	device digitalWritePin: 4 value: true.
	self assert: device outputValue equals: 16r10.
	self assert: port written equals:
		#[16rF0 16r76 16r20 0 0 0 0 0 16rF7
		  16rF0 16r76 16r20 0 0 0 16r10 0 16rF7]! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testInitializeDeviceReturnsSelf
	self assert: (device initializeDevice) == device! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testInitializeDeviceWritesOutputValue
	"writePort: 0xFF → data byte 0xFF = packed [0x7F, 0x01]."
	device initializeDevice.
	self assert: port written equals:
		#[16rF0 16r76 16r20 0 0 0 16r7F 1 16rF7]! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testReadPortContinuousSendsRegisterlessReadContinuously
	device startReadingPort.
	self assert: port written equals:
		#[16rF0 16r76 16r20 16r10 1 0 16rF7]! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testReadPortSendsRegisterlessRead
	"argc=4: addr, modeRead, countL=1, countH=0."
	device readPort.
	self assert: port written equals:
		#[16rF0 16r76 16r20 16r08 1 0 16rF7]! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testReplyUpdatesInputValue
	port data: (self replyForPortValue: 16rA5).
	bus processInput.
	self assert: device inputValue equals: 16rA5! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testWritePortSendsSingleByteMessage
	device writePort: 16r55.
	self assert: port written equals:
		#[16rF0 16r76 16r20 0 0 0 16r55 0 16rF7]! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testWritePortUpdatesOutputValue
	device writePort: 16r0F.
	self assert: device outputValue equals: 16r0F! !

!FirmataPCF8574Test methodsFor: 'testing' stamp: 'sf 16/Sep/2026 00:00:00'!
testWritePortZeroAllLow
	device writePort: 0.
	self assert: port written equals:
		#[16rF0 16r76 16r20 0 0 0 0 0 16rF7]! !
