// Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/WebVTT/VTTCue.cpp — a WebVTT cue, which extends
// HTML::TextTrackCue (embedded here). Covers construction, the vertical writing-direction
// mapping, and the computed line / position / position-alignment algorithms.
// https://w3c.github.io/webvtt/#vttcue
module webvtt

import html
import math

// https://w3c.github.io/webvtt/#webvtt-cue-writing-direction
pub enum WritingDirection {
	horizontal
	vertical_growing_left
	vertical_growing_right
}

// Bindings::DirectionSetting: "" (horizontal), "rl", "lr".
pub enum DirectionSetting {
	empty
	rl
	lr
}

// Bindings::LineAlignSetting: "start", "center", "end".
pub enum LineAlignSetting {
	start
	center
	end
}

// Bindings::PositionAlignSetting: "line-left", "center", "line-right", "auto".
pub enum PositionAlignSetting {
	line_left
	center
	line_right
	auto
}

// Bindings::AlignSetting: "start", "center", "end", "left", "right".
pub enum AlignSetting {
	start
	center
	end
	left
	right
}

// LineAndPositionSetting = Variant<double, Bindings::AutoKeyword>. AutoKeyword has the single
// value "auto", so the union is modelled as "a number, or auto".
pub struct LineAndPositionSetting {
pub:
	is_auto bool = true
	value   f64
}

pub fn line_and_position_auto() LineAndPositionSetting {
	return LineAndPositionSetting{
		is_auto: true
	}
}

pub fn line_and_position_number(value f64) LineAndPositionSetting {
	return LineAndPositionSetting{
		is_auto: false
		value: value
	}
}

// https://w3c.github.io/webvtt/#vttcue
@[heap]
pub struct VTTCue {
	html.TextTrackCue
mut:
	// https://w3c.github.io/webvtt/#cue-text
	text_ string
	// https://w3c.github.io/webvtt/#webvtt-cue-writing-direction
	writing_direction_ WritingDirection = .horizontal
	// https://w3c.github.io/webvtt/#webvtt-cue-snap-to-lines-flag
	snap_to_lines_ bool = true
	// https://w3c.github.io/webvtt/#webvtt-cue-line
	line_ LineAndPositionSetting = line_and_position_auto()
	// https://w3c.github.io/webvtt/#webvtt-cue-line-alignment
	line_alignment_ LineAlignSetting = .start
	// https://w3c.github.io/webvtt/#webvtt-cue-position
	position_ LineAndPositionSetting = line_and_position_auto()
	// https://w3c.github.io/webvtt/#webvtt-cue-position-alignment
	position_alignment_ PositionAlignSetting = .auto
	// https://w3c.github.io/webvtt/#webvtt-cue-size
	size_ f64 = 100.0
	// https://w3c.github.io/webvtt/#webvtt-cue-text-alignment
	text_alignment_ AlignSetting = .center
	// https://w3c.github.io/webvtt/#webvtt-cue-region
	region_ ?&VTTRegion
	// Number of showing text tracks before this cue's track. HTML's media
	// element owns that list; this optional value is the typed integration
	// point used by the computed-line algorithm.
	showing_tracks_before_ ?u32
}

// https://w3c.github.io/webvtt/#dom-vttcue-vttcue
pub fn VTTCue.construct_impl(start_time f64, end_time f64, text string) !&VTTCue {
	return VTTCue.create(start_time, end_time, text)
}

pub fn VTTCue.create(start_time f64, end_time f64, text string) !&VTTCue {
	// 3. If endTime is negative Infinity or NaN, throw a TypeError.
	if end_time == math.inf(-1) || math.is_nan(end_time) {
		return error('End time is negative infinity or NaN')
	}
	mut new_cue := &VTTCue{}
	// 2. text track cue start time = startTime.
	new_cue.TextTrackCue.set_start_time(start_time)
	// 3. text track cue end time = endTime.
	new_cue.TextTrackCue.set_end_time(end_time)!
	// 4. cue text = text.
	new_cue.text_ = text
	// 5. text track cue identifier = "".
	new_cue.TextTrackCue.set_id('')
	// 6. text track cue pause-on-exit flag = false.
	new_cue.TextTrackCue.set_pause_on_exit(false)
	// 7-15. The remaining WebVTT defaults match the struct field defaults.
	return new_cue
}

// The C++ binding uses this offset to trace the region GC edge. V traces the
// typed optional pointer directly, but exposing the corresponding layout value
// keeps generated binding adapters independent of the struct definition.
pub fn VTTCue.region_offset() uint {
	return uint(__offsetof(VTTCue, region_))
}

// https://w3c.github.io/webvtt/#dom-vttcue-region
pub fn (cue &VTTCue) region() ?&VTTRegion {
	return cue.region_
}

pub fn (mut cue VTTCue) set_region(region ?&VTTRegion) {
	cue.region_ = region
}

// https://w3c.github.io/webvtt/#dom-vttcue-vertical
pub fn (cue &VTTCue) vertical() DirectionSetting {
	return match cue.writing_direction_ {
		.horizontal { DirectionSetting.empty }
		.vertical_growing_left { DirectionSetting.rl }
		.vertical_growing_right { DirectionSetting.lr }
	}
}

pub fn (mut cue VTTCue) set_vertical(vertical DirectionSetting) {
	cue.writing_direction_ = match vertical {
		.empty { WritingDirection.horizontal }
		.rl { WritingDirection.vertical_growing_left }
		.lr { WritingDirection.vertical_growing_right }
	}
}

pub fn (cue &VTTCue) snap_to_lines() bool {
	return cue.snap_to_lines_
}

pub fn (mut cue VTTCue) set_snap_to_lines(snap_to_lines bool) {
	cue.snap_to_lines_ = snap_to_lines
}

