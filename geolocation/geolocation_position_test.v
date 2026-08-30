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

@[heap]
struct GeolocationRecorder {
mut:
	positions []&GeolocationPosition
	errors    []GeolocationPositionErrorCode
}

fn test_geolocation_document_security_and_task_boundaries() {
	mut recorder := &GeolocationRecorder{}
	mut inactive := Geolocation.create(GeolocationHost{ fully_active: false })
	inactive.get_current_position(fn [mut recorder] (position &GeolocationPosition) {
		recorder.positions << position
	}, fn [mut recorder] (position_error &GeolocationPositionError) {
		recorder.errors << position_error.code()
	}, PositionOptions{})
	assert recorder.errors.len == 0
	inactive.drain_tasks()
	assert recorder.errors == [.position_unavailable]

	mut insecure := Geolocation.create(GeolocationHost{ secure_context: false })
	watch_id := insecure.watch_position(fn [mut recorder] (position &GeolocationPosition) {
		recorder.positions << position
	}, fn [mut recorder] (position_error &GeolocationPositionError) {
		recorder.errors << position_error.code()
	}, PositionOptions{})
	assert watch_id == 1
	assert !insecure.has_watch(watch_id)
	insecure.drain_tasks()
	assert recorder.errors.last() == .permission_denied
}

fn test_geolocation_visibility_emulation_cache_and_watch() {
	mut recorder := &GeolocationRecorder{}
	mut geo := Geolocation.create(GeolocationHost{
		visible:       false
		now_ms:        1_000
		emulated_data: CoordinatesData{
			latitude:  12.5
			longitude: 44.0
			accuracy:  2.0
		}
	})
	emulated := geo.get_emulated_position_data()
	assert emulated.coordinates?.latitude() == 12.5
	watch_id := geo.watch_position(fn [mut recorder] (position &GeolocationPosition) {
		recorder.positions << position
	}, none, PositionOptions{ enable_high_accuracy: true })
	assert geo.has_watch(watch_id)
	geo.drain_tasks()
	assert recorder.positions.len == 0
	geo.set_visible(true)
	geo.drain_tasks()
	assert recorder.positions.len == 1
	assert recorder.positions[0].coords().latitude() == 12.5
	assert recorder.positions[0].is_high_accuracy()
	geo.clear_watch(watch_id)
	assert !geo.has_watch(watch_id)

	geo.host.emulated_data = none
	geo.host.now_ms = 1_050
	geo.cached_position = recorder.positions[0]
	geo.get_current_position(fn [mut recorder] (position &GeolocationPosition) {
		recorder.positions << position
	}, none, PositionOptions{
		enable_high_accuracy: true
		maximum_age:          100
	})
	geo.drain_tasks()
	assert recorder.positions.len == 2
	assert recorder.positions[1] == recorder.positions[0]
}

fn test_geolocation_json_records() {
	coordinates := GeolocationCoordinates.create(CoordinatesData{
		latitude: 1
		accuracy: 2
	})
	assert coordinates.to_json().latitude == 1
	position := GeolocationPosition.create(coordinates, 99, false)
	json := position.to_json()
	assert json.timestamp == 99
	assert json.coords.accuracy == 2
}

fn test_hidden_position_request_expires_without_callback() {
	mut recorder := &GeolocationRecorder{}
	mut geo := Geolocation.create(GeolocationHost{
		visible: false
		now_ms:  100
	})
	geo.get_current_position(fn [mut recorder] (position &GeolocationPosition) {
		recorder.positions << position
	}, fn [mut recorder] (position_error &GeolocationPositionError) {
		recorder.errors << position_error.code()
	}, PositionOptions{})
	geo.host.now_ms = 5_100
	geo.expire_visibility_waits()
	geo.set_visible(true)
	geo.drain_tasks()
	assert recorder.positions.len == 0
	assert recorder.errors.len == 0
}
