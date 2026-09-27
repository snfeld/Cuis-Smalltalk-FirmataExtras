'From Cuis7.8 [latest update: #7977] on 27 September 2026 at 2:52:14 pm'!
'Description '!
!provides: 'Tests-Firmata-PCA9685' 1 1!
!requires: 'Firmata-PCA9685' 1 1 nil!
SystemOrganization addCategory: #'Tests-Firmata-PCA9685'!


!classDefinition: #FirmataPCA9685PortMock category: #'Tests-Firmata-PCA9685'!
Object subclass: #FirmataPCA9685PortMock
	instanceVariableNames: 'written buffer'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-PCA9685'!
!classDefinition: 'FirmataPCA9685PortMock class' category: #'Tests-Firmata-PCA9685'!
FirmataPCA9685PortMock class
	instanceVariableNames: ''!

!classDefinition: #FirmataPCA9685Test category: #'Tests-Firmata-PCA9685'!
TestCase subclass: #FirmataPCA9685Test
	instanceVariableNames: 'device port'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-PCA9685'!
!classDefinition: 'FirmataPCA9685Test class' category: #'Tests-Firmata-PCA9685'!
FirmataPCA9685Test class
	instanceVariableNames: ''!


!FirmataPCA9685PortMock commentStamp: 'sf 12/Sep/2026' prior: 0!
I play the role of a serial port for Firmata-PCA9685 tests. Writes are recorded in #written.!

!FirmataPCA9685Test commentStamp: 'sf 12/Sep/2026' prior: 0!
I test Firmata-PCA9685 without hardware. Every I2C write produced by the driver is asserted byte-exactly against the expected sysex stream, including registers, phase counts and the frequency change sequence.!

!FirmataPCA9685PortMock methodsFor: 'initialize-release' stamp: 'sf 12/Sep/2026 00:00:00'!
initialize
	written := ByteArray new.
	buffer := ByteArray new! !

!FirmataPCA9685PortMock methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
data: aByteArray
	"Bytes the next #readByteArray answers"
	buffer := aByteArray! !

!FirmataPCA9685PortMock methodsFor: 'accessing' stamp: 'sf 12/Sep/2026 00:00:00'!
written
	^ written! !

!FirmataPCA9685PortMock methodsFor: 'serial protocol' stamp: 'sf 12/Sep/2026 00:00:00'!
nextPutAll: aByteArray
	written := written , aByteArray! !

!FirmataPCA9685PortMock methodsFor: 'serial protocol' stamp: 'sf 12/Sep/2026 00:00:00'!
readByteArray
	buffer size > 0
		ifTrue: [ | result |
			result := buffer.
			buffer := ByteArray new.
			^ result ].
	^ ByteArray new! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
setUp
	| bus |
	port := FirmataPCA9685PortMock new.
	bus := FirmataI2C new.
	bus instVarNamed: 'port' put: port.
	device := FirmataPCA9685 new.
	device firmata: bus address: FirmataPCA9685Constants defaultAddress! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
tearDown
	device firmata disconnect.
	(Delay forMilliseconds: 50) wait! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testDefaultAddressIs0x40
	self assert: device address equals: 16r40! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testDefaultFrequencyIs50Hz
	self assert: device frequency equals: 50! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 24/Sep/2026 00:00:00'!
testInitializeDeviceWritesModesAndClearsOutputs
	"initializeDevice writes mode1 (with auto-increment), mode2, programs
	the default 50 Hz oscillator (sleep, prescale 121, wake, restart) and
	clears all outputs."
	device initializeDevice.
	self assert: port written equals: #[
		16rF0 16r76 16r40 0 16r00 0 16r20 0 16rF7
		16rF0 16r76 16r40 0 16r01 0 4 0 16rF7
		16rF0 16r76 16r40 0 16r00 0 16r30 0 16rF7
		16rF0 16r76 16r40 0 16r7E 1 121 0 16rF7
		16rF0 16r76 16r40 0 16r00 0 16r20 0 16rF7
		16rF0 16r76 16r40 0 16r00 0 16r20 1 16rF7
		16rF0 16r76 16r40 0 16r7A 1 0 0 0 0 16rF7
		16rF0 16r76 16r40 0 16r7C 1 0 0 0 0 16rF7 ]! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 24/Sep/2026 00:00:00'!
