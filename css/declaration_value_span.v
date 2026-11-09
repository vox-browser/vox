module css

import os

const disable_borrowed_declaration_value_scan = os.getenv('VOX_DISABLE_BORROWED_DECLARATION_VALUE_SCAN') != ''
const borrowed_declaration_value_scan_diagnostics = os.getenv('VOX_BORROWED_DECLARATION_VALUE_SCAN_DIAGNOSTICS') != ''
__global borrowed_declaration_value_scan_reported bool

// The stream already contains complete immutable component values. Nested
// blocks/functions cannot terminate a declaration. Inspect each top-level token
// once, without copying the stream and component headers for every predicate.
fn declaration_value_span_end(input &ParserTokenStream, nested ParserNested) int {
	mut end := input.index
	if end < 0 { return end }
	for end < input.values.len {
		component := unsafe { &input.values[end] }
		if component.value is &Token {
			type_ := component.value.type_
			if type_ in [.end_of_file, .semicolon]
				|| (nested == .yes && type_ == .close_curly) { break }
		}
		end++
	}
	if borrowed_declaration_value_scan_diagnostics && !borrowed_declaration_value_scan_reported {
		borrowed_declaration_value_scan_reported = true
		eprintln('Vox CSS declaration: scanned borrowed component span without repeated lookahead copies')
	}
	return end
}
