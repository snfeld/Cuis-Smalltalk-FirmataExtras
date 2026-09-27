'From Cuis7.8 [latest update: #7977] on 27 September 2026 at 2:52:20 pm'!
'Description '!
!provides: 'Tests-Firmata-I2C' 1 1!
!requires: 'Firmata-I2C' 1 1 nil!
SystemOrganization addCategory: #'Tests-Firmata-I2C'!


!classDefinition: #FirmataI2CTestDevice category: #'Tests-Firmata-I2C'!
FirmataI2CDevice subclass: #FirmataI2CTestDevice
	instanceVariableNames: 'lastRegister lastData'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-I2C'!
!classDefinition: 'FirmataI2CTestDevice class' category: #'Tests-Firmata-I2C'!
FirmataI2CTestDevice class
	instanceVariableNames: ''!

!classDefinition: #FirmataI2CPortMock category: #'Tests-Firmata-I2C'!
Object subclass: #FirmataI2CPortMock
	instanceVariableNames: 'buffer written broken closed'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-I2C'!
!classDefinition: 'FirmataI2CPortMock class' category: #'Tests-Firmata-I2C'!
FirmataI2CPortMock class
	instanceVariableNames: ''!

!classDefinition: #FirmataI2CTest category: #'Tests-Firmata-I2C'!
TestCase subclass: #FirmataI2CTest
	instanceVariableNames: 'firmata port'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-I2C'!
!classDefinition: 'FirmataI2CTest class' category: #'Tests-Firmata-I2C'!
FirmataI2CTest class
	instanceVariableNames: ''!


!FirmataI2CTestDevice commentStamp: 'sf 12/Sep/2026' prior: 0!
I am a minimal concrete device used to verify the reply routing. I record the last reply I received.!

!FirmataI2CPortMock commentStamp: 'sf 12/Sep/2026' prior: 0!
I play the role of a serial port for Firmata-I2C tests. Incoming bytes are queued in my buffer and answered by #readByteArray. Writes are recorded in #written.!

!FirmataI2CTest commentStamp: 'sf 12/Sep/2026' prior: 0!
I test Firmata-I2C without hardware. An in-image mock port answers incoming bytes and records all writes, so the exact protocol bytes can be asserted.!

!FirmataI2CTestDevice methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
lastData
	^ lastData! !

!FirmataI2CTestDevice methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
lastRegister
	^ lastRegister! !

!FirmataI2CTestDevice methodsFor: 'subclass responsibility' stamp: 'sf 12/Sep/2026 00:00:00'!
handleI2CReply: aRegister data: aByteArray
	lastRegister := aRegister.
	lastData := aByteArray! !

!FirmataI2CTestDevice methodsFor: 'subclass responsibility' stamp: 'sf 12/Sep/2026 00:00:00'!
initializeDevice
	"Nothing to configure for the test double."! !

!FirmataI2CTestDevice class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultAddress
	"Use the standard PCA9685 address for the test double."
	^ 16r40! !

!FirmataI2CPortMock methodsFor: 'initialize-release' stamp: 'sf 12/Sep/2026 00:00:00'!
initialize
	buffer := ByteArray new.
	written := ByteArray new.
	broken := false.
	closed := false! !

!FirmataI2CPortMock methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
appendData: aByteArray
	"Add more incoming bytes"
	buffer := buffer , aByteArray! !

!FirmataI2CPortMock methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
breakConnection
	"Simulate a broken serial connection for lifecycle tests"
	broken := true! !

!FirmataI2CPortMock methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
data: aByteArray
	"Bytes the next #readByteArray answers"
	buffer := aByteArray! !

!FirmataI2CPortMock methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
isClosed
	^ closed! !

!FirmataI2CPortMock methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
written
	^ written! !

!FirmataI2CPortMock methodsFor: 'serial protocol' stamp: 'sf 12/Sep/2026 00:00:00'!
close
	closed := true! !

!FirmataI2CPortMock methodsFor: 'serial protocol' stamp: 'sf 12/Sep/2026 00:00:00'!
nextPutAll: aByteArray
	written := written , aByteArray! !

!FirmataI2CPortMock methodsFor: 'serial protocol' stamp: 'sf 12/Sep/2026 00:00:00'!
readByteArray
	buffer size > 0
		ifTrue: [ | result |
			result := buffer.
			buffer := ByteArray new.
			^ result ].
	broken
		ifTrue: [ self error: 'simulated serial failure' ].
	^ ByteArray new! !

!FirmataI2CTest methodsFor: 'support' stamp: 'sf 12/Sep/2026 00:00:00'!
firmwareSysexForName: aName
	"REPORT_FIRMWARE sysex: 0xF0 0x79 <name as 14-bit characters>
	<major 7-bit> <minor 7-bit> 0xF7"
	| message |
	message := ByteArray new: 2 + (aName size * 2) + 3.
	message at: 1 put: 16rF0; at: 2 put: 16r79.
	1 to: aName size do: [ :i |
		| code |
		code := (aName at: i) codePoint.
		message at: (2 + ((i - 1) * 2) + 1) put: (code bitAnd: 127).
		message at: (2 + ((i - 1) * 2) + 2) put: ((code bitShift: -7) bitAnd: 127) ].
	message at: (2 + (aName size * 2) + 1) put: 2.
	message at: (2 + (aName size * 2) + 2) put: 5.
	message at: (2 + (aName size * 2) + 3) put: 16rF7.
	^ message! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
