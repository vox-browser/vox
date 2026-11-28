module css

import os

const disable_direct_selector_prelude = os.getenv('VOX_DISABLE_DIRECT_SELECTOR_PRELUDE') != ''

// Measures, then fills, one selector's serialized source.
struct SelectorPreludeOutput {
mut:
	counting bool = true
	length   int
	bytes    []u8
}

fn (mut output SelectorPreludeOutput) put(text string) {
	if output.counting {
		output.length += text.len
		return
	}
	if text.len == 0 { return }
	unsafe { C.memcpy(&output.bytes[output.length], text.str, uint(text.len)) }
	output.length += text.len
}

// Whitespace and end-of-file tokens at either end of the span contribute
// nothing to the trimmed source.
fn selector_prelude_trimmed(component &ComponentValue) bool {
	return component.value is &Token
		&& component.value.type_ in [TokenType.whitespace, .end_of_file]
}

// A quoted string that needs no escape serializes as its value in quotes.
fn selector_prelude_string_verbatim(value string) bool {
	for byte in value {
		if byte < 0x20 || byte >= 0x7f || byte == `"` || byte == `\\` { return false }
	}
	return true
}

// An identifier spelled in the source without an escape holds only name code
// points (letters, digits, `-`, `_` and non-ASCII), cannot start with a digit
// or `-` and a digit, and serialize_an_identifier() returns it unchanged. Its
// decoded value then equals its spelling between the token's fixed prefix and
// suffix. Other names keep the code-point check.
fn selector_prelude_name_verbatim(value string, source string, prefix int, suffix int) bool {
	if source.len == prefix + value.len + suffix
		&& unsafe { C.memcmp(source.str + prefix, value.str, uint(value.len)) } == 0
		&& unsafe { C.memchr(source.str, i32(`\\`), uint(source.len)) } == unsafe { nil } {
		return true
	}
	return identifier_serializes_verbatim(value)
}

// Each accepted token serializes, exactly as parser_selector_prelude_to_string
// does, as text it already owns or a constant. Anything else (an escaped
// identifier that needs escaping again, a string that needs escaping, a number
// without its source spelling) returns false in the counting walk, which
// checks each piece once; the copy walk only writes them.
fn selector_prelude_pieces(component &ComponentValue, mut output SelectorPreludeOutput) bool {
	if component.value is &Token {
		token := component.value
		match token.type_ {
			.number, .percentage, .dimension {
				if token.original_source_text_.len == 0 { return false }
				output.put(token.original_source_text_)
			}
			.ident {
				if output.counting
					&& !selector_prelude_name_verbatim(token.value, token.original_source_text_, 0, 0) {
					return false
				}
				output.put(token.value)
			}
			.function {
				if output.counting
					&& !selector_prelude_name_verbatim(token.value, token.original_source_text_, 0, 1) {
					return false
				}
				output.put(token.value)
				output.put('(')
			}
			.hash {
				if output.counting && token.hash_type_ == .id
					&& !selector_prelude_name_verbatim(token.value, token.original_source_text_, 1, 0) {
					return false
				}
				output.put('#')
				output.put(token.value)
			}
			.string {
				if output.counting && !selector_prelude_string_verbatim(token.value) { return false }
				output.put('"')
				output.put(token.value)
				output.put('"')
			}
			.delim {
				// trim_space() treats a vertical tab as whitespace; CSS does not.
				if output.counting
					&& (token.value.len != 1 || token.value[0] < 0x20 || token.value[0] >= 0x7f) {
					return false
				}
				output.put(token.value)
			}
			.whitespace { output.put(' ') }
			.colon { output.put(':') }
			.comma { output.put(',') }
			.open_square, .close_square, .open_paren, .close_paren, .open_curly, .close_curly {
				output.put(token.bracket_string())
			}
			.end_of_file, .bad_string {}
			else { return false }
		}
		return true
	} else if component.value is &SimpleBlock {
		block := component.value
		output.put(block.token.bracket_string())
		for index in 0 .. block.value.len {
			if !selector_prelude_pieces(unsafe { &block.value[index] }, mut output) { return false }
		}
		output.put(block.token.bracket_mirror_string())
		return true
	} else if component.value is &Function {
		function := component.value
		if output.counting && !selector_prelude_name_verbatim(function.name,
			function.name_token.original_source_text_, 0, 1) {
			return false
		}
		output.put(function.name)
		output.put('(')
		for index in 0 .. function.value.len {
			if !selector_prelude_pieces(unsafe { &function.value[index] }, mut output) { return false }
		}
		output.put(')')
		return true
	}
	return false
}

// Most selector preludes contain only plain identifiers, punctuation and
// numbers with their source spelling. Their trimmed serialization is the
// concatenation of strings the tokens already own, so measure it and copy it
// once into the selector's owned source. The general serializer assembles
// intermediate strings and needs a scratch arena for them.
fn direct_selector_prelude_text(values []ComponentValue) ?string {
	if disable_direct_selector_prelude { return none }
	mut start := 0
	mut end := values.len
	for start < end && selector_prelude_trimmed(unsafe { &values[start] }) { start++ }
	for end > start && selector_prelude_trimmed(unsafe { &values[end - 1] }) { end-- }
	mut output := SelectorPreludeOutput{}
	for index in start .. end {
		if !selector_prelude_pieces(unsafe { &values[index] }, mut output) { return none }
	}
	if output.length == 0 { return '' }
	output.bytes = []u8{len: output.length + 1}
	output.counting = false
	output.length = 0
	for index in start .. end {
		selector_prelude_pieces(unsafe { &values[index] }, mut output)
	}
	text := unsafe { (&u8(output.bytes.data)).vstring_with_len(output.length) }
	// Leading or trailing pieces are never whitespace; keep trim_space()'s
	// result exact if a future token kind breaks that.
	if text[0] in [u8(` `), `\t`, `\n`, `\r`, `\f`, `\v`]
		|| text[text.len - 1] in [u8(` `), `\t`, `\n`, `\r`, `\f`, `\v`] {
		return none
	}
	return text
}
