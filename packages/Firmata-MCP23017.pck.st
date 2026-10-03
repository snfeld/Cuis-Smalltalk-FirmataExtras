'From Cuis7.8 [latest update: #7977] on 3 October 2026 at 5:23:25 pm'!
'Description '!
!provides: 'Firmata-MCP23017' 1 1!
!requires: 'Firmata-I2C' 1 1 nil!
SystemOrganization addCategory: #'Firmata-MCP23017'!


!classDefinition: #FirmataMCP23017 category: #'Firmata-MCP23017'!
FirmataI2CDevice subclass: #FirmataMCP23017
	instanceVariableNames: 'directionA directionB pullUpA pullUpB portOutputA portOutputB portInputA portInputB'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-MCP23017'!
!classDefinition: 'FirmataMCP23017 class' category: #'Firmata-MCP23017'!
FirmataMCP23017 class
	instanceVariableNames: ''!

!classDefinition: #FirmataMCP23017Constants category: #'Firmata-MCP23017'!
Object subclass: #FirmataMCP23017Constants
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-MCP23017'!
!classDefinition: 'FirmataMCP23017Constants class' category: #'Firmata-MCP23017'!
FirmataMCP23017Constants class
	instanceVariableNames: ''!


!FirmataMCP23017 commentStamp: 'sf 17/Sep/2026' prior: 0!
I control a Microchip MCP23017 16-bit I/O expander through a FirmataI2C connection. The chip exposes two 8-bit ports, GPIOA (pins 0-7) and GPIOB (pins 8-15), each with its own direction, pull-up, interrupt and output-latch registers.

Typical use:
	bus := FirmataI2C new.
	bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
	expander := FirmataMCP23017 new.
	expander firmata: bus address: FirmataMCP23017Constants defaultAddress.
	expander initializeDevice.
	expander registerWithFirmata.
	expander setPinMode: 0 value: true.      "pin 0 as output"
	expander digitalWritePin: 0 value: false.
	expander setPinMode: 8 value: false.     "pin 8 as input"
	expander setPullUpPin: 8 value: true.
	expander readPort: 1.
	expander digitalReadPin: 8.              "level of pin 8"

The shadow direction and output bytes keep the register state in sync, so per-pin changes are written back as whole port bytes; reads go through the register-based I2C requests, which StandardFirmata serves without touching the port state. Pin 0-7 live in GPIOA, pin 8-15 in GPIOB. The chip answers addresses 0x20-0x27 depending on its A0-A2 pins.!

!FirmataMCP23017Constants commentStamp: 'sf 17/Sep/2026' prior: 0!
See class side. I collect the MCP23017 register map, specification and default constants from the Microchip datasheet.!

!FirmataMCP23017 methodsFor: 'initialize-release' stamp: 'sf 17/Sep/2026 00:00:00'!
initialize
	super initialize.
	directionA := 16rFF.
	directionB := 16rFF.
	pullUpA := 0.
	pullUpB := 0.
	portOutputA := 16rFF.
	portOutputB := 16rFF! !

!FirmataMCP23017 methodsFor: 'device initialization' stamp: 'sf 17/Sep/2026 00:00:00'!
initializeDevice
	"Start with all sixteen pins as inputs and all pull-ups disabled."
	self writeRegister: FirmataMCP23017Constants iodirARegister
		data: (ByteArray with: directionA).
	self writeRegister: FirmataMCP23017Constants iodirBRegister
		data: (ByteArray with: directionB).
	self writeRegister: FirmataMCP23017Constants gppuARegister
		data: (ByteArray with: 0).
	self writeRegister: FirmataMCP23017Constants gppuBRegister
		data: (ByteArray with: 0).
	^ self! !

