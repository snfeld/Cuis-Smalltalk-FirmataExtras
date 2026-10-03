'From Cuis7.8 [latest update: #7977] on 3 October 2026 at 5:23:33 pm'!
'Description '!
!provides: 'Firmata-MPU6050' 1 1!
!requires: 'Firmata-I2C' 1 1 nil!
SystemOrganization addCategory: #'Firmata-MPU6050'!


!classDefinition: #FirmataMPU6050 category: #'Firmata-MPU6050'!
FirmataI2CDevice subclass: #FirmataMPU6050
	instanceVariableNames: 'accelX accelY accelZ temperature gyroX gyroY gyroZ accelRange gyroRange'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-MPU6050'!
!classDefinition: 'FirmataMPU6050 class' category: #'Firmata-MPU6050'!
FirmataMPU6050 class
	instanceVariableNames: ''!

!classDefinition: #FirmataMPU6050Constants category: #'Firmata-MPU6050'!
Object subclass: #FirmataMPU6050Constants
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Firmata-MPU6050'!
!classDefinition: 'FirmataMPU6050Constants class' category: #'Firmata-MPU6050'!
FirmataMPU6050Constants class
	instanceVariableNames: ''!


!FirmataMPU6050 commentStamp: 'sf 12/Sep/2026' prior: 0!
I control an InvenSense MPU6050 six-axis motion sensor through a FirmataI2C connection. The chip combines a three-axis accelerometer, a three-axis gyroscope and a temperature sensor, all served from 14 consecutive registers starting at ACCEL_XOUT_H.

Typical use:
	bus := FirmataI2C new.
	bus connectOnPort: '/dev/ttyACM0' baudRate: 57600.
	sensor := FirmataMPU6050 new.
	sensor firmata: bus address: FirmataMPU6050Constants defaultAddress.
	sensor initializeDevice.
	sensor registerWithFirmata.
	sensor startReading.
	sensor accelZ       "raw 16-bit signed count on Z"
	sensor scaledAccelZ "Z acceleration in g"
	sensor scaledGyroX  "X rotation rate in degrees per second"

Start the stream with #startReading (or do a single #readOnce) and read the raw or scaled values afterwards; each incoming I2C_REPLY overwrites the last sample via #handleI2CReply:data:. The scaled accessors divide the raw 16-bit counts by the sensitivity of the configured full-scale range, see #setAccelerationRange: and #setGyroRange:.!

!FirmataMPU6050Constants commentStamp: 'sf 12/Sep/2026' prior: 0!
See class side. I collect the MPU6050 register map, configuration bits and specification constants from the InvenSense MPU6050 datasheet.!

!FirmataMPU6050 methodsFor: 'initialize-release' stamp: 'sf 12/Sep/2026 00:00:00'!
initialize
	super initialize.
	accelRange := self class defaultAccelRange.
	gyroRange := self class defaultGyroRange! !

!FirmataMPU6050 methodsFor: 'device initialization' stamp: 'sf 12/Sep/2026 00:00:00'!
initializeDevice
	"Wake the sensor up by clearing the sleep bit, keeping the internal clock."
	self writeRegister: FirmataMPU6050Constants powerManagement1Register
		data: (ByteArray with: FirmataMPU6050Constants awakeValue).
	^ self! !

!FirmataMPU6050 methodsFor: 'sensor configuration' stamp: 'sf 12/Sep/2026 00:00:00'!
setAccelerationRange: anIndex
	"Set the accelerometer full-scale range: 0 is +/-2g, 1 +/-4g, 2 +/-8g, 3 +/-16g."
	self checkRangeIndex: anIndex.
	self writeRegister: FirmataMPU6050Constants accelConfigRegister
		data: (ByteArray with: (anIndex bitShift: 3)).
	accelRange := anIndex.
	^ self! !

!FirmataMPU6050 methodsFor: 'sensor configuration' stamp: 'sf 12/Sep/2026 00:00:00'!
setGyroRange: anIndex
	"Set the gyroscope full-scale range: 0 is +/-250, 1 +/-500, 2 +/-1000, 3 +/-2000 dps."
	self checkRangeIndex: anIndex.
	self writeRegister: FirmataMPU6050Constants gyroConfigRegister
		data: (ByteArray with: (anIndex bitShift: 3)).
	gyroRange := anIndex.
	^ self! !

