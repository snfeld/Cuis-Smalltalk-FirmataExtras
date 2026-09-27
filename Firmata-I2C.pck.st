'From Cuis7.8 [latest update: #7977] on 27 September 2026 at 2:41:06 pm'!
'Description '!
!provides: 'Firmata-I2C' 1 1!
!requires: 'Firmata' 1 4 nil!
SystemOrganization addCategory: #'Firmata-I2C'!


!classDefinition: #FirmataI2C category: #'Firmata-I2C'!
Firmata subclass: #FirmataI2C
	instanceVariableNames: 'i2cDevices'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-I2C'!
!classDefinition: 'FirmataI2C class' category: #'Firmata-I2C'!
FirmataI2C class
	instanceVariableNames: ''!

!classDefinition: #FirmataI2CConstants category: #'Firmata-I2C'!
Object subclass: #FirmataI2CConstants
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-I2C'!
!classDefinition: 'FirmataI2CConstants class' category: #'Firmata-I2C'!
FirmataI2CConstants class
	instanceVariableNames: ''!

!classDefinition: #FirmataI2CDevice category: #'Firmata-I2C'!
Object subclass: #FirmataI2CDevice
	instanceVariableNames: 'firmata address'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-I2C'!
!classDefinition: 'FirmataI2CDevice class' category: #'Firmata-I2C'!
FirmataI2CDevice class
	instanceVariableNames: ''!


!FirmataI2C commentStamp: 'sf 12/Sep/2026' prior: 0!
I extend Firmata with the I2C sysex commands of the Firmata protocol so that I2C devices on the Arduino bus can be addressed from Cuis. See the protocol spec at https://github.com/firmata/protocol.

The low-level messages are #i2cRequestWrite:register:data:, #i2cRequestRead:register:byteCount:, #i2cRequestReadContinuously:register:byteCount:, #i2cStopReading:, #i2cConfig and #i2cConfigDelay:.

Incoming I2C_REPLY messages are dispatched to the device registered for the slave address, see #registerI2CDevice:. All other sysex messages keep the base class behavior of being collected and ignored.!

!FirmataI2CConstants commentStamp: 'sf 12/Sep/2026' prior: 0!
See class side. I collect the I2C sysex command numbers and mode flags of the Firmata protocol.!

!FirmataI2CDevice commentStamp: 'sf 12/Sep/2026' prior: 0!
I am the abstract base class for I2C devices behind a FirmataI2C connection. A device wraps the connection plus its slave address and offers the shared I2C operations, so subclasses only implement the device specific behavior.

Subclasses must implement #initializeDevice to configure the device on the bus and #handleI2CReply:data: to react to incoming reads (see FirmataPCA9685 for a concrete example). Classes that receive replies should call #registerWithFirmata after wiring.!

!FirmataI2C methodsFor: 'initialize-release' stamp: 'sf 12/Sep/2026 00:00:00'!
initializeVariables
	"Add the device registry on top of the base protocol state."
	super initializeVariables.
	i2cDevices := Dictionary new! !

!FirmataI2C methodsFor: 'device support' stamp: 'sf 12/Sep/2026 00:00:00'!
registerI2CDevice: aDevice
	"Make replies for aDevice's slave address be forwarded to aDevice."
	i2cDevices at: aDevice address put: aDevice! !

!FirmataI2C methodsFor: 'device support' stamp: 'sf 12/Sep/2026 00:00:00'!
registeredDeviceFor: anAddress
	^ i2cDevices at: anAddress ifAbsent: [ nil ]! !

!FirmataI2C methodsFor: 'sysex parsing' stamp: 'sf 12/Sep/2026 00:00:00'!
dispatchSysexMessageOfLength: messageLength
	"Route completed sysex messages. Only I2C_REPLY is acted on so far."
	messageLength = 0 ifTrue: [ ^ self ].
	(storedInputData first = FirmataI2CConstants i2cReply)
		ifTrue: [ self parseI2CReplyOfLength: messageLength ]! !