testMode1DefaultEnablesAutoIncrement
	"The chip needs the auto-increment bit so that a writeRegister: that
	sends the low and high phase bytes in one burst reaches both
	consecutive registers (NXP PCA9685 datasheet, MODE1 bit 5)."
	self assert: (FirmataPCA9685Constants mode1Default bitAnd: 16r20) equals: 16r20! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testNumberOfChannelsIs16
	self assert: device numberOfChannels equals: 16! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testPwmCountsForMicroseconds50Hz
	"1.5 ms at 50 Hz: 1.5e-3 * 4096 * 50 = 307.2 counts, rounded to 307."
	self assert: (device pwmCountsForMicroseconds: 1500) equals: 307! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testPwmCountsForMicrosecondsScalesWithFrequency
	"At 60 Hz the same pulse covers 1.5e-3 * 4096 * 60 = 368.64 counts."
	device setFrequency: 60.
	self assert: (device pwmCountsForMicroseconds: 1500) equals: 369! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testServoAngle180UsesMaxPulse
	"180 degrees: 2400 microseconds, 2400 * 4096 * 50 / 1e6 = 491.52, so 492 counts."
	self assert: (device pwmCountsForServoAngle: 180 minPulse: 544 maxPulse: 2400) equals: 492! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testServoAngle90UsesMidPulse
	"90 degrees: 1472 microseconds, 1472 * 4096 * 50 / 1e6 = 301.47, so 301 counts."
	self assert: (device pwmCountsForServoAngle: 90 minPulse: 544 maxPulse: 2400) equals: 301! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testServoAngleClampsAbove180
	self assert: (device pwmCountsForServoAngle: 200 minPulse: 544 maxPulse: 2400) equals: 492! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testServoAngleClampsBelowZero
	self assert: (device pwmCountsForServoAngle: -10 minPulse: 544 maxPulse: 2400) equals: 111! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testServoAngleZeroUsesMinPulse
	"0 degrees: 544 microseconds, 544 * 4096 * 50 / 1e6 = 111.41, so 111 counts."
	device setServoOnChannel: 0 angle: 0.
	self assert: (device pwmCountsForServoAngle: 0 minPulse: 544 maxPulse: 2400) equals: 111! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetAllPWMUsesBroadcastRegisters
	device setAllPWM: 0.
	self assert: port written equals: #[
		16rF0 16r76 16r40 0 16r7A 1 0 0 0 0 16rF7
		16rF0 16r76 16r40 0 16r7C 1 0 0 0 0 16rF7 ]! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 24/Sep/2026 00:00:00'!
testSetFrequency50WritesPrescale121
	"The 25 MHz oscillator at 4096 steps and 50 Hz needs a prescale of 121.
	Auto-increment stays enabled across sleep, wake and restart."
	device setFrequency: 50.
	self assert: (device prescaleForFrequency: 50) equals: 121.
	self assert: port written equals: #[
		16rF0 16r76 16r40 0 16r00 0 16r30 0 16rF7
		16rF0 16r76 16r40 0 16r7E 1 121 0 16rF7
		16rF0 16r76 16r40 0 16r00 0 16r20 0 16rF7
		16rF0 16r76 16r40 0 16r00 0 16r20 1 16rF7 ]! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetFrequency60WritesPrescale101
	device setFrequency: 60.
	self assert: (device prescaleForFrequency: 60) equals: 101.
	self assert: (port written occurrencesOf: 101) equals: 1! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetFrequencyUpdatesFrequencyState
	device setFrequency: 60.
	self assert: device frequency equals: 60! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetPWMChannelOutOfRangeFails
	self should: [ device setPWMOnChannel: 16 value: 0 ] raise: Error! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetPWMFullOnWrites4096ToOnPhase
	device setPWMOnChannel: 0 value: 4096.
	self assert: port written equals: #[
		16rF0 16r76 16r40 0 16r06 0 0 0 16 0 16rF7
		16rF0 16r76 16r40 0 16r08 0 0 0 0 0 16rF7 ]! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetPWMHighValueCodesAbove255
	"2047 as an OFF phase: low byte 255, high byte 7."
	device setPWMOnChannel: 0 value: 2047.
	self assert: port written equals: #[
		16rF0 16r76 16r40 0 16r06 0 0 0 0 0 16rF7
		16rF0 16r76 16r40 0 16r08 0 127 1 7 0 16rF7 ]! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetPWMNegativeValueTurnsChannelOff
	device setPWMOnChannel: 0 value: -1.
	self assert: port written equals: #[
		16rF0 16r76 16r40 0 16r06 0 0 0 0 0 16rF7
		16rF0 16r76 16r40 0 16r08 0 0 0 0 0 16rF7 ]! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetPWMOffUsesChannelRegisters
	device setPWMOnChannel: 3 value: 0.
	self assert: port written equals: #[
		16rF0 16r76 16r40 0 16r12 0 0 0 0 0 16rF7
		16rF0 16r76 16r40 0 16r14 0 0 0 0 0 16rF7 ]! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 24/Sep/2026 00:00:00'!
testSetPWMOffWritesZeroCounts
	device setPWMOnChannel: 0 value: 0.
	self assert: port written equals: #[
		16rF0 16r76 16r40 0 16r06 0 0 0 0 0 16rF7
		16rF0 16r76 16r40 0 16r08 0 0 0 0 0 16rF7 ]! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetServoWithCustomPulseRange
	device setServoOnChannel: 0 angle: 0 minPulse: 500 maxPulse: 2500.
	self assert: port written equals: #[
		16rF0 16r76 16r40 0 16r06 0 0 0 0 0 16rF7
		16rF0 16r76 16r40 0 16r08 0 102 0 0 0 16rF7 ]! !

!FirmataPCA9685Test methodsFor: 'testing' stamp: 'sf 12/Sep/2026 00:00:00'!
testSetServoWritesPwmCountsForAngle
	"90 degrees matches testServoAngle90UsesMidPulse: ON stays 0, OFF 301."
	device setServoOnChannel: 3 angle: 90.
	self assert: port written equals: #[
		16rF0 16r76 16r40 0 16r12 0 0 0 0 0 16rF7
		16rF0 16r76 16r40 0 16r14 0 45 0 1 0 16rF7 ]! !
