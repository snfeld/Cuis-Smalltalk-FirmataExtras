'From Cuis7.8 [latest update: #7977] on 27 September 2026 at 2:52:23 pm'!
'Description '!
!provides: 'Tests-Firmata-Net' 1 1!
!requires: 'Firmata-Net' 1 1 nil!
SystemOrganization addCategory: #'Tests-Firmata-Net'!


!classDefinition: #FirmataNetI2CStubPort category: #'Tests-Firmata-Net'!
FirmataNetI2C subclass: #FirmataNetI2CStubPort
	instanceVariableNames: 'innerStream'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-Net'!
!classDefinition: 'FirmataNetI2CStubPort class' category: #'Tests-Firmata-Net'!
FirmataNetI2CStubPort class
	instanceVariableNames: ''!

!classDefinition: #FirmataNetStubPort category: #'Tests-Firmata-Net'!
FirmataNet subclass: #FirmataNetStubPort
	instanceVariableNames: 'innerStream'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-Net'!
!classDefinition: 'FirmataNetStubPort class' category: #'Tests-Firmata-Net'!
FirmataNetStubPort class
	instanceVariableNames: ''!

!classDefinition: #FirmataNetStreamMock category: #'Tests-Firmata-Net'!
Object subclass: #FirmataNetStreamMock
	instanceVariableNames: 'buffer written closed'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-Net'!
!classDefinition: 'FirmataNetStreamMock class' category: #'Tests-Firmata-Net'!
FirmataNetStreamMock class
	instanceVariableNames: ''!

!classDefinition: #FirmataNetI2CTest category: #'Tests-Firmata-Net'!
TestCase subclass: #FirmataNetI2CTest
	instanceVariableNames: 'net innerStream'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-Net'!
!classDefinition: 'FirmataNetI2CTest class' category: #'Tests-Firmata-Net'!
FirmataNetI2CTest class
	instanceVariableNames: ''!

!classDefinition: #FirmataNetTest category: #'Tests-Firmata-Net'!
TestCase subclass: #FirmataNetTest
	instanceVariableNames: 'net innerStream'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-Net'!
!classDefinition: 'FirmataNetTest class' category: #'Tests-Firmata-Net'!
FirmataNetTest class
	instanceVariableNames: ''!


!FirmataNetI2CStubPort commentStamp: 'sf 12/Sep/2026' prior: 0!
I am the I2C variant of FirmataNetStubPort, so the I2C commands can be tested over a mocked connection.!

!FirmataNetStubPort commentStamp: 'sf 12/Sep/2026' prior: 0!
I make FirmataNet connect to a mock byte stream instead of a real socket: #createPortToHost:port: wraps my inner stream in a FirmataNetPort.!

!FirmataNetStreamMock commentStamp: 'sf 12/Sep/2026' prior: 0!
I play the role of the SocketStream behind a FirmataNetPort in tests. Incoming bytes are queued in my buffer and answered by #next; writes are recorded in #written. Asking for the protocol version (single byte 0xF9) queues a version reply, just like a real board would.!

!FirmataNetI2CStubPort methodsFor: 'connection' stamp: 'sf 12/Sep/2026 00:00:00'!
createPortToHost: aHostName port: aPort
	^ FirmataNetPort new stream: innerStream! !

!FirmataNetI2CStubPort methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
innerStream: aMock
	innerStream := aMock! !

!FirmataNetStubPort methodsFor: 'connection' stamp: 'sf 12/Sep/2026 00:00:00'!
createPortToHost: aHostName port: aPort
	^ FirmataNetPort new stream: innerStream! !

!FirmataNetStubPort methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
innerStream: aMock
	innerStream := aMock! !

!FirmataNetStreamMock methodsFor: 'initialize' stamp: 'sf 12/Sep/2026 00:00:00'!
initialize
	super initialize.
	buffer := ByteArray new.
	closed := false! !

!FirmataNetStreamMock methodsFor: 'reading' stamp: 'sf 12/Sep/2026 00:00:00'!
isDataAvailable
	^ buffer notNil and: [ buffer isEmpty not ]! !

!FirmataNetStreamMock methodsFor: 'reading' stamp: 'sf 12/Sep/2026 00:00:00'!
next
	| byte |
	byte := buffer first.
	buffer := buffer allButFirst.
	^ byte! !

!FirmataNetStreamMock methodsFor: 'writing' stamp: 'sf 12/Sep/2026 00:00:00'!
flush
	^ self! !