!FirmataI2C methodsFor: 'sysex parsing' stamp: 'sf 12/Sep/2026 00:00:00'!
parseI2CReplyOfLength: messageLength
	"Parse an I2C_REPLY message and forward it to the device that asked
	for the data. The collected bytes (without the START_SYSEX header byte)
	are: command, slave address, register, data pairs and END_SYSEX; each
	value is stored as a 7-bit LSB/MSB pair."
	| slaveAddress register dataLength data index |
	messageLength < 5 ifTrue: [ ^ self ].
	slaveAddress := (storedInputData at: 2)
		bitOr: ((storedInputData at: 3) bitShift: 7).
	register := (storedInputData at: 4)
		bitOr: ((storedInputData at: 5) bitShift: 7).
	dataLength := (messageLength - 5) // 2.
	data := ByteArray new: dataLength.
	1 to: dataLength do: [ :i |
		index := 6 + ((i - 1) * 2).
		data at: i put: ((storedInputData at: index)
			bitOr: ((storedInputData at: index + 1) bitShift: 7)) ].
	(self registeredDeviceFor: slaveAddress)
		ifNotNil: [ :device | device handleI2CReply: register data: data ]! !

!FirmataI2C methodsFor: 'sysex parsing' stamp: 'sf 12/Sep/2026 00:00:00'!
parseSysex: inputByte
	"Collect the whole sysex message and dispatch it once it ends."
	inputByte = FirmataConstants endSysex
		ifTrue: [
			| messageLength |
			messageLength := sysexBytesRead.
			parsingSysex := false.
			sysexBytesRead := 0.
			self dispatchSysexMessageOfLength: messageLength ]
		ifFalse: [
			sysexBytesRead < storedInputData size
				ifTrue: [ storedInputData at: sysexBytesRead + 1 put: inputByte ].
			sysexBytesRead := sysexBytesRead + 1 ]! !

!FirmataI2C methodsFor: 'i2c messages' stamp: 'sf 12/Sep/2026 00:00:00'!
i2cConfig
	"Set the I2C read delay to zero for the whole bus."
	self i2cConfigDelay: 0! !

!FirmataI2C methodsFor: 'i2c messages' stamp: 'sf 12/Sep/2026 00:00:00'!
i2cConfigDelay: delayMicroseconds
	"Set the delay between an I2C request and reading the reply."
	self port nextPutAll: (self sysexMessageWith: (ByteArray
		with: FirmataI2CConstants i2cConfig
		with: (delayMicroseconds bitAnd: 127)
		with: ((delayMicroseconds bitShift: -7) bitAnd: 127)))! !

!FirmataI2C methodsFor: 'i2c messages' stamp: 'sf 12/Sep/2026 00:00:00'!
i2cRequestRead: slaveAddress register: register byteCount: count
	"Send a single-read I2C request for one register."
	self sendReadRequestTo: slaveAddress
		register: register
		count: count
		mode: FirmataI2CConstants modeRead! !

!FirmataI2C methodsFor: 'i2c messages' stamp: 'sf 12/Sep/2026 00:00:00'!
i2cRequestReadContinuously: slaveAddress register: register byteCount: count
	"Ask the board to keep reading a register and report value changes."
	self sendReadRequestTo: slaveAddress
		register: register
		count: count
		mode: FirmataI2CConstants modeReadContinuously! !

!FirmataI2C methodsFor: 'i2c messages' stamp: 'sf 12/Sep/2026 00:00:00'!
i2cRequestWrite: slaveAddress register: register data: data
	"Send an I2C write: set the register, then write the data bytes."
	self port nextPutAll: (self
		i2cRequestTo: slaveAddress
		mode: FirmataI2CConstants modeWrite
		register: register
		payload: (self packedBytesForData: data))! !