setUp
	"Each test gets a FirmataI2C instance with an in-image mock port."
	port := FirmataI2CPortMock new.
	firmata := FirmataI2C new.
	firmata instVarNamed: 'port' put: port! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
tearDown
	"Leave no background stepping process running across tests."
	firmata disconnect.
	(Delay forMilliseconds: 50) wait! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testDeviceDefaultAddressIsSubclassResponsibility
	self should: [ FirmataI2CDevice defaultAddress ] raise: Error! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testDeviceInitializeIsSubclassResponsibility
	self should: [ (FirmataI2CDevice basicNew) initializeDevice ] raise: Error! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testDeviceReadRegisterGoesThroughFirmata
	| device |
	device := FirmataI2CTestDevice new.
	device firmata: firmata address: 16r40.
	device readRegister: 6 byteCount: 4.
	self assert: port written equals: #[16rF0 16r76 16r40 16r08 6 0 4 0 16rF7]! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testDeviceReplyHandlingIsSubclassResponsibility
	self should: [ (FirmataI2CDevice basicNew) handleI2CReply: 0 data: #[0] ] raise: Error! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testDeviceStopReadingGoesThroughFirmata
	| device |
	device := FirmataI2CTestDevice new.
	device firmata: firmata address: 16r40.
	device stopReading.
	self assert: port written equals: #[16rF0 16r76 16r40 16r18 16rF7]! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testDeviceWriteRegisterGoesThroughFirmata
	| device |
	device := FirmataI2CTestDevice new.
	device firmata: firmata address: 16r40.
	device writeRegister: 3 data: #[1].
	self assert: port written equals: #[16rF0 16r76 16r40 0 3 0 1 0 16rF7]! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testFirmwareSysexStillIgnoredSafely
	"Non-I2C sysex messages must keep the safe ignore behavior."
	port data: (self firmwareSysexForName: 'StandardFirmataPlus.ino').
	self shouldnt: [ firmata processInput ] raise: Error.
	self deny: (firmata instVarNamed: 'parsingSysex')! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CConfigDelaySendsExpectedBytes
	firmata i2cConfigDelay: 300.
	self assert: port written equals: #[16rF0 16r78 44 2 16rF7]! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CConfigSendsExpectedBytes
	firmata i2cConfig.
	self assert: port written equals: #[16rF0 16r78 0 0 16rF7]! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CRepliesAreRoutedPerSlaveAddress
	| deviceA deviceB |
	deviceA := FirmataI2CTestDevice new firmata: firmata address: 16r40.
	deviceB := FirmataI2CTestDevice new firmata: firmata address: 16r41.
	deviceA registerWithFirmata.
	deviceB registerWithFirmata.
	port data: #[16rF0 16r77 16r41 0 0 0 7 0 16rF7].
	firmata processInput.
	self assert: deviceA lastRegister isNil.
	self assert: deviceB lastData equals: #[7]! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CReplyIgnoredWhenNoDeviceRegistered
	port data: #[16rF0 16r77 16r40 0 6 0 32 0 16rF7].
	self shouldnt: [ firmata processInput ] raise: Error! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CReplyIsForwardedToRegisteredDevice
	| device |
	device := FirmataI2CTestDevice new.
	device firmata: firmata address: 16r40.
	device registerWithFirmata.
	port data: #[16rF0 16r77 16r40 0 6 0 32 0 16rF7].
	firmata processInput.
	self assert: device lastRegister equals: 6.
	self assert: device lastData equals: #[32]! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CRequestReadContinuouslySendsExpectedBytes
	firmata i2cRequestReadContinuously: 16r40 register: 6 byteCount: 2.
	self assert: port written equals: #[16rF0 16r76 16r40 16r10 6 0 2 0 16rF7]! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CRequestReadSendsExpectedBytes
	firmata i2cRequestRead: 16r40 register: 6 byteCount: 4.
	self assert: port written equals: #[16rF0 16r76 16r40 16r08 6 0 4 0 16rF7]! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CRequestWritePacksValueAboveSevenBits
	"Byte values above 127 travel as a low and a high 7-bit byte."
	firmata i2cRequestWrite: 16r40 register: 0 data: #[16rFF].
	self assert: port written equals: #[16rF0 16r76 16r40 0 0 0 127 1 16rF7]! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CRequestWriteSendsExpectedBytes
	firmata i2cRequestWrite: 16r40 register: 6 data: #[16r10].
	self assert: port written equals: #[16rF0 16r76 16r40 0 6 0 16 0 16rF7]! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CRequestWriteSendsMultipleDataBytes
	firmata i2cRequestWrite: 16r40 register: 0 data: #[1 2 3].
	self assert: port written equals: #[16rF0 16r76 16r40 0 0 0 1 0 2 0 3 0 16rF7]! !

!FirmataI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CStopReadingSendsExpectedBytes
	firmata i2cStopReading: 16r40.
	self assert: port written equals: #[16rF0 16r76 16r40 16r18 16rF7]! !
