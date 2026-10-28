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
	regex_is_in_character_class bool
	allow_html_comments         bool
	template_states             []TemplateState
	saved_states                []SavedLexerState
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
			if utf16_equals(s, utf16('do')) {
				return .do_kw
			}
			if utf16_equals(s, utf16('if')) {
				return .if_kw
			}
			if utf16_equals(s, utf16('in')) {
				return .in_kw
			}
		}
		3 {
			if utf16_equals(s, utf16('for')) {
				return .for_kw
			}
			if utf16_equals(s, utf16('let')) {
				return .let_kw
			}
			if utf16_equals(s, utf16('new')) {
				return .new_kw
			}
			if utf16_equals(s, utf16('try')) {
				return .try_kw
			}
			if utf16_equals(s, utf16('var')) {
				return .var_kw
			}
		}
		4 {
			if utf16_equals(s, utf16('case')) {
				return .case_kw
			}
			if utf16_equals(s, utf16('else')) {
				return .else_kw
			}
			if utf16_equals(s, utf16('enum')) {
				return .enum_kw
			}
			if utf16_equals(s, utf16('null')) {
				return .null_literal
			}
			if utf16_equals(s, utf16('this')) {
				return .this_kw
			}
			if utf16_equals(s, utf16('true')) {
				return .bool_literal
			}
			if utf16_equals(s, utf16('void')) {
				return .void_kw
			}
			if utf16_equals(s, utf16('with')) {
				return .with_kw
			}
		}
		5 {
			if utf16_equals(s, utf16('async')) {
				return .async
			}
			if utf16_equals(s, utf16('await')) {
				return .await_kw
			}
			if utf16_equals(s, utf16('break')) {
				return .break_kw
			}
			if utf16_equals(s, utf16('catch')) {
				return .catch_kw
			}
			if utf16_equals(s, utf16('class')) {
				return .class_kw
			}
			if utf16_equals(s, utf16('const')) {
				return .const_kw
			}
			if utf16_equals(s, utf16('false')) {
				return .bool_literal
			}
			if utf16_equals(s, utf16('super')) {
				return .super_kw
			}
			if utf16_equals(s, utf16('throw')) {
				return .throw_kw
			}
			if utf16_equals(s, utf16('while')) {
				return .while_kw
			}
			if utf16_equals(s, utf16('yield')) {
				return .yield_kw
			}
		}
		6 {
			if utf16_equals(s, utf16('delete')) {
				return .delete_kw
			}
			if utf16_equals(s, utf16('export')) {
				return .export_kw
			}
			if utf16_equals(s, utf16('import')) {
				return .import_kw
			}
			if utf16_equals(s, utf16('return')) {
				return .return_kw
			}
			if utf16_equals(s, utf16('switch')) {
				return .switch_kw
			}
			if utf16_equals(s, utf16('typeof')) {
				return .typeof_kw
			}
		}
		7 {
			if utf16_equals(s, utf16('default')) {
				return .default_kw
			}
			if utf16_equals(s, utf16('extends')) {
				return .extends_kw
			}
			if utf16_equals(s, utf16('finally')) {
				return .finally_kw
			}
		}
		8 {
			if utf16_equals(s, utf16('continue')) {
				return .continue_kw
			}
			if utf16_equals(s, utf16('debugger')) {
				return .debugger
			}
			if utf16_equals(s, utf16('function')) {
				return .function_kw
			}
		}
		10 {
			if utf16_equals(s, utf16('instanceof')) {
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

fn parse_two_char_token(ch0 u16, ch1 u16) TokenType {
	if ch0 >= 128 || ch1 >= 128 {
		return .invalid
	}
	c0 := u8(ch0)
	c1 := u8(ch1)
	if c0 == `=` && c1 == `>` {
		return .arrow
	}
	if c0 == `=` && c1 == `=` {
		return .equals_equals
	}
	if c0 == `+` && c1 == `=` {
		return .plus_equals
	}
	if c0 == `+` && c1 == `+` {
		return .plus_plus
	}
	if c0 == `-` && c1 == `=` {
		return .minus_equals
	}
	if c0 == `-` && c1 == `-` {
		return .minus_minus
	}
	if c0 == `*` && c1 == `=` {
		return .asterisk_equals
	}
	if c0 == `*` && c1 == `*` {
		return .double_asterisk
	}
	if c0 == `/` && c1 == `=` {
		return .slash_equals
	}
	if c0 == `%` && c1 == `=` {
		return .percent_equals
	}
	if c0 == `&` && c1 == `=` {
		return .ampersand_equals
	}
	if c0 == `&` && c1 == `&` {
		return .double_ampersand
	}
	if c0 == `|` && c1 == `=` {
		return .pipe_equals
	}
	if c0 == `|` && c1 == `|` {
		return .double_pipe
	}
	if c0 == `^` && c1 == `=` {
		return .caret_equals
	}
	if c0 == `<` && c1 == `=` {
		return .less_than_equals
	}
	if c0 == `<` && c1 == `<` {
		return .shift_left
	}
	if c0 == `>` && c1 == `=` {
		return .greater_than_equals
	}
	if c0 == `>` && c1 == `>` {
		return .shift_right
	}
	if c0 == `?` && c1 == `?` {
		return .double_question_mark
	}
	if c0 == `?` && c1 == `.` {
		return .question_mark_period
	}
	if c0 == `!` && c1 == `=` {
		return .exclamation_mark_equals
	}
	return .invalid
}

fn parse_three_char_token(ch0 u16, ch1 u16, ch2 u16) TokenType {
	if ch0 >= 128 || ch1 >= 128 || ch2 >= 128 {
		return .invalid
	}
	c0 := u8(ch0)
	c1 := u8(ch1)
	c2 := u8(ch2)
	if c0 == `<` && c1 == `<` && c2 == `=` {
		return .shift_left_equals
	}
	if c0 == `>` && c1 == `>` && c2 == `=` {
		return .shift_right_equals
	}
	if c0 == `>` && c1 == `>` && c2 == `>` {
		return .unsigned_shift_right
	}
	if c0 == `=` && c1 == `=` && c2 == `=` {
		return .equals_equals_equals
	}
	if c0 == `!` && c1 == `=` && c2 == `=` {
		return .exclamation_mark_equals_equals
	}
	if c0 == `.` && c1 == `.` && c2 == `.` {
		return .triple_dot
	}
	if c0 == `*` && c1 == `*` && c2 == `=` {
		return .double_asterisk_equals
	}
	if c0 == `&` && c1 == `&` && c2 == `=` {
		return .double_ampersand_equals
	}
	if c0 == `|` && c1 == `|` && c2 == `=` {
		return .double_pipe_equals
	}
	if c0 == `?` && c1 == `?` && c2 == `=` {
		return .double_question_mark_equals
	}
	return .invalid
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

// Scan an identifier body. Returns true if it contains escape sequences.
fn (mut l Lexer) scan_identifier_body(initial_len int) bool {
	mut has_escape := false
	mut ident_len := initial_len
	for {
		is_pair := l.is_surrogate_pair(ident_len)
		has_escape = has_escape || (ident_len > 1 && !is_pair)
		consume_count := if is_pair { 1 } else { ident_len }
		for _ in 0 .. consume_count {
			l.consume()
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

// Check if current position starts an identifier start character.
// Returns (code_point, len) or (-1, 0).
fn (l &Lexer) is_identifier_start() (i64, int) {
	cp := l.current_code_point()
	if cp == u32(`\\`) {
		esc_cp, esc_len := l.is_identifier_unicode_escape()
		if esc_cp >= 0 {
			if is_identifier_start_cp(u32(esc_cp)) {
				return esc_cp, esc_len
			}
		}
		return -1, 0
	}

	if is_identifier_start_cp(cp) {
		len := if cp > 0xFFFF { 2 } else { 1 }
		return i64(cp), len
	}

	return -1, 0
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
	l.regex_is_in_character_class = false
	for !l.is_eof() {
		if l.is_line_terminator()
			|| (!l.regex_is_in_character_class && l.current_code_unit == ch(u8(`/`))) {
			break
		}

		if l.current_code_unit == ch(u8(`[`)) {
			l.regex_is_in_character_class = true
		} else if l.current_code_unit == ch(u8(`]`)) {
			l.regex_is_in_character_class = false
		}

		if l.match2(ch(u8(`\\`)), ch(u8(`/`))) || l.match2(ch(u8(`\\`)), ch(u8(`[`)))
			|| l.match2(ch(u8(`\\`)), ch(u8(`\\`)))
			|| (l.regex_is_in_character_class && l.match2(ch(u8(`\\`)), ch(u8(`]`)))) {
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

fn (mut l Lexer) next() Token {
	trivia_start := l.position
	in_template := l.template_states.len > 0
	mut line_has_token_yet := l.line_column > 1
	mut unterminated_comment := false
	mut token_message := ?string(none)

	if !in_template || l.template_states[l.template_states.len - 1].in_expression {
		for {
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

	mut identifier_value := ?Utf16String(none)

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
		start_cp, start_len := l.is_identifier_start()
		if start_cp >= 0 {
			has_escape := l.scan_identifier_body(start_len)
			if has_escape {
				identifier_value = l.build_identifier_value(value_start)
			}
			token_type = .private_identifier
		} else {
			token_type = .invalid
			token_message = "Start of private name '#' but not followed by valid identifier"
		}
	} else {
		start_cp, start_len := l.is_identifier_start()
		if start_cp >= 0 {
			has_escape := l.scan_identifier_body(start_len)

			if has_escape {
				decoded := l.build_identifier_value(value_start)
				if _ := keyword_from_str(decoded.data) {
					token_type = .escaped_keyword
				} else {
					token_type = .identifier
				}
				identifier_value = decoded
			} else {
				source_slice := l.source[value_start - 1..l.position - 1].clone()
				if kw := keyword_from_str(source_slice) {
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

			if l.match4(ch(u8(`>`)), ch(u8(`>`)), ch(u8(`>`)), ch(u8(`=`))) {
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
		message:                    token_message
	}
}

// === State save/restore ===

fn (mut l Lexer) save_state() {
	l.saved_states << SavedLexerState{
		position:           l.position
		current_code_unit:  l.current_code_unit
		eof:                l.eof
		line_number:        l.line_number
		line_column:        l.line_column
		current_token_type: l.current_token_type
		template_states:    l.template_states.clone()
	}
}

fn (mut l Lexer) load_state() {
	if l.saved_states.len == 0 {
		panic('No saved lexer state')
	}
	state := l.saved_states.pop()
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
