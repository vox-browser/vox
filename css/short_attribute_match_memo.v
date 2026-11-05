module css

import dom
import os
import platform

const retain_short_attribute_matching = os.getenv('VOX_RETAIN_SHORT_ATTRIBUTE_MATCHING') != ''
const short_attribute_match_diagnostics = os.getenv('VOX_SHORT_ATTRIBUTE_MATCH_DIAGNOSTICS') != ''
__global short_attribute_match_reported bool

struct ShortAttributeMatchSlot {
mut:
	valid bool
	value_length int
	pattern_length int
	case_sensitivity SelectorCaseSensitivity
	result bool
	value [256]u8
	pattern [32]u8
}

// Fixed storage owns both inputs without retaining DOM owners, CSS string
// pointers or a producer's scratch bytes. Overwrites never allocate strings.
@[heap]
struct ShortAttributeMatchMemo {
mut:
	slots [256]ShortAttributeMatchSlot
	hits u64
}

fn (computer &StyleComputer) short_attribute_match_memo() &ShortAttributeMatchMemo {
	mut owner := unsafe { &StyleComputer(computer) }
	if owner.short_attribute_matches_ == unsafe { nil } {
		mut retained := platform.enter_retained_allocations()
		owner.short_attribute_matches_ = &ShortAttributeMatchMemo{}
		retained.finish()
	}
	return owner.short_attribute_matches_
}

// Only select a slot with this fingerprint. Every hit compares all bytes too,
// so collisions, new strings and reused addresses cannot change the answer.
// The caller has checked value.len >= 16 and 0 < pattern.len <= 32.
fn short_attribute_match_slot(value string, pattern string, sensitivity SelectorCaseSensitivity) int {
	mut first := u64(0)
	mut last := u64(0)
	unsafe {
		C.memcpy(&first, value.str, 8)
		C.memcpy(&last, value.str + value.len - 8, 8)
	}
	pattern_bits := u64(pattern[0]) | (u64(pattern[pattern.len - 1]) << 8)
		| (u64(pattern.len) << 16) | (u64(sensitivity) << 24)
	mixed := first ^ (last << 17) ^ (last >> 47) ^ (pattern_bits * u64(0x9e3779b1))
		^ (u64(value.len) * u64(0x85ebca77))
	return int((mixed ^ (mixed >> 16) ^ (mixed >> 32)) & 255)
}

fn (mut memo ShortAttributeMatchMemo) contains(value string, pattern string,
	sensitivity SelectorCaseSensitivity) bool {
	index := short_attribute_match_slot(value, pattern, sensitivity)
	mut slot := unsafe { &memo.slots[index] }
	if slot.valid && slot.value_length == value.len && slot.pattern_length == pattern.len
		&& slot.case_sensitivity == sensitivity
		&& unsafe { C.memcmp(&slot.pattern[0], pattern.str, pattern.len) == 0
			&& C.memcmp(&slot.value[0], value.str, value.len) == 0 } {
		memo.hits++
		if short_attribute_match_diagnostics && !short_attribute_match_reported {
			short_attribute_match_reported = true
			eprintln('Vox attribute substring memo: reused an exact bounded byte comparison')
		}
		return slot.result
	}
	result := selector_string_contains(value, pattern, sensitivity)
	slot.value_length = value.len
	slot.pattern_length = pattern.len
	slot.case_sensitivity = sensitivity
	slot.result = result
	unsafe {
		C.memcpy(&slot.value[0], value.str, value.len)
		C.memcpy(&slot.pattern[0], pattern.str, pattern.len)
	}
	slot.valid = true
	return result
}

fn matches_single_attribute_with_memo(selector SelectorAttribute, attribute &dom.Attr_,
	sensitivity SelectorCaseSensitivity, owner &StyleComputer) bool {
	if !retain_short_attribute_matching && owner != unsafe { nil }
		&& selector.match_type == .contains_string && selector.value.len > 0
		&& selector.value.len <= 32 {
		value := attribute.value()
		if value.len >= 16 && value.len <= 256 && value.len >= selector.value.len {
			mut memo := owner.short_attribute_match_memo()
			return memo.contains(value, selector.value, sensitivity)
		}
	}
	return matches_single_attribute(selector, attribute, sensitivity)
}
