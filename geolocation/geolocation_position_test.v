module geolocation

fn test_coordinates_getters() {
	coords := GeolocationCoordinates.create(CoordinatesData{
		accuracy:          10.0
		latitude:          51.5
		longitude:         -0.12
		altitude:          25.0
		altitude_accuracy: 5.0
		heading:           90.0
		speed:             1.5
	})
	assert coords.accuracy() == 10.0
	assert coords.latitude() == 51.5
	assert coords.longitude() == -0.12
	assert coords.altitude()? == 25.0
	assert coords.altitude_accuracy()? == 5.0
	assert coords.heading()? == 90.0
	assert coords.speed()? == 1.5
}

fn test_coordinates_optional_fields_default_to_none() {
	// Only the three required fields are given; the optional ones are none.
	coords := GeolocationCoordinates.create(CoordinatesData{
		accuracy:  20.0
		latitude:  0.0
		longitude: 0.0
	})
	assert coords.accuracy() == 20.0
	assert coords.altitude() == none
	assert coords.altitude_accuracy() == none
	assert coords.heading() == none
	assert coords.speed() == none
}

fn test_position_holds_coords_timestamp_and_accuracy_flag() {
	coords := GeolocationCoordinates.create(CoordinatesData{
		accuracy:  10.0
		latitude:  1.0
		longitude: 2.0
	})
	position := GeolocationPosition.create(coords, EpochTimeStamp(1700000000000), true)
	// coords() returns the same object by reference.
	assert voidptr(position.coords()) == voidptr(coords)
	assert position.coords().latitude() == 1.0
	assert position.timestamp() == u64(1700000000000)
	assert position.is_high_accuracy()
}

fn test_position_low_accuracy() {
	coords := GeolocationCoordinates.create(CoordinatesData{})
	position := GeolocationPosition.create(coords, EpochTimeStamp(0), false)
	assert !position.is_high_accuracy()
	assert position.timestamp() == u64(0)
}

fn test_position_error_code_values() {
	assert int(GeolocationPositionErrorCode.permission_denied) == 1
	assert int(GeolocationPositionErrorCode.position_unavailable) == 2
	assert int(GeolocationPositionErrorCode.timeout) == 3
}

fn test_position_error_messages() {
	permission := GeolocationPositionError.create(.permission_denied)
	assert permission.code() == .permission_denied
	assert permission.message() == 'Permission denied'

	unavailable := GeolocationPositionError.create(.position_unavailable)
	assert unavailable.message() == 'Position unavailable'

	timeout := GeolocationPositionError.create(.timeout)
	assert timeout.message() == 'Timeout'
}
