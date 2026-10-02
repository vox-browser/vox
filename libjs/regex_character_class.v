module libjs

// LibRegex/Rust/src/vm.rs::char_in_ranges. The large-set path preserves Rust
// slice::binary_search_by's base/size search, including its right-biased equal
// comparisons; generated large range arrays are sorted.
pub fn regex_char_in_ranges(code_point u32, ranges []RegexCharRange) bool {
	if ranges.len <= 8 {
		for range in ranges {
			if code_point >= range.start && code_point <= range.end { return true }
		}
		return false
	}
	mut size := ranges.len
	mut base := 0
	for size > 1 {
		half := size / 2
		mid := base + half
		if code_point >= ranges[mid].start { base = mid }
		size -= half
	}
	range := ranges[base]
	return code_point >= range.start && code_point <= range.end
}

pub fn regex_match_char_class(code_point u32, ranges []RegexCharRange, ignore_case bool, unicode_mode bool, unicode_sets bool) bool {
	if ignore_case && unicode_sets {
		mut closure := []u32{len: 16}
		count := regex_get_case_closure(code_point, mut closure)
		for point in closure[..int(count)] {
			if regex_char_in_ranges(point, ranges) { return true }
		}
		return false
	} else if ignore_case {
		if regex_char_in_ranges(code_point, ranges) { return true }
		folded := regex_case_fold(code_point, unicode_mode)
		if folded != code_point && regex_char_in_ranges(folded, ranges) { return true }
		for range in ranges {
			if regex_code_point_matches_range_ignoring_case(code_point, range.start, range.end,
				unicode_mode)
			{
				return true
			}
		}
		return false
	}
	return regex_char_in_ranges(code_point, ranges)
}