!FirmataI2C methodsFor: 'i2c messages' stamp: 'sf 12/Sep/2026 00:00:00'!
i2cStopReading: slaveAddress
	"Stop continuous reads for a slave address."
	self port nextPutAll: (ByteArray
		with: FirmataConstants startSysex
		with: FirmataI2CConstants i2cRequest
		with: (slaveAddress bitAnd: 127)
		with: FirmataI2CConstants modeStopReading
		with: FirmataConstants endSysex)! !

!FirmataI2C methodsFor: 'i2c messages - private' stamp: 'sf 12/Sep/2026 00:00:00'!
i2cRequestTo: slaveAddress mode: aMode register: aRegister payload: aByteArray
	"Build an I2C_REQUEST sysex message from packed payload bytes."
	| message |
	message := ByteArray new: 7 + aByteArray size.
	message at: 1 put: FirmataConstants startSysex.
	message at: 2 put: FirmataI2CConstants i2cRequest.
	message at: 3 put: (slaveAddress bitAnd: 127).
	message at: 4 put: (aMode bitAnd: 127).
	message at: 5 put: (aRegister bitAnd: 127).
	message at: 6 put: ((aRegister bitShift: -7) bitAnd: 127).
	1 to: aByteArray size do: [ :i |
		message at: 6 + i put: (aByteArray at: i) ].
	message at: message size put: FirmataConstants endSysex.
	^ message! !

!FirmataI2C methodsFor: 'i2c messages - private' stamp: 'sf 12/Sep/2026 00:00:00'!
packedBytesForData: aByteArray
	"7-bit pack each data byte as a LSB/MSB pair."
	| packed |
	packed := ByteArray new: aByteArray size * 2.
	1 to: aByteArray size do: [ :i |
		| value |
		value := aByteArray at: i.
		packed at: ((i - 1) * 2) + 1 put: (value bitAnd: 127).
		packed at: ((i - 1) * 2) + 2 put: ((value bitShift: -7) bitAnd: 127) ].
	^ packed! !

!FirmataI2C methodsFor: 'i2c messages - private' stamp: 'sf 12/Sep/2026 00:00:00'!
packedNumber: aNumber
	"7-bit pack one 14-bit value as a LSB/MSB pair."
	^ ByteArray with: (aNumber bitAnd: 127) with: ((aNumber bitShift: -7) bitAnd: 127)! !

!FirmataI2C methodsFor: 'i2c messages - private' stamp: 'sf 12/Sep/2026 00:00:00'!
sendReadRequestTo: slaveAddress register: register count: count mode: aMode
	"Read requests carry the read count as a 14-bit payload value."
	self port nextPutAll: (self
		i2cRequestTo: slaveAddress
		mode: aMode
		register: register
		payload: (self packedNumber: count))! !

!FirmataI2C methodsFor: 'private' stamp: 'sf 12/Sep/2026 00:00:00'!
sysexMessageWith: aByteArray
	"Wrap a payload in the sysex start and end bytes."
	| message |
	message := ByteArray new: aByteArray size + 2.
	message at: 1 put: FirmataConstants startSysex.
	1 to: aByteArray size do: [ :i |
		message at: i + 1 put: (aByteArray at: i) ].
	message at: message size put: FirmataConstants endSysex.
	^ message! !

!FirmataI2CConstants class methodsFor: 'i2c commands' stamp: 'sf 12/Sep/2026 00:00:00'!
i2cConfig
	"0x78 sysex command configuring the I2C read delay"
	^ 16r78! !

!FirmataI2CConstants class methodsFor: 'i2c commands' stamp: 'sf 12/Sep/2026 00:00:00'!
i2cReply
	"0x77 sysex command carrying I2C data from the board"
	^ 16r77! !

!FirmataI2CConstants class methodsFor: 'i2c commands' stamp: 'sf 12/Sep/2026 00:00:00'!
i2cRequest
	"0x76 sysex command to request an I2C transaction"
	^ 16r76! !

