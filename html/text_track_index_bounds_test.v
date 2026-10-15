module html

import dom
import math

fn ttib_rejected_properties(object voidptr) []dom.JSValue {
	mut values := []dom.JSValue{}
	for number in [f64(-1), -0.25, 0.5, 1.5, 1.9999999999999998, 2.0, 3.0,
		2147483648.0, 4294967295.0, 4294967296.0, 4294967297.0,
		9007199254740991.0, 18446744073709551616.0, 1.7976931348623157e308,
		-4294967296.0, -1.7976931348623157e308, math.nan(), math.inf(1), math.inf(-1)] {
		values << dom.js_number(number)
	}
	// This typed adapter accepts numeric indices without coercing other JS kinds.
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

fn test_text_track_cue_index_getter_rejects_unrepresentable_indices_without_wrapping_or_mutation() {
	mut owner := TextTrack.create()
	list := owner.cues()
	for number in [f64(0), 1.0, -0.0] {
		assert list.internal_get_own_property(dom.js_number(number)) == none
	}
	mut first := TextTrackCue.create(0, 1, 'First retained cue')!
	mut second := TextTrackCue.create(1, 2, 'Second retained cue')!
	first.set_id('first')
	second.set_id('second')
	owner.add_cue(mut first)
	owner.add_cue(mut second)
	for index, number in [f64(0), 1.0, -0.0] {
		actual := list.internal_get_own_property(dom.js_number(number)) or { panic('Missing valid cue index ${number}') }
		expected := if index == 1 { second } else { first }
		assert voidptr(actual) == voidptr(expected)
	}
	for property in ttib_rejected_properties(voidptr(first)) {
		assert list.internal_get_own_property(property) == none
	}
	assert voidptr(owner.cues()) == voidptr(list) && list.length() == 2
	assert voidptr(list.item(0) or { panic('Lost first cue after rejected lookup') }) == voidptr(first)
	assert voidptr(list.item(1) or { panic('Lost second cue after rejected lookup') }) == voidptr(second)
	assert voidptr(first.track() or { panic('Lost first cue ownership') }) == voidptr(owner)
	assert voidptr(second.track() or { panic('Lost second cue ownership') }) == voidptr(owner)
	assert first.id() == 'first' && first.text() == 'First retained cue'
	assert second.id() == 'second' && second.text() == 'Second retained cue'
}

fn test_text_track_index_getter_rejects_unrepresentable_indices_without_wrapping_or_mutation() {
	mut list := &TextTrackList{}
	for number in [f64(0), 1.0, -0.0] {
		assert list.internal_get_own_property(dom.js_number(number)) == none
	}
	mut first := TextTrack.create()
	mut second := TextTrack.create()
	first.set_id('first')
	second.set_id('second')
	first.set_mode(.hidden)
	second.set_mode(.showing)
	list.add_track(first)
	list.add_track(second)
	for index, number in [f64(0), 1.0, -0.0] {
		actual := list.internal_get_own_property(dom.js_number(number)) or { panic('Missing valid track index ${number}') }
		expected := if index == 1 { second } else { first }
		assert voidptr(actual) == voidptr(expected)
	}
	for property in ttib_rejected_properties(voidptr(first)) {
		assert list.internal_get_own_property(property) == none
	}
	assert list.length() == 2
	assert voidptr(list.item(0) or { panic('Lost first track after rejected lookup') }) == voidptr(first)
	assert voidptr(list.item(1) or { panic('Lost second track after rejected lookup') }) == voidptr(second)
	assert voidptr(list.get_track_by_id('first') or { panic('Lost first track ID') }) == voidptr(first)
	assert voidptr(list.get_track_by_id('second') or { panic('Lost second track ID') }) == voidptr(second)
	assert first.mode() == .hidden && second.mode() == .showing
	assert first.readiness_state() == .not_loaded && second.readiness_state() == .not_loaded
}
