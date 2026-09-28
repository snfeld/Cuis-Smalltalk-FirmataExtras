'From Cuis7.8 [latest update: #7977] on 28 September 2026 at 8:19:07 am'!
'Description '!
!provides: 'Tests-Firmata-Servo' 1 1!
!requires: 'Firmata-Servo' 1 1 nil!
SystemOrganization addCategory: #'Tests-Firmata-Servo'!


!classDefinition: #FirmataServoPortMock category: #'Tests-Firmata-Servo'!
Object subclass: #FirmataServoPortMock
	instanceVariableNames: 'written buffer'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-Servo'!
!classDefinition: 'FirmataServoPortMock class' category: #'Tests-Firmata-Servo'!
FirmataServoPortMock class
	instanceVariableNames: ''!

!classDefinition: #FirmataServoTest category: #'Tests-Firmata-Servo'!
TestCase subclass: #FirmataServoTest
	instanceVariableNames: 'servo port'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-Firmata-Servo'!
!classDefinition: 'FirmataServoTest class' category: #'Tests-Firmata-Servo'!
FirmataServoTest class
	instanceVariableNames: ''!


!FirmataServoPortMock commentStamp: 'sf 24/Sep/2026' prior: 0!
I play the role of a serial port for Firmata-Servo tests. Writes are recorded in #written.!

!FirmataServoTest commentStamp: 'sf 24/Sep/2026' prior: 0!
I test Firmata-Servo without hardware. The servo is wired to a FirmataI2C bus whose port is a mock; every byte the servo produces is asserted exactly. Ramping is verified with small step intervals so the background process finishes fast.!

!FirmataServoPortMock methodsFor: 'initialize-release' stamp: 'sf 24/Sep/2026 00:00:00'!
initialize
	written := ByteArray new.
	buffer := ByteArray new! !

!FirmataServoPortMock methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
data: aByteArray
	"Bytes the next #readByteArray answers"
	buffer := aByteArray! !

!FirmataServoPortMock methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
written
	^ written! !

!FirmataServoPortMock methodsFor: 'serial protocol' stamp: 'sf 24/Sep/2026 00:00:00'!
nextPutAll: aByteArray
	written := written , aByteArray! !

!FirmataServoPortMock methodsFor: 'serial protocol' stamp: 'sf 24/Sep/2026 00:00:00'!
readByteArray
	buffer size > 0
		ifTrue: [ | result |
			result := buffer.
			buffer := ByteArray new.
			^ result ].
	^ ByteArray new! !

!FirmataServoTest methodsFor: 'testing' stamp: 'sf 24/Sep/2026 00:00:00'!
setUp
	| bus |
	port := FirmataServoPortMock new.
	bus := FirmataI2C new.
	bus instVarNamed: 'port' put: port.
	servo := FirmataPinServo on: bus pin: 9.
	servo stepIntervalMilliseconds: 5! !

!FirmataServoTest methodsFor: 'testing' stamp: 'sf 24/Sep/2026 00:00:00'!
tearDown
	servo stopMovingProcess.
	servo firmata disconnect.
	(Delay forMilliseconds: 50) wait! !

!FirmataServoTest methodsFor: 'testing' stamp: 'sf 24/Sep/2026 00:00:00'!
waitUntilStopped
	| guard |
	guard := 0.
	[ servo isMoving and: [ guard < 2000 ] ] whileTrue: [
		(Delay forMilliseconds: 5) wait.
		guard := guard + 1 ]! !

!FirmataServoTest methodsFor: 'mapping tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testPositionRangeRestrictsPositionInput
	servo setPositionRangeFrom: 20 to: 30.
	servo setAngleRangeFrom: 0 to: 90.
	self assert: (servo positionToAngle: 20) equals: 0.
	self assert: (servo positionToAngle: 30) equals: 90.
	self assert: (servo positionToAngle: 25) equals: 45! !

!FirmataServoTest methodsFor: 'mapping tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testPositionToAngleClampsOutOfRangePositions
	servo setAngleRangeFrom: 10 to: 80.
	self assert: (servo positionToAngle: 200) equals: 80.
	self assert: (servo positionToAngle: -20) equals: 10! !

!FirmataServoTest methodsFor: 'mapping tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testPositionToAngleMapsLinearly
	servo setAngleRangeFrom: 10 to: 80.
	self assert: (servo positionToAngle: 0) equals: 10.
	self assert: (servo positionToAngle: 50) equals: 45.
	self assert: (servo positionToAngle: 100) equals: 80! !

!FirmataServoTest methodsFor: 'mapping tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testPositionToAngleSupportsInvertedAngleRange
	servo setAngleRangeFrom: 80 to: 10.
	self assert: (servo positionToAngle: 0) equals: 80.
	self assert: (servo positionToAngle: 100) equals: 10.
	self assert: (servo positionToAngle: 50) equals: 45! !

!FirmataServoTest methodsFor: 'mapping tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testProtocolAngleScalesDownFor270DegreeServo
	servo rangeDegrees: 270.
	self assert: (servo protocolAngleForDegrees: 135) equals: 90.
	self assert: (servo protocolAngleForDegrees: 270) equals: 180! !

