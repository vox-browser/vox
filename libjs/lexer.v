module libjs

// Lexer: tokenizes UTF-16 JavaScript source code — translated from lexer.rs.

// === Template literal state ===

struct TemplateState {
mut:
	in_expression      bool
	open_bracket_count u32
}

// === Saved lexer state ===

struct SavedLexerState {
	position           int
	current_code_unit  u16
	eof                bool
	line_number        u32
	line_column        u32
	current_token_type TokenType
	template_states    []TemplateState
}

// === Lexer ===

struct Lexer {
mut:
	source                      []u16
	position                    int // 1-based index: one past current_code_unit
	current_code_unit           u16
	eof                         bool
	line_number                 u32
	line_column                 u32
	current_token_type          TokenType
	allow_html_comments         bool
	template_states             []TemplateState
	saved_states                []SavedLexerState
	has_lookahead               bool
	lookahead                   Token
	lookahead_state             SavedLexerState
}

// Unicode constants
const no_break_space = u16(0x00A0)
const zero_width_non_joiner = u32(0x200C)
const zero_width_joiner = u32(0x200D)
const line_separator = u16(0x2028)
const paragraph_separator = u16(0x2029)
const zero_width_no_break_space = u16(0xFEFF)

// === Character classification helpers ===

fn lex_is_ascii(cu u16) bool {
	return cu < 128
}

fn lex_is_ascii_alpha(cp u32) bool {
	return cp < 128 && ((cp >= u32(`a`) && cp <= u32(`z`)) || (cp >= u32(`A`) && cp <= u32(`Z`)))
}

fn lex_is_ascii_digit(cu u16) bool {
	return cu >= ch(u8(`0`)) && cu <= ch(u8(`9`))
}

fn lex_is_ascii_digit_cp(cp u32) bool {
	return cp >= u32(`0`) && cp <= u32(`9`)
}

fn lex_is_ascii_hex_digit(cu u16) bool {
	return lex_is_ascii_digit(cu) || (cu >= ch(u8(`a`)) && cu <= ch(u8(`f`)))
		|| (cu >= ch(u8(`A`)) && cu <= ch(u8(`F`)))
}

fn lex_is_ascii_alphanumeric(cp u32) bool {
	return lex_is_ascii_alpha(cp) || lex_is_ascii_digit_cp(cp)
}

fn lex_is_ascii_space(cu u16) bool {
	return cu == 0x09 || cu == 0x0A || cu == 0x0B || cu == 0x0C || cu == 0x0D || cu == 0x20
}

fn is_octal_digit(cu u16) bool {
	return cu >= ch(u8(`0`)) && cu <= ch(u8(`7`))
}

fn is_binary_digit(cu u16) bool {
	return cu == ch(u8(`0`)) || cu == ch(u8(`1`))
}

fn is_utf16_high_surrogate(cu u16) bool {
	return cu >= 0xD800 && cu <= 0xDBFF
}

fn is_utf16_low_surrogate(cu u16) bool {
	return cu >= 0xDC00 && cu <= 0xDFFF
}

fn decode_code_point(source []u16, pos int) (u32, int) {
	if pos >= source.len {
		return 0xFFFD, 1
	}
	cu := source[pos]
	if is_utf16_high_surrogate(cu) && pos + 1 < source.len
		&& is_utf16_low_surrogate(source[pos + 1]) {
		hi := u32(cu)
		lo := u32(source[pos + 1])
		cp := u32(0x10000) + ((hi - 0xD800) << 10) + (lo - 0xDC00)
		return cp, 2
	}
	return u32(cu), 1
}

fn is_line_terminator_cp(cp u32) bool {
	return cp == u32(`\n`) || cp == u32(`\r`) || cp == u32(line_separator)
		|| cp == u32(paragraph_separator)
}

fn is_whitespace_cp(cp u32) bool {
	if cp < 128 {
		return lex_is_ascii_space(u16(cp))
	}
	if cp == u32(no_break_space) || cp == u32(zero_width_no_break_space) {
		return true
	}
	return cp == 0x1680 || (cp >= 0x2000 && cp <= 0x200A) || cp == 0x202F
		|| cp == 0x205F || cp == 0x3000
}

fn is_identifier_start_cp(cp u32) bool {
	if lex_is_ascii_alpha(cp) || cp == u32(`_`) || cp == u32(`$`) {
		return true
	}
	if cp < 128 {
		return false
	}
	return unicode_id_start(cp)
}

fn is_identifier_continue_cp(cp u32) bool {
	if lex_is_ascii_alphanumeric(cp) || cp == u32(`$`) || cp == u32(`_`)
		|| cp == zero_width_non_joiner || cp == zero_width_joiner {
		return true
	}
	if cp < 128 {
		return false
	}
	return unicode_id_continue(cp)
}

