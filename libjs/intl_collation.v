// SPDX-License-Identifier: BSD-2-Clause
module libjs

struct IntlCollationSettings {
	sensitivity string = 'variant'
	case_first string = 'false'
	numeric bool
	ignore_punctuation bool
}

struct IntlCollationKey {
mut:
	primary []u32
	secondary []u32
	case_ []u32
	tertiary []u32
	shifted bool
}

fn intl_collation_append(mut key IntlCollationKey, settings IntlCollationSettings, element IntlCollationElement) {
	if settings.ignore_punctuation {
		if element.flags & 1 != 0 && element.primary != 0 { key.shifted = true; return }
		if key.shifted && element.primary == 0 { return }
		if element.primary != 0 { key.shifted = false }
	}
	// Leave gaps between table primaries for the numeric token's unique lead.
	if element.primary != 0 { key.primary << element.primary * 2 }
	if settings.sensitivity in ['accent', 'variant'] && element.secondary != 0 { key.secondary << element.secondary }
	upper := element.flags & 2 != 0
	case_weight := if settings.case_first == 'upper' { if upper { u32(1) } else { u32(3) } } else { if upper { u32(3) } else { u32(1) } }
	if settings.sensitivity == 'case' && element.primary != 0 { key.case_ << case_weight }
	if settings.sensitivity == 'variant' && element.tertiary != 0 {
		prefix := if element.primary == 0 && element.secondary == 0 { u32(3) } else { case_weight }
		key.tertiary << if settings.case_first == 'false' { element.tertiary } else { (prefix << 16) | element.tertiary }
	}
}

fn intl_collation_key(mut vm VM, text Utf16String, settings IntlCollationSettings) !IntlCollationKey {
	data := intl_collation_data(mut vm)!
	mut points := intl_collation_normalize(mut vm, text)!
	mut key := IntlCollationKey{}
	mut cursor := 0
	for cursor < points.len {
		vm.consume_execution_budget()!
		if settings.numeric && intl_collation_digit(points[cursor]) != none {
			mut digits := []u32{}
			for cursor < points.len {
				digit := intl_collation_digit(points[cursor]) or { break }
				vm.consume_execution_budget()!; digits << digit; cursor++
			}
			mut start := 0
			for start + 1 < digits.len && digits[start] == 0 { start++ }
			zero_node := data.child(0, `0`) or { return vm.throw_error(.internal_error, 'Missing collation numeric lead') }
			zero := data.element(int(data.node_word(zero_node, 3)))
			// Unique numeric lead, significant length, then digits. No binary64
			// conversion or length cap: long runs and cross-script Nd stay exact.
			key.primary << zero.primary * 2 - 1
			key.primary << u32(digits.len - start)
			for digit in digits[start..] { key.primary << digit + 1 }
			key.primary << u32(0)
			key.shifted = false
			if settings.sensitivity in ['accent', 'variant'] { key.secondary << u32(0x20) }
			if settings.sensitivity == 'case' { key.case_ << if settings.case_first == 'upper' { u32(3) } else { u32(1) } }
			if settings.sensitivity == 'variant' { key.tertiary << if settings.case_first == 'false' { u32(2) } else { (if settings.case_first == 'upper' { u32(3) } else { u32(1) }) << 16 | 2 } }
			continue
		}
		node, end := intl_collation_match(mut vm, data, mut points, cursor)!
		if node < 0 {
			for element in intl_collation_implicit(points[cursor]) { intl_collation_append(mut key, settings, element) }
		} else {
			first := int(data.node_word(node, 3)); count := int(data.node_word(node, 4))
			for index in first .. first + count { vm.consume_execution_budget()!; intl_collation_append(mut key, settings, data.element(index)) }
		}
		cursor = end
	}
	return key
}

fn intl_collation_compare_level(mut vm VM, left []u32, right []u32) !int {
	mut index := 0
	for index < left.len && index < right.len {
		if index % 128 == 0 { vm.consume_execution_budget()! }
		if left[index] != right[index] { return if left[index] < right[index] { -1 } else { 1 } }
		index++
	}
	return if left.len == right.len { 0 } else if left.len < right.len { -1 } else { 1 }
}

fn intl_collation_compare(mut vm VM, left Utf16String, right Utf16String, settings IntlCollationSettings) !int {
	if left == right { return 0 }
	a := intl_collation_key(mut vm, left, settings)!
	b := intl_collation_key(mut vm, right, settings)!
	for pair in [[a.primary, b.primary], [a.secondary, b.secondary], [a.case_, b.case_], [a.tertiary, b.tertiary]] {
		result := intl_collation_compare_level(mut vm, pair[0], pair[1])!
		if result != 0 { return result }
	}
	return 0
}
