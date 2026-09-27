'From Cuis7.8 [latest update: #7977] on 27 September 2026 at 2:52:05 pm'!
'Description '!
!provides: 'Firmata-PCA9685' 1 1!
!requires: 'Firmata-I2C' 1 1 nil!
SystemOrganization addCategory: #'Firmata-PCA9685'!


!classDefinition: #FirmataPCA9685 category: #'Firmata-PCA9685'!
FirmataI2CDevice subclass: #FirmataPCA9685
	instanceVariableNames: 'frequency'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-PCA9685'!
!classDefinition: 'FirmataPCA9685 class' category: #'Firmata-PCA9685'!
FirmataPCA9685 class
	instanceVariableNames: ''!

!classDefinition: #FirmataPCA9685Constants category: #'Firmata-PCA9685'!
Object subclass: #FirmataPCA9685Constants
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-PCA9685'!
!classDefinition: 'FirmataPCA9685Constants class' category: #'Firmata-PCA9685'!
FirmataPCA9685Constants class
	instanceVariableNames: ''!


!FirmataPCA9685 commentStamp: 'sf 12/Sep/2026' prior: 0!
I control a PCA9685 16-channel PWM and servo driver through a FirmataI2C connection. Each of the 16 channels drives a 12-bit pulse count; values at or above 4096 force the output fully on.

Typical use:
	bus := FirmataI2C new.
	bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
	driver := FirmataPCA9685 new.
	driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
	driver initializeDevice.
	driver setFrequency: 50.
	driver setServoOnChannel: 0 angle: 90.

The servo helper maps angles to pulse counts using a configurable min and max pulse; the default range 544 to 2400 microseconds matches the Firmata servo convention.!

!FirmataPCA9685Constants commentStamp: 'sf 12/Sep/2026' prior: 0!
See class side. I collect the PCA9685 register map, mode bits and specification constants from the NXP PCA9685 datasheet.!

!FirmataPCA9685 methodsFor: 'initialize-release' stamp: 'sf 12/Sep/2026 00:00:00'!
initialize
	super initialize.
	frequency := self class defaultFrequency! !

!FirmataPCA9685 methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
frequency
	^ frequency! !

!FirmataPCA9685 methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
frequency: aNumber
	frequency := aNumber! !

!FirmataPCA9685 methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
numberOfChannels
	^ FirmataPCA9685Constants numberOfChannels! !

!FirmataPCA9685 methodsFor: 'device initialization' stamp: 'sf 24/Sep/2026 00:00:00'!
initializeDevice
	"Bring the controller to a known state: default modes, the PWM
	frequency matching #frequency and all outputs off. Programming the
	oscillator is essential because the chip powers up at prescale 30
	(~196.9 Hz) while the servo counts are computed for #frequency."
	self writeMode1: FirmataPCA9685Constants mode1Default.
	self writeMode2: FirmataPCA9685Constants mode2Default.
	self setFrequency: self frequency.
	self setAllPWM: 0! !

!FirmataPCA9685 methodsFor: 'pwm generation' stamp: 'sf 12/Sep/2026 00:00:00'!
prescaleForFrequency: aFrequency
	"Prescale value so the 25 MHz oscillator yields aFrequency in Hz."
	^ ((FirmataPCA9685Constants oscillatorFrequency
		/ (FirmataPCA9685Constants resolutionSteps * aFrequency)) - 1.0) rounded! !

!FirmataPCA9685 methodsFor: 'pwm generation' stamp: 'sf 12/Sep/2026 00:00:00'!
setAllPWM: aValue
	"Drive all channels with the same 12-bit count, see #setPWMOnChannel:value:."
	aValue < 0
		ifTrue: [ ^ self setAllChannelsPhaseOn: 0 off: 0 ].
	aValue >= FirmataPCA9685Constants resolutionSteps
		ifTrue: [ ^ self setAllChannelsPhaseOn: 4096 off: 0 ].
	self setAllChannelsPhaseOn: 0 off: aValue! !

!FirmataPCA9685 methodsFor: 'pwm generation' stamp: 'sf 12/Sep/2026 00:00:00'!
setFrequency: aFrequency
	"Set the PWM update frequency in Hz for the 25 MHz oscillator.
	The prescale can only be changed while the oscillator sleeps, so the
	sequence is sleep, write prescale, wake, restart."
	| prescale mode1 |
	prescale := self prescaleForFrequency: aFrequency.
	mode1 := FirmataPCA9685Constants mode1Default.
	self writeMode1: (mode1 bitOr: FirmataPCA9685Constants sleepBit).
	self writeRegister: FirmataPCA9685Constants preScaleRegister
		data: (ByteArray with: prescale).
	self writeMode1: (mode1 bitAnd: FirmataPCA9685Constants sleepBit bitInvert).
	self writeMode1: (mode1 bitOr: FirmataPCA9685Constants restartBit).
	frequency := aFrequency! !