fn keyword_from_str(s []u16) ?TokenType {
	match s.len {
		2 {
			if utf16_equals_ascii(s, 'do') {
				return .do_kw
			}
			if utf16_equals_ascii(s, 'if') {
				return .if_kw
			}
			if utf16_equals_ascii(s, 'in') {
				return .in_kw
			}
		}
		3 {
			if utf16_equals_ascii(s, 'for') {
				return .for_kw
			}
			if utf16_equals_ascii(s, 'let') {
				return .let_kw
			}
			if utf16_equals_ascii(s, 'new') {
				return .new_kw
			}
			if utf16_equals_ascii(s, 'try') {
				return .try_kw
			}
			if utf16_equals_ascii(s, 'var') {
				return .var_kw
			}
		}
		4 {
			if utf16_equals_ascii(s, 'case') {
				return .case_kw
			}
			if utf16_equals_ascii(s, 'else') {
				return .else_kw
			}
			if utf16_equals_ascii(s, 'enum') {
				return .enum_kw
			}
			if utf16_equals_ascii(s, 'null') {
				return .null_literal
			}
			if utf16_equals_ascii(s, 'this') {
				return .this_kw
			}
			if utf16_equals_ascii(s, 'true') {
				return .bool_literal
			}
			if utf16_equals_ascii(s, 'void') {
				return .void_kw
			}
			if utf16_equals_ascii(s, 'with') {
				return .with_kw
			}
		}
		5 {
			if utf16_equals_ascii(s, 'async') {
				return .async
			}
			if utf16_equals_ascii(s, 'await') {
				return .await_kw
			}
			if utf16_equals_ascii(s, 'break') {
				return .break_kw
			}
			if utf16_equals_ascii(s, 'catch') {
				return .catch_kw
			}
			if utf16_equals_ascii(s, 'class') {
				return .class_kw
			}
			if utf16_equals_ascii(s, 'const') {
				return .const_kw
			}
			if utf16_equals_ascii(s, 'false') {
				return .bool_literal
			}
			if utf16_equals_ascii(s, 'super') {
				return .super_kw
			}
			if utf16_equals_ascii(s, 'throw') {
				return .throw_kw
			}
			if utf16_equals_ascii(s, 'while') {
				return .while_kw
			}
			if utf16_equals_ascii(s, 'yield') {
				return .yield_kw
			}
		}
		6 {
			if utf16_equals_ascii(s, 'delete') {
				return .delete_kw
			}
			if utf16_equals_ascii(s, 'export') {
				return .export_kw
			}
			if utf16_equals_ascii(s, 'import') {
				return .import_kw
			}
			if utf16_equals_ascii(s, 'return') {
				return .return_kw
			}
			if utf16_equals_ascii(s, 'switch') {
				return .switch_kw
			}
			if utf16_equals_ascii(s, 'typeof') {
				return .typeof_kw
			}
		}
		7 {
			if utf16_equals_ascii(s, 'default') {
				return .default_kw
			}
			if utf16_equals_ascii(s, 'extends') {
				return .extends_kw
			}
			if utf16_equals_ascii(s, 'finally') {
				return .finally_kw
			}
		}
		8 {
			if utf16_equals_ascii(s, 'continue') {
				return .continue_kw
			}
			if utf16_equals_ascii(s, 'debugger') {
				return .debugger
			}
			if utf16_equals_ascii(s, 'function') {
				return .function_kw
			}
		}
		10 {
			if utf16_equals_ascii(s, 'instanceof') {
				return .instanceof_kw
			}
		}
		else {}
	}

	return none
}

// === Single/multi-char token lookup ===

fn single_char_token(c u16) TokenType {
	return match u8(c) {
		u8(`&`) { TokenType.ampersand }
		u8(`*`) { TokenType.asterisk }
		u8(`[`) { TokenType.bracket_open }
		u8(`]`) { TokenType.bracket_close }
		u8(`^`) { TokenType.caret }
		u8(`:`) { TokenType.colon }
		u8(`,`) { TokenType.comma }
		u8(`{`) { TokenType.curly_open }
		u8(`}`) { TokenType.curly_close }
		u8(`=`) { TokenType.equals }
		u8(`!`) { TokenType.exclamation_mark }
		u8(`-`) { TokenType.minus }
		u8(`(`) { TokenType.paren_open }
		u8(`)`) { TokenType.paren_close }
		u8(`%`) { TokenType.percent }
		u8(`.`) { TokenType.period }
		u8(`|`) { TokenType.pipe }
		u8(`+`) { TokenType.plus }
		u8(`?`) { TokenType.question_mark }
		u8(`;`) { TokenType.semicolon }
		u8(`/`) { TokenType.slash }
		u8(`~`) { TokenType.tilde }
		u8(`<`) { TokenType.less_than }
		u8(`>`) { TokenType.greater_than }
		else { TokenType.invalid }
	}
}

// Dispatch on the first code unit, so a punctuator compares only the
// candidates that start with it instead of every two- or three-unit form.
fn parse_two_char_token(ch0 u16, ch1 u16) TokenType {
	if ch0 >= 128 || ch1 >= 128 {
		return .invalid
	}
	c1 := u8(ch1)
	return match u8(ch0) {
		`=` { if c1 == `>` { TokenType.arrow } else if c1 == `=` { TokenType.equals_equals } else { TokenType.invalid } }
		`+` { if c1 == `=` { TokenType.plus_equals } else if c1 == `+` { TokenType.plus_plus } else { TokenType.invalid } }
		`-` { if c1 == `=` { TokenType.minus_equals } else if c1 == `-` { TokenType.minus_minus } else { TokenType.invalid } }
		`*` { if c1 == `=` { TokenType.asterisk_equals } else if c1 == `*` { TokenType.double_asterisk } else { TokenType.invalid } }
		`/` { if c1 == `=` { TokenType.slash_equals } else { TokenType.invalid } }
		`%` { if c1 == `=` { TokenType.percent_equals } else { TokenType.invalid } }
		`&` { if c1 == `=` { TokenType.ampersand_equals } else if c1 == `&` { TokenType.double_ampersand } else { TokenType.invalid } }
		`|` { if c1 == `=` { TokenType.pipe_equals } else if c1 == `|` { TokenType.double_pipe } else { TokenType.invalid } }
		`^` { if c1 == `=` { TokenType.caret_equals } else { TokenType.invalid } }
		`<` { if c1 == `=` { TokenType.less_than_equals } else if c1 == `<` { TokenType.shift_left } else { TokenType.invalid } }
		`>` { if c1 == `=` { TokenType.greater_than_equals } else if c1 == `>` { TokenType.shift_right } else { TokenType.invalid } }
		`?` { if c1 == `?` { TokenType.double_question_mark } else if c1 == `.` { TokenType.question_mark_period } else { TokenType.invalid } }
		`!` { if c1 == `=` { TokenType.exclamation_mark_equals } else { TokenType.invalid } }
		else { TokenType.invalid }
	}
}

