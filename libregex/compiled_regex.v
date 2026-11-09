// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// V owner for the translated parser, compiler and matcher in libjs.
module libregex

import libjs

pub struct NamedCaptureGroup {
pub:
	name  libjs.Utf16String
	index u32
}

@[heap]
pub struct CompiledRegex {
mut:
	engine_          &libjs.RegexEngine = unsafe { nil }
	named_groups_    []NamedCaptureGroup
	capture_buffer_  []i32
	find_all_buffer_ []i32
}

fn regex_source_characters(pattern libjs.Utf16String) []rune {
	units := pattern.code_units()
	mut points := []rune{cap: units.len}
	for index := 0; index < units.len; index++ {
		unit := units[index]
		if unit >= 0xd800 && unit <= 0xdbff && index + 1 < units.len
			&& units[index + 1] >= 0xdc00 && units[index + 1] <= 0xdfff {
			points << rune(0x10000 + ((u32(unit) - 0xd800) << 10) + u32(units[index + 1]) - 0xdc00)
			index++
		} else if unit >= 0xd800 && unit <= 0xdfff {
			points << rune(0xfffd)
		} else {
			points << rune(unit)
		}
	}
	return points
}

fn regex_input(text libjs.Utf16String) libjs.RegexInput {
	units := text.code_units()
	if text.has_ascii_storage() { return libjs.RegexAsciiInput{ bytes: units.map(u8(it)) } }
	return libjs.RegexUtf16Input{ units: units }
}

pub fn CompiledRegex.compile(pattern libjs.Utf16String, flags ECMAScriptCompileFlags) !&CompiledRegex {
	engine := libjs.RegexEngine.compile(regex_source_characters(pattern), libjs.RegexAstFlags{
		global:       flags.global_
		ignore_case:  flags.ignore_case
		multiline:    flags.multiline
		dot_all:      flags.dot_all
		unicode:      flags.unicode
		unicode_sets: flags.unicode_sets
		sticky:       flags.sticky
		has_indices:  flags.has_indices
	})!
	mut groups := []NamedCaptureGroup{cap: engine.program.named_groups.len}
	for group in engine.program.named_groups {
		groups << NamedCaptureGroup{ name: libjs.utf16_string(group.name), index: group.index }
	}
	return &CompiledRegex{ engine_: engine, named_groups_: groups }
}

pub fn (mut regex CompiledRegex) destroy() {
	// All state belongs to V's collector or the caller's allocation arena.
	// Detach the owner so moved/destroyed wrappers cannot execute stale state.
	regex.engine_ = unsafe { nil }
	regex.named_groups_ = []
	regex.capture_buffer_ = []
	regex.find_all_buffer_ = []
}

pub fn (mut regex CompiledRegex) move_from(mut other CompiledRegex) {
	if voidptr(&regex) == voidptr(&other) { return }
	regex.destroy()
	regex.engine_ = other.engine_
	regex.named_groups_ = other.named_groups_
	regex.capture_buffer_ = other.capture_buffer_
	regex.find_all_buffer_ = other.find_all_buffer_
	other.engine_ = unsafe { nil }
	other.named_groups_ = []
	other.capture_buffer_ = []
	other.find_all_buffer_ = []
}

fn compiled_match_result(result libjs.RegexVmResult) int {
	return match result {
		.match { 1 }
		.no_match { 0 }
		.limit_exceeded { -1 }
	}
}

pub fn (regex &CompiledRegex) exec_internal(input libjs.Utf16String, start_pos uint) int {
	if isnil(regex.engine_) { return 0 }
	mut actual := unsafe { regex }
	slots := int(regex.total_groups()) * 2
	if actual.capture_buffer_.len < slots {
		actual.capture_buffer_ << []i32{len: slots - actual.capture_buffer_.len}
	} else if actual.capture_buffer_.len > slots {
		actual.capture_buffer_.trim(slots)
	}
	return compiled_match_result(actual.engine_.exec(regex_input(input), start_pos, mut actual.capture_buffer_))
}

pub fn (regex &CompiledRegex) capture_slot(slot u32) int {
	return int(regex.capture_buffer_[int(slot)])
}

pub fn (regex &CompiledRegex) test(input libjs.Utf16String, start_pos uint) int {
	if isnil(regex.engine_) { return 0 }
	mut actual := unsafe { regex }
	return compiled_match_result(actual.engine_.test(regex_input(input), start_pos))
}

pub fn (regex &CompiledRegex) capture_count() u32 {
	return if isnil(regex.engine_) { 0 } else { regex.engine_.program.capture_count }
}

pub fn (regex &CompiledRegex) total_groups() u32 { return regex.capture_count() + 1 }

pub fn (regex &CompiledRegex) is_single_non_bmp_literal() bool {
	return !isnil(regex.engine_) && regex.engine_.is_single_non_bmp_literal()
}

pub fn (regex &CompiledRegex) named_groups() []NamedCaptureGroup { return regex.named_groups_ }

pub fn (regex &CompiledRegex) find_all(input libjs.Utf16String, start_pos uint) int {
	if isnil(regex.engine_) { return 0 }
	mut actual := unsafe { regex }
	if actual.find_all_buffer_.len < 256 { actual.find_all_buffer_ = []i32{len: 256} }
	view := regex_input(input)
	for {
		result := actual.engine_.find_all(view, start_pos, mut actual.find_all_buffer_)
		if result != -1 { return int(result) }
		actual.find_all_buffer_ << []i32{len: actual.find_all_buffer_.len}
	}
	return 0
}

pub fn (regex &CompiledRegex) find_all_match(index int) MatchPair {
	return MatchPair{ start: int(regex.find_all_buffer_[index * 2]), end: int(regex.find_all_buffer_[index * 2 + 1]) }
}