!FirmataPCA9685 methodsFor: 'pwm generation' stamp: 'sf 12/Sep/2026 00:00:00'!
setPWMOnChannel: aChannel value: aValue
	"Drive one of the 16 channels with a 12-bit count. Negative values
	turn the channel off, values at or above 4096 force it fully on."
	self checkChannel: aChannel.
	aValue < 0
		ifTrue: [ ^ self setChannel: aChannel on: 0 off: 0 ].
	aValue >= FirmataPCA9685Constants resolutionSteps
		ifTrue: [ ^ self setChannel: aChannel on: 4096 off: 0 ].
	self setChannel: aChannel on: 0 off: aValue! !

!FirmataPCA9685 methodsFor: 'pwm generation - private' stamp: 'sf 12/Sep/2026 00:00:00'!
checkChannel: aChannel
	"Guard against addressing a non-existing channel."
	(aChannel between: 0 and: (FirmataPCA9685Constants numberOfChannels - 1))
		ifFalse: [ self error: 'PCA9685 channel out of range' ]! !

!FirmataPCA9685 methodsFor: 'pwm generation - private' stamp: 'sf 12/Sep/2026 00:00:00'!
offLowRegisterOfChannel: aChannel
	^ (self onLowRegisterOfChannel: aChannel) + 2! !

!FirmataPCA9685 methodsFor: 'pwm generation - private' stamp: 'sf 12/Sep/2026 00:00:00'!
onLowRegisterOfChannel: aChannel
	^ FirmataPCA9685Constants led0OnLowRegister + (aChannel * 4)! !

!FirmataPCA9685 methodsFor: 'pwm generation - private' stamp: 'sf 12/Sep/2026 00:00:00'!
setAllChannelsPhaseOn: onCount off: offCount
	"Write all-channels ON and OFF phases via the broadcast registers."
	self writeRegister: FirmataPCA9685Constants allLedOnLowRegister
		data: (ByteArray
			with: (onCount bitAnd: 255)
			with: ((onCount bitShift: -8) bitAnd: 16r1F)).
	self writeRegister: FirmataPCA9685Constants allLedOffLowRegister
		data: (ByteArray
			with: (offCount bitAnd: 255)
			with: ((offCount bitShift: -8) bitAnd: 16r1F))! !

!FirmataPCA9685 methodsFor: 'pwm generation - private' stamp: 'sf 12/Sep/2026 00:00:00'!
setChannel: aChannel on: onCount off: offCount
	"Write the ON and OFF phase counts of a channel. Each phase is a
	12-bit value; the register high byte also carries the full-phase flag."
	self writeRegister: (self onLowRegisterOfChannel: aChannel)
		data: (ByteArray
			with: (onCount bitAnd: 255)
			with: ((onCount bitShift: -8) bitAnd: 16r1F)).
	self writeRegister: (self offLowRegisterOfChannel: aChannel)
		data: (ByteArray
			with: (offCount bitAnd: 255)
			with: ((offCount bitShift: -8) bitAnd: 16r1F))! !

!FirmataPCA9685 methodsFor: 'mode registers' stamp: 'sf 12/Sep/2026 00:00:00'!
writeMode1: aByte
	self writeRegister: FirmataPCA9685Constants mode1Register
		data: (ByteArray with: aByte)! !

!FirmataPCA9685 methodsFor: 'mode registers' stamp: 'sf 12/Sep/2026 00:00:00'!
writeMode2: aByte
	self writeRegister: FirmataPCA9685Constants mode2Register
		data: (ByteArray with: aByte)! !

!FirmataPCA9685 methodsFor: 'servo support' stamp: 'sf 12/Sep/2026 00:00:00'!
pwmCountsForMicroseconds: microseconds
	"Convert a pulse width to the 12-bit count at my current frequency."
	^ (microseconds * FirmataPCA9685Constants resolutionSteps * self frequency / 1000000) rounded! !

!FirmataPCA9685 methodsFor: 'servo support' stamp: 'sf 12/Sep/2026 00:00:00'!
pwmCountsForServoAngle: degrees minPulse: minPulseMicroseconds maxPulse: maxPulseMicroseconds
	"Map an angle to the 12-bit count for the current frequency."
	| clamped microseconds |
	clamped := degrees.
	clamped < 0 ifTrue: [ clamped := 0 ].
	clamped > 180 ifTrue: [ clamped := 180 ].
	microseconds := minPulseMicroseconds
		+ ((maxPulseMicroseconds - minPulseMicroseconds) * clamped / 180).
	^ self pwmCountsForMicroseconds: microseconds! !

!FirmataPCA9685 methodsFor: 'servo support' stamp: 'sf 12/Sep/2026 00:00:00'!
setServoOnChannel: aChannel angle: degrees
	"Move a servo on a channel using the default 544 to 2400 microseconds pulse range."
	self setServoOnChannel: aChannel
		angle: degrees
		minPulse: self class defaultMinPulseMicroseconds
		maxPulse: self class defaultMaxPulseMicroseconds! !