fn parse_three_char_token(ch0 u16, ch1 u16, ch2 u16) TokenType {
	if ch0 >= 128 || ch1 >= 128 || ch2 >= 128 {
		return .invalid
	}
	c1 := u8(ch1)
	c2 := u8(ch2)
	return match u8(ch0) {
		`<` { if c1 == `<` && c2 == `=` { TokenType.shift_left_equals } else { TokenType.invalid } }
		`>` {
			if c1 == `>` && c2 == `=` {
				TokenType.shift_right_equals
			} else if c1 == `>` && c2 == `>` {
				TokenType.unsigned_shift_right
			} else {
				TokenType.invalid
			}
		}
		`=` { if c1 == `=` && c2 == `=` { TokenType.equals_equals_equals } else { TokenType.invalid } }
		`!` { if c1 == `=` && c2 == `=` { TokenType.exclamation_mark_equals_equals } else { TokenType.invalid } }
		`.` { if c1 == `.` && c2 == `.` { TokenType.triple_dot } else { TokenType.invalid } }
		`*` { if c1 == `*` && c2 == `=` { TokenType.double_asterisk_equals } else { TokenType.invalid } }
		`&` { if c1 == `&` && c2 == `=` { TokenType.double_ampersand_equals } else { TokenType.invalid } }
		`|` { if c1 == `|` && c2 == `=` { TokenType.double_pipe_equals } else { TokenType.invalid } }
		`?` { if c1 == `?` && c2 == `=` { TokenType.double_question_mark_equals } else { TokenType.invalid } }
		else { TokenType.invalid }
	}
}

// Punctuators that never begin a longer one (parentheses, braces, brackets,
// comma, semicolon, colon, tilde) are most punctuators in real code.
@[inline]
fn lex_single_only_punctuator(c u16) bool {
	return c == u16(`(`) || c == u16(`)`) || c == u16(`,`) || c == u16(`;`) || c == u16(`{`)
		|| c == u16(`}`) || c == u16(`[`) || c == u16(`]`) || c == u16(`:`) || c == u16(`~`)
}

// === Lexer constructor and methods ===

fn Lexer.new(source []u16, line_number u32, line_column u32) Lexer {
	mut lexer := Lexer{
		source:              source
		line_number:         line_number
		line_column:         line_column
		current_token_type:  .eof
		allow_html_comments: true
	}
	lexer.consume()
	return lexer
}

fn Lexer.new_at_offset(source []u16, offset int, line_number u32, line_column u32) Lexer {
	mut lexer := Lexer{
		source:              source
		position:            offset
		line_number:         line_number
		line_column:         if line_column > 0 { line_column - 1 } else { u32(0) }
		current_token_type:  .eof
		allow_html_comments: true
	}
	lexer.consume()
	return lexer
}

fn (l &Lexer) current_template_state() &TemplateState {
	if l.template_states.len == 0 {
		panic('template_states must not be empty')
	}
	return &l.template_states[l.template_states.len - 1]
}

fn (mut l Lexer) disallow_html_comments() {
	l.allow_html_comments = false
	l.has_lookahead = false
}

fn (l &Lexer) source_len() int {
	return l.source.len
}

fn (mut l Lexer) consume() {
	if l.position > l.source_len() {
		return
	}

	if l.position >= l.source_len() {
		l.eof = true
		l.current_code_unit = 0
		l.position = l.source_len() + 1
		l.line_column += 1
		return
	}

	if l.is_line_terminator() {
		second_char_of_crlf := l.position > 1 && l.source[l.position - 2] == ch(u8(`\r`))
			&& l.current_code_unit == ch(u8(`\n`))

		if !second_char_of_crlf {
			l.line_number += 1
			l.line_column = 1
		}
	} else {
		if is_utf16_high_surrogate(l.current_code_unit) && l.position < l.source_len()
			&& is_utf16_low_surrogate(l.source[l.position]) {
			l.position += 1
			if l.position >= l.source_len() {
				l.eof = true
				l.current_code_unit = 0
				l.position = l.source_len() + 1
				l.line_column += 1
				return
			}
		}
		l.line_column += 1
	}

	l.current_code_unit = l.source[l.position]
	l.position += 1
}

fn (l &Lexer) current_code_point() u32 {
	if l.position == 0 {
		return 0xFFFD
	}
	cp, _ := decode_code_point(l.source, l.position - 1)
	return cp
}

fn (l &Lexer) is_eof() bool {
	return l.eof
}

fn (l &Lexer) is_line_terminator() bool {
	cu := l.current_code_unit
	if cu == ch(u8(`\n`)) || cu == ch(u8(`\r`)) {
		return true
	}
	if lex_is_ascii(cu) {
		return false
	}
	return is_line_terminator_cp(u32(l.current_code_unit))
}