!FirmataNetStreamMock methodsFor: 'writing' stamp: 'sf 12/Sep/2026 00:00:00'!
nextPutAll: aByteArray
	"Record the write. A protocol version query is answered like a real board."
	| bytes |
	bytes := aByteArray asByteArray.
	written := (written ifNil: [ ByteArray new ]) , bytes.
	(bytes size = 1 and: [ bytes first = FirmataConstants reportVersion ])
		ifTrue: [ buffer := #[16rF9 2 5] ].
	^ aByteArray! !

!FirmataNetStreamMock methodsFor: 'closing' stamp: 'sf 12/Sep/2026 00:00:00'!
close
	closed := true! !

!FirmataNetStreamMock methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
isConnected
	^ closed not! !

!FirmataNetStreamMock methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
buffer: aByteArray
	buffer := aByteArray! !

!FirmataNetStreamMock methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
written
	^ written ifNil: [ ByteArray new ]! !

!FirmataNetI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
setUp
	innerStream := FirmataNetStreamMock new.
	net := FirmataNetI2CStubPort new.
	net innerStream: innerStream! !

!FirmataNetI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
tearDown
	net disconnect! !

!FirmataNetI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testConnectToHostConnectsAndFindsFirmware
	self connectNet.
	self assert: net version equals: 2.5! !

!FirmataNetI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CConfigOverNetworkConnection
	self connectNet.
	net i2cConfig.
	self assertLastWritten: #[16rF0 16r78 0 0 16rF7]! !

!FirmataNetI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CRequestReadOverNetworkConnection
	self connectNet.
	net i2cRequestRead: 16r40 register: 16r3B byteCount: 14.
	self assertLastWritten: #[16rF0 16r76 16r40 16r08 16r3B 0 14 0 16rF7]! !

!FirmataNetI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CRequestWriteOverNetworkConnection
	self connectNet.
	net i2cRequestWrite: 16r40 register: 0 data: #[16r10].
	self assertLastWritten: #[16rF0 16r76 16r40 0 0 0 16r10 0 16rF7]! !

!FirmataNetI2CTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testI2CStopReadingOverNetworkConnection
	self connectNet.
	net i2cStopReading: 16r68.
	self assertLastWritten: #[16rF0 16r76 16r68 16r18 16rF7]! !

!FirmataNetI2CTest methodsFor: 'support' stamp: 'sf 12/Sep/2026 00:00:00'!
assertLastWritten: aByteArray
	self assert: (innerStream written last: aByteArray size) equals: aByteArray! !

!FirmataNetI2CTest methodsFor: 'support' stamp: 'sf 12/Sep/2026 00:00:00'!
connectNet
	net connectToHost: '192.168.1.20' port: 3030.
	self assert: net isConnected! !

!FirmataNetTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
setUp
	innerStream := FirmataNetStreamMock new.
	net := FirmataNetStubPort new.
	net innerStream: innerStream! !

!FirmataNetTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
tearDown
	net disconnect! !

!FirmataNetTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testCloseReleasesStreamAndMakesPortEmpty
	| port |
	port := FirmataNetPort new stream: innerStream.
	port close.
	self deny: port isConnected.
	self deny: innerStream isConnected.
	self assert: port readByteArray isEmpty! !

!FirmataNetTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testConnectToHostInstallsPortAndDiscoversFirmwareVersion
	self connectNet.
	self assert: net version equals: 2.5.
	self assert: (innerStream written includes: FirmataConstants reportVersion)! !

!FirmataNetTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testConnectToHostStartsAndStopsSteppingProcess
	self connectNet.
	self assert: (net instVarNamed: 'steppingProcess') notNil.
	net disconnect.
	self deny: net isConnected.
	self assert: (net instVarNamed: 'steppingProcess') isNil! !

!FirmataNetTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testNextPutAllWritesAndFlushesThroughTheStream
	| port |
	port := FirmataNetPort new stream: innerStream.
	port nextPutAll: (ByteArray
		with: FirmataConstants startSysex
		with: FirmataI2CConstants i2cRequest).
	self assert: innerStream written equals: #[16rF0 16r76]! !

!FirmataNetTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testReadByteArrayReturnsAllAvailableBytes
	| port |
	innerStream buffer: #[1 2 3 4].
	port := FirmataNetPort new stream: innerStream.
	self assert: port readByteArray equals: #[1 2 3 4].
	self assert: port readByteArray isEmpty! !

!FirmataNetTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testReadByteArrayReturnsEmptyWhenNoDataIsAvailable
	| port |
	port := FirmataNetPort new stream: innerStream.
	self assert: port readByteArray isEmpty.
	self assert: port isConnected! !

!FirmataNetTest methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testStepParsesIncomingVersionWithoutConnection
	innerStream buffer: #[16rF9 3 7].
	net instVarNamed: 'port' put: (FirmataNetPort new stream: innerStream).
	net step.
	self assert: net majorVersion equals: 3.
	self assert: net minorVersion equals: 7! !

!FirmataNetTest methodsFor: 'support' stamp: 'sf 12/Sep/2026 00:00:00'!
connectNet
	net connectToHost: '127.0.0.1' port: 3030.
	self assert: net isConnected! !
