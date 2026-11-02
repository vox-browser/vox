module css

import os

const retain_selector_substring_scan = os.getenv('VOX_RETAIN_SELECTOR_SUBSTRING_SCAN') != ''
const selector_substring_scan_diagnostics = os.getenv('VOX_SELECTOR_SUBSTRING_SCAN_DIAGNOSTICS') != ''

__global selector_substring_boundary_reported bool

@[inline]
fn selector_substring_fold_byte(value u8) u8 {
	return if value >= `A` && value <= `Z` { value + u8(32) } else { value }
}

// The caller has checked 0 < needle.len <= min(32, haystack.len). Reject a
// window by its boundary bytes before comparing its interior. Pointer reads
// stay inside that window, including for borrowed, non-NUL-terminated slices.
fn selector_short_substring_contains(haystack string, needle string, case_sensitivity SelectorCaseSensitivity) bool {
	if selector_substring_scan_diagnostics && !selector_substring_boundary_reported {
		selector_substring_boundary_reported = true
		eprintln('Vox selector substring: selected bounded boundary scan')
	}
	last := needle.len - 1
	if case_sensitivity == .case_sensitive {
		first_byte := needle[0]
		last_byte := needle[last]
		for offset in 0 .. haystack.len - needle.len + 1 {
			if unsafe { haystack.str[offset] != first_byte || haystack.str[offset + last] != last_byte } {
				continue
			}
			if last < 2 || unsafe { haystack.substr_unsafe(offset + 1, offset + last) == needle.substr_unsafe(1, last) } {
				return true
			}
		}
	} else {
		first_byte := selector_substring_fold_byte(needle[0])
		last_byte := selector_substring_fold_byte(needle[last])
		for offset in 0 .. haystack.len - needle.len + 1 {
			if unsafe { selector_substring_fold_byte(haystack.str[offset]) != first_byte
				|| selector_substring_fold_byte(haystack.str[offset + last]) != last_byte } {
				continue
			}
			mut matches := true
			for i in 1 .. last {
				if unsafe { selector_substring_fold_byte(haystack.str[offset + i]) != selector_substring_fold_byte(needle.str[i]) } {
					matches = false
					break
				}
			}
			if matches { return true }
		}
	}
	return false
}
