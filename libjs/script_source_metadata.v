module libjs

// Embedding backends parse and validate their own programs. They still need
// the Script Record's strictness without building an unused translated AST.
// A directive is an unparenthesized string-literal expression statement, so
// a line break alone is insufficient when the next token extends it.
pub fn script_source_is_strict(source string) bool {
	// Most bundled programs start with a keyword or punctuation, so they
	// cannot have a directive prologue. Avoid copying their entire source to
	// UTF-16 just to lex that first token. Comments, hashbangs, HTML comments,
	// quotes and non-ASCII trivia still use the complete lexer below.
	mut start := 0
	for start < source.len && source[start] in [u8(9), 10, 11, 12, 13, 32] { start++ }
	if start == source.len { return false }
	first := source[start]
	if first < 128 && first !in [u8(`"`), `'`, `/`, `<`, `-`, `#`] { return false }
	// The prologue is at the start of the script. Lex a prefix, widened only
	// when the decision reaches its end: bundles often open with a license
	// comment, and copying all of them to UTF-16 here is the bulk of the cost.
	mut length := 4096
	for length < source.len {
		mut end := length
		for end > 0 && source[end] & 0xc0 == 0x80 { end-- }
		strict, decided := script_prefix_is_strict(source[..end], false)
		if decided { return strict }
		length *= 8
	}
	strict, _ := script_prefix_is_strict(source, true)
	return strict
}

// Whether `source`, the start of a script or all of it when `complete`, begins
// with a "use strict" directive, and whether that is decided: a token the
// answer depends on can continue past the end of an incomplete prefix.
fn script_prefix_is_strict(source string, complete bool) (bool, bool) {
	code_units := utf16(source)
	defer { unsafe { code_units.free() } }
	end := u32(code_units.len)
	mut lexer := Lexer.new(code_units, 1, 1)
	mut token := lexer.next()
	for {
		if !complete && script_token_reaches(token, end) { return false, false }
		if token.token_type != .string_literal { return false, true }
		next := lexer.next()
		if !complete && script_token_reaches(next, end) { return false, false }
		terminated := next.token_type in [.semicolon, .eof, .curly_close]
			|| (next.trivia_has_line_terminator
				&& !script_directive_expression_continues(next.token_type))
		if !terminated { return false, true }
		if script_token_is_use_strict(code_units, token) {
			return true, true
		}
		token = if next.token_type == .semicolon { lexer.next() } else { next }
	}
	return false, true
}

fn script_token_reaches(token Token, end u32) bool {
	return token.token_type == .eof || token.value_start + token.value_len >= end
}

fn script_token_is_use_strict(source []u16, token Token) bool {
	if token.value_len != 12 { return false }
	start := int(token.value_start)
	quote := source[start]
	if (quote != u16(`"`) && quote != u16(`'`)) || source[start + 11] != quote { return false }
	for index, character in 'use strict' {
		if source[start + index + 1] != u16(character) { return false }
	}
	return true
}

fn script_directive_expression_continues(token TokenType) bool {
	return token in [
		// Calls, member access, tagged templates, and comma/conditional forms.
		.paren_open,
		.bracket_open,
		.period,
		.question_mark_period,
		.template_literal_start,
		.comma,
		.question_mark,
		// Binary operators continue an expression across a line terminator.
		.asterisk,
		.slash,
		.percent,
		.double_asterisk,
		.plus,
		.minus,
		.shift_left,
		.shift_right,
		.unsigned_shift_right,
		.less_than,
		.less_than_equals,
		.greater_than,
		.greater_than_equals,
		.in_kw,
		.instanceof_kw,
		.equals_equals,
		.equals_equals_equals,
		.exclamation_mark_equals,
		.exclamation_mark_equals_equals,
		.ampersand,
		.caret,
		.pipe,
		.double_ampersand,
		.double_pipe,
		.double_question_mark,
		// These are invalid assignment targets, which the executing backend
		// diagnoses; they cannot turn the literal into a directive either.
		.equals,
		.plus_equals,
		.minus_equals,
		.asterisk_equals,
		.slash_equals,
		.percent_equals,
		.double_asterisk_equals,
		.shift_left_equals,
		.shift_right_equals,
		.unsigned_shift_right_equals,
		.ampersand_equals,
		.caret_equals,
		.pipe_equals,
		.double_ampersand_equals,
		.double_pipe_equals,
		.double_question_mark_equals,
	]
}
