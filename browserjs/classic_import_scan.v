// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import os

const disable_classic_import_word_scan = os.getenv('VOX_DISABLE_CLASSIC_IMPORT_WORD_SCAN') != ''
const classic_import_word_diagnostics = os.getenv('VOX_CLASSIC_IMPORT_WORD_DIAGNOSTICS') != ''

__global classic_import_word_skip_reported bool

fn ascii_import_identifier_byte(value u8) bool {
	return (value >= `a` && value <= `z`) || (value >= `A` && value <= `Z`)
		|| (value >= `0` && value <= `9`) || value == `_` || value == `$`
}

// A real import token cannot adjoin an ASCII identifier character. Keep all
// other boundaries, including Unicode and escapes, on the trusted lexer path.
// This is only a rejection filter; strings and comments can remain candidates.
fn classic_source_may_have_import_word(source string) bool {
	mut offset := 0
	for offset < source.len {
		start := source.index_after('import', offset) or { return false }
		end := start + 6
		if (start == 0 || !ascii_import_identifier_byte(source[start - 1]))
			&& (end == source.len || !ascii_import_identifier_byte(source[end])) {
			return true
		}
		offset = end
	}
	return false
}

fn classic_source_can_skip_import_lexer(source string) bool {
	if disable_classic_import_word_scan || classic_source_may_have_import_word(source) { return false }
	if classic_import_word_diagnostics && !classic_import_word_skip_reported {
		classic_import_word_skip_reported = true
		eprintln('Vox module rewrite: skipped identifier-only import text')
	}
	return true
}
