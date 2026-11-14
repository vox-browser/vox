module libjs

import vunicode

fn regex_set_endpoint(point u32) u32 {
	if point >= 0x80000000 { return 0 }
	return if point > 0x10ffff { u32(0x10ffff) } else { point }
}

pub fn regex_expand_range_case_insensitive(input_start u32, input_end u32) []RegexCharRange {
	start := regex_set_endpoint(input_start)
	end := regex_set_endpoint(input_end)
	if start > end { return []RegexCharRange{} }
	mut result := [RegexCharRange{start, if end > 0x10ffff { u32(0x10ffff) } else { end }}]
	if start == end {
		for p in vunicode.case_closure(start) { result << RegexCharRange{p, p} }
	} else {
		for p in vunicode.case_variants() {
			for peer in vunicode.case_closure(p) {
				if peer >= start && peer <= end {
					result << RegexCharRange{p, p}
					break
				}
			}
		}
	}
	result.sort(a.start < b.start)
	mut merged := []RegexCharRange{}
	for r in result {
		if merged.len > 0 && r.start <= merged.last().end + 1 {
			if r.end > merged.last().end { merged[merged.len - 1].end = r.end }
		} else {
			merged << r
		}
	}
	return merged
}

pub fn regex_get_case_closure(point u32, mut output []u32) uint {
	points := vunicode.case_closure(regex_set_endpoint(regex_canonicalize(point, true)))
	count := if output.len < points.len { output.len } else { points.len }
	for i in 0 .. count { output[i] = points[i] }
	return uint(count)
}

pub fn regex_code_point_matches_range_ignoring_case(point u32, start u32, end u32, unicode_mode bool) bool {
	if point >= start && point <= end { return true }
	canonical := regex_canonicalize(point, unicode_mode)
	bounded_start := regex_set_endpoint(start)
	bounded_end := regex_set_endpoint(end)
	for p in vunicode.case_closure(regex_set_endpoint(point)) {
		if p >= bounded_start && p <= bounded_end && regex_canonicalize(p, unicode_mode) == canonical {
			return true
		}
	}
	return false
}