pub fn (cue &VTTCue) line() LineAndPositionSetting {
	return cue.line_
}

pub fn (mut cue VTTCue) set_line(line LineAndPositionSetting) {
	cue.line_ = line
}

pub fn (cue &VTTCue) line_align() LineAlignSetting {
	return cue.line_alignment_
}

pub fn (mut cue VTTCue) set_line_align(line_align LineAlignSetting) {
	cue.line_alignment_ = line_align
}

pub fn (cue &VTTCue) position() LineAndPositionSetting {
	return cue.position_
}

pub fn (mut cue VTTCue) set_position(position LineAndPositionSetting) {
	cue.position_ = position
}

pub fn (cue &VTTCue) position_align() PositionAlignSetting {
	return cue.position_alignment_
}

pub fn (mut cue VTTCue) set_position_align(position_align PositionAlignSetting) {
	cue.position_alignment_ = position_align
}

pub fn (cue &VTTCue) size() f64 {
	return cue.size_
}

pub fn (mut cue VTTCue) set_size(size f64) {
	cue.size_ = size
}

pub fn (cue &VTTCue) align() AlignSetting {
	return cue.text_alignment_
}

pub fn (mut cue VTTCue) set_align(align AlignSetting) {
	cue.text_alignment_ = align
}

pub fn (cue &VTTCue) text() string {
	return cue.text_
}

pub fn (mut cue VTTCue) set_text(text string) {
	cue.text_ = text
}

pub fn (mut cue VTTCue) set_showing_tracks_before(count ?u32) {
	cue.showing_tracks_before_ = count
}

// https://w3c.github.io/webvtt/#cue-computed-line
pub fn (cue &VTTCue) computed_line() f64 {
	// 1. If line is numeric, snap-to-lines is false, and line is < 0 or > 100, return 100.
	if !cue.line_.is_auto && !cue.snap_to_lines_ && (cue.line_.value < 0 || cue.line_.value > 100) {
		return 100
	}
	// 2. If line is numeric, return it.
	if !cue.line_.is_auto {
		return cue.line_.value
	}
	// 3. If snap-to-lines is false (line is auto), return 100.
	if !cue.snap_to_lines_ {
		return 100
	}
	// 4-7. The media-element track list supplies the count through the typed
	// integration point. A detached cue has no containing track and returns -1.
	showing_before := cue.showing_tracks_before_ or { return -1 }
	// 8-10. Increment the count, negate it, and return it.
	return -f64(showing_before + 1)
}

// https://w3c.github.io/webvtt/#cue-computed-position
pub fn (cue &VTTCue) computed_position() f64 {
	// 1. If position is numeric between 0 and 100, return it.
	if !cue.position_.is_auto && cue.position_.value >= 0 && cue.position_.value <= 100 {
		return cue.position_.value
	}
	// 2. If text alignment is left, return 0.
	if cue.text_alignment_ == .left {
		return 0
	}
	// 3. If text alignment is right, return 100.
	if cue.text_alignment_ == .right {
		return 100
	}
	// 4. Otherwise, return 50.
	return 50
}

// https://w3c.github.io/webvtt/#cue-computed-position-alignment
pub fn (cue &VTTCue) computed_position_alignment() PositionAlignSetting {
	// 1. If position alignment is not auto, return it.
	if cue.position_alignment_ != .auto {
		return cue.position_alignment_
	}
	// 2. If text alignment is left, return line-left.
	if cue.text_alignment_ == .left {
		return .line_left
	}
	// 3. If text alignment is right, return line-right.
	if cue.text_alignment_ == .right {
		return .line_right
	}
	// 4-5. start/end depend on the base direction of the cue text.
	base_direction := cue_text_base_direction(cue.text_)
	if cue.text_alignment_ == .start {
		return if base_direction == .ltr { .line_left } else { .line_right }
	}
	if cue.text_alignment_ == .end {
		return if base_direction == .ltr { .line_right } else { .line_left }
	}
	// 6. Otherwise, return center.
	return .center
}

enum CueTextDirection {
	ltr
	rtl
}

// WebVTT's base-direction step uses the first strong bidi code point. Unicode
// database lookup is a platform service in upstream; the typed port covers the
// strong Latin/Greek/Cyrillic, Hebrew and Arabic letter ranges and defaults to
// LTR. In particular, weak Arabic-Indic digits must not decide the direction.
fn cue_text_base_direction(text string) CueTextDirection {
	for character in text.runes() {
		code_point := u32(character)
		if (code_point >= 0x05d0 && code_point <= 0x05ea)
			|| (code_point >= 0x05ef && code_point <= 0x05f2)
			|| (code_point >= 0x0620 && code_point <= 0x063f)
			|| (code_point >= 0x0641 && code_point <= 0x064a)
			|| (code_point >= 0x066e && code_point <= 0x066f)
			|| (code_point >= 0x0671 && code_point <= 0x06d3) || code_point == 0x06d5
			|| (code_point >= 0x06e5 && code_point <= 0x06e6)
			|| (code_point >= 0x06ee && code_point <= 0x06ef)
			|| (code_point >= 0x06fa && code_point <= 0x06fc) || code_point == 0x06ff
			|| (code_point >= 0x0750 && code_point <= 0x077f)
			|| (code_point >= 0x08a0 && code_point <= 0x08c9)
			|| (code_point >= 0xfb1d && code_point <= 0xfdff)
			|| (code_point >= 0xfe70 && code_point <= 0xfefc) {
			return .rtl
		}
		if (code_point >= `A` && code_point <= `Z`)
			|| (code_point >= `a` && code_point <= `z`)
			|| (code_point >= 0x00c0 && code_point <= 0x058f) {
			return .ltr
		}
	}
	return .ltr
}
