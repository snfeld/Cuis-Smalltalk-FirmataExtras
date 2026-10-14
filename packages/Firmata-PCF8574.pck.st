'From Cuis7.8 [latest update: #7977] on 3 October 2026 at 5:47:40 pm'!
'Description '!
!provides: 'Firmata-PCF8574' 1 1!
!requires: 'Firmata-I2C' 1 1 nil!
SystemOrganization addCategory: #'Firmata-PCF8574'!


!classDefinition: #FirmataPCF8574 category: #'Firmata-PCF8574'!
FirmataI2CDevice subclass: #FirmataPCF8574
	instanceVariableNames: 'outputValue inputValue'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-PCF8574'!
!classDefinition: 'FirmataPCF8574 class' category: #'Firmata-PCF8574'!
FirmataPCF8574 class
	instanceVariableNames: ''!

!classDefinition: #FirmataPCF8574Constants category: #'Firmata-PCF8574'!
Object subclass: #FirmataPCF8574Constants
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-PCF8574'!
!classDefinition: 'FirmataPCF8574Constants class' category: #'Firmata-PCF8574'!
FirmataPCF8574Constants class
	instanceVariableNames: ''!


!FirmataPCF8574 commentStamp: 'sf 16/Sep/2026' prior: 0!
I control a NXP PCF8574 8-bit quasi-bidirectional I/O expander through a FirmataI2C connection. The chip has no register addressing — a single-byte write sets the port latch and a single-byte read returns the pin levels.

Write port value (set all eight pins):
	bus := FirmataI2C new.
	bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
	expander := FirmataPCF8574 new.
	expander firmata: bus address: FirmataPCF8574Constants defaultAddress.
	expander initializeDevice.
	expander registerWithFirmata.

	expander writePort: 16r0F.     "pins 0-3 low, pins 4-7 high (inputs)"
	expander writePort: 16rFF.     "all pins high (inputs)"

Pin-level operations:
	expander digitalWritePin: 0 value: true.   "set pin 0 high"
	expander digitalWritePin: 3 value: false.  "drive pin 3 low"

Reading:
	expander readPort.            "single read (register-less)"
	expander startReadingPort.    "continuous register-less read"
	expander inputValue.          "last port byte read"
	expander digitalReadPin: 0.   "true if pin 0 is high"

IMPORTANT: StandardFirmata (>=2.5) skips the register write when the I2C request carries exactly one data word and no register pair (argc=4). This register-less read avoids clearing the port latch before reading, which would otherwise drive all pins low and return 0x00.!

!FirmataPCF8574Constants commentStamp: 'sf 16/Sep/2026' prior: 0!
See class side. I collect the PCF8574 default constants.!

!FirmataPCF8574 methodsFor: 'initialize-release' stamp: 'sf 16/Sep/2026 00:00:00'!
initialize
	super initialize.
	outputValue := self class allPinsHigh! !

!FirmataPCF8574 methodsFor: 'device initialization' stamp: 'sf 16/Sep/2026 00:00:00'!
initializeDevice
	"Re-assert the retained output value so all pins start as inputs."
	self writePort: outputValue.
	^ self! !

!FirmataPCF8574 methodsFor: 'port operations' stamp: 'sf 16/Sep/2026 00:00:00'!
writePort: aByte
	"Set all eight port pins. The single data byte ensures the PCF8574
	latches the correct value (the port updates on every byte received,
	the final byte wins)."
	outputValue := aByte.
	self writeRegister: FirmataPCF8574Constants portRegister
		data: (ByteArray with: aByte)! !

!FirmataPCF8574 methodsFor: 'pin operations' stamp: 'sf 16/Sep/2026 00:00:00'!
digitalReadPin: anIndex
	"Answer a boolean reflecting the level of the given input pin (0-7).
	Requires a preceding #readPort or #startReadingPort."
	self checkPinIndex: anIndex.
	^ (inputValue bitAt: anIndex + 1) ~= 0! !