!FirmataI2CConstants class methodsFor: 'i2c modes' stamp: 'sf 12/Sep/2026 00:00:00'!
modeRead
	"Read a register once"
	^ 16r08! !

!FirmataI2CConstants class methodsFor: 'i2c modes' stamp: 'sf 12/Sep/2026 00:00:00'!
modeReadContinuously
	"Read a register and keep reporting it"
	^ 16r10! !

!FirmataI2CConstants class methodsFor: 'i2c modes' stamp: 'sf 12/Sep/2026 00:00:00'!
modeStopReading
	"Stop continuous reading"
	^ 16r18! !

!FirmataI2CConstants class methodsFor: 'i2c modes' stamp: 'sf 12/Sep/2026 00:00:00'!
modeWrite
	"Write data to the bus"
	^ 0! !

!FirmataI2CConstants class methodsFor: 'i2c flags' stamp: 'sf 12/Sep/2026 00:00:00'!
endOfTransmissionFlag
	"Bit asking for restart instead of stop after a transaction"
	^ 16r40! !

!FirmataI2CDevice methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
address
	^ address! !

!FirmataI2CDevice methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
address: anInteger
	address := anInteger! !

!FirmataI2CDevice methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
firmata
	^ firmata! !

!FirmataI2CDevice methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
firmata: aFirmataI2C
	firmata := aFirmataI2C! !

!FirmataI2CDevice methodsFor: 'initialize-release' stamp: 'sf 12/Sep/2026 00:00:00'!
initialize
	address := self class defaultAddress! !

!FirmataI2CDevice methodsFor: 'wiring' stamp: 'sf 12/Sep/2026 00:00:00'!
firmata: aFirmataI2C address: anInteger
	"Wire the device to a connection and set its slave address."
	firmata := aFirmataI2C.
	address := anInteger.
	^ self! !

!FirmataI2CDevice methodsFor: 'wiring' stamp: 'sf 12/Sep/2026 00:00:00'!
registerWithFirmata
	"Register myself so incoming replies for my address reach me."
	firmata registerI2CDevice: self! !

!FirmataI2CDevice methodsFor: 'i2c operations' stamp: 'sf 12/Sep/2026 00:00:00'!
readRegister: aRegister byteCount: count
	"Read count bytes from one of my registers."
	firmata i2cRequestRead: address register: aRegister byteCount: count! !

!FirmataI2CDevice methodsFor: 'i2c operations' stamp: 'sf 12/Sep/2026 00:00:00'!
readRegisterContinuously: aRegister byteCount: count
	"Keep reading a register; the board reports value changes."
	firmata i2cRequestReadContinuously: address register: aRegister byteCount: count! !

!FirmataI2CDevice methodsFor: 'i2c operations' stamp: 'sf 12/Sep/2026 00:00:00'!
stopReading
	"Stop continuous reads for my slave address."
	firmata i2cStopReading: address! !

!FirmataI2CDevice methodsFor: 'i2c operations' stamp: 'sf 12/Sep/2026 00:00:00'!
writeRegister: aRegister data: aByteArray
	"Write data bytes to one of my registers."
	firmata i2cRequestWrite: address register: aRegister data: aByteArray! !

!FirmataI2CDevice methodsFor: 'subclass responsibility' stamp: 'sf 12/Sep/2026 00:00:00'!
handleI2CReply: aRegister data: aByteArray
	"Process an incoming I2C reply for my slave address. Subclass responsibility."
	^ self subclassResponsibility! !

!FirmataI2CDevice methodsFor: 'subclass responsibility' stamp: 'sf 12/Sep/2026 00:00:00'!
initializeDevice
	"Configure the device on the bus. Subclass responsibility."
	^ self subclassResponsibility! !

!FirmataI2CDevice class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultAddress
	"Subclasses define the typical slave address of their device."
	^ self subclassResponsibility! !