!FirmataServoTest methodsFor: 'mapping tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testProtocolAngleStaysDirectFor180DegreeServo
	self assert: (servo protocolAngleForDegrees: 0) equals: 0.
	self assert: (servo protocolAngleForDegrees: 90) equals: 90.
	self assert: (servo protocolAngleForDegrees: 180) equals: 180! !

!FirmataServoTest methodsFor: 'moving tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testMovingProcessRampsToTarget
	servo speedDegreesPerSecond: 400.
	servo setAngleRangeFrom: 0 to: 180.
	servo moveTo: 100.
	self waitUntilStopped.
	self assert: servo isMoving equals: false.
	self assert: servo currentAngle equals: 180! !

!FirmataServoTest methodsFor: 'moving tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testSettingSpeedToZeroMidRampFinishesMove
	"Regression: stopping the speed while the background process is ramping
	must not leave the process stuck forever, it finishes the move instead."
	| guard |
	servo speedDegreesPerSecond: 400.
	servo moveToAngle: 180.
	servo speedDegreesPerSecond: 0.
	self assert: servo movingProcess notNil.
	servo step.
	self assert: servo currentAngle equals: 180.
	self assert: servo isMoving equals: false.
	guard := 0.
	[ servo movingProcess notNil and: [ guard < 1000 ] ] whileTrue: [
		(Delay forMilliseconds: 5) wait.
		guard := guard + 1 ].
	self assert: servo movingProcess isNil! !

!FirmataServoTest methodsFor: 'moving tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testStepAdvancesTowardsTarget
	servo speedDegreesPerSecond: 200.
	servo currentAngle: 0.
	servo targetAngle: 4.
	self assert: servo isMoving equals: true.
	servo step.
	servo step.
	self assert: servo currentAngle equals: 2! !

!FirmataServoTest methodsFor: 'moving tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testStepStopsExactlyAtTarget
	servo speedDegreesPerSecond: 200.
	servo currentAngle: 0.
	servo targetAngle: 3.
	[ servo isMoving ] whileTrue: [ servo step ].
	self assert: servo currentAngle equals: 3.
	self assert: servo isMoving equals: false! !

!FirmataServoTest methodsFor: 'moving tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testStopMovingProcessTerminatesBackgroundProcess
	servo speedDegreesPerSecond: 1.
	servo moveToAngle: 180.
	servo stopMovingProcess.
	self assert: servo movingProcess isNil! !

!FirmataServoTest methodsFor: 'moving tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testZeroSpeedMovesImmediately
	servo speedDegreesPerSecond: 0.
	servo setAngleRangeFrom: 0 to: 90.
	servo moveTo: 50.
	self assert: (port written) equals: #[16rE9 16r2D 0].
	self assert: servo currentAngle equals: 45.
	self assert: servo isMoving equals: false! !

!FirmataServoTest methodsFor: 'transport tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testPCA9685ServoMoveToWritesSysex
	| driver pcaServo |
	driver := FirmataPCA9685 new.
	driver firmata: servo firmata address: FirmataPCA9685Constants defaultAddress.
	pcaServo := FirmataPCA9685Servo on: driver channel: 0.
	pcaServo speedDegreesPerSecond: 0.
	pcaServo moveTo: 50.
	self assert: port written equals: #[
		16rF0 16r76 16r40 0 16r06 0 0 0 0 0 16rF7
		16rF0 16r76 16r40 0 16r08 0 16r2D 0 1 0 16rF7 ]! !

!FirmataServoTest methodsFor: 'transport tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testPCA9685ServoUsesItsOwnChannel
	| driver pcaServo |
	driver := FirmataPCA9685 new.
	driver firmata: servo firmata address: FirmataPCA9685Constants defaultAddress.
	pcaServo := FirmataPCA9685Servo on: driver channel: 3.
	pcaServo speedDegreesPerSecond: 0.
	pcaServo moveTo: 50.
	self assert: port written equals: #[
		16rF0 16r76 16r40 0 16r12 0 0 0 0 0 16rF7
		16rF0 16r76 16r40 0 16r14 0 16r2D 0 1 0 16rF7 ]! !

!FirmataServoTest methodsFor: 'transport tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testPinServo270DegreeMiddleWritesScaledAngle
	servo rangeDegrees: 270.
	servo setAngleRangeFrom: 0 to: 270.
	servo moveTo: 50.
	self assert: servo currentAngle equals: 135.
	self assert: port written equals: #[16rE9 16r5A 0]! !

!FirmataServoTest methodsFor: 'transport tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testPinServoAttachWritesPinModeAndServoConfig
	servo attach.
	self assert: port written equals: #[
		16rF4 16r09 16r04
		16rF0 16r70 16r09 16r20 16r04 16r60 16r12 16r00 16r00 16rF7 ]! !

!FirmataServoTest methodsFor: 'transport tests' stamp: 'sf 24/Sep/2026 00:00:00'!
testPinServoMoveToWritesAnalogMessage
	servo setAngleRangeFrom: 0 to: 90.
	servo moveTo: 50.
	self assert: port written equals: #[16rE9 16r2D 0]! !
