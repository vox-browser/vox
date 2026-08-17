module webvtt

import math

fn cue() &VTTCue {
	return VTTCue.construct_impl(1.0, 5.0, 'hello') or { panic('${err}') }
}

fn test_construct_sets_inherited_and_own_fields() {
	c := cue()
	// Inherited TextTrackCue fields (via embedding).
	assert c.start_time() == 1.0
	assert c.end_time() == 5.0
	assert c.id() == ''
	assert c.pause_on_exit() == false
	// Own field.
	assert c.text() == 'hello'
}

fn test_construct_rejects_bad_end_time() {
	if _ := VTTCue.construct_impl(0, math.nan(), 't') {
		assert false, 'expected TypeError for NaN end time'
	}
	if _ := VTTCue.construct_impl(0, math.inf(-1), 't') {
		assert false, 'expected TypeError for -Infinity end time'
	}
}

fn test_defaults() {
	c := cue()
	assert c.vertical() == .empty
	assert c.snap_to_lines() == true
	assert c.line().is_auto == true
	assert c.line_align() == .start
	assert c.position().is_auto == true
	assert c.position_align() == .auto
	assert c.size() == 100.0
	assert c.align() == .center
	assert c.region() == none
}

fn test_vertical_round_trip() {
	mut c := cue()
	c.set_vertical(.rl)
	assert c.vertical() == .rl
	c.set_vertical(.lr)
	assert c.vertical() == .lr
	c.set_vertical(.empty)
	assert c.vertical() == .empty
}

fn test_computed_line() {
	mut c := cue()
	// Numeric line returns its value.
	c.set_line(line_and_position_number(42))
	assert c.computed_line() == 42.0
	// Numeric out of range with snap-to-lines false clamps to 100.
	c.set_snap_to_lines(false)
	c.set_line(line_and_position_number(150))
	assert c.computed_line() == 100.0
	// Auto line with snap-to-lines false returns 100.
	c.set_line(line_and_position_auto())
	assert c.computed_line() == 100.0
	// A detached cue has no containing track and returns -1.
	c.set_snap_to_lines(true)
	assert c.computed_line() == -1.0
	// When integrated with a media track list, showing tracks before this one
	// determine the negative snap-to-lines position.
	c.set_showing_tracks_before(2)
	assert c.computed_line() == -3.0
}

fn test_computed_position() {
	mut c := cue()
	c.set_position(line_and_position_number(30))
	assert c.computed_position() == 30.0
	// Auto position: left alignment → 0, right → 100, otherwise 50.
	c.set_position(line_and_position_auto())
	c.set_align(.left)
	assert c.computed_position() == 0.0
	c.set_align(.right)
	assert c.computed_position() == 100.0
	c.set_align(.center)
	assert c.computed_position() == 50.0
}

fn test_computed_position_alignment() {
	mut c := cue()
	// A non-auto position alignment is returned directly.
	c.set_position_align(.line_right)
	assert c.computed_position_alignment() == .line_right
	// Auto derives from text alignment.
	c.set_position_align(.auto)
	c.set_align(.left)
	assert c.computed_position_alignment() == .line_left
	c.set_align(.right)
	assert c.computed_position_alignment() == .line_right
	c.set_align(.center)
	assert c.computed_position_alignment() == .center
	c.set_align(.start)
	c.set_text('English')
	assert c.computed_position_alignment() == .line_left
	c.set_text('עברית')
	assert c.computed_position_alignment() == .line_right
	c.set_align(.end)
	assert c.computed_position_alignment() == .line_left
}

fn test_computed_position_alignment_ignores_weak_bidi_characters() {
	mut c := cue()
	c.set_align(.start)
	// Arabic-Indic digits are weak AN characters. They do not establish an
	// RTL base direction, so the following Latin letter is the first strong
	// character.
	c.set_text('١٢ English')
	assert c.computed_position_alignment() == .line_left
	// Whitespace and punctuation are neutral; the Hebrew letter decides RTL.
	c.set_text('... עברית')
	assert c.computed_position_alignment() == .line_right
}

fn test_region_and_text_setters() {
	mut c := cue()
	region := VTTRegion.construct_impl()
	c.set_region(region)
	assert c.region() != none
	c.set_text('updated')
	assert c.text() == 'updated'
}

fn test_remaining_cue_setters_round_trip() {
	mut c := cue()
	c.set_snap_to_lines(false)
	c.set_line(line_and_position_number(12))
	c.set_line_align(.end)
	c.set_position(line_and_position_number(34))
	c.set_position_align(.line_left)
	c.set_size(56)
	c.set_align(.right)
	assert !c.snap_to_lines()
	assert c.line().value == 12
	assert c.line_align() == .end
	assert c.position().value == 34
	assert c.position_align() == .line_left
	assert c.size() == 56
	assert c.align() == .right
}
