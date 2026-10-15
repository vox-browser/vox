module html

import dom
import math

fn mtib_rejected_properties(object voidptr) []dom.JSValue {
	mut values := []dom.JSValue{}
	for number in [f64(-1), -0.25, 0.5, 1.5, 1.9999999999999998, 2.0, 3.0,
		2147483648.0, 4294967295.0, 4294967296.0, 4294967297.0,
		9007199254740991.0, 18446744073709551616.0, 1.7976931348623157e308,
		-4294967296.0, -1.7976931348623157e308, math.nan(), math.inf(1), math.inf(-1)] {
		values << dom.js_number(number)
	}
	// The typed numeric-index adapter does not coerce other JSValue kinds.
	values << dom.js_undefined()
	values << dom.js_null()
	values << dom.js_bool(false)
	values << dom.js_bool(true)
	values << dom.js_string('0')
	values << dom.js_string('1')
	values << dom.js_string('4294967296')
	values << dom.js_object(object)
	values << dom.JSValue{kind: .runtime_value, number_data: 1}
	return values
}

fn mtib_unexpected_change() {
	panic('Indexed media track lookup must not queue a change task')
}

fn mtib_unexpected_audio_update(_ &AudioTrack, _ bool) {
	panic('Indexed audio track lookup must not update playback')
}

fn mtib_unexpected_video_update(_ ?&VideoTrack) {
	panic('Indexed video track lookup must not change playback selection')
}

fn mtib_reject_events(target &dom.EventTarget) {
	callback := &dom.CallbackType{
		handle_event: fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			panic('Indexed media track lookup must not dispatch mutation events')
		}
	}
	for name in ['change', 'addtrack', 'removetrack'] {
		target.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn test_audio_track_index_getter_checks_numeric_bounds_without_mutating_owned_tracks() {
	owner := HTMLMediaElement.create(none, dom.url_about_blank())
	mut list := owner.audio_tracks()
	properties := mtib_rejected_properties(voidptr(owner))
	for number in [f64(0), 1.0, -0.0] {
		assert list.internal_get_own_property(dom.js_number(number)) == none
	}
	for property in properties { assert list.internal_get_own_property(property) == none }
	mut first := AudioTrack.create(MediaTrackMetadata{identifier: 101, name: 'First audio'},
		mtib_unexpected_change, mtib_unexpected_audio_update)
	mut second := AudioTrack.create(MediaTrackMetadata{identifier: 202, name: 'Second audio'},
		mtib_unexpected_change, mtib_unexpected_audio_update)
	first.base.set_media_element(owner)
	second.base.set_media_element(owner)
	first.enabled = true
	list.add_track(first)
	list.add_track(second)
	mtib_reject_events(list.event_target())
	for index, number in [f64(0), 1.0, -0.0] {
		actual := list.internal_get_own_property(dom.js_number(number)) or { panic('Missing valid audio index ${number}') }
		expected := if index == 1 { second } else { first }
		assert voidptr(actual) == voidptr(expected)
	}
	for property in properties { assert list.internal_get_own_property(property) == none }
	assert voidptr(owner.audio_tracks()) == voidptr(list) && list.length() == 2
	assert voidptr(list.item(0) or { panic('Lost first audio track') }) == voidptr(first)
	assert voidptr(list.item(1) or { panic('Lost second audio track') }) == voidptr(second)
	assert voidptr(list.get_track_by_id('101') or { panic('Lost first audio ID') }) == voidptr(first)
	assert voidptr(list.get_track_by_id('202') or { panic('Lost second audio ID') }) == voidptr(second)
	for track in [first, second] {
		assert voidptr(track.audio_track_list or { panic('Lost audio list back-reference') }) == voidptr(list)
		assert voidptr(track.base.media_element() or { panic('Lost audio media owner') }) == voidptr(owner)
	}
	assert first.enabled && !second.enabled && list.has_enabled_track()
	assert first.base.id == '101' && first.base.label == 'First audio'
	assert second.base.id == '202' && second.base.label == 'Second audio'
}

fn test_video_track_index_getter_checks_numeric_bounds_without_mutating_owned_tracks() {
	owner := HTMLMediaElement.create(none, dom.url_about_blank())
	mut list := owner.video_tracks()
	properties := mtib_rejected_properties(voidptr(owner))
	for number in [f64(0), 1.0, -0.0] {
		assert list.internal_get_own_property(dom.js_number(number)) == none
	}
	for property in properties { assert list.internal_get_own_property(property) == none }
	mut first := VideoTrack.create(MediaTrackMetadata{identifier: 101, name: 'First video'},
		mtib_unexpected_change, mtib_unexpected_video_update)
	mut second := VideoTrack.create(MediaTrackMetadata{identifier: 202, name: 'Second video'},
		mtib_unexpected_change, mtib_unexpected_video_update)
	first.base.set_media_element(owner)
	second.base.set_media_element(owner)
	second.selected = true
	list.add_track(first)
	list.add_track(second)
	mtib_reject_events(&list.EventTarget)
	for index, number in [f64(0), 1.0, -0.0] {
		actual := list.internal_get_own_property(dom.js_number(number)) or { panic('Missing valid video index ${number}') }
		expected := if index == 1 { second } else { first }
		assert voidptr(actual) == voidptr(expected)
	}
	for property in properties { assert list.internal_get_own_property(property) == none }
	assert voidptr(owner.video_tracks()) == voidptr(list) && list.length() == 2
	assert voidptr(list.item(0) or { panic('Lost first video track') }) == voidptr(first)
	assert voidptr(list.item(1) or { panic('Lost second video track') }) == voidptr(second)
	assert voidptr(list.get_track_by_id('101') or { panic('Lost first video ID') }) == voidptr(first)
	assert voidptr(list.get_track_by_id('202') or { panic('Lost second video ID') }) == voidptr(second)
	for track in [first, second] {
		assert voidptr(track.video_track_list or { panic('Lost video list back-reference') }) == voidptr(list)
		assert voidptr(track.base.media_element() or { panic('Lost video media owner') }) == voidptr(owner)
	}
	assert !first.selected && second.selected && list.selected_index() == 1
	assert first.base.id == '101' && first.base.label == 'First video'
	assert second.base.id == '202' && second.base.label == 'Second video'
}
