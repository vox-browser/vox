// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import os

const disable_classic_import_call_scan = os.getenv('VOX_DISABLE_CLASSIC_IMPORT_CALL_SCAN') != ''
const classic_import_call_diagnostics = os.getenv('VOX_CLASSIC_IMPORT_CALL_DIAGNOSTICS') != ''

__global classic_import_call_skip_reported bool

// A classic script can need URL rewriting only for ImportCall. Keep a dot
// (import.meta / future import phases), non-ASCII whitespace and Annex B HTML
// comment candidates on the trusted lexer path too. This byte filter does not
// classify strings, regular expressions or preceding tokens: false positives
// still use the lexer. Invalid static imports remain unchanged for JSC's
// classic-script parser to reject; module scripts never use this filter.
fn classic_import_tail_may_need_rewrite(source string, after_word int) bool {
	mut offset := after_word
	for offset < source.len {
		value := source[offset]
		if value in [` `, `\t`, `\n`, `\r`, `\v`, `\f`] {
			offset++
			continue
		}
		if value >= 0x80 { return true }
		if value == `/` && offset + 1 < source.len {
			if source[offset + 1] == `*` {
				end := source.index_after('*/', offset + 2) or { return true }
				offset = end + 2
				continue
			}
			if source[offset + 1] == `/` {
				offset += 2
				for offset < source.len && source[offset] !in [`\n`, `\r`] {
					// U+2028/U+2029 also end a line comment. Leave every
					// non-ASCII byte to the lexer rather than skipping it.
					if source[offset] >= 0x80 { return true }
					offset++
				}
				continue
			}
		}
		return value in [`(`, `.`, `<`, `-`]
	}
	return false
}

fn classic_source_may_need_import_rewrite(source string) bool {
	mut offset := 0
	for offset < source.len {
		start := source.index_after('import', offset) or { return false }
		end := start + 6
		if (start == 0 || !ascii_import_identifier_byte(source[start - 1]))
			&& (end == source.len || !ascii_import_identifier_byte(source[end]))
			&& classic_import_tail_may_need_rewrite(source, end) {
			return true
		}
		offset = end
	}
	return false
}

fn classic_import_call_scan_can_skip(source string) bool {
	if disable_classic_import_call_scan { return false }
	if classic_source_may_need_import_rewrite(source) {
		return classic_named_import_scan_can_skip(source)
	}
	if classic_import_call_diagnostics && !classic_import_call_skip_reported {
		classic_import_call_skip_reported = true
		eprintln('Vox module rewrite: skipped import text without a call or meta candidate')
	}
	return true
}