!FirmataPCF8574 methodsFor: 'pin operations' stamp: 'sf 16/Sep/2026 00:00:00'!
digitalWritePin: anIndex value: aBoolean
	"Set a single output pin (0-7) and re-apply the whole port."
	self checkPinIndex: anIndex.
	aBoolean
		ifTrue: [ outputValue := outputValue bitOr: (1 bitShift: anIndex) ]
		ifFalse: [ outputValue := outputValue bitAnd: (1 bitShift: anIndex) bitInvert ].
	self writePort: outputValue! !

!FirmataPCF8574 methodsFor: 'reading' stamp: 'sf 16/Sep/2026 00:00:00'!
readPort
	"Read the current port state without corrupting the pin latch.
	Sends a register-less I2C read (argc=4) so StandardFirmata skips
	the register write that would otherwise drive all pins low."
	self sendRegisterlessReadTo: 1 mode: FirmataI2CConstants modeRead! !

!FirmataPCF8574 methodsFor: 'reading' stamp: 'sf 16/Sep/2026 00:00:00'!
startReadingPort
	"Start continuous register-less reading of the port."
	self sendRegisterlessReadTo: 1 mode: FirmataI2CConstants modeReadContinuously! !

!FirmataPCF8574 methodsFor: 'reply handling' stamp: 'sf 16/Sep/2026 00:00:00'!
handleI2CReply: aRegister data: aByteArray
	"Store the port value from a read reply."
	aByteArray size >= 1
		ifTrue: [ inputValue := aByteArray first ]! !

!FirmataPCF8574 methodsFor: 'accessing' stamp: 'sf 16/Sep/2026 00:00:00'!
inputValue
	^ inputValue! !

!FirmataPCF8574 methodsFor: 'accessing' stamp: 'sf 16/Sep/2026 00:00:00'!
outputValue
	^ outputValue! !

!FirmataPCF8574 methodsFor: 'pin operations - private' stamp: 'sf 16/Sep/2026 00:00:00'!
checkPinIndex: anIndex
	"Guard against a pin index outside the 0-7 range."
	(anIndex between: 0 and: 7)
		ifFalse: [ self error: 'PCF8574 pin index out of range' ]! !

!FirmataPCF8574 methodsFor: 'private' stamp: 'sf 16/Sep/2026 00:00:00'!
sendRegisterlessReadTo: aCount mode: aMode
	"Build an I2C_REQUEST sysex without register bytes (argc=4 on the
	Arduino side). StandardFirmata skips the register write when argc
	differs from 6, which avoids corrupting the port state of register-less
	devices like the PCF8574."
	| message |
	message := ByteArray new: 7.
	message at: 1 put: FirmataConstants startSysex.
	message at: 2 put: FirmataI2CConstants i2cRequest.
	message at: 3 put: (address bitAnd: 127).
	message at: 4 put: (aMode bitAnd: 127).
	message at: 5 put: (aCount bitAnd: 127).
	message at: 6 put: ((aCount bitShift: -7) bitAnd: 127).
	message at: 7 put: FirmataConstants endSysex.
	firmata port nextPutAll: message! !

!FirmataPCF8574 class methodsFor: 'defaults' stamp: 'sf 16/Sep/2026 00:00:00'!
allPinsHigh
	"All eight pins set high = input mode"
	^ 16rFF! !

!FirmataPCF8574 class methodsFor: 'defaults' stamp: 'sf 16/Sep/2026 00:00:00'!
defaultAddress
	"I2C slave address 0x20 with all address pins low"
	^ 16r20! !

!FirmataPCF8574Constants class methodsFor: 'registers' stamp: 'sf 16/Sep/2026 00:00:00'!
portRegister
	"Dummy register 0 — the PCF8574 has no register addressing.
	For writes, the last byte on the bus is the port value.
	For reads, we use a register-less message instead."
	^ 0! !

!FirmataPCF8574Constants class methodsFor: 'specification' stamp: 'sf 16/Sep/2026 00:00:00'!
pinCount
	"Number of I/O pins"
	^ 8! !

!FirmataPCF8574Constants class methodsFor: 'defaults' stamp: 'sf 16/Sep/2026 00:00:00'!
defaultAddress
	"I2C slave address 0x20 with all address pins low"
	^ 16r20! !
