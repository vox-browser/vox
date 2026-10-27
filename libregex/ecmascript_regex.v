// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// Translation of LibRegex/ECMAScriptRegex.{h,cpp}.
module libregex

import libjs

pub enum MatchResult as i8 {
	match_
	no_match
	limit_exceeded
}

pub struct ECMAScriptCompileFlags {
pub:
	global_      bool
	ignore_case  bool
	multiline    bool
	dot_all      bool
	unicode      bool
	unicode_sets bool
	sticky       bool
	has_indices  bool
}

pub struct ECMAScriptNamedCaptureGroup {
pub:
	name  libjs.Utf16String
	index u32
}

pub struct MatchPair {
pub:
	start int
	end   int
}

@[heap]
pub struct ECMAScriptRegex {
mut:
	rust_regex_   &CompiledRustRegex
	named_groups_ []ECMAScriptNamedCaptureGroup
}

pub fn ECMAScriptRegex.compile(pattern libjs.Utf16String, flags ECMAScriptCompileFlags) !&ECMAScriptRegex {
	compiled := CompiledRustRegex.compile(pattern, flags)!
	mut groups := []ECMAScriptNamedCaptureGroup{cap: compiled.named_groups().len}
	for group in compiled.named_groups() {
		groups << ECMAScriptNamedCaptureGroup{ name: group.name, index: group.index }
	}
	return &ECMAScriptRegex{ rust_regex_: compiled, named_groups_: groups }
}

pub fn (mut regex ECMAScriptRegex) destroy() { regex.rust_regex_.destroy() }

pub fn (mut regex ECMAScriptRegex) move_from(mut other ECMAScriptRegex) {
	if voidptr(&regex) == voidptr(&other) { return }
	regex.destroy()
	regex.rust_regex_ = other.rust_regex_
	regex.named_groups_ = other.named_groups_
	other.rust_regex_ = &CompiledRustRegex{}
	other.named_groups_ = []
}

fn match_result(result int) MatchResult {
	if result == 1 { return .match_ }
	if result == -1 { return .limit_exceeded }
	return .no_match
}

pub fn (regex &ECMAScriptRegex) exec(input libjs.Utf16String, start_pos uint) MatchResult {
	return match_result(regex.rust_regex_.exec_internal(input, start_pos))
}

pub fn (regex &ECMAScriptRegex) capture_slot(slot u32) int {
	return regex.rust_regex_.capture_slot(slot)
}

pub fn (regex &ECMAScriptRegex) test(input libjs.Utf16String, start_pos uint) MatchResult {
	return match_result(regex.rust_regex_.test(input, start_pos))
}

pub fn (regex &ECMAScriptRegex) capture_count() u32 { return regex.rust_regex_.capture_count() }

pub fn (regex &ECMAScriptRegex) total_groups() u32 { return regex.rust_regex_.total_groups() }

pub fn (regex &ECMAScriptRegex) is_single_non_bmp_literal() bool {
	return regex.rust_regex_.is_single_non_bmp_literal()
}

pub fn (regex &ECMAScriptRegex) named_groups() []ECMAScriptNamedCaptureGroup {
	return regex.named_groups_
}

pub fn (regex &ECMAScriptRegex) find_all(input libjs.Utf16String, start_pos uint) int {
	return regex.rust_regex_.find_all(input, start_pos)
}

pub fn (regex &ECMAScriptRegex) find_all_match(index int) MatchPair {
	return regex.rust_regex_.find_all_match(index)
}
