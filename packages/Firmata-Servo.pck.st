'From Cuis7.8 [latest update: #7977] on 28 September 2026 at 8:18:57 am'!
'Description '!
!provides: 'Firmata-Servo' 1 1!
!requires: 'Firmata-PCA9685' 1 1 nil!
SystemOrganization addCategory: #'Firmata-Servo'!


!classDefinition: #FirmataServo category: #'Firmata-Servo'!
Object subclass: #FirmataServo
	instanceVariableNames: 'firmata minPosition maxPosition minAngle maxAngle rangeDegrees minPulseMicroseconds maxPulseMicroseconds speedDegreesPerSecond stepIntervalMilliseconds currentAngle targetAngle movingProcess'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-Servo'!
!classDefinition: 'FirmataServo class' category: #'Firmata-Servo'!
FirmataServo class
	instanceVariableNames: ''!

!classDefinition: #FirmataPCA9685Servo category: #'Firmata-Servo'!
FirmataServo subclass: #FirmataPCA9685Servo
	instanceVariableNames: 'channel'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-Servo'!
!classDefinition: 'FirmataPCA9685Servo class' category: #'Firmata-Servo'!
FirmataPCA9685Servo class
	instanceVariableNames: ''!

!classDefinition: #FirmataPinServo category: #'Firmata-Servo'!
FirmataServo subclass: #FirmataPinServo
	instanceVariableNames: 'pin'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-Servo'!
!classDefinition: 'FirmataPinServo class' category: #'Firmata-Servo'!
FirmataPinServo class
	instanceVariableNames: ''!


!FirmataServo commentStamp: 'sf 24/Sep/2026' prior: 0!
I am a servo with speed control and input-to-angle mapping.