!FirmataMCP23017 methodsFor: 'pin operations' stamp: 'sf 17/Sep/2026 00:00:00'!
digitalReadPin: anIndex
	"Answer a boolean reflecting the level of input pin anIndex (0-15).
	Requires a preceding #readPort: or #startReadingPort:."
	self checkPinIndex: anIndex.
	^ ((self inputByteForPort: (self portForPin: anIndex))
		bitAt: (anIndex bitAnd: 7) + 1) ~= 0! !

!FirmataMCP23017 methodsFor: 'pin operations' stamp: 'sf 17/Sep/2026 00:00:00'!
digitalWritePin: anIndex value: aBoolean
	"Drive output pin anIndex (0-15) high (true) or low (false)."
	| port |
	self checkPinIndex: anIndex.
	port := self portForPin: anIndex.
	self outputByteForPort: port put:
		(self updateByte: (self outputByteForPort: port)
			bit: (self bitForPin: anIndex)
			put: aBoolean).
	self writeRegister: (self outputRegisterForPort: port)
		data: (ByteArray with: (self outputByteForPort: port))! !

!FirmataMCP23017 methodsFor: 'pin operations' stamp: 'sf 17/Sep/2026 00:00:00'!
setPinMode: anIndex value: aBoolean
	"Configure pin anIndex (0-15) as output (true) or input (false),
	matching Arduino pinMode(). An IODIR bit of 0 means output."
	| port bit |
	self checkPinIndex: anIndex.
	port := self portForPin: anIndex.
	bit := self bitForPin: anIndex.
	self directionByteForPort: port put:
		(self updateByte: (self directionByteForPort: port)
			bit: bit
			put: aBoolean not).
	self writeRegister: (self directionRegisterForPort: port)
		data: (ByteArray with: (self directionByteForPort: port)).
	^ self! !

!FirmataMCP23017 methodsFor: 'pin operations' stamp: 'sf 17/Sep/2026 00:00:00'!
setPullUpPin: anIndex value: aBoolean
	"Enable (true) or disable (false) the internal pull-up of pin anIndex."
	| port |
	self checkPinIndex: anIndex.
	port := self portForPin: anIndex.
	self pullUpByteForPort: port put:
		(self updateByte: (self pullUpByteForPort: port)
			bit: (self bitForPin: anIndex)
			put: aBoolean).
	self writeRegister: (self pullUpRegisterForPort: port)
		data: (ByteArray with: (self pullUpByteForPort: port)).
	^ self! !

!FirmataMCP23017 methodsFor: 'I/O port operations' stamp: 'sf 17/Sep/2026 00:00:00'!
readPort: aPortIndex
	"Read the current pin levels of port 0 (GPIOA) or 1 (GPIOB)."
	self checkPortIndex: aPortIndex.
	self readRegister: (self outputRegisterForPort: aPortIndex)
		byteCount: 1.
	^ self! !

!FirmataMCP23017 methodsFor: 'I/O port operations' stamp: 'sf 17/Sep/2026 00:00:00'!
startReadingPort: aPortIndex
	"Keep streaming the pin levels of port 0 (GPIOA) or 1 (GPIOB)."
	self checkPortIndex: aPortIndex.
	self readRegisterContinuously: (self outputRegisterForPort: aPortIndex)
		byteCount: 1.
	^ self! !

!FirmataMCP23017 methodsFor: 'I/O port operations' stamp: 'sf 17/Sep/2026 00:00:00'!
writePort: aPortIndex value: aByte
	"Set all eight pins of port 0 (GPIOA) or 1 (GPIOB) at once."
	self checkPortIndex: aPortIndex.
	aPortIndex = 0
		ifTrue: [ portOutputA := aByte ]
		ifFalse: [ portOutputB := aByte ].
	self writeRegister: (self outputRegisterForPort: aPortIndex)
		data: (ByteArray with: aByte)! !

