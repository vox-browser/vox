module page

import geolocation

@[heap]
struct PageGeolocationRecorder {
mut:
	values []string
}

fn record_page_geolocation_result(mut recorder PageGeolocationRecorder, label string, result GeolocationPositionResult) {
	match result {
		geolocation.CoordinatesData {
			recorder.values << '${label}:position:${result.latitude},${result.longitude}'
		}
		geolocation.GeolocationPositionErrorCode {
			recorder.values << '${label}:error:${result}'
		}
	}
}

fn test_page_geolocation_requests_coalesce_one_shots_and_keep_watches_alive() {
	mut model := Page.create(1.0)!
	mut recorder := &PageGeolocationRecorder{}
	first := model.request_one_shot_geolocation_position(fn [mut recorder] (result GeolocationPositionResult) {
		record_page_geolocation_result(mut recorder, 'first', result)
	})
	second := model.request_one_shot_geolocation_position(fn [mut recorder] (result GeolocationPositionResult) {
		record_page_geolocation_result(mut recorder, 'second', result)
	})
	assert first == 0
	assert second == 1
	assert model.active_geolocation_request()? == first
	assert model.client().events.map(it.name) == ['request-geolocation-position']
	assert model.client().events.last().text == '0'

	position := geolocation.CoordinatesData{
		latitude: 51.5
		longitude: -0.12
		accuracy: 4
	}
	model.receive_geolocation_position(first, position)
	assert recorder.values == ['first:position:51.5,-0.12', 'second:position:51.5,-0.12']
	assert model.active_geolocation_request() == none
	assert model.pending_geolocation_request_count() == 0
	model.receive_geolocation_position(second, position)
	assert recorder.values.len == 2

	watch := model.request_geolocation_position(fn [mut recorder] (result GeolocationPositionResult) {
		record_page_geolocation_result(mut recorder, 'watch', result)
	}, .watch)
	assert watch == 2
	assert model.client().events.last() == ClientEvent{
		name: 'start-geolocation-position-watch'
		text: '2'
	}
	model.receive_geolocation_position(watch, position)
	model.receive_geolocation_position(watch, geolocation.GeolocationPositionErrorCode.timeout)
	assert model.pending_geolocation_request_count() == 1
	model.receive_geolocation_position(watch, geolocation.GeolocationPositionErrorCode.permission_denied)
	assert recorder.values.last() == 'watch:error:permission_denied'
	assert model.pending_geolocation_request_count() == 0
	model.receive_geolocation_position(watch, position)
	assert recorder.values.len == 5
}

fn test_page_geolocation_cancellation_promotes_the_next_one_shot() {
	mut model := Page.create(1.0)!
	mut recorder := &PageGeolocationRecorder{}
	first := model.request_one_shot_geolocation_position(fn [mut recorder] (result GeolocationPositionResult) {
		record_page_geolocation_result(mut recorder, 'first', result)
	})
	second := model.request_one_shot_geolocation_position(fn [mut recorder] (result GeolocationPositionResult) {
		record_page_geolocation_result(mut recorder, 'second', result)
	})
	watch := model.request_geolocation_position(fn [mut recorder] (result GeolocationPositionResult) {
		record_page_geolocation_result(mut recorder, 'watch', result)
	}, .watch)
	model.cancel_geolocation_position_request(first)
	assert model.active_geolocation_request()? == second
	assert model.client().events.map(it.name) == [
		'request-geolocation-position',
		'start-geolocation-position-watch',
		'cancel-geolocation-position',
		'request-geolocation-position',
	]
	assert model.client().events.last().text == second.str()
	model.cancel_geolocation_position_request(watch)
	assert model.client().events.last() == ClientEvent{
		name: 'stop-geolocation-position-watch'
		text: watch.str()
	}
	model.cancel_geolocation_position_request(watch)
	assert model.client().events.filter(it.name == 'stop-geolocation-position-watch').len == 1
}