fn (l &Lexer) is_whitespace() bool {
	if lex_is_ascii_space(l.current_code_unit) {
		return true
	}
	if lex_is_ascii(l.current_code_unit) {
		return false
	}
	return is_whitespace_cp(u32(l.current_code_unit))
}

// Try to parse a unicode escape sequence at the current position.
// Returns (code_point, consumed_len) or (-1, 0) if not found.
fn (l &Lexer) is_identifier_unicode_escape() (i64, int) {
	start := l.position - 1
	if start >= l.source_len() {
		return -1, 0
	}
	pos := l.position
	if pos >= l.source_len() {
		return -1, 0
	}
	if l.source[pos] != ch(u8(`u`)) {
		return -1, 0
	}
	mut p := pos + 1
	if p >= l.source_len() {
		return -1, 0
	}

	if l.source[p] == ch(u8(`{`)) {
		mut cp := u32(0)
		mut i := p + 1
		if i >= l.source_len() {
			return -1, 0
		}
		for i < l.source_len() && l.source[i] != ch(u8(`}`)) {
			cu := l.source[i]
			if !lex_is_ascii_hex_digit(cu) {
				return -1, 0
			}
			cp = cp * 16 + hex_value(cu)
			if cp > 0x10FFFF {
				return -1, 0
			}
			i++
		}
		if i >= l.source_len() || l.source[i] != ch(u8(`}`)) {
			return -1, 0
		}
		consumed := i + 1 - (l.position - 1)
		return i64(cp), consumed
	} else {
		if p + 4 > l.source_len() {
			return -1, 0
		}
		mut cp := u32(0)
		for i in 0 .. 4 {
			cu := l.source[p + i]
			if !lex_is_ascii_hex_digit(cu) {
				return -1, 0
			}
			cp = cp * 16 + hex_value(cu)
		}
		consumed := p + 4 - (l.position - 1)
		return i64(cp), consumed
	}
}

fn (l &Lexer) is_surrogate_pair(len int) bool {
	return len == 2
}

// ASCII identifier characters advance by one column and cannot end a line.
// Leave the first other code unit to the Unicode and escape checks.
@[direct_array_access]
fn (mut l Lexer) consume_ascii_identifier_tail() {
	start := l.position - 1
	mut end := start
	for end < l.source.len {
		unit := l.source[end]
		letter := unit | 0x20
		if !((letter >= u16(`a`) && letter <= u16(`z`)) || lex_is_ascii_digit(unit)
			|| unit == u16(`_`) || unit == u16(`$`)) {
			break
		}
		end++
	}
	if end == start { return }
	l.line_column += u32(end - start)
	l.position = end + 1
	if end == l.source.len {
		l.eof = true
		l.current_code_unit = 0
	} else {
		l.current_code_unit = l.source[end]
	}
}

// Scan an identifier body. Returns true if it contains escape sequences.
fn (mut l Lexer) scan_identifier_body(initial_len int) bool {
	mut has_escape := false
	mut ident_len := initial_len
	for {
		// A validated ASCII start fits in the same run as its tail.
		if ident_len != 1 || l.current_code_unit >= 128 {
			is_pair := l.is_surrogate_pair(ident_len)
			has_escape = has_escape || (ident_len > 1 && !is_pair)
			consume_count := if is_pair { 1 } else { ident_len }
			for _ in 0 .. consume_count {
				l.consume()
			}
		}
		l.consume_ascii_identifier_tail()
		// The run stops at a delimiter, a Unicode unit, an escape or EOF.
		if l.current_code_unit < 128 && l.current_code_unit != u16(`\\`) {
			break
		}
		next_cp, next_len := l.is_identifier_middle()
		if next_cp >= 0 {
			ident_len = next_len
		} else {
			break
		}
	}
	return has_escape
}

// Re-scan from scan_start to build decoded identifier value (when escapes present).
fn (l &Lexer) build_identifier_value(scan_start int) Utf16String {
	raw := l.source[scan_start - 1..l.position - 1]
	mut result := []u16{cap: raw.len}
	mut i := 0
	for i < raw.len {
		if raw[i] == ch(u8(`\\`)) {
			i++ // skip '\'
			if i < raw.len && raw[i] == ch(u8(`u`)) {
				i++ // skip 'u'
				if i < raw.len && raw[i] == ch(u8(`{`)) {
					i++ // skip '{'
					mut cp := u32(0)
					for i < raw.len && raw[i] != ch(u8(`}`)) {
						cp = cp * 16 + hex_value(raw[i])
						i++
					}
					if i < raw.len {
						i++ // skip '}'
					}
					encode_utf16_to(cp, mut result)
				} else {
					mut cp := u32(0)
					for _ in 0 .. 4 {
						if i < raw.len {
							cp = cp * 16 + hex_value(raw[i])
							i++
						}
					}
					encode_utf16_to(cp, mut result)
				}
			}
		} else {
			result << raw[i]
			i++
		}
	}
	return Utf16String{
		data: result
	}
}

// Number of source code units in a valid identifier start, or zero.
fn (l &Lexer) identifier_start_length() int {
	unit := u32(l.current_code_unit)
	if unit < 128 && unit != u32(`\\`) {
		return if is_identifier_start_cp(unit) { 1 } else { 0 }
	}
	if unit == u32(`\\`) {
		esc_cp, esc_len := l.is_identifier_unicode_escape()
		return if esc_cp >= 0 && is_identifier_start_cp(u32(esc_cp)) { esc_len } else { 0 }
	}

	cp := l.current_code_point()
	if is_identifier_start_cp(cp) {
		return if cp > 0xFFFF { 2 } else { 1 }
	}

	return 0
}