!FirmataPCA9685 methodsFor: 'servo support' stamp: 'sf 12/Sep/2026 00:00:00'!
setServoOnChannel: aChannel angle: degrees minPulse: minPulseMicroseconds maxPulse: maxPulseMicroseconds
	"Move a servo on a channel; the angle is clamped to the 0 to 180 degree range."
	self setPWMOnChannel: aChannel value: (self
		pwmCountsForServoAngle: degrees
		minPulse: minPulseMicroseconds
		maxPulse: maxPulseMicroseconds)! !

!FirmataPCA9685 methodsFor: 'subclass responsibility' stamp: 'sf 12/Sep/2026 00:00:00'!
handleI2CReply: aRegister data: aByteArray
	"The PCA9685 is write-only in this implementation; nothing to do."
	^ self! !

!FirmataPCA9685 class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultAddress
	"The PCA9685 answers at 0x40 when all address pins are low."
	^ FirmataPCA9685Constants defaultAddress! !

!FirmataPCA9685 class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultFrequency
	"Fallback frequency used for servo timing before #setFrequency:."
	^ FirmataPCA9685Constants defaultFrequency! !

!FirmataPCA9685 class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultMaxPulseMicroseconds
	"Standard servo pulse for a 180 degree position."
	^ FirmataPCA9685Constants defaultMaxPulseMicroseconds! !

!FirmataPCA9685 class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultMinPulseMicroseconds
	"Standard servo pulse for a 0 degree position."
	^ FirmataPCA9685Constants defaultMinPulseMicroseconds! !

!FirmataPCA9685Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
allLedOffLowRegister
	"0xFC low byte of the all-channels OFF phase"
	^ 16rFC! !

!FirmataPCA9685Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
allLedOnLowRegister
	"0xFA low byte of the all-channels ON phase"
	^ 16rFA! !

!FirmataPCA9685Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
led0OnLowRegister
	"0x06 low byte of the ON phase of channel 0; channels step by 4"
	^ 16r06! !

!FirmataPCA9685Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
mode1Register
	"0x00 mode register 1"
	^ 16r00! !

!FirmataPCA9685Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
mode2Register
	"0x01 mode register 2"
	^ 16r01! !

!FirmataPCA9685Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
preScaleRegister
	"0xFE prescale value for the PWM update frequency"
	^ 16rFE! !

!FirmataPCA9685Constants class methodsFor: 'modes' stamp: 'sf 24/Sep/2026 00:00:00'!
mode1Default
	"Default mode 1 value: auto-increment enabled. Register writes that
	send more than one data byte depend on AI, otherwise the chip would
	stuff every byte into the low register and the high phase bytes would
	be lost (see NXP PCA9685 datasheet, MODE1 bit 5)."
	^ 16r20! !

!FirmataPCA9685Constants class methodsFor: 'modes' stamp: 'sf 12/Sep/2026 00:00:00'!
mode2Default
	"Default mode 2 value: totem-pole output drives the outputs"
	^ 16r04! !

!FirmataPCA9685Constants class methodsFor: 'modes' stamp: 'sf 12/Sep/2026 00:00:00'!
restartBit
	"Mode 1 bit to restart the internal oscillator"
	^ 16r80! !

!FirmataPCA9685Constants class methodsFor: 'modes' stamp: 'sf 12/Sep/2026 00:00:00'!
sleepBit
	"Mode 1 bit to put the oscillator to sleep so the prescale can change"
	^ 16r10! !

!FirmataPCA9685Constants class methodsFor: 'specification' stamp: 'sf 12/Sep/2026 00:00:00'!
channelRegisterStep
	"Register distance between two neighboring channels"
	^ 4! !

!FirmataPCA9685Constants class methodsFor: 'specification' stamp: 'sf 12/Sep/2026 00:00:00'!
numberOfChannels
	"Sixteen PWM channels per controller"
	^ 16! !

!FirmataPCA9685Constants class methodsFor: 'specification' stamp: 'sf 12/Sep/2026 00:00:00'!
oscillatorFrequency
	"Internal oscillator of the PCA9685 in Hz"
	^ 25000000! !

!FirmataPCA9685Constants class methodsFor: 'specification' stamp: 'sf 12/Sep/2026 00:00:00'!
resolutionSteps
	"Twelve-bit PWM resolution gives 4096 steps"
	^ 4096! !

!FirmataPCA9685Constants class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultAddress
	"I2C slave address 0x40 with all address pins grounded"
	^ 16r40! !

!FirmataPCA9685Constants class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultFrequency
	"Fallback PWM frequency of 50 Hz used by the servo helper"
	^ 50! !

!FirmataPCA9685Constants class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultMaxPulseMicroseconds
	"Standard servo pulse for a 180 degree position"
	^ 2400! !

!FirmataPCA9685Constants class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultMinPulseMicroseconds
	"Standard servo pulse for a 0 degree position"
	^ 544! !