A servo spends its working life between a mount range (physical angles, see #minAngle and #maxAngle). Its input is an abstract position value, typically a percentage between 0 and 100 (#minPosition and #maxPosition). #moveTo: maps the value linearly onto the physical angle range — inverted ranges are supported for servos mounted the other way round — clamps it, and drives the servo there.

The angular speed (#speedDegreesPerSecond) controls how fast the angle changes: with zero speed the servo jumps straight to the target, with a positive speed the servo ramps there in small steps from a background process (#startMovingProcess), stopping automatically when the target is reached. Current and target angle are kept as state (#currentAngle, #targetAngle).

The mechanical range (#rangeDegrees, 180 or 270) together with the pulse width calibration (#minPulseMicroseconds and #maxPulseMicroseconds) scales the physical angle to the protocol angle. Protocol details are delegated to subclasses through #writeAngle:; see FirmataPinServo and FirmataPCA9685Servo.!

!FirmataPCA9685Servo commentStamp: 'sf 24/Sep/2026' prior: 0!
I drive a servo that is connected to one channel of a PCA9685 PWM driver, which in turn talks over I2C to the Arduino. Movement is a #setServoOnChannel:angle:minPulse:maxPulse: message on the FirmataPCA9685 driver; the driver must be initialized and the frequency set first.

	driver := FirmataPCA9685 new.
	driver firmata: bus address: FirmataPCA9685Constants defaultAddress.
	driver initializeDevice.
	driver setFrequency: 50.
	servo := FirmataPCA9685Servo on: driver channel: 0.
	servo speedDegreesPerSecond: 45.
	servo moveTo: 50.!

!FirmataPinServo commentStamp: 'sf 24/Sep/2026' prior: 0!
I drive a servo that is connected directly to a digital pin of the Arduino board. #attach configures the pin as servo and sends the pulse width calibration once; afterwards every movement is a #servoOnPin:angle: message on the Firmata connection.

	servo := FirmataPinServo on: firmata pin: 9.
	servo attach.
	servo speedDegreesPerSecond: 45.
	servo moveTo: 50.!

!FirmataServo methodsFor: 'initialize-release' stamp: 'sf 24/Sep/2026 00:00:00'!
attach
	"Configure the hardware once. No-op by default; subclasses that need
	calibration (e.g. pulse widths) override this."! !

!FirmataServo methodsFor: 'initialize-release' stamp: 'sf 24/Sep/2026 00:00:00'!
initialize
	super initialize.
	minPosition := 0.
	maxPosition := 100.
	minAngle := 0.
	maxAngle := self class defaultRangeDegrees.
	rangeDegrees := self class defaultRangeDegrees.
	minPulseMicroseconds := self class defaultMinPulseMicroseconds.
	maxPulseMicroseconds := self class defaultMaxPulseMicroseconds.
	speedDegreesPerSecond := self class defaultSpeedDegreesPerSecond.
	stepIntervalMilliseconds := self class defaultStepIntervalMilliseconds.
	currentAngle := 0.
	targetAngle := 0! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
currentAngle
	"Physical angle the servo is currently at (tracked state)."
	^ currentAngle! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
currentAngle: degrees
	currentAngle := degrees! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
firmata
	^ firmata! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
maxAngle
	^ maxAngle! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
maxAngle: degrees
	maxAngle := degrees! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
maxPosition
	^ maxPosition! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
maxPosition: aValue
	maxPosition := aValue! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
maxPulseMicroseconds
	^ maxPulseMicroseconds! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
maxPulseMicroseconds: aNumber
	maxPulseMicroseconds := aNumber! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
minAngle
	^ minAngle! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
minAngle: degrees
	minAngle := degrees! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
minPosition
	^ minPosition! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
minPosition: aValue
	minPosition := aValue! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
minPulseMicroseconds
	^ minPulseMicroseconds! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
minPulseMicroseconds: aNumber
	minPulseMicroseconds := aNumber! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
rangeDegrees
	^ rangeDegrees! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
rangeDegrees: aNumber
	rangeDegrees := aNumber! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
setAngleRangeFrom: minDegrees to: maxDegrees
	minAngle := minDegrees.
	maxAngle := maxDegrees! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
setPositionRangeFrom: minValue to: maxValue
	minPosition := minValue.
	maxPosition := maxValue! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
speedDegreesPerSecond
	^ speedDegreesPerSecond! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
speedDegreesPerSecond: aNumber
	"Speed in physical degrees per second. Zero means: jump straight to
	the target, no ramping. Changing the speed while ramping takes effect
	with the next step."
	speedDegreesPerSecond := aNumber! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
stepIntervalMilliseconds
	^ stepIntervalMilliseconds! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
stepIntervalMilliseconds: aNumber
	stepIntervalMilliseconds := aNumber! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
targetAngle
	"Physical angle the servo is moving to."
	^ targetAngle! !

!FirmataServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
targetAngle: degrees
	"Set the target and ramp if speed is positive. Does not start the
	background process; use #moveTo: or #moveToAngle: for that."
	(targetAngle := self clampAngle: degrees) == currentAngle
		ifTrue: [ ^ self ]! !

!FirmataServo methodsFor: 'moving' stamp: 'sf 24/Sep/2026 00:00:00'!
isMoving
	^ currentAngle ~= targetAngle! !

!FirmataServo methodsFor: 'moving' stamp: 'sf 24/Sep/2026 00:00:00'!
moveTo: aPosition
	"Map the abstract position onto the physical angle range and move there."
	self moveToAngle: (self positionToAngle: aPosition)! !

!FirmataServo methodsFor: 'moving' stamp: 'sf 24/Sep/2026 00:00:00'!
moveToAngle: degrees
	"Move to a physical angle. With zero speed the servo jumps there, with
	a positive speed it ramps in the background process."
	targetAngle := self clampAngle: degrees.
	(self speedDegreesPerSecond > 0 and: [ self isMoving ])
		ifTrue: [ self startMovingProcess ]
		ifFalse: [
			currentAngle := targetAngle.
			self sendAngle: currentAngle ]! !

!FirmataServo methodsFor: 'moving' stamp: 'sf 24/Sep/2026 00:00:00'!
movingProcess
	^ movingProcess! !

!FirmataServo methodsFor: 'moving' stamp: 'sf 24/Sep/2026 00:00:00'!
startMovingProcess
	"Ramp towards the target in small steps from a background process that
	stops by itself once the target is reached."
	self stopMovingProcess.
	movingProcess := [
		[ [ self isMoving ] whileTrue: [
			self step.
			(Delay forMilliseconds: self stepIntervalMilliseconds) wait ] ]
			ensure: [ movingProcess := nil ] ] newProcess.
	movingProcess priority: Processor activePriority.
	movingProcess name: 'FirmataServo ' , self class name.
	movingProcess resume! !

!FirmataServo methodsFor: 'moving' stamp: 'sf 24/Sep/2026 00:00:00'!
step
	"Advance one step towards the target and send the new angle.
	Zero or negative speed finishes the move in one step."
	| delta direction stepSize |
	self isMoving ifFalse: [ ^ self ].
	stepSize := self speedDegreesPerSecond * (self stepIntervalMilliseconds / 1000.0).
	stepSize <= 0
		ifTrue: [
			currentAngle := targetAngle.
			^ self sendAngle: currentAngle ].
	delta := targetAngle - currentAngle.
	direction := delta sign.
	currentAngle := currentAngle + (stepSize * direction).
	(targetAngle - currentAngle) sign = direction
		ifFalse: [ currentAngle := targetAngle ].
	self sendAngle: currentAngle! !

!FirmataServo methodsFor: 'moving' stamp: 'sf 24/Sep/2026 00:00:00'!
stopMovingProcess
	movingProcess ifNotNil: [
		movingProcess terminate.
		movingProcess := nil ]! !

!FirmataServo methodsFor: 'mapping' stamp: 'sf 24/Sep/2026 00:00:00'!
clampAngle: degrees
	"Clamp a physical angle to the mount range, regardless of direction."
	^ (degrees
		max: (self minAngle min: self maxAngle))
		min: (self minAngle max: self maxAngle)! !

!FirmataServo methodsFor: 'mapping' stamp: 'sf 24/Sep/2026 00:00:00'!
interpolate: aValue from: inMin to: inMax to: outMin to: outMax
	"Linear interpolation; inMin = inMax maps everything to the output end."
	| ratio |
	inMin = inMax
		ifTrue: [ ^ outMax ].
	ratio := (aValue - inMin) / (inMax - inMin).
	^ outMin + (ratio * (outMax - outMin))! !

!FirmataServo methodsFor: 'mapping' stamp: 'sf 24/Sep/2026 00:00:00'!
positionToAngle: aPosition
	"Map an abstract position linearly onto the physical angle range,
	clamped to the position range."
	| clamped |
	clamped := aPosition
		max: (self minPosition min: self maxPosition).
	clamped := clamped
		min: (self minPosition max: self maxPosition).
	^ self interpolate: clamped
		from: self minPosition to: self maxPosition
		to: self minAngle to: self maxAngle! !

!FirmataServo methodsFor: 'mapping' stamp: 'sf 24/Sep/2026 00:00:00'!
protocolAngleForDegrees: degrees
	"Scale a physical angle to the 0-180 protocol angle of Firmata,
	according to the mechanical range of the servo."
	^ degrees * 180 / self rangeDegrees! !

!FirmataServo methodsFor: 'private' stamp: 'sf 24/Sep/2026 00:00:00'!
sendAngle: degrees
	"Clamp and scale a physical angle, then hand it to the transport."
	self writeAngle: (self protocolAngleForDegrees: (self clampAngle: degrees))! !

!FirmataServo methodsFor: 'private' stamp: 'sf 24/Sep/2026 00:00:00'!
writeAngle: protocolAngle
	"Send a protocol angle to the hardware. Subclass responsibility."
	self subclassResponsibility! !

!FirmataServo class methodsFor: 'defaults' stamp: 'sf 24/Sep/2026 00:00:00'!
defaultMaxPulseMicroseconds
	"Pulse width for the 180 degree position of a standard 180 degree servo."
	^ 2400! !

!FirmataServo class methodsFor: 'defaults' stamp: 'sf 24/Sep/2026 00:00:00'!
defaultMinPulseMicroseconds
	"Pulse width for the 0 degree position of a standard 180 degree servo."
	^ 544! !

!FirmataServo class methodsFor: 'defaults' stamp: 'sf 24/Sep/2026 00:00:00'!
defaultRangeDegrees
	"Mechanical swing of a standard servo."
	^ 180! !

!FirmataServo class methodsFor: 'defaults' stamp: 'sf 24/Sep/2026 00:00:00'!
defaultSpeedDegreesPerSecond
	"Zero: jump straight to the target, no ramping."
	^ 0! !

!FirmataServo class methodsFor: 'defaults' stamp: 'sf 24/Sep/2026 00:00:00'!
defaultStepIntervalMilliseconds
	"Delay between two ramp steps in milliseconds."
	^ 20! !

!FirmataPCA9685Servo methodsFor: 'initialize-release' stamp: 'sf 24/Sep/2026 00:00:00'!
initializeOn: aFirmataPCA9685 channel: aChannel
	self initialize.
	firmata := aFirmataPCA9685.
	channel := aChannel! !

!FirmataPCA9685Servo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
channel
	^ channel! !

!FirmataPCA9685Servo methodsFor: 'private' stamp: 'sf 24/Sep/2026 00:00:00'!
writeAngle: protocolAngle
	firmata
		setServoOnChannel: channel
		angle: protocolAngle rounded
		minPulse: self minPulseMicroseconds
		maxPulse: self maxPulseMicroseconds! !

!FirmataPCA9685Servo class methodsFor: 'instance creation' stamp: 'sf 24/Sep/2026 00:00:00'!
on: aFirmataPCA9685 channel: aChannel
	^ self new initializeOn: aFirmataPCA9685 channel: aChannel! !

!FirmataPinServo methodsFor: 'initialize-release' stamp: 'sf 24/Sep/2026 00:00:00'!
attach
	"Set the pin to servo mode and send the pulse width calibration once.
	The rest angle (mount range start) is used as the initial position."
	self firmata pin: self pin mode: FirmataConstants pinModeServo.
	self firmata
		servoConfig: self pin
		minPulse: self minPulseMicroseconds
		maxPulse: self maxPulseMicroseconds
		angle: (self protocolAngleForDegrees: self minAngle).
	currentAngle := self minAngle.
	targetAngle := self minAngle! !

!FirmataPinServo methodsFor: 'initialize-release' stamp: 'sf 24/Sep/2026 00:00:00'!
initializeOn: aFirmata pin: aPinNumber
	self initialize.
	firmata := aFirmata.
	pin := aPinNumber! !

!FirmataPinServo methodsFor: 'accessing' stamp: 'sf 24/Sep/2026 00:00:00'!
pin
	^ pin! !

!FirmataPinServo methodsFor: 'private' stamp: 'sf 24/Sep/2026 00:00:00'!
writeAngle: protocolAngle
	firmata servoOnPin: pin angle: protocolAngle rounded! !

!FirmataPinServo class methodsFor: 'instance creation' stamp: 'sf 24/Sep/2026 00:00:00'!
on: aFirmata pin: aPinNumber
	^ self new initializeOn: aFirmata pin: aPinNumber! !