// Check if current position continues an identifier.
// Returns (code_point, len) or (-1, 0).
fn (l &Lexer) is_identifier_middle() (i64, int) {
	cp := l.current_code_point()
	if cp == u32(`\\`) {
		esc_cp, esc_len := l.is_identifier_unicode_escape()
		if esc_cp >= 0 {
			if is_identifier_continue_cp(u32(esc_cp)) {
				return esc_cp, esc_len
			}
		}
		return -1, 0
	}

	if is_identifier_continue_cp(cp) {
		len := if cp > 0xFFFF { 2 } else { 1 }
		return i64(cp), len
	}

	return -1, 0
}

fn (l &Lexer) match2(a u16, b u16) bool {
	if l.position >= l.source_len() {
		return false
	}
	return l.current_code_unit == a && l.source[l.position] == b
}

fn (l &Lexer) match3(a u16, b u16, c u16) bool {
	if l.position + 1 >= l.source_len() {
		return false
	}
	return l.current_code_unit == a && l.source[l.position] == b && l.source[l.position + 1] == c
}

fn (l &Lexer) match4(a u16, b u16, c u16, d u16) bool {
	if l.position + 2 >= l.source_len() {
		return false
	}
	return l.current_code_unit == a && l.source[l.position] == b && l.source[l.position + 1] == c
		&& l.source[l.position + 2] == d
}

fn (l &Lexer) match_numeric_literal_separator_followed_by(check fn (u16) bool) bool {
	if l.position >= l.source_len() {
		return false
	}
	return l.current_code_unit == ch(u8(`_`)) && check(l.source[l.position])
}

fn (l &Lexer) is_line_comment_start(line_has_token_yet bool) bool {
	return l.match2(ch(u8(`/`)), ch(u8(`/`)))
		|| (l.allow_html_comments && l.match4(ch(u8(`<`)), ch(u8(`!`)), ch(u8(`-`)), ch(u8(`-`))))
		|| (l.allow_html_comments && !line_has_token_yet
		&& l.match3(ch(u8(`-`)), ch(u8(`-`)), ch(u8(`>`))))
		|| (l.match2(ch(u8(`#`)), ch(u8(`!`))) && l.position == 1)
}

fn (l &Lexer) is_block_comment_start() bool {
	return l.match2(ch(u8(`/`)), ch(u8(`*`)))
}

fn (l &Lexer) is_block_comment_end() bool {
	return l.match2(ch(u8(`*`)), ch(u8(`/`)))
}

fn (l &Lexer) is_numeric_literal_start() bool {
	return lex_is_ascii_digit(l.current_code_unit)
		|| (l.current_code_unit == ch(u8(`.`)) && l.position < l.source_len()
		&& lex_is_ascii_digit(l.source[l.position]))
}

fn (l &Lexer) slash_means_division() bool {
	tt := l.current_token_type
	return tt.is_identifier_name() || tt == .big_int_literal || tt == .bracket_close
		|| tt == .curly_close || tt == .minus_minus || tt == .numeric_literal || tt == .paren_close
		|| tt == .plus_plus || tt == .private_identifier || tt == .regex_literal
		|| tt == .string_literal || tt == .template_literal_end
}

fn (mut l Lexer) consume_decimal_number() bool {
	if !lex_is_ascii_digit(l.current_code_unit) {
		return false
	}
	for lex_is_ascii_digit(l.current_code_unit)
		|| l.match_numeric_literal_separator_followed_by(lex_is_ascii_digit) {
		l.consume()
	}
	return true
}

fn (mut l Lexer) consume_exponent() bool {
	l.consume()
	if l.current_code_unit == ch(u8(`-`)) || l.current_code_unit == ch(u8(`+`)) {
		l.consume()
	}
	if !lex_is_ascii_digit(l.current_code_unit) {
		return false
	}
	return l.consume_decimal_number()
}

fn (mut l Lexer) consume_octal_number() bool {
	l.consume()
	if !is_octal_digit(l.current_code_unit) {
		return false
	}
	for is_octal_digit(l.current_code_unit)
		|| l.match_numeric_literal_separator_followed_by(is_octal_digit) {
		l.consume()
	}
	return true
}

fn (mut l Lexer) consume_hexadecimal_number() bool {
	l.consume()
	if !lex_is_ascii_hex_digit(l.current_code_unit) {
		return false
	}
	for lex_is_ascii_hex_digit(l.current_code_unit)
		|| l.match_numeric_literal_separator_followed_by(lex_is_ascii_hex_digit) {
		l.consume()
	}
	return true
}

fn (mut l Lexer) try_consume_bigint_suffix(mut token_type TokenType) {
	if l.current_code_unit == ch(u8(`n`)) {
		l.consume()
		unsafe {
			*token_type = .big_int_literal
		}
	}
}

fn (mut l Lexer) consume_binary_number() bool {
	l.consume()
	if !is_binary_digit(l.current_code_unit) {
		return false
	}
	for is_binary_digit(l.current_code_unit)
		|| l.match_numeric_literal_separator_followed_by(is_binary_digit) {
		l.consume()
	}
	return true
}

