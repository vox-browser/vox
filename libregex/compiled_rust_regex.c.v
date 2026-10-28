// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// Translation of LibRegex/RustRegex.{h,cpp}; pinned native Rust is unchanged.
module libregex

import libjs

#flag darwin @DIR/../Build/libregex/darwin/libregex_native.a
#flag linux @DIR/../Build/libregex/linux/libregex_native.a
#flag windows @DIR/../Build/libregex/windows/libregex_native.a
#flag darwin -Wl,-dead_strip
#flag linux -Wl,--gc-sections
#flag linux -ldl -lpthread -lm
#include "@DIR/native_abi.h"

@[typedef]
struct C.RustRegex {}

@[typedef]
struct C.RustRegexFlags {
	global_      bool
	ignore_case  bool
	multiline    bool
	dot_all      bool
	unicode      bool
	unicode_sets bool
	sticky       bool
	has_indices  bool
}

@[typedef]
struct C.RustRegexNamedGroup {
	name     &u8
	name_len uint
	index    u32
}

fn C.rust_regex_compile(&u16, uint, C.RustRegexFlags, &&u8, &uint) &C.RustRegex
fn C.rust_regex_compile_ascii(&u8, uint, C.RustRegexFlags, &&u8, &uint) &C.RustRegex
fn C.rust_regex_free_error(&u8, uint)
fn C.rust_regex_free(&C.RustRegex)
fn C.rust_regex_exec_into(&C.RustRegex, &u16, uint, uint, &int, u32) int
fn C.rust_regex_exec_into_ascii(&C.RustRegex, &u8, uint, uint, &int, u32) int
fn C.rust_regex_test(&C.RustRegex, &u16, uint, uint) int
fn C.rust_regex_test_ascii(&C.RustRegex, &u8, uint, uint) int
fn C.rust_regex_capture_count(&C.RustRegex) u32
fn C.rust_regex_is_single_non_bmp_literal(&C.RustRegex) bool
fn C.rust_regex_find_all(&C.RustRegex, &u16, uint, uint, &int, u32) int
fn C.rust_regex_find_all_ascii(&C.RustRegex, &u8, uint, uint, &int, u32) int
fn C.rust_regex_get_named_groups(&C.RustRegex, &u32) &C.RustRegexNamedGroup
fn C.rust_regex_free_named_groups(&C.RustRegexNamedGroup, u32)

pub struct RustNamedCaptureGroup {
pub:
	name  libjs.Utf16String
	index u32
}

@[heap]
pub struct CompiledRustRegex {
mut:
	regex_                &C.RustRegex = unsafe { nil }
	named_groups_         []RustNamedCaptureGroup
	capture_buffer_       []int
	capture_count_        u32
	capture_count_cached_ bool
	find_all_buffer_      []int
}

fn regex_ascii_bytes(units []u16) []u8 {
	// AK's empty short string still has non-null storage. Preserve that ABI
	// requirement when V's empty array has a null data pointer.
	mut bytes := []u8{len: units.len + 1}
	for index, unit in units { bytes[index] = u8(unit) }
	return bytes
}

pub fn CompiledRustRegex.compile(pattern libjs.Utf16String, flags ECMAScriptCompileFlags) !&CompiledRustRegex {
	mut error_data := &u8(unsafe { nil })
	mut error_length := uint(0)
	mut handle := &C.RustRegex(unsafe { nil })
	units := pattern.code_units()
	actual_flags := C.RustRegexFlags{
		global_:      flags.global_
		ignore_case:  flags.ignore_case
		multiline:    flags.multiline
		dot_all:      flags.dot_all
		unicode:      flags.unicode
		unicode_sets: flags.unicode_sets
		sticky:       flags.sticky
		has_indices:  flags.has_indices
	}
	if pattern.has_ascii_storage() {
		bytes := regex_ascii_bytes(units)
		handle = C.rust_regex_compile_ascii(bytes.data, uint(units.len), actual_flags, &error_data, &error_length)
	} else {
		mut storage := units.clone()
		if storage.len == 0 { storage = [u16(0)] }
		handle = C.rust_regex_compile(storage.data, uint(units.len), actual_flags, &error_data, &error_length)
	}
	if isnil(handle) {
		mut message := 'Invalid pattern'
		if !isnil(error_data) {
			message = unsafe { error_data.vbytes(int(error_length)).bytestr() }
			C.rust_regex_free_error(error_data, error_length)
		}
		return error(message)
	}
	mut compiled := &CompiledRustRegex{ regex_: handle }
	mut group_count := u32(0)
	groups := C.rust_regex_get_named_groups(handle, &group_count)
	if !isnil(groups) {
		compiled.named_groups_.ensure_cap(int(group_count))
		for index in 0 .. int(group_count) {
			group := unsafe { groups[index] }
			name := unsafe { group.name.vbytes(int(group.name_len)).bytestr() }
			compiled.named_groups_ << RustNamedCaptureGroup{ name: libjs.utf16_string(name), index: group.index }
		}
		C.rust_regex_free_named_groups(groups, group_count)
	}
	return compiled
}

