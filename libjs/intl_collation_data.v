// SPDX-License-Identifier: BSD-2-Clause
module libjs

import vunicode

const intl_collation_root_blob = $embed_file('@VMODROOT/libjs/intl_collation_data/root.dat').to_string()
const intl_collation_digits_blob = $embed_file('@VMODROOT/libjs/intl_collation_data/digits.dat').to_string()
const intl_collation_implicit_blob = $embed_file('@VMODROOT/libjs/intl_collation_data/implicit.dat').to_string()

struct IntlCollationData { nodes int; elements int; element_offset int }
struct IntlCollationElement { primary u32; secondary u32; tertiary u32; flags u32 }

// Immutable little-endian tables. The trie has sorted contiguous sibling
// spans, followed by shared collation-element expansions; no per-VM decode.
fn intl_collation_word(data string, offset int) u32 {
	return u32(data[offset]) | (u32(data[offset + 1]) << 8) | (u32(data[offset + 2]) << 16) | (u32(data[offset + 3]) << 24)
}

fn intl_collation_data(mut vm VM) !IntlCollationData {
	if intl_collation_root_blob.len < 16 || intl_collation_root_blob[..8] != 'VCOLL01\x00' { return vm.throw_error(.internal_error, 'Invalid embedded collation header') }
	nodes := int(intl_collation_word(intl_collation_root_blob, 8))
	elements := int(intl_collation_word(intl_collation_root_blob, 12))
	if nodes < 1 || 16 + nodes * 20 + elements * 16 != intl_collation_root_blob.len
		|| intl_collation_digits_blob.len % 8 != 0 || intl_collation_implicit_blob.len % 16 != 0 { return vm.throw_error(.internal_error, 'Invalid embedded collation spans') }
	return IntlCollationData{nodes: nodes, elements: elements, element_offset: 16 + nodes * 20}
}

fn (data IntlCollationData) node_word(node int, field int) u32 { return intl_collation_word(intl_collation_root_blob, 16 + node * 20 + field * 4) }

fn (data IntlCollationData) child(node int, point u32) ?int {
	start := int(data.node_word(node, 1))
	mut low := start
	mut high := start + int(data.node_word(node, 2))
	for low < high {
		middle := low + (high - low) / 2
		candidate := data.node_word(middle, 0)
		if point < candidate { high = middle } else if point > candidate { low = middle + 1 } else { return middle }
	}
	return none
}

fn (data IntlCollationData) element(index int) IntlCollationElement {
	offset := data.element_offset + index * 16
	return IntlCollationElement{primary: intl_collation_word(intl_collation_root_blob, offset), secondary: intl_collation_word(intl_collation_root_blob, offset + 4), tertiary: intl_collation_word(intl_collation_root_blob, offset + 8), flags: intl_collation_word(intl_collation_root_blob, offset + 12)}
}

fn intl_collation_digit(point u32) ?u32 {
	mut low := 0; mut high := intl_collation_digits_blob.len / 8
	for low < high {
		middle := low + (high - low) / 2
		candidate := intl_collation_word(intl_collation_digits_blob, middle * 8)
		if point < candidate { high = middle } else if point > candidate { low = middle + 1 }
		else { return intl_collation_word(intl_collation_digits_blob, middle * 8 + 4) }
	}
	return none
}

// UTS #10 §10.1.3: assigned siniform scripts, core/extension Han, and
// unassigned/private-use/surrogate code points get distinct implicit ranges.
// Lone surrogates retain their identity, an explicitly permitted UCA policy.
fn intl_collation_implicit(point u32) []IntlCollationElement {
	hani := vunicode.property_named(point, 'Unified_Ideograph')
	mut primary := u32(0xfbc0) + (point >> 15)
	mut trail := (point & 0x7fff) | 0x8000
	if hani { primary = 0xfb80 + (point >> 15) }
	for offset := 0; offset < intl_collation_implicit_blob.len; offset += 16 {
		start := intl_collation_word(intl_collation_implicit_blob, offset)
		end := intl_collation_word(intl_collation_implicit_blob, offset + 4)
		if point < start || point > end { continue }
		base := intl_collation_word(intl_collation_implicit_blob, offset + 8)
		if base == 0xfb40 {
			if hani { primary = base + (point >> 15) }
		} else if vunicode.category(point) != 0 {
			primary = base; trail = (point - intl_collation_word(intl_collation_implicit_blob, offset + 12)) | 0x8000
		}
		break
	}
	return [IntlCollationElement{primary: primary, secondary: 0x20, tertiary: 2}, IntlCollationElement{primary: trail}]
}