fn (mut l Lexer) consume_regex_literal() TokenType {
	mut in_character_class := false
	for !l.is_eof() {
		if l.is_line_terminator()
			|| (!in_character_class && l.current_code_unit == ch(u8(`/`))) {
			break
		}

		if l.current_code_unit == ch(u8(`[`)) {
			in_character_class = true
		} else if l.current_code_unit == ch(u8(`]`)) {
			in_character_class = false
		}

		if l.match2(ch(u8(`\\`)), ch(u8(`/`))) || l.match2(ch(u8(`\\`)), ch(u8(`[`)))
			|| l.match2(ch(u8(`\\`)), ch(u8(`\\`)))
			|| (in_character_class && l.match2(ch(u8(`\\`)), ch(u8(`]`)))) {
			l.consume()
		}
		l.consume()
	}

	if l.current_code_unit == ch(u8(`/`)) {
		l.consume()
		return .regex_literal
	}
	return .unterminated_regex_literal
}

// === Main tokenization ===

@[inline]
fn lex_may_start_trivia(unit u16) bool {
	return unit <= 0x20 || unit >= 0x80 || unit in [u16(`/`), u16(`<`), u16(`-`), u16(`#`)]
}

fn (mut l Lexer) next() Token {
	if l.has_lookahead {
		l.has_lookahead = false
		l.restore_state(l.lookahead_state)
		return l.lookahead
	}
	return l.lex_token()
}

fn (mut l Lexer) peek() Token {
	if l.has_lookahead {
		return l.lookahead
	}
	before := l.snapshot()
	token := l.lex_token()
	// Template tokens mutate a stack. Keep those peeks on the snapshot path.
	if before.template_states.len == 0 && l.template_states.len == 0 {
		l.lookahead = token
		l.lookahead_state = l.snapshot()
		l.has_lookahead = true
	}
	l.restore_state(before)
	return token
}