!FirmataMPU6050 methodsFor: 'sensor configuration - private' stamp: 'sf 12/Sep/2026 00:00:00'!
checkRangeIndex: anIndex
	"Guard against a full-scale range index that the regsiters cannot encode."
	(anIndex between: 0 and: 3)
		ifFalse: [ self error: 'MPU6050 range index out of range' ]! !

!FirmataMPU6050 methodsFor: 'reading' stamp: 'sf 12/Sep/2026 00:00:00'!
readOnce
	"Read the current sensor output with a single request."
	self readRegister: FirmataMPU6050Constants accelXHighRegister
		byteCount: FirmataMPU6050Constants sensorOutputByteCount.
	^ self! !

!FirmataMPU6050 methodsFor: 'reading' stamp: 'sf 12/Sep/2026 00:00:00'!
startReading
	"Ask the board to keep streaming the sensor output registers."
	self readRegisterContinuously: FirmataMPU6050Constants accelXHighRegister
		byteCount: FirmataMPU6050Constants sensorOutputByteCount.
	^ self! !

!FirmataMPU6050 methodsFor: 'reply handling' stamp: 'sf 12/Sep/2026 00:00:00'!
handleI2CReply: aRegister data: aByteArray
	"Parse a sensor output reply into raw counts, overwriting the last sample.
	Replies shorter than the sensor output block are ignored."
	aByteArray size >= FirmataMPU6050Constants sensorOutputByteCount
		ifFalse: [ ^ self ].
	accelX := self signed16At: 1 in: aByteArray.
	accelY := self signed16At: 3 in: aByteArray.
	accelZ := self signed16At: 5 in: aByteArray.
	temperature := (self signed16At: 7 in: aByteArray)
		/ FirmataMPU6050Constants temperatureScaleFactor
		+ FirmataMPU6050Constants temperatureOffset.
	gyroX := self signed16At: 9 in: aByteArray.
	gyroY := self signed16At: 11 in: aByteArray.
	gyroZ := self signed16At: 13 in: aByteArray! !

!FirmataMPU6050 methodsFor: 'reply handling - private' stamp: 'sf 12/Sep/2026 00:00:00'!
signed16At: index in: aByteArray
	"16-bit signed value read big-endian from aByteArray at index (1-based)."
	| value |
	value := ((aByteArray at: index) bitShift: 8)
		bitOr: (aByteArray at: index + 1).
	value >= 16r8000 ifTrue: [ ^ value - 16r10000 ].
	^ value! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
accelRange
	^ accelRange! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
accelSensitivity
	"LSB per g at the configured range, halved each range step."
	^ FirmataMPU6050Constants accelSensitivity bitShift: accelRange negated! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
accelX
	^ accelX! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
accelY
	^ accelY! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
accelZ
	^ accelZ! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
gyroRange
	^ gyroRange! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
gyroSensitivity
	"LSB per degrees per second at the configured range, halved each range step."
	^ FirmataMPU6050Constants gyroSensitivity / (1 bitShift: gyroRange)! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
gyroX
	^ gyroX! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
gyroY
	^ gyroY! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
gyroZ
	^ gyroZ! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
scaledAccelX
	"X acceleration in g using the configured full-scale range."
	^ self accelX / self accelSensitivity! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
scaledAccelY
	"Y acceleration in g using the configured full-scale range."
	^ self accelY / self accelSensitivity! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
scaledAccelZ
	"Z acceleration in g using the configured full-scale range."
	^ self accelZ / self accelSensitivity! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
scaledGyroX
	"X rotation rate in degrees per second using the configured full-scale range."
	^ self gyroX / self gyroSensitivity! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
scaledGyroY
	"Y rotation rate in degrees per second using the configured full-scale range."
	^ self gyroY / self gyroSensitivity! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
scaledGyroZ
	"Z rotation rate in degrees per second using the configured full-scale range."
	^ self gyroZ / self gyroSensitivity! !

!FirmataMPU6050 methodsFor: 'sensor output' stamp: 'sf 12/Sep/2026 00:00:00'!
temperature
	^ temperature! !

!FirmataMPU6050 class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultAccelRange
	"Fallback accelerometer full-scale range index (+/-2g)."
	^ FirmataMPU6050Constants defaultAccelRange! !

!FirmataMPU6050 class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultAddress
	"Typical MPU6050 slave address with the AD0 pin low."
	^ FirmataMPU6050Constants defaultAddress! !

