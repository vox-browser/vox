module html

import dom
import math

fn test_text_track_kind_from_string() {
	assert text_track_kind_from_string('') == .subtitles
	assert text_track_kind_from_string('SubTitles') == .subtitles
	assert text_track_kind_from_string('captions') == .captions
	assert text_track_kind_from_string('DESCRIPTIONS') == .descriptions
	assert text_track_kind_from_string('chapters') == .chapters
	assert text_track_kind_from_string('metadata') == .metadata
	// Unknown values fall back to metadata.
	assert text_track_kind_from_string('nonsense') == .metadata
}

fn test_text_track_accessors_defaults() {
	mut t := TextTrack.create()
	assert t.kind() == .subtitles
	assert t.mode() == .disabled
	assert t.readiness_state() == .not_loaded
	t.set_kind(.captions)
	t.set_label('English')
	t.set_language('en')
	t.set_id('track-1')
	t.set_mode(.showing)
	assert t.kind() == .captions
	assert t.label() == 'English'
	assert t.language() == 'en'
	assert t.id() == 'track-1'
	assert t.mode() == .showing
}

struct ReadinessRecorder {
mut:
	last  TextTrackReadinessState
	count int
}

fn test_readiness_observer_is_notified() {
	mut track := TextTrack.create()
	mut observer := TextTrackObserver.create(mut track)
	mut rec := &ReadinessRecorder{}
	observer.set_track_readiness_observer(fn [mut rec] (state TextTrackReadinessState) {
		rec.last = state
		rec.count += 1
	})
	track.set_readiness_state(.loaded)
	assert rec.count == 1
	assert rec.last == .loaded
	assert track.readiness_state() == .loaded

	// After finalize the observer is detached and no longer notified.
	observer.finalize()
	track.set_readiness_state(.failed_to_load)
	assert rec.count == 1
}

fn test_text_track_cue_end_time_validation() {
	mut cue := &TextTrackCue{}
	cue.set_start_time(1.5)
	assert cue.start_time() == 1.5
	cue.set_end_time(3.0)!
	assert cue.end_time() == 3.0
	// Negative infinity and NaN are rejected with a TypeError-equivalent error.
	if _ := cue.set_end_time_result(math.inf(-1)) {
		assert false, 'expected error for -Infinity'
	}
	if _ := cue.set_end_time_result(math.nan()) {
		assert false, 'expected error for NaN'
	}
	// The end time is unchanged after a rejected set.
	assert cue.end_time() == 3.0
}

// Small wrapper so the test can inspect the ! result of set_end_time.
fn (mut c TextTrackCue) set_end_time_result(end_time f64) !bool {
	c.set_end_time(end_time)!
	return true
}

fn test_text_track_cue_list_lookup() {
	mut cue_a := &TextTrackCue{}
	cue_a.set_id('a')
	mut cue_b := &TextTrackCue{}
	cue_b.set_id('b')
	mut list := &TextTrackCueList{}
	list.add_cue(cue_a)
	list.add_cue(cue_b)
	assert list.length() == 2
	assert list.item(0)?.id() == 'a'
	assert list.item(1)?.id() == 'b'
	assert list.internal_get_own_property(dom.js_number(1))?.id() == 'b'
	assert list.internal_get_own_property(dom.js_string('1')) == none
	assert list.item(2) == none
	assert list.get_cue_by_id('b')?.id() == 'b'
	// The empty string always returns null.
	assert list.get_cue_by_id('') == none
	assert list.get_cue_by_id('missing') == none
}

fn test_text_track_list_lookup() {
	mut track_a := TextTrack.create()
	track_a.set_id('a')
	mut track_b := TextTrack.create()
	track_b.set_id('b')
	mut list := &TextTrackList{}
	list.add_track(track_a)
	list.add_track(track_b)
	assert list.length() == 2
	assert list.item(1)?.id() == 'b'
	assert list.internal_get_own_property(dom.js_number(0))?.id() == 'a'
	assert list.internal_get_own_property(dom.js_number(1.5)) == none
	assert list.get_track_by_id('a')?.id() == 'a'
	assert list.get_track_by_id('missing') == none
}

fn test_event_handler_attribute_round_trip() {
	mut track := TextTrack.create()
	assert track.oncuechange() == none
	callback := &dom.CallbackType{
		handle_event: fn (event &dom.Event, current_target ?&dom.EventTarget) dom.JSValue {
			return dom.js_undefined()
		}
	}
	track.set_oncuechange(callback)
	assert track.oncuechange() != none
	// Setting null clears the handler.
	track.set_oncuechange(none)
	assert track.oncuechange() == none
}