fn (mut l Lexer) lex_token() Token {
	trivia_start := l.position
	in_template := l.template_states.len > 0
	mut line_has_token_yet := l.line_column > 1
	mut unterminated_comment := false
	mut token_message := ?string(none)

	if !in_template || l.template_states[l.template_states.len - 1].in_expression {
		for lex_may_start_trivia(l.current_code_unit) {
			if l.is_line_terminator() {
				line_has_token_yet = false
				for {
					l.consume()
					if !l.is_line_terminator() {
						break
					}
				}
			} else if l.is_whitespace() {
				start_line_number := l.line_number
				for {
					l.consume()
					if !l.is_whitespace() {
						break
					}
				}
				if start_line_number != l.line_number {
					line_has_token_yet = false
				}
			} else if l.is_line_comment_start(line_has_token_yet) {
				l.consume()
				for {
					l.consume()
					if l.is_eof() || l.is_line_terminator() {
						break
					}
				}
			} else if l.is_block_comment_start() {
				start_line_number := l.line_number
				l.consume()
				for {
					l.consume()
					if l.is_eof() || l.is_block_comment_end() {
						break
					}
				}
				if l.is_eof() {
					unterminated_comment = true
				}
				l.consume() // consume *
				if l.is_eof() {
					unterminated_comment = true
				}
				l.consume() // consume /

				if start_line_number != l.line_number {
					line_has_token_yet = false
				}
			} else {
				break
			}
		}
	}

	value_start := l.position
	value_start_line_number := l.line_number
	value_start_column_number := l.line_column
	mut token_type := TokenType.invalid
	did_consume_whitespace_or_comments := trivia_start != value_start

	mut identifier_value := ?&Utf16String(none)

	if l.current_token_type == .regex_literal && !l.is_eof()
		&& (l.current_code_unit < 128 && lex_is_ascii_alpha(u32(l.current_code_unit)))
		&& !did_consume_whitespace_or_comments {
		token_type = .regex_flags
		for !l.is_eof() && l.current_code_unit < 128 && lex_is_ascii_alpha(u32(l.current_code_unit)) {
			l.consume()
		}
	} else if l.current_code_unit == ch(u8(`\``)) {
		l.consume()
		if !in_template {
			token_type = .template_literal_start
			l.template_states << TemplateState{
				in_expression:      false
				open_bracket_count: 0
			}
		} else if l.template_states[l.template_states.len - 1].in_expression {
			l.template_states << TemplateState{
				in_expression:      false
				open_bracket_count: 0
			}
			token_type = .template_literal_start
		} else {
			l.template_states.delete(l.template_states.len - 1)
			token_type = .template_literal_end
		}
	} else if in_template && l.template_states[l.template_states.len - 1].in_expression
		&& l.template_states[l.template_states.len - 1].open_bracket_count == 0
		&& l.current_code_unit == ch(u8(`}`)) {
		l.consume()
		token_type = .template_literal_expr_end
		l.template_states[l.template_states.len - 1].in_expression = false
	} else if in_template && !l.template_states[l.template_states.len - 1].in_expression {
		if l.is_eof() {
			token_type = .unterminated_template_literal
			l.template_states.delete(l.template_states.len - 1)
		} else if l.match2(ch(u8(`$`)), ch(u8(`{`))) {
			token_type = .template_literal_expr_start
			l.consume()
			l.consume()
			l.template_states[l.template_states.len - 1].in_expression = true
		} else {
			for !l.match2(ch(u8(`$`)), ch(u8(`{`))) && l.current_code_unit != ch(u8(`\``))
				&& !l.is_eof() {
				if l.match2(ch(u8(`\\`)), ch(u8(`$`))) || l.match2(ch(u8(`\\`)), ch(u8(`\``)))
					|| l.match2(ch(u8(`\\`)), ch(u8(`\\`))) {
					l.consume()
				}
				l.consume()
			}
			if l.is_eof() && l.template_states.len > 0 {
				token_type = .unterminated_template_literal
			} else {
				token_type = .template_literal_string
			}
		}
	} else if l.current_code_unit == ch(u8(`#`)) {
		l.consume()
		start_len := l.identifier_start_length()
		if start_len > 0 {
			has_escape := l.scan_identifier_body(start_len)
			if has_escape {
				identifier_value = ast_text(l.build_identifier_value(value_start))
			}
			token_type = .private_identifier
		} else {
			token_type = .invalid
			token_message = "Start of private name '#' but not followed by valid identifier"
		}
	} else {
		start_len := l.identifier_start_length()
		if start_len > 0 {
			has_escape := l.scan_identifier_body(start_len)

			if has_escape {
				decoded := l.build_identifier_value(value_start)
				if _ := keyword_from_str(decoded.data) {
					token_type = .escaped_keyword
				} else {
					token_type = .identifier
				}
				identifier_value = ast_text(decoded)
			} else if l.position - value_start == 1 {
				// Every keyword has at least two code units.
				token_type = .identifier
			} else {
				if kw := keyword_from_str(l.source[value_start - 1..l.position - 1]) {
					token_type = kw
				} else {
					token_type = .identifier
				}
			}
		} else if l.is_numeric_literal_start() {
			token_type = .numeric_literal
			mut is_invalid := false
			if l.current_code_unit == ch(u8(`0`)) {
				l.consume()
				if l.current_code_unit == ch(u8(`.`)) {
					l.consume()
					for lex_is_ascii_digit(l.current_code_unit) {
						l.consume()
					}
					if l.current_code_unit == ch(u8(`e`)) || l.current_code_unit == ch(u8(`E`)) {
						is_invalid = !l.consume_exponent()
					}
				} else if l.current_code_unit == ch(u8(`e`)) || l.current_code_unit == ch(u8(`E`)) {
					is_invalid = !l.consume_exponent()
				} else if l.current_code_unit == ch(u8(`o`)) || l.current_code_unit == ch(u8(`O`)) {
					is_invalid = !l.consume_octal_number()
					l.try_consume_bigint_suffix(mut &token_type)
				} else if l.current_code_unit == ch(u8(`b`)) || l.current_code_unit == ch(u8(`B`)) {
					is_invalid = !l.consume_binary_number()
					l.try_consume_bigint_suffix(mut &token_type)
				} else if l.current_code_unit == ch(u8(`x`)) || l.current_code_unit == ch(u8(`X`)) {
					is_invalid = !l.consume_hexadecimal_number()
					l.try_consume_bigint_suffix(mut &token_type)
				} else if l.current_code_unit == ch(u8(`n`)) {
					l.try_consume_bigint_suffix(mut &token_type)
				} else if lex_is_ascii_digit(l.current_code_unit) {
					// Legacy octal without 0o prefix
					for {
						l.consume()
						if !lex_is_ascii_digit(l.current_code_unit) {
							break
						}
					}
				}
			} else {
				for lex_is_ascii_digit(l.current_code_unit)
					|| l.match_numeric_literal_separator_followed_by(lex_is_ascii_digit) {
					l.consume()
				}
				if l.current_code_unit == ch(u8(`n`)) {
					l.consume()
					token_type = .big_int_literal
				} else {
					if l.current_code_unit == ch(u8(`.`)) {
						l.consume()
						if l.current_code_unit == ch(u8(`_`)) {
							is_invalid = true
						}
						for lex_is_ascii_digit(l.current_code_unit)
							|| l.match_numeric_literal_separator_followed_by(lex_is_ascii_digit) {
							l.consume()
						}
					}
					if (l.current_code_unit == ch(u8(`e`))
						|| l.current_code_unit == ch(u8(`E`))) && !l.consume_exponent() {
						is_invalid = true
					}
				}
			}
			if is_invalid {
				token_type = .invalid
				token_message = 'Invalid numeric literal'
			}
		} else if l.current_code_unit == ch(u8(`"`)) || l.current_code_unit == ch(u8(`'`)) {
			stop_char := l.current_code_unit
			l.consume()
			for l.current_code_unit != stop_char && l.current_code_unit != ch(u8(`\r`))
				&& l.current_code_unit != ch(u8(`\n`)) && !l.is_eof() {
				if l.current_code_unit == ch(u8(`\\`)) {
					l.consume()
					if l.current_code_unit == ch(u8(`\r`)) && l.position < l.source_len()
						&& l.source[l.position] == ch(u8(`\n`)) {
						l.consume()
					}
				}
				l.consume()
			}
			if l.current_code_unit != stop_char {
				token_type = .unterminated_string_literal
			} else {
				l.consume()
				token_type = .string_literal
			}
		} else if l.current_code_unit == ch(u8(`/`)) && !l.slash_means_division() {
			l.consume()
			token_type = l.consume_regex_literal()
		} else if l.eof {
			if unterminated_comment {
				token_type = .invalid
				token_message = 'Unterminated multi-line comment'
			} else {
				token_type = .eof
			}
		} else {
			mut found_token := false

			if lex_single_only_punctuator(l.current_code_unit) {
				found_token = true
				token_type = single_char_token(l.current_code_unit)
				l.consume()
			}

			if !found_token && l.match4(ch(u8(`>`)), ch(u8(`>`)), ch(u8(`>`)), ch(u8(`=`))) {
				found_token = true
				token_type = .unsigned_shift_right_equals
				l.consume()
				l.consume()
				l.consume()
				l.consume()
			}

			if !found_token && l.position + 1 < l.source_len() {
				c0 := l.current_code_unit
				c1 := l.source[l.position]
				c2 := l.source[l.position + 1]
				tt := parse_three_char_token(c0, c1, c2)
				if tt != .invalid {
					found_token = true
					token_type = tt
					l.consume()
					l.consume()
					l.consume()
				}
			}

			if !found_token && l.position < l.source_len() {
				c0 := l.current_code_unit
				c1 := l.source[l.position]
				tt := parse_two_char_token(c0, c1)
				if tt != .invalid {
					if !(tt == .question_mark_period && l.position + 1 < l.source_len()
						&& lex_is_ascii_digit(l.source[l.position + 1])) {
						found_token = true
						token_type = tt
						l.consume()
						l.consume()
					}
				}
			}

			if !found_token && lex_is_ascii(l.current_code_unit) {
				tt := single_char_token(l.current_code_unit)
				if tt != .invalid {
					found_token = true
					token_type = tt
					l.consume()
				}
			}

			if !found_token {
				token_type = .invalid
				l.consume()
			}
		}
	}

	if l.template_states.len > 0 && l.template_states[l.template_states.len - 1].in_expression {
		if token_type == .curly_open {
			l.template_states[l.template_states.len - 1].open_bracket_count += 1
		} else if token_type == .curly_close {
			count := l.template_states[l.template_states.len - 1].open_bracket_count
			l.template_states[l.template_states.len - 1].open_bracket_count = if count > 0 {
				count - 1
			} else {
				u32(0)
			}
		}
	}

	l.current_token_type = token_type

	mut trivia_has_line_terminator := false
	if trivia_start > 0 && value_start > trivia_start {
		for ci in trivia_start - 1 .. value_start - 1 {
			cu := l.source[ci]
			if cu == ch(u8(`\n`)) || cu == ch(u8(`\r`)) || cu == line_separator
				|| cu == paragraph_separator {
				trivia_has_line_terminator = true
				break
			}
		}
	}

	vs := if value_start > 0 { u32(value_start - 1) } else { u32(0) }
	ts := if trivia_start > 0 { u32(trivia_start - 1) } else { u32(0) }

	return Token{
		token_type:                 token_type
		trivia_start:               ts
		trivia_len:                 u32(value_start - trivia_start)
		value_start:                vs
		value_len:                  u32(l.position - value_start)
		line_number:                value_start_line_number
		line_column:                value_start_column_number
		offset:                     vs
		trivia_has_line_terminator: trivia_has_line_terminator
		identifier_value:           identifier_value
		message:                    if text := token_message { &TokenMessage{text: text} } else { none }
	}
}

