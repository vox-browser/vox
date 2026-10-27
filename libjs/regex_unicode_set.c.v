module libjs

#flag -I @DIR
#flag darwin -licucore
#flag linux -licuuc
#include "regex_unicode_set.h"

@[typedef]
struct C.USet {}

fn C.uset_open(start int, end int) &C.USet
fn C.uset_close(set &C.USet)
fn C.uset_closeOver(set &C.USet, attributes int)
fn C.uset_retain(set &C.USet, start int, end int)
fn C.uset_isEmpty(set &C.USet) i8
fn C.uset_getRangeCount(set &C.USet) int
fn C.uset_getItem(set &C.USet, index int, start &int, end &int, output &u16, capacity int, status &int) int

fn regex_unicode_set_range(set &C.USet, index int) RegexCharRange {
	mut start := 0
	mut end := 0
	mut status := 0
	length := C.uset_getItem(set, index, &start, &end, unsafe { nil }, 0, &status)
	// Only range indices are requested, never UnicodeSet's string items.
	assert status <= 0 && length == 0
	return RegexCharRange{
		start: u32(start)
		end:   u32(end)
	}
}

// LibUnicode/CharacterTypes.cpp::expand_range_case_insensitive.
pub fn regex_expand_range_case_insensitive(start u32, end u32) []RegexCharRange {
	set := C.uset_open(int(start), int(end))
	if unsafe { set == nil } { panic('ICU UnicodeSet allocation failed') }
	defer { C.uset_close(set) }
	C.uset_closeOver(set, C.USET_CASE_INSENSITIVE)
	count := C.uset_getRangeCount(set)
	mut result := []RegexCharRange{cap: count}
	for index in 0 .. count {
		result << regex_unicode_set_range(set, index)
	}
	return result
}

// LibUnicode's for_each_case_folded_code_point and unicode_get_case_closure,
// followed by the Rust get_case_closure wrapper's output-length boundary.
pub fn regex_get_case_closure(code_point u32, mut output []u32) uint {
	canonical := regex_canonicalize(code_point, true)
	set := C.uset_open(int(canonical), int(canonical))
	if unsafe { set == nil } { panic('ICU UnicodeSet allocation failed') }
	defer { C.uset_close(set) }
	C.uset_closeOver(set, C.USET_CASE_INSENSITIVE)
	mut written := 0
	for index in 0 .. C.uset_getRangeCount(set) {
		range := regex_unicode_set_range(set, index)
		for point := range.start; point <= range.end; point++ {
			if written < output.len {
				output[written] = point
				written++
			} else {
				return uint(written)
			}
		}
	}
	return uint(written)
}

pub fn regex_code_point_matches_range_ignoring_case(code_point u32, start u32, end u32, unicode_mode bool) bool {
	if code_point >= start && code_point <= end { return true }
	set := C.uset_open(int(code_point), int(code_point))
	if unsafe { set == nil } { panic('ICU UnicodeSet allocation failed') }
	defer { C.uset_close(set) }
	C.uset_closeOver(set, C.USET_CASE_INSENSITIVE)
	C.uset_retain(set, int(start), int(end))
	if C.uset_isEmpty(set) != 0 { return false }
	canonical := regex_canonicalize(code_point, unicode_mode)
	for index in 0 .. C.uset_getRangeCount(set) {
		range := regex_unicode_set_range(set, index)
		for point := range.start; point <= range.end; point++ {
			if regex_canonicalize(point, unicode_mode) == canonical { return true }
		}
	}
	return false
}
