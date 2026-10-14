'From Cuis7.8 [latest update: #7977] on 27 September 2026 at 2:41:54 pm'!
'Description '!
!provides: 'Firmata-Net' 1 1!
!requires: 'Network-Kernel' 1 nil 1!
!requires: 'Firmata' 1 4 nil!
!requires: 'Firmata-I2C' 1 1 nil!
SystemOrganization addCategory: #'Firmata-Net'!


!classDefinition: #FirmataNetI2C category: #'Firmata-Net'!
FirmataI2C subclass: #FirmataNetI2C
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-Net'!
!classDefinition: 'FirmataNetI2C class' category: #'Firmata-Net'!
FirmataNetI2C class
	instanceVariableNames: ''!

!classDefinition: #FirmataNet category: #'Firmata-Net'!
Firmata subclass: #FirmataNet
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-Net'!
!classDefinition: 'FirmataNet class' category: #'Firmata-Net'!
FirmataNet class
	instanceVariableNames: ''!

!classDefinition: #FirmataNetConstants category: #'Firmata-Net'!
Object subclass: #FirmataNetConstants
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-Net'!
!classDefinition: 'FirmataNetConstants class' category: #'Firmata-Net'!
FirmataNetConstants class
	instanceVariableNames: ''!

!classDefinition: #FirmataNetPort category: #'Firmata-Net'!
Object subclass: #FirmataNetPort
	instanceVariableNames: 'stream'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-Net'!
!classDefinition: 'FirmataNetPort class' category: #'Firmata-Net'!
FirmataNetPort class
	instanceVariableNames: ''!


!FirmataNetI2C commentStamp: 'sf 12/Sep/2026' prior: 0!
I am the I2C capable variant of FirmataNet: network connection plus all the I2C sysex support in one object.!

!FirmataNet commentStamp: 'sf 12/Sep/2026' prior: 0!
I connect Firmata to an Arduino over TCP/IP. #connectToHost:port: follows the same flow as the serial #connectOnPort:baudRate: but dials a network address, so every command of the base protocol works unchanged. The default port is #FirmataNetConstants defaultPort.!

!FirmataNetConstants commentStamp: 'sf 12/Sep/2026' prior: 0!
See class side. I collect the connection defaults of the Firmata-Net package.!

!FirmataNetPort commentStamp: 'sf 12/Sep/2026' prior: 0!
I wrap a SocketStream as the byte transport behind one Firmata connection. #readByteArray answers whatever is currently available without ever waiting, because the Firmata parser carries its message state across chunks. Writes go through the stream buffering and are flushed immediately.!

!FirmataNetI2C methodsFor: 'connection' stamp: 'sf 12/Sep/2026 00:00:00'!
connectToHost: aHostName
	^ self connectToHost: aHostName port: FirmataNetConstants defaultPort! !

!FirmataNetI2C methodsFor: 'connection' stamp: 'sf 12/Sep/2026 00:00:00'!
connectToHost: aHostName port: aPort
	"Open the network port and start the same handshake as the serial
	connection. Throws when the host cannot be reached."
	self isConnected ifTrue: [ ^ self ].
	port := self createPortToHost: aHostName port: aPort.
	self isConnected ifTrue: [
		self
			startSteppingProcess;
			controlFirmataInstallation ].
	^ self! !

!FirmataNetI2C methodsFor: 'connection' stamp: 'sf 12/Sep/2026 00:00:00'!
createPortToHost: aHostName port: aPort
	"Overridable, so tests can substitute a mock transport."
	^ FirmataNetPort openToHostNamed: aHostName port: aPort! !

!FirmataNetI2C methodsFor: 'stepping' stamp: 'sf 12/Sep/2026 00:00:00'!
stepTime
	"Polling a network port is a bit more expensive than reading a
	serial port, so poll less often than the base class."
	^ 10! !

!FirmataNet methodsFor: 'connection' stamp: 'sf 12/Sep/2026 00:00:00'!
connectToHost: aHostName
	^ self connectToHost: aHostName port: FirmataNetConstants defaultPort! !

!FirmataNet methodsFor: 'connection' stamp: 'sf 12/Sep/2026 00:00:00'!
connectToHost: aHostName port: aPort
	"Open the network port and start the same handshake as the serial
	connection. Throws when the host cannot be reached."
	self isConnected ifTrue: [ ^ self ].
	port := self createPortToHost: aHostName port: aPort.
	self isConnected ifTrue: [
		self
			startSteppingProcess;
			controlFirmataInstallation ].
	^ self! !

!FirmataNet methodsFor: 'connection' stamp: 'sf 12/Sep/2026 00:00:00'!
createPortToHost: aHostName port: aPort
	"Overridable, so tests can substitute a mock transport."
	^ FirmataNetPort openToHostNamed: aHostName port: aPort! !

!FirmataNet methodsFor: 'stepping' stamp: 'sf 12/Sep/2026 00:00:00'!
stepTime
	"Polling a network port is a bit more expensive than reading a
	serial port, so poll less often than the base class."
	^ 10! !

!FirmataNetConstants class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultPort
	"Fallback TCP port used when #connectToHost: is called without one."
	^ 3030! !

!FirmataNetPort methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
stream
	^ stream! !

!FirmataNetPort methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
stream: aSocketStream
	stream := aSocketStream.
	^ self! !

!FirmataNetPort methodsFor: 'reading' stamp: 'sf 12/Sep/2026 00:00:00'!
readByteArray
	"Answer the bytes that are available right now without waiting for
	more. An empty ByteArray is returned when there is nothing to read
	or the connection is gone. Partial messages are fine: the Firmata
	parser keeps its state across chunks."
	| result |
	stream isNil ifTrue: [ ^ ByteArray new ].
	stream isConnected ifFalse: [ ^ ByteArray new ].
	result := WriteStream on: (ByteArray new: 64).
	[ stream isDataAvailable and: [ result size < 4096 ] ]
		whileTrue: [ result nextPut: stream next ].
	^ result contents! !

!FirmataNetPort methodsFor: 'writing' stamp: 'sf 12/Sep/2026 00:00:00'!
nextPutAll: aByteArray
	stream nextPutAll: aByteArray; flush.
	^ aByteArray! !

!FirmataNetPort methodsFor: 'closing' stamp: 'sf 12/Sep/2026 00:00:00'!
close
	stream ifNotNil: [
		[ stream close ]
			on: Error
			do: [ :error | ] ].
	stream := nil! !

!FirmataNetPort methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
isConnected
	^ stream notNil and: [ stream isConnected ]! !

!FirmataNetPort class methodsFor: 'instance creation' stamp: 'sf 12/Sep/2026 00:00:00'!
openToHostNamed: aHostName port: aPort
	"Resolve the given host name and open a fresh binary TCP stream."
	| aStream |
	aStream := SocketStream openConnectionToHostNamed: aHostName port: aPort.
	aStream binary.
	^ self new stream: aStream! !
