// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import os

const disable_classic_import_named_method_scan = os.getenv('VOX_DISABLE_CLASSIC_IMPORT_NAMED_METHOD_SCAN') != ''
const classic_import_named_method_diagnostics = os.getenv('VOX_CLASSIC_IMPORT_NAMED_METHOD_DIAGNOSTICS') != ''

__global classic_import_named_method_skip_reported bool

fn ascii_import_parameter_start(value u8) bool {
	return (value >= `a` && value <= `z`) || (value >= `A` && value <= `Z`)
		|| value in [`_`, `$`]
}

// A single adjacent dot denotes a property name, not the import keyword.
// Keep ellipsis/spread candidates, including ...import(specifier).
fn classic_import_word_is_property(source string, start int) bool {
	return start > 0 && source[start - 1] == `.`
		&& (start < 2 || source[start - 2] != `.`)
}

// Recognize only the tightly delimited minified member spelling
// }import(identifier){. The leading } rules out a class heritage expression
// (class C extends import(identifier) {}), and the adjacent ){ rules out ASI
// before a following block. Without that exact context, keep the trusted lexer.
// No strings, regex literals, comments or general parameter lists are parsed.
fn classic_import_word_is_minified_method(source string, start int, end int) bool {
	if start == 0 || source[start - 1] != `}` || end + 3 >= source.len
		|| source[end] != `(` || !ascii_import_parameter_start(source[end + 1]) {
		return false
	}
	mut offset := end + 2
	for offset < source.len && ascii_import_identifier_byte(source[offset]) { offset++ }
	return offset + 1 < source.len && source[offset] == `)` && source[offset + 1] == `{`
}

fn classic_source_has_only_named_import_candidates(source string) bool {
	mut offset := 0
	mut skipped := false
	for offset < source.len {
		start := source.index_after('import', offset) or { return skipped }
		end := start + 6
		if (start == 0 || !ascii_import_identifier_byte(source[start - 1]))
			&& (end == source.len || !ascii_import_identifier_byte(source[end]))
			&& classic_import_tail_may_need_rewrite(source, end) {
			if !classic_import_word_is_property(source, start)
				&& !classic_import_word_is_minified_method(source, start, end) {
				return false
			}
			skipped = true
		}
		offset = end
	}
	return skipped
}

fn classic_named_import_scan_can_skip(source string) bool {
	if disable_classic_import_named_method_scan
		|| !classic_source_has_only_named_import_candidates(source) { return false }
	if classic_import_named_method_diagnostics && !classic_import_named_method_skip_reported {
		classic_import_named_method_skip_reported = true
		eprintln('Vox module rewrite: skipped named import members without an import expression')
	}
	return true
}
