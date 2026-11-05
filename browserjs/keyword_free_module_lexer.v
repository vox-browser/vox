// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import os

const disable_keyword_free_module_lexer = os.getenv('VOX_DISABLE_KEYWORD_FREE_MODULE_LEXER') != ''
const keyword_free_module_diagnostics = os.getenv('VOX_KEYWORD_FREE_MODULE_DIAGNOSTICS') != ''

__global keyword_free_module_skip_reported bool

// ImportCall, import.meta and every static import/re-export contain an import
// or export keyword. Identifier substrings cannot be those keywords; Unicode
// boundaries, strings and comments stay conservative candidates. Preserve the
// original lexer handling for hashbang/HTML-comment/NUL spellings as well.
fn module_source_may_need_specifier_lexer(source string) bool {
	if source.contains('#!') || source.contains('<!--') || source.contains('-->')
		|| source.contains('\x00') { return true }
	for keyword in ['import', 'export'] {
		mut offset := 0
		for offset < source.len {
			start := source.index_after(keyword, offset) or { break }
			end := start + keyword.len
			if (start == 0 || !ascii_import_identifier_byte(source[start - 1]))
				&& (end == source.len || !ascii_import_identifier_byte(source[end])) {
				return true
			}
			offset = end
		}
	}
	return false
}

fn report_keyword_free_module_lexer_skip() {
	if keyword_free_module_diagnostics && !keyword_free_module_skip_reported {
		keyword_free_module_skip_reported = true
		eprintln('Vox module rewrite: skipped keyword-free module lexer after native syntax check')
	}
}