// === State save/restore ===

fn (l &Lexer) snapshot() SavedLexerState {
	return SavedLexerState{
		position:           l.position
		current_code_unit:  l.current_code_unit
		eof:                l.eof
		line_number:        l.line_number
		line_column:        l.line_column
		current_token_type: l.current_token_type
		// Only an active template has entries to protect from in-place updates.
		template_states:    if l.template_states.len == 0 { []TemplateState{} } else { l.template_states.clone() }
	}
}

fn (mut l Lexer) save_state() {
	l.saved_states << l.snapshot()
}

fn (mut l Lexer) load_state() {
	if l.saved_states.len == 0 {
		panic('No saved lexer state')
	}
	l.has_lookahead = false
	l.restore_state(l.saved_states.pop())
}

fn (mut l Lexer) restore_state(state SavedLexerState) {
	l.position = state.position
	l.current_code_unit = state.current_code_unit
	l.eof = state.eof
	l.line_number = state.line_number
	l.line_column = state.line_column
	l.current_token_type = state.current_token_type
	l.template_states = state.template_states
}

fn (mut l Lexer) discard_saved_state() {
	l.saved_states.pop()
}

// Re-lex the current Slash or SlashEquals token as a regex literal.
fn (mut l Lexer) force_slash_as_regex() Token {
	l.has_lookahead = false
	has_equals := l.current_token_type == .slash_equals

	mut value_start := l.position - 1

	token_line_number := l.line_number
	mut token_line_column := l.line_column - 1

	if has_equals {
		value_start -= 1
		l.position -= 1
		l.current_code_unit = ch(u8(`=`))
		token_line_column -= 1
	}

	token_type := l.consume_regex_literal()
	l.current_token_type = token_type

	vs := if value_start > 0 { u32(value_start - 1) } else { u32(0) }

	return Token{
		token_type:                 token_type
		trivia_start:               0
		trivia_len:                 0
		value_start:                vs
		value_len:                  u32(l.position - value_start)
		line_number:                token_line_number
		line_column:                token_line_column
		offset:                     vs
		trivia_has_line_terminator: false
	}
}

// === Helpers ===

fn hex_value(cu u16) u32 {
	if cu >= 0x30 && cu <= 0x39 {
		return u32(cu - 0x30)
	}
	if cu >= 0x41 && cu <= 0x46 {
		return u32(cu - 0x41 + 10)
	}
	if cu >= 0x61 && cu <= 0x66 {
		return u32(cu - 0x61 + 10)
	}
	return 0
}

fn encode_utf16_to(cp u32, mut buffer []u16) {
	if cp <= 0xFFFF {
		buffer << u16(cp)
	} else {
		c := cp - 0x10000
		buffer << u16(0xD800 + (c >> 10))
		buffer << u16(0xDC00 + (c & 0x3FF))
	}
}