pub fn (mut regex CompiledRustRegex) destroy() {
	if !isnil(regex.regex_) { C.rust_regex_free(regex.regex_) }
	regex.regex_ = unsafe { nil }
}

pub fn (mut regex CompiledRustRegex) move_from(mut other CompiledRustRegex) {
	if voidptr(&regex) == voidptr(&other) { return }
	regex.destroy()
	regex.regex_ = other.regex_
	regex.named_groups_ = other.named_groups_
	regex.capture_buffer_ = other.capture_buffer_
	regex.capture_count_ = other.capture_count_
	regex.capture_count_cached_ = other.capture_count_cached_
	regex.find_all_buffer_ = other.find_all_buffer_
	other.regex_ = unsafe { nil }
	other.named_groups_ = []
	other.capture_buffer_ = []
	other.find_all_buffer_ = []
	other.capture_count_ = 0
	other.capture_count_cached_ = false
}

pub fn (regex &CompiledRustRegex) exec_internal(input libjs.Utf16String, start_pos uint) int {
	mut actual := unsafe { regex }
	if !actual.capture_count_cached_ {
		actual.capture_count_ = C.rust_regex_capture_count(actual.regex_) + 1
		actual.capture_count_cached_ = true
	}
	slots := actual.capture_count_ * 2
	if actual.capture_buffer_.len < int(slots) {
		actual.capture_buffer_ << []int{len: int(slots) - actual.capture_buffer_.len}
	} else if actual.capture_buffer_.len > int(slots) {
		actual.capture_buffer_ = actual.capture_buffer_[..int(slots)]
	}
	units := input.code_units()
	if input.has_ascii_storage() {
		bytes := regex_ascii_bytes(units)
		return C.rust_regex_exec_into_ascii(actual.regex_, bytes.data, uint(units.len), start_pos, actual.capture_buffer_.data, slots)
	}
	return C.rust_regex_exec_into(actual.regex_, units.data, uint(units.len), start_pos, actual.capture_buffer_.data, slots)
}

pub fn (regex &CompiledRustRegex) capture_slot(slot u32) int {
	return regex.capture_buffer_[int(slot)]
}

pub fn (regex &CompiledRustRegex) test(input libjs.Utf16String, start_pos uint) int {
	units := input.code_units()
	if input.has_ascii_storage() {
		bytes := regex_ascii_bytes(units)
		return C.rust_regex_test_ascii(regex.regex_, bytes.data, uint(units.len), start_pos)
	}
	return C.rust_regex_test(regex.regex_, units.data, uint(units.len), start_pos)
}

pub fn (regex &CompiledRustRegex) capture_count() u32 {
	return C.rust_regex_capture_count(regex.regex_)
}

pub fn (regex &CompiledRustRegex) total_groups() u32 {
	mut actual := unsafe { regex }
	if !actual.capture_count_cached_ {
		actual.capture_count_ = C.rust_regex_capture_count(actual.regex_) + 1
		actual.capture_count_cached_ = true
	}
	return actual.capture_count_
}

pub fn (regex &CompiledRustRegex) is_single_non_bmp_literal() bool {
	return C.rust_regex_is_single_non_bmp_literal(regex.regex_)
}

pub fn (regex &CompiledRustRegex) named_groups() []RustNamedCaptureGroup {
	return regex.named_groups_
}

pub fn (regex &CompiledRustRegex) find_all(input libjs.Utf16String, start_pos uint) int {
	mut actual := unsafe { regex }
	if actual.find_all_buffer_.len < 256 { actual.find_all_buffer_ = []int{len: 256} }
	units := input.code_units()
	mut result := -1
	for result == -1 {
		if input.has_ascii_storage() {
			bytes := regex_ascii_bytes(units)
			result = C.rust_regex_find_all_ascii(actual.regex_, bytes.data, uint(units.len), start_pos, actual.find_all_buffer_.data, u32(actual.find_all_buffer_.len))
		} else {
			result = C.rust_regex_find_all(actual.regex_, units.data, uint(units.len), start_pos, actual.find_all_buffer_.data, u32(actual.find_all_buffer_.len))
		}
		if result == -1 {
			actual.find_all_buffer_ << []int{len: actual.find_all_buffer_.len}
		}
	}
	return result
}

pub fn (regex &CompiledRustRegex) find_all_match(index int) MatchPair {
	return MatchPair{ start: regex.find_all_buffer_[index * 2], end: regex.find_all_buffer_[index * 2 + 1] }
}