!FirmataMPU6050 class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultGyroRange
	"Fallback gyroscope full-scale range index (+/-250 dps)."
	^ FirmataMPU6050Constants defaultGyroRange! !

!FirmataMPU6050Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
accelConfigRegister
	"0x1C accelerometer full-scale configuration register"
	^ 16r1C! !

!FirmataMPU6050Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
accelXHighRegister
	"0x3B high byte of the X accelerometer output, first of the 14 output registers"
	^ 16r3B! !

!FirmataMPU6050Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
configRegister
	"0x1A digital low-pass filter configuration register"
	^ 16r1A! !

!FirmataMPU6050Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
gyroConfigRegister
	"0x1B gyroscope full-scale configuration register"
	^ 16r1B! !

!FirmataMPU6050Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
gyroXHighRegister
	"0x43 high byte of the X gyroscope output"
	^ 16r43! !

!FirmataMPU6050Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
powerManagement1Register
	"0x6B power management register 1 holding the device reset and sleep bits"
	^ 16r6B! !

!FirmataMPU6050Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
powerManagement2Register
	"0x6C power management register 2"
	^ 16r6C! !

!FirmataMPU6050Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
smplrtDivRegister
	"0x19 sample rate divider register"
	^ 16r19! !

!FirmataMPU6050Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
temperatureHighRegister
	"0x41 high byte of the temperature output"
	^ 16r41! !

!FirmataMPU6050Constants class methodsFor: 'registers' stamp: 'sf 12/Sep/2026 00:00:00'!
whoAmIRegister
	"0x75 who am I register answering 0x68"
	^ 16r75! !

!FirmataMPU6050Constants class methodsFor: 'power management' stamp: 'sf 12/Sep/2026 00:00:00'!
awakeValue
	"Writing 0 clears the sleep bit and uses the internal 8 MHz clock"
	^ 0! !

!FirmataMPU6050Constants class methodsFor: 'power management' stamp: 'sf 12/Sep/2026 00:00:00'!
deviceResetBit
	"Bit 7 of power management register 1 resetting the whole chip"
	^ 16r80! !

!FirmataMPU6050Constants class methodsFor: 'power management' stamp: 'sf 12/Sep/2026 00:00:00'!
sleepBit
	"Bit 6 of power management register 1 putting the chip to sleep"
	^ 16r40! !

!FirmataMPU6050Constants class methodsFor: 'power management' stamp: 'sf 12/Sep/2026 00:00:00'!
temperatureDisableBit
	"Bit 3 of power management register 1 disabling the temperature sensor"
	^ 16r08! !

!FirmataMPU6050Constants class methodsFor: 'specification' stamp: 'sf 12/Sep/2026 00:00:00'!
accelSensitivity
	"Raw counts per g at the +/-2g full-scale range"
	^ 16384! !

!FirmataMPU6050Constants class methodsFor: 'specification' stamp: 'sf 12/Sep/2026 00:00:00'!
gyroSensitivity
	"Raw counts per degrees per second at the +/-250 dps full-scale range"
	^ 131.0! !

!FirmataMPU6050Constants class methodsFor: 'specification' stamp: 'sf 12/Sep/2026 00:00:00'!
sensorOutputByteCount
	"Accelerometer, temperature and gyroscope values: 3 plus 1 plus 3 values of two bytes"
	^ 14! !

!FirmataMPU6050Constants class methodsFor: 'specification' stamp: 'sf 12/Sep/2026 00:00:00'!
temperatureOffset
	"Degrees Celsius added to the scaled temperature raw value"
	^ 36.53! !

!FirmataMPU6050Constants class methodsFor: 'specification' stamp: 'sf 12/Sep/2026 00:00:00'!
temperatureScaleFactor
	"Raw counts per degree Celsius of the temperature sensor"
	^ 340.0! !

!FirmataMPU6050Constants class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultAccelRange
	"Full-scale range index for +/-2g"
	^ 0! !

!FirmataMPU6050Constants class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultAddress
	"I2C slave address 0x68 with the AD0 pin low"
	^ 16r68! !

!FirmataMPU6050Constants class methodsFor: 'defaults' stamp: 'sf 12/Sep/2026 00:00:00'!
defaultGyroRange
	"Full-scale range index for +/-250 degrees per second"
	^ 0! !