!FirmataMCP23017 methodsFor: 'reply handling' stamp: 'sf 17/Sep/2026 00:00:00'!
handleI2CReply: aRegister data: aByteArray
	"Store the port value of a GPIOA or GPIOB read reply."
	aByteArray size >= 1
		ifFalse: [ ^ self ].
	aRegister = FirmataMCP23017Constants gpioARegister
		ifTrue: [ portInputA := aByteArray first ].
	aRegister = FirmataMCP23017Constants gpioBRegister
		ifTrue: [ portInputB := aByteArray first ]! !

!FirmataMCP23017 methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
directionA
	^ directionA! !

!FirmataMCP23017 methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
directionB
	^ directionB! !

!FirmataMCP23017 methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
inputValueForPort: aPortIndex
	"Last port value read from port 0 (GPIOA) or 1 (GPIOB)."
	^ aPortIndex = 0 ifTrue: [ portInputA ] ifFalse: [ portInputB ]! !

!FirmataMCP23017 methodsFor: 'accessing' stamp: 'sf 17/Sep/2026 00:00:00'!
outputValueForPort: aPortIndex
	"Shadow output-latch byte of port 0 (GPIOA) or 1 (GPIOB)."
	^ aPortIndex = 0 ifTrue: [ portOutputA ] ifFalse: [ portOutputB ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
bitForPin: anIndex
	"Bit mask of a pin within its port."
	^ 1 bitShift: (anIndex bitAnd: 7)! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
checkPinIndex: anIndex
	"Guard against a pin index outside the 0-15 range."
	(anIndex between: 0 and: 15)
		ifFalse: [ self error: 'MCP23017 pin index out of range' ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
checkPortIndex: aPortIndex
	"Guard against a port index outside the 0-1 range."
	(aPortIndex between: 0 and: 1)
		ifFalse: [ self error: 'MCP23017 port index out of range' ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
directionByteForPort: aPortIndex
	"Shadow IODIR byte of port 0 (GPIOA) or 1 (GPIOB)."
	^ aPortIndex = 0 ifTrue: [ directionA ] ifFalse: [ directionB ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
directionByteForPort: aPortIndex put: aByte
	aPortIndex = 0
		ifTrue: [ directionA := aByte ]
		ifFalse: [ directionB := aByte ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
directionRegisterForPort: aPortIndex
	"IODIR register address of port 0 (GPIOA) or 1 (GPIOB)."
	^ aPortIndex = 0
		ifTrue: [ FirmataMCP23017Constants iodirARegister ]
		ifFalse: [ FirmataMCP23017Constants iodirBRegister ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
inputByteForPort: aPortIndex
	"Last input value read from port 0 (GPIOA) or 1 (GPIOB)."
	^ aPortIndex = 0 ifTrue: [ portInputA ] ifFalse: [ portInputB ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
outputByteForPort: aPortIndex
	"Shadow output-latch byte of port 0 (GPIOA) or 1 (GPIOB)."
	^ aPortIndex = 0 ifTrue: [ portOutputA ] ifFalse: [ portOutputB ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
outputByteForPort: aPortIndex put: aByte
	aPortIndex = 0
		ifTrue: [ portOutputA := aByte ]
		ifFalse: [ portOutputB := aByte ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
outputRegisterForPort: aPortIndex
	"GPIO register address of port 0 (GPIOA) or 1 (GPIOB)."
	^ aPortIndex = 0
		ifTrue: [ FirmataMCP23017Constants gpioARegister ]
		ifFalse: [ FirmataMCP23017Constants gpioBRegister ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
portForPin: anIndex
	"Port index 0 (GPIOA) for pins 0-7, 1 (GPIOB) for pins 8-15."
	^ anIndex < 8 ifTrue: [ 0 ] ifFalse: [ 1 ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
pullUpByteForPort: aPortIndex
	"Shadow GPPU byte of port 0 (GPIOA) or 1 (GPIOB)."
	^ aPortIndex = 0 ifTrue: [ pullUpA ] ifFalse: [ pullUpB ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
pullUpByteForPort: aPortIndex put: aByte
	"Remember the pull-up settings so per-pin writes rebuild the port byte."
	aPortIndex = 0
		ifTrue: [ pullUpA := aByte ]
		ifFalse: [ pullUpB := aByte ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
pullUpRegisterForPort: aPortIndex
	"GPPU register address of port 0 (GPIOA) or 1 (GPIOB)."
	^ aPortIndex = 0
		ifTrue: [ FirmataMCP23017Constants gppuARegister ]
		ifFalse: [ FirmataMCP23017Constants gppuBRegister ]! !

!FirmataMCP23017 methodsFor: 'private' stamp: 'sf 17/Sep/2026 00:00:00'!
updateByte: aByte bit: aBit put: aBoolean
	"Set (true) or clear (false) bit aBit in aByte, answering the result."
	aBoolean
		ifTrue: [ ^ aByte bitOr: aBit ]
		ifFalse: [ ^ aByte bitAnd: aBit bitInvert ]! !

!FirmataMCP23017 class methodsFor: 'defaults' stamp: 'sf 17/Sep/2026 00:00:00'!
addressWithAddressPins: anInteger
	"Answer the slave address for the low A0-A2 bits on the address pins."
	^ FirmataMCP23017Constants baseAddress + (anInteger bitAnd: 7)! !

!FirmataMCP23017 class methodsFor: 'defaults' stamp: 'sf 17/Sep/2026 00:00:00'!
defaultAddress
	"I2C slave address 0x20 with all address pins low."
	^ FirmataMCP23017Constants defaultAddress! !

!FirmataMCP23017Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
gpioARegister
	"0x12 GPIOA output latch and pin levels"
	^ 16r12! !

!FirmataMCP23017Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
gpioBRegister
	"0x13 GPIOB output latch and pin levels"
	^ 16r13! !

!FirmataMCP23017Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
gppuARegister
	"0x0C GPIOA pull-up configuration"
	^ 16r0C! !

!FirmataMCP23017Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
gppuBRegister
	"0x0D GPIOB pull-up configuration"
	^ 16r0D! !

!FirmataMCP23017Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
ioconRegister
	"0x0A configuration of bank addressing, polarity and interrupt polarity"
	^ 16r0A! !

!FirmataMCP23017Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
iodirARegister
	"0x00 GPIOA data direction: a bit of 1 selects input"
	^ 16r00! !

!FirmataMCP23017Constants class methodsFor: 'registers' stamp: 'sf 17/Sep/2026 00:00:00'!
iodirBRegister
	"0x01 GPIOB data direction: a bit of 1 selects input"
	^ 16r01! !

!FirmataMCP23017Constants class methodsFor: 'specification' stamp: 'sf 17/Sep/2026 00:00:00'!
addressCount
	"Number of slave addresses selectable via A0-A2"
	^ 8! !

!FirmataMCP23017Constants class methodsFor: 'specification' stamp: 'sf 17/Sep/2026 00:00:00'!
pinCount
	"Number of I/O pins"
	^ 16! !

!FirmataMCP23017Constants class methodsFor: 'specification' stamp: 'sf 17/Sep/2026 00:00:00'!
portCount
	"Number of 8-bit I/O ports"
	^ 2! !

!FirmataMCP23017Constants class methodsFor: 'specification' stamp: 'sf 17/Sep/2026 00:00:00'!
portPinCount
	"Number of pins per port"
	^ 8! !

!FirmataMCP23017Constants class methodsFor: 'defaults' stamp: 'sf 17/Sep/2026 00:00:00'!
baseAddress
	"Slave address of the MCP23017 with A0-A2 low"
	^ 16r20! !

!FirmataMCP23017Constants class methodsFor: 'defaults' stamp: 'sf 17/Sep/2026 00:00:00'!
defaultAddress
	"I2C slave address 0x20 with all address pins low"
	^ 16r20! !
