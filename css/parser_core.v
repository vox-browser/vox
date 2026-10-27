module css

import encoding as text_encoding
import math
import strconv
import strings
import platform

const replacement_character = u32(0xfffd)
const tokenizer_eof = u32(0xffffffff)

// --- CSS syntax character types ---

// https://www.w3.org/TR/css-syntax-3/#digit
fn is_digit(code_point u32) bool {
	// A code point between U+0030 DIGIT ZERO (0) and U+0039 DIGIT NINE (9) inclusive.
	return code_point >= 0x30 && code_point <= 0x39
}

// https://www.w3.org/TR/css-syntax-3/#hex-digit
fn is_hex_digit(code_point u32) bool {
	// A digit,
	// or a code point between U+0041 LATIN CAPITAL LETTER A (A) and U+0046 LATIN CAPITAL LETTER F (F) inclusive,
	// or a code point between U+0061 LATIN SMALL LETTER A (a) and U+0066 LATIN SMALL LETTER F (f) inclusive.
	return is_digit(code_point) || (code_point >= 0x41 && code_point <= 0x46)
		|| (code_point >= 0x61 && code_point <= 0x66)
}

// https://www.w3.org/TR/css-syntax-3/#ident-start-code-point
fn is_ident_start_code_point(code_point u32) bool {
	// A letter, a non-ASCII code point, or U+005F LOW LINE (_).
	// Note: the is_unicode condition is used to reject the Tokenizer's EOF codepoint.
	return is_ascii_alpha(code_point)
		|| (!is_ascii(code_point) && is_unicode(code_point)) || code_point == `_`
}

// https://www.w3.org/TR/css-syntax-3/#ident-code-point
fn is_ident_code_point(code_point u32) bool {
	// An ident-start code point, a digit, or U+002D HYPHEN-MINUS (-).
	return is_ident_start_code_point(code_point) || is_digit(code_point) || code_point == `-`
}

// https://www.w3.org/TR/css-syntax-3/#non-printable-code-point
fn is_non_printable_code_point(code_point u32) bool {
	return code_point <= 0x8 || code_point == 0xb
		|| (code_point >= 0xe && code_point <= 0x1f) || code_point == 0x7f
}

// https://www.w3.org/TR/css-syntax-3/#newline
fn is_newline(code_point u32) bool {
	// U+000A LINE FEED.
	// Note that U+000D CARRIAGE RETURN and U+000C FORM FEED are not included in this definition,
	// as they are converted to U+000A LINE FEED during preprocessing.
	return code_point == `\n`
}

// https://www.w3.org/TR/css-syntax-3/#whitespace
fn is_whitespace(code_point u32) bool {
	// A newline, U+0009 CHARACTER TABULATION, or U+0020 SPACE.
	return is_newline(code_point) || code_point == `\t` || code_point == ` `
}

// https://www.w3.org/TR/css-syntax-3/#maximum-allowed-code-point
fn is_greater_than_maximum_allowed_code_point(code_point u32) bool {
	// The greatest code point defined by Unicode: U+10FFFF.
	return code_point > 0x10ffff
}

fn is_ascii(code_point u32) bool {
	return code_point <= 0x7f
}

fn is_ascii_alpha(code_point u32) bool {
	return (code_point >= `A` && code_point <= `Z`) || (code_point >= `a` && code_point <= `z`)
}

fn is_unicode(code_point u32) bool {
	return code_point <= 0x10ffff
}

fn is_unicode_surrogate(code_point u32) bool {
	return code_point >= 0xd800 && code_point <= 0xdfff
}

fn equals_ignoring_ascii_case(left string, right string) bool {
	if left.len != right.len {
		return false
	}
	for i in 0 .. left.len {
		left_byte := left[i]
		right_byte := right[i]
		if left_byte == right_byte {
			continue
		}
		folded_left := if left_byte >= `A` && left_byte <= `Z` { left_byte + 32 } else { left_byte }
		folded_right := if right_byte >= `A` && right_byte <= `Z` { right_byte + 32 } else { right_byte }
		if folded_left != folded_right {
			return false
		}
	}
	return true
}

fn string_from_code_point(code_point u32) string {
	return rune(code_point).str()
}

fn append_code_point(mut builder strings.Builder, code_point u32) {
	builder.write_rune(rune(code_point))
}

// --- Token ---

pub enum TokenType {
	invalid
	end_of_file
	ident
	function
	at_keyword
	hash
	string
	bad_string
	url
	bad_url
	delim
	number
	percentage
	dimension
	whitespace
	cdo
	cdc
	colon
	semicolon
	comma
	open_square
	close_square
	open_paren
	close_paren
	open_curly
	close_curly
}

pub enum HashType {
	id
	unrestricted
}

pub struct TokenPosition {
pub mut:
	line   uint
	column uint
}

pub struct Token {
pub mut:
	type_                 TokenType = .invalid
	value                 string
	number_value_         Number
	hash_type_            HashType = .unrestricted
	original_source_text_ string
	start_position_       TokenPosition
	end_position_         TokenPosition
}

// Use this only to create types that don't have their own create_foo() methods below.
pub fn Token.create(type_ TokenType, original_source_text string) Token {
	assert type_ in [
		TokenType.invalid,
		.end_of_file,
		.bad_string,
		.bad_url,
		.cdo,
		.cdc,
		.colon,
		.semicolon,
		.comma,
		.open_square,
		.close_square,
		.open_paren,
		.close_paren,
		.open_curly,
		.close_curly,
	]

	return Token{
		type_:                 type_
		original_source_text_: original_source_text
	}
}

pub fn Token.create_ident(ident string, original_source_text string) Token {
	return Token{
		type_:                 .ident
		value:                 ident
		original_source_text_: original_source_text
	}
}

pub fn Token.create_function(name string, original_source_text string) Token {
	return Token{
		type_:                 .function
		value:                 name
		original_source_text_: original_source_text
	}
}

pub fn Token.create_at_keyword(name string, original_source_text string) Token {
	return Token{
		type_:                 .at_keyword
		value:                 name
		original_source_text_: original_source_text
	}
}

pub fn Token.create_hash(value string, hash_type HashType, original_source_text string) Token {
	return Token{
		type_:                 .hash
		value:                 value
		hash_type_:            hash_type
		original_source_text_: original_source_text
	}
}

pub fn Token.create_string(value string, original_source_text string) Token {
	return Token{
		type_:                 .string
		value:                 value
		original_source_text_: original_source_text
	}
}

pub fn Token.create_url(url string, original_source_text string) Token {
	return Token{
		type_:                 .url
		value:                 url
		original_source_text_: original_source_text
	}
}

pub fn Token.create_delim(delim u32, original_source_text string) Token {
	value := if delim <= 0x7f && original_source_text.len == 1
		&& original_source_text[0] == u8(delim) {
		original_source_text
	} else {
		string_from_code_point(delim)
	}
	return Token{
		type_:                 .delim
		value:                 value
		original_source_text_: original_source_text
	}
}

pub fn Token.create_number(value Number, original_source_text string) Token {
	return Token{
		type_:                 .number
		number_value_:         value
		original_source_text_: original_source_text
	}
}

pub fn Token.create_percentage(value Number, original_source_text string) Token {
	return Token{
		type_:                 .percentage
		number_value_:         value
		original_source_text_: original_source_text
	}
}

pub fn Token.create_dimension(value Number, unit string, original_source_text string) Token {
	return Token{
		type_:                 .dimension
		number_value_:         value
		value:                 unit
		original_source_text_: original_source_text
	}
}

pub fn Token.create_dimension_from_double(value f64, unit string, original_source_text string) Token {
	return Token.create_dimension(Number.with_type(.number, value), unit, original_source_text)
}

pub fn Token.create_whitespace(original_source_text string) Token {
	return Token{
		type_:                 .whitespace
		original_source_text_: original_source_text
	}
}

pub fn (token Token) token_type() TokenType {
	return token.type_
}

pub fn (token Token) is(type_ TokenType) bool {
	return token.type_ == type_
}

pub fn (token Token) ident() string {
	assert token.type_ == .ident
	return token.value
}

pub fn (token Token) function_name() string {
	assert token.type_ == .function
	return token.value
}

pub fn (token Token) delim() u32 {
	assert token.type_ == .delim
	if token.value.len == 0 {
		return 0
	}
	return u32(token.value.runes()[0])
}

pub fn (token Token) string_value() string {
	assert token.type_ == .string
	return token.value
}

pub fn (token Token) url() string {
	assert token.type_ == .url
	return token.value
}

pub fn (token Token) at_keyword() string {
	assert token.type_ == .at_keyword
	return token.value
}

pub fn (token Token) hash_type() HashType {
	assert token.type_ == .hash
	return token.hash_type_
}

pub fn (token Token) hash_value() string {
	assert token.type_ == .hash
	return token.value
}

pub fn (token Token) number() Number {
	assert token.type_ == .number || token.type_ == .dimension || token.type_ == .percentage
	return token.number_value_
}

fn clamp_to_single_precision(value f64) f64 {
	if value > f64(math.max_f32) {
		return f64(math.max_f32)
	}
	if value < -f64(math.max_f32) {
		return -f64(math.max_f32)
	}
	return value
}

pub fn (token Token) number_value() f64 {
	assert token.type_ == .number
	return clamp_to_single_precision(token.number_value_.value())
}

pub fn (token Token) to_integer() i64 {
	assert token.type_ == .number && token.number_value_.is_integer()
	return token.number_value_.integer_value()
}

pub fn (token Token) dimension_unit() string {
	assert token.type_ == .dimension
	return token.value
}

pub fn (token Token) dimension_value() f64 {
	assert token.type_ == .dimension
	return clamp_to_single_precision(token.number_value_.value())
}

pub fn (token Token) dimension_value_int() i64 {
	return token.number_value_.integer_value()
}

pub fn (token Token) percentage() f64 {
	assert token.type_ == .percentage
	return clamp_to_single_precision(token.number_value_.value())
}

pub fn (token Token) mirror_variant() TokenType {
	if token.is(.open_curly) {
		return .close_curly
	}
	if token.is(.open_square) {
		return .close_square
	}
	if token.is(.open_paren) {
		return .close_paren
	}
	return .invalid
}

pub fn (token Token) bracket_string() string {
	if token.is(.open_curly) {
		return '{'
	}
	if token.is(.close_curly) {
		return '}'
	}
	if token.is(.open_square) {
		return '['
	}
	if token.is(.close_square) {
		return ']'
	}
	if token.is(.open_paren) {
		return '('
	}
	if token.is(.close_paren) {
		return ')'
	}
	return ''
}

pub fn (token Token) bracket_mirror_string() string {
	if token.is(.open_curly) {
		return '}'
	}
	if token.is(.close_curly) {
		return '{'
	}
	if token.is(.open_square) {
		return ']'
	}
	if token.is(.close_square) {
		return '['
	}
	if token.is(.open_paren) {
		return ')'
	}
	if token.is(.close_paren) {
		return '('
	}
	return ''
}

pub fn (token Token) to_string() string {
	match token.type_ {
		.end_of_file {
			return ''
		}
		.ident {
			return serialize_an_identifier(token.ident())
		}
		.function {
			return '${serialize_an_identifier(token.function_name())}('
		}
		.at_keyword {
			return '@${serialize_an_identifier(token.at_keyword())}'
		}
		.hash {
			match token.hash_type_ {
				.id {
					return '#${serialize_an_identifier(token.hash_value())}'
				}
				.unrestricted {
					return '#${token.hash_value()}'
				}
			}
		}
		.string {
			return serialize_a_string(token.string_value())
		}
		.bad_string {
			return ''
		}
		.url {
			return serialize_a_url(token.url())
		}
		.bad_url {
			return 'url()'
		}
		.delim {
			return token.value
		}
		.number {
			return serialize_a_number(token.number_value_.value())
		}
		.percentage {
			return '${serialize_a_number(token.number_value_.value())}%'
		}
		.dimension {
			return '${serialize_a_number(token.number_value_.value())}${token.dimension_unit()}'
		}
		.whitespace {
			return ' '
		}
		.cdo {
			return '<!--'
		}
		.cdc {
			return '-->'
		}
		.colon {
			return ':'
		}
		.semicolon {
			return ';'
		}
		.comma {
			return ','
		}
		.open_square {
			return '['
		}
		.close_square {
			return ']'
		}
		.open_paren {
			return '('
		}
		.close_paren {
			return ')'
		}
		.open_curly {
			return '{'
		}
		.close_curly {
			return '}'
		}
		.invalid {
			panic('invalid token cannot be serialized')
		}
	}
}

pub fn (token Token) to_debug_string() string {
	match token.type_ {
		.invalid {
			panic('invalid token cannot be debug-serialized')
		}
		.end_of_file {
			return '__EOF__'
		}
		.ident {
			return 'Ident: ${token.ident()}'
		}
		.function {
			return 'Function: ${token.function_name()}'
		}
		.at_keyword {
			return 'AtKeyword: ${token.at_keyword()}'
		}
		.hash {
			hash_type := if token.hash_type_ == .unrestricted { 'Unrestricted' } else { 'Id' }
			return 'Hash: ${token.hash_value()} (hash_type: ${hash_type})'
		}
		.string {
			return 'String: ${token.string_value()}'
		}
		.bad_string {
			return 'BadString'
		}
		.url {
			return 'Url: ${token.url()}'
		}
		.bad_url {
			return 'BadUrl'
		}
		.delim {
			return 'Delim: ${token.value}'
		}
		.number {
			sign := if token.number_value_.value() > 0
				&& token.number_value_.is_integer_with_explicit_sign() {
				'+'
			} else {
				''
			}
			number_type := if token.number_value_.is_integer() { 'Integer' } else { 'Number' }
			return 'Number: ${sign}${token.number_value_.value()} (number_type: ${number_type})'
		}
		.percentage {
			number_type := if token.number_value_.is_integer() { 'Integer' } else { 'Number' }
			return 'Percentage: ${token.percentage()}% (number_type: ${number_type})'
		}
		.dimension {
			number_type := if token.number_value_.is_integer() { 'Integer' } else { 'Number' }
			return 'Dimension: ${token.dimension_value()}${token.dimension_unit()} (number_type: ${number_type})'
		}
		.whitespace {
			return 'Whitespace'
		}
		.cdo {
			return 'CDO'
		}
		.cdc {
			return 'CDC'
		}
		.colon {
			return 'Colon'
		}
		.semicolon {
			return 'Semicolon'
		}
		.comma {
			return 'Comma'
		}
		.open_square {
			return 'OpenSquare'
		}
		.close_square {
			return 'CloseSquare'
		}
		.open_paren {
			return 'OpenParen'
		}
		.close_paren {
			return 'CloseParen'
		}
		.open_curly {
			return 'OpenCurly'
		}
		.close_curly {
			return 'CloseCurly'
		}
	}
}

pub fn (token Token) original_source_text() string {
	return token.original_source_text_
}

pub fn (token Token) start_position() TokenPosition {
	return token.start_position_
}

pub fn (token Token) end_position() TokenPosition {
	return token.end_position_
}

pub fn (mut token Token) set_position_range(start TokenPosition, end TokenPosition) {
	token.start_position_ = start
	token.end_position_ = end
}

// --- Tokenizer ---

struct U32Twin {
pub mut:
	first  u32
	second u32
}

fn (mut twin U32Twin) set(index uint, value u32) {
	if index == 0 {
		twin.first = value
	}
	if index == 1 {
		twin.second = value
	}
}

struct U32Triplet {
pub mut:
	first  u32
	second u32
	third  u32
}

fn (mut triplet U32Triplet) set(index uint, value u32) {
	if index == 0 {
		triplet.first = value
	}
	if index == 1 {
		triplet.second = value
	}
	if index == 2 {
		triplet.third = value
	}
}

fn (triplet U32Triplet) to_twin_12() U32Twin {
	return U32Twin{
		first:  triplet.first
		second: triplet.second
	}
}

fn (triplet U32Triplet) to_twin_23() U32Twin {
	return U32Twin{
		first:  triplet.second
		second: triplet.third
	}
}

pub struct Tokenizer {
mut:
	decoded_input string
	input_arena   TokenizerInputArena
	index         int
	prev_index    int
	position      TokenPosition
	prev_position TokenPosition
}

// The tokenizer alone owns these numeric lookup tables. Tokens retain only
// decoded text, so the tables need neither tracing nor a lifetime beyond the
// tokenization call. Allocate both in one arena and release it at that boundary.
struct TokenizerInputArena {
mut:
	storage      voidptr
	code_points  &u32 = unsafe { nil }
	byte_offsets &int = unsafe { nil }
	len          int
}

fn C.malloc(uint) voidptr
fn C.free(voidptr)

fn TokenizerInputArena.new(input string) TokenizerInputArena {
	if input.len == 0 { return TokenizerInputArena{} }
	storage := unsafe { C.malloc(uint(input.len) * (sizeof(u32) + sizeof(int))) }
	if storage == unsafe { nil } { panic('Unable to allocate CSS tokenizer input') }
	mut arena := TokenizerInputArena{
		storage: storage
		code_points: unsafe { &u32(storage) }
		byte_offsets: unsafe { &int(&u8(storage) + uint(input.len) * sizeof(u32)) }
	}
	// ASCII code points and byte offsets are identical. Avoid constructing an
	// optional rune for each byte while filling these privately owned tables.
	mut all_ascii := true
	for byte in input {
		if byte >= 0x80 {
			all_ascii = false
			break
		}
	}
	if all_ascii {
		for offset, byte in input {
			unsafe {
				arena.code_points[offset] = u32(byte)
				arena.byte_offsets[offset] = offset
			}
		}
		arena.len = input.len
		return arena
	}
	mut byte_offset := 0
	for code_point in input.runes_iterator() {
		unsafe {
			arena.code_points[arena.len] = u32(code_point)
			arena.byte_offsets[arena.len] = byte_offset
		}
		arena.len++
		// input has already been decoded and filtered to valid UTF-8.
		byte_offset += utf8_char_len(input[byte_offset])
	}
	return arena
}

fn (mut arena TokenizerInputArena) release() {
	unsafe { C.free(arena.storage) }
	arena = TokenizerInputArena{}
}

fn decode_css_input(input string, encoding_name string) string {
	mut decoder := text_encoding.TextDecoder.construct(encoding_name,
		text_encoding.TextDecoderOptions{}) or {
		panic('VERIFY(TextCodec::decoder_for(${encoding_name}).has_value())')
	}
	// A fresh UTF-8 decoder maps every ASCII byte to itself. Keep the
	// constructor/label policy and a fresh, terminated destination owner;
	// neither the caller's buffer nor a substring view may back our result.
	if decoder.encoding() == 'utf-8' {
		mut ascii := true
		for byte in input {
			if byte >= 0x80 {
				ascii = false
				break
			}
		}
		if ascii {
			return input.clone()
		}
	}
	// CSS consumes UTF-8. Use the selected decoder's existing UTF-8 destination
	// instead of materializing the web TextDecoder's UTF-16 result and converting
	// it back. This fresh one-shot owner is discarded after the final item.
	mut output := text_encoding.TextDecoderOutputQueue{}
	decoder.process_an_item(input.bytes(), true, mut output) or {
		panic('MUST(decoder->to_utf8(input)): ${err.msg()}')
	}
	return decoder.serialize_io_queue(mut output) or {
		panic('MUST(decoder->to_utf8(input)): ${err.msg()}')
	}
}

// Upstream's tokenizer diagnostic is guarded by CSS_TOKENIZER_DEBUG. Production
// builds do not emit it, so the disabled branch intentionally has no side effect.
fn log_parse_error() {}

// https://www.w3.org/TR/css-syntax-3/#css-filter-code-points
fn filter_code_points(input string, encoding string) string {
	decoded_input := decode_css_input(input, encoding)

	// The decoder produces valid UTF-8: CR, FF and NUL occur only as single
	// bytes, and surrogate code points cannot occur. Probe bytes before paying
	// for scalar iteration in the replacement path below.
	mut contains_filterable := false
	for byte in decoded_input {
		if byte == `\r` || byte == `\f` || byte == 0 {
			contains_filterable = true
			break
		}
	}
	if !contains_filterable {
		return decoded_input
	}

	mut builder := strings.new_builder(input.len)
	mut last_was_carriage_return := false

	// To filter code points from a stream of (unfiltered) code points input:
	for code_point in decoded_input.runes_iterator() {
		code_point_u32 := u32(code_point)
		// Replace any U+000D CARRIAGE RETURN (CR) code points,
		// U+000C FORM FEED (FF) code points,
		// or pairs of U+000D CARRIAGE RETURN (CR) followed by U+000A LINE FEED (LF)
		// in input by a single U+000A LINE FEED (LF) code point.
		if code_point_u32 == `\r` {
			if last_was_carriage_return {
				builder.write_u8(`\n`)
			} else {
				last_was_carriage_return = true
			}
		} else {
			if last_was_carriage_return {
				builder.write_u8(`\n`)
			}

			if code_point_u32 == `\n` {
				if !last_was_carriage_return {
					builder.write_u8(`\n`)
				}
			} else if code_point_u32 == `\f` {
				builder.write_u8(`\n`)
			} else if code_point_u32 == 0 || is_unicode_surrogate(code_point_u32) {
				// Replace any U+0000 NULL or surrogate code points in input with U+FFFD REPLACEMENT CHARACTER.
				append_code_point(mut builder, replacement_character)
			} else {
				append_code_point(mut builder, code_point_u32)
			}

			last_was_carriage_return = false
		}
	}
	return builder.str()
}

pub fn Tokenizer.tokenize(input string, encoding string) []Token {
	mut tokenizer := Tokenizer.new(filter_code_points(input, encoding))
	defer { tokenizer.input_arena.release() }
	return tokenizer.tokenize_all()
}

fn Tokenizer.new(decoded_input string) Tokenizer {
	return Tokenizer{
		decoded_input: decoded_input
		input_arena: TokenizerInputArena.new(decoded_input)
	}
}

fn (mut tokenizer Tokenizer) tokenize_all() []Token {
	mut tokens := []Token{}
	for {
		if tokens.len % 256 == 0 { platform.cooperative_work_checkpoint() }
		token_start := tokenizer.position
		mut token := tokenizer.consume_a_token()
		token.set_position_range(token_start, tokenizer.position)
		tokens << token

		if token.is(.end_of_file) {
			return tokens
		}
	}
	return tokens
}

pub fn Tokenizer.create_eof_token() Token {
	return Token.create(.end_of_file, '')
}

fn is_eof(code_point u32) bool {
	return code_point == tokenizer_eof
}

fn is_quotation_mark(code_point u32) bool {
	return code_point == 0x22
}

fn is_hyphen_minus(code_point u32) bool {
	return code_point == 0x2d
}

fn is_number_sign(code_point u32) bool {
	return code_point == 0x23
}

fn is_reverse_solidus(code_point u32) bool {
	return code_point == 0x5c
}

fn is_apostrophe(code_point u32) bool {
	return code_point == 0x27
}

fn is_left_paren(code_point u32) bool {
	return code_point == 0x28
}

fn is_right_paren(code_point u32) bool {
	return code_point == 0x29
}

fn is_plus_sign(code_point u32) bool {
	return code_point == 0x2b
}

fn is_comma(code_point u32) bool {
	return code_point == 0x2c
}

fn is_full_stop(code_point u32) bool {
	return code_point == 0x2e
}

fn is_asterisk(code_point u32) bool {
	return code_point == 0x2a
}

fn is_solidus(code_point u32) bool {
	return code_point == 0x2f
}

fn is_colon(code_point u32) bool {
	return code_point == 0x3a
}

fn is_semicolon(code_point u32) bool {
	return code_point == 0x3b
}

fn is_less_than_sign(code_point u32) bool {
	return code_point == 0x3c
}

fn is_greater_than_sign(code_point u32) bool {
	return code_point == 0x3e
}

fn is_at(code_point u32) bool {
	return code_point == 0x40
}

fn is_open_square_bracket(code_point u32) bool {
	return code_point == 0x5b
}

fn is_closed_square_bracket(code_point u32) bool {
	return code_point == 0x5d
}

fn is_open_curly_bracket(code_point u32) bool {
	return code_point == 0x7b
}

fn is_closed_curly_bracket(code_point u32) bool {
	return code_point == 0x7d
}

fn is_percent(code_point u32) bool {
	return code_point == 0x25
}

fn is_exclamation_mark(code_point u32) bool {
	return code_point == 0x21
}

fn is_e(code_point u32) bool {
	return code_point == 0x65
}

fn is_upper_e(code_point u32) bool {
	return code_point == 0x45
}

fn (mut tokenizer Tokenizer) next_code_point() u32 {
	if tokenizer.index >= tokenizer.input_arena.len {
		return tokenizer_eof
	}
	tokenizer.prev_index = tokenizer.index
	tokenizer.index++
	code_point := unsafe { tokenizer.input_arena.code_points[tokenizer.prev_index] }

	tokenizer.prev_position = tokenizer.position
	if is_newline(code_point) {
		tokenizer.position.line++
		tokenizer.position.column = 0
	} else {
		tokenizer.position.column++
	}

	return code_point
}

fn (tokenizer Tokenizer) peek_code_point(offset uint) u32 {
	index := tokenizer.index + int(offset)
	if index >= tokenizer.input_arena.len {
		return tokenizer_eof
	}
	return unsafe { tokenizer.input_arena.code_points[index] }
}

fn (tokenizer Tokenizer) peek_twin() U32Twin {
	mut values := U32Twin{
		first:  tokenizer_eof
		second: tokenizer_eof
	}
	for i := 0; i < 2 && tokenizer.index + i < tokenizer.input_arena.len; i++ {
		values.set(uint(i), unsafe { tokenizer.input_arena.code_points[tokenizer.index + i] })
	}
	return values
}

fn (tokenizer Tokenizer) peek_triplet() U32Triplet {
	mut values := U32Triplet{
		first:  tokenizer_eof
		second: tokenizer_eof
		third:  tokenizer_eof
	}
	for i := 0; i < 3 && tokenizer.index + i < tokenizer.input_arena.len; i++ {
		values.set(uint(i), unsafe { tokenizer.input_arena.code_points[tokenizer.index + i] })
	}
	return values
}

fn (mut tokenizer Tokenizer) start_of_input_stream_twin() U32Twin {
	mut twin := U32Twin{}
	// FIXME: Reconsuming just to read the current code point again is weird.
	tokenizer.reconsume_current_input_code_point()
	twin.first = tokenizer.next_code_point()
	twin.second = tokenizer.peek_code_point(0)

	return twin
}

fn (mut tokenizer Tokenizer) start_of_input_stream_triplet() U32Triplet {
	mut triplet := U32Triplet{}
	// FIXME: Reconsuming just to read the current code point again is weird.
	tokenizer.reconsume_current_input_code_point()
	triplet.first = tokenizer.next_code_point()
	next_two := tokenizer.peek_twin()
	triplet.second = next_two.first
	triplet.third = next_two.second

	return triplet
}

// https://www.w3.org/TR/css-syntax-3/#consume-escaped-code-point
fn (mut tokenizer Tokenizer) consume_escaped_code_point() u32 {
	// This section describes how to consume an escaped code point.
	// It assumes that the U+005C REVERSE SOLIDUS (\) has already been consumed and that the next
	// input code point has already been verified to be part of a valid escape.
	// It will return a code point.

	// Consume the next input code point.
	input := tokenizer.next_code_point()

	// hex digit
	if is_hex_digit(input) {
		// At most six hexadecimal digits fit in 24 bits. Accumulate their value
		// directly while retaining the same code-point and whitespace consumption.
		mut unhexed := u32(0)
		mut digit := input
		mut counter := 0
		for {
			value := if is_digit(digit) {
				digit - u32(`0`)
			} else if digit >= `a` {
				digit - u32(`a`) + 10
			} else {
				digit - u32(`A`) + 10
			}
			unhexed = unhexed * 16 + value
			if counter == 5 || !is_hex_digit(tokenizer.peek_code_point(0)) {
				break
			}
			counter++
			digit = tokenizer.next_code_point()
		}

		// If the next input code point is whitespace, consume it as well.
		if is_whitespace(tokenizer.peek_code_point(0)) {
			_ = tokenizer.next_code_point()
		}

		// If this number is zero, or is for a surrogate, or is greater than the maximum allowed
		// code point, return U+FFFD REPLACEMENT CHARACTER.
		if unhexed == 0 || is_unicode_surrogate(unhexed)
			|| is_greater_than_maximum_allowed_code_point(unhexed) {
			return replacement_character
		}

		// Otherwise, return the code point with that value.
		return unhexed
	}

	// EOF
	if is_eof(input) {
		// This is a parse error. Return U+FFFD REPLACEMENT CHARACTER.
		log_parse_error()
		return replacement_character
	}

	// anything else
	// Return the current input code point.
	return input
}

// https://www.w3.org/TR/css-syntax-3/#consume-ident-like-token
fn (mut tokenizer Tokenizer) consume_an_ident_like_token() Token {
	// This section describes how to consume an ident-like token from a stream of code points.
	// It returns an <ident-token>, <function-token>, <url-token>, or <bad-url-token>.

	// Consume an ident sequence, and let string be the result.
	start_byte_offset := tokenizer.current_byte_offset()
	ident_string, had_escape := tokenizer.consume_an_ident_sequence_with_escape_flag()

	// If string's value is an ASCII case-insensitive match for "url", and the next input code
	// point is U+0028 LEFT PARENTHESIS ((), consume it.
	if equals_ignoring_ascii_case(ident_string, 'url')
		&& is_left_paren(tokenizer.peek_code_point(0)) {
		_ = tokenizer.next_code_point()

		// While the next two input code points are whitespace, consume the next input code point.
		for {
			maybe_whitespace := tokenizer.peek_twin()
			if !(is_whitespace(maybe_whitespace.first) && is_whitespace(maybe_whitespace.second)) {
				break
			}

			_ = tokenizer.next_code_point()
		}

		// If the next one or two input code points are U+0022 QUOTATION MARK ("), U+0027 APOSTROPHE ('),
		// or whitespace followed by U+0022 QUOTATION MARK (") or U+0027 APOSTROPHE ('), then create a
		// <function-token> with its value set to string and return it.
		next_two := tokenizer.peek_twin()
		if is_quotation_mark(next_two.first) || is_apostrophe(next_two.first)
			|| (is_whitespace(next_two.first) && (is_quotation_mark(next_two.second)
			|| is_apostrophe(next_two.second))) {
			return Token.create_function(ident_string, tokenizer.input_since(start_byte_offset))
		}

		// Otherwise, consume a url token, and return it.
		return tokenizer.consume_a_url_token(start_byte_offset)
	}

	// Otherwise, if the next input code point is U+0028 LEFT PARENTHESIS ((), consume it.
	if is_left_paren(tokenizer.peek_code_point(0)) {
		_ = tokenizer.next_code_point()

		// Create a <function-token> with its value set to string and return it.
		return Token.create_function(ident_string, tokenizer.input_since(start_byte_offset))
	}

	// Otherwise, create an <ident-token> with its value set to string and return it.
	// Unescaped identifiers already have the exact, terminated source spelling.
	// Keep one immutable string instead of copying the same span a second time.
	original_source_text := if had_escape {
		tokenizer.input_since(start_byte_offset)
	} else {
		ident_string
	}
	return Token.create_ident(ident_string, original_source_text)
}

// https://www.w3.org/TR/css-syntax-3/#consume-number
fn (mut tokenizer Tokenizer) consume_a_number() Number {
	// This section describes how to consume a number from a stream of code points.
	// It returns a numeric value, and a type which is either "integer" or "number".
	//
	// Note: This algorithm does not do the verification of the first few code points
	// that are necessary to ensure a number can be obtained from the stream. Ensure
	// that the stream starts with a number before calling this algorithm.

	// Execute the following steps in order:

	// 1. Initially set type to "integer". Let repr be the empty string.
	// Numeric spelling is a contiguous ASCII span of the filtered input.
	// Keep the same consumption algorithm and parse its terminated spelling.
	start_byte_offset := tokenizer.current_byte_offset()
	mut type_ := NumberType.integer
	mut integer_value := u64(0)
	mut integer_is_exact := true
	mut has_integer_digit := false
	mut fractional_integer := u64(0)
	mut fractional_fives := u64(1)
	mut fractional_bits := u32(0)
	mut fraction_is_exact := false
	mut has_exponent := false

	// 2. If the next input code point is U+002B PLUS SIGN (+) or U+002D HYPHEN-MINUS (-),
	// consume it and append it to repr.
	mut has_explicit_sign := false
	next_input := tokenizer.peek_code_point(0)
	if is_plus_sign(next_input) || is_hyphen_minus(next_input) {
		has_explicit_sign = true
		_ = tokenizer.next_code_point()
	}

	// 3. While the next input code point is a digit, consume it and append it to repr.
	for {
		digits := tokenizer.peek_code_point(0)
		if !is_digit(digits) {
			break
		}

		_ = tokenizer.next_code_point()
		has_integer_digit = true
		if integer_is_exact {
			// The previous value is at most 2^53, so this step cannot overflow u64.
			integer_value = integer_value * 10 + u64(digits - `0`)
			integer_is_exact = integer_value <= u64(9007199254740992)
		}
	}

	// 4. If the next 2 input code points are U+002E FULL STOP (.) followed by a digit, then:
	maybe_number := tokenizer.peek_twin()
	if is_full_stop(maybe_number.first) && is_digit(maybe_number.second) {
		// 1. Consume them.
		// 2. Append them to repr.
		_ = tokenizer.next_code_point()
		_ = tokenizer.next_code_point()
		fractional_integer = integer_value
		fractional_fives = 5
		fractional_bits = 1
		fraction_is_exact = integer_is_exact
		if fraction_is_exact {
			fractional_integer = fractional_integer * 10 + u64(maybe_number.second - `0`)
			fraction_is_exact = fractional_integer <= u64(9007199254740992)
		}

		// 3. Set type to "number".
		type_ = .number

		// 4. While the next input code point is a digit, consume it and append it to repr.
		for {
			digit := tokenizer.peek_code_point(0)
			if !is_digit(digit) {
				break
			}

			_ = tokenizer.next_code_point()
			if fraction_is_exact {
				// 5^22 still fits in the exact-integer range of binary64.
				if fractional_bits == 22 {
					fraction_is_exact = false
				} else {
					fractional_integer = fractional_integer * 10 + u64(digit - `0`)
					fraction_is_exact = fractional_integer <= u64(9007199254740992)
					fractional_fives *= 5
					fractional_bits++
				}
			}
		}
	}

	// 5. If the next 2 or 3 input code points are U+0045 LATIN CAPITAL LETTER E (E) or
	// U+0065 LATIN SMALL LETTER E (e), optionally followed by U+002D HYPHEN-MINUS (-)
	// or U+002B PLUS SIGN (+), followed by a digit, then:
	maybe_exp := tokenizer.peek_triplet()
	if (is_upper_e(maybe_exp.first) || is_e(maybe_exp.first))
		&& (((is_plus_sign(maybe_exp.second) || is_hyphen_minus(maybe_exp.second))
		&& is_digit(maybe_exp.third)) || is_digit(maybe_exp.second)) {
		has_exponent = true
		// 1. Consume them.
		// 2. Append them to repr.
		if is_plus_sign(maybe_exp.second) || is_hyphen_minus(maybe_exp.second) {
			if is_digit(maybe_exp.third) {
				_ = tokenizer.next_code_point()
				_ = tokenizer.next_code_point()
				_ = tokenizer.next_code_point()
			}
		} else if is_digit(maybe_exp.second) {
			_ = tokenizer.next_code_point()
			_ = tokenizer.next_code_point()
		}

		// 3. Set type to "number".
		type_ = .number

		// 4. While the next input code point is a digit, consume it and append it to repr.
		for {
			digits := tokenizer.peek_code_point(0)
			if !is_digit(digits) {
				break
			}

			_ = tokenizer.next_code_point()
		}
	}

	// 6. Convert repr to a number, and set the value to the returned value.
	// Integers through 2^53 and selected fractions need no rounding. Preserve
	// signed zero and keep the converter for all remaining numeric spellings.
	value := if type_ == .integer && has_integer_digit && integer_is_exact {
		if is_hyphen_minus(next_input) { -f64(integer_value) } else { f64(integer_value) }
	} else if fraction_is_exact && !has_exponent && fractional_integer % fractional_fives == 0 {
		// After cancelling 5^k, the remaining divisor is 2^k. Both operands
		// and their quotient are exact, independent of the FP rounding mode.
		fraction := f64(fractional_integer / fractional_fives) / f64(u64(1) << fractional_bits)
		if is_hyphen_minus(next_input) { -fraction } else { fraction }
	} else {
		tokenizer.convert_a_string_to_a_number(tokenizer.input_since(start_byte_offset))
	}

	// 7. Return value and type.
	if type_ == .integer && has_explicit_sign {
		return Number.with_type(.integer_with_explicit_sign, value)
	}
	return Number.with_type(type_, value)
}

// https://www.w3.org/TR/css-syntax-3/#convert-string-to-number
fn (tokenizer Tokenizer) convert_a_string_to_a_number(string_value string) f64 {
	_ = tokenizer
	// FIXME: We already found the whole part, fraction part and exponent during
	//        validation, we could probably skip
	return strconv.atof64(string_value) or { 0.0 }
}

// https://www.w3.org/TR/css-syntax-3/#consume-name
@[heap]
struct TokenizerNameBuilder {
mut:
	text strings.Builder
}

fn (mut tokenizer Tokenizer) consume_an_ident_sequence() string {
	name, _ := tokenizer.consume_an_ident_sequence_with_escape_flag()
	return name
}

fn (mut tokenizer Tokenizer) consume_an_ident_sequence_with_escape_flag() (string, bool) {
	// This section describes how to consume an ident sequence from a stream of code points.
	// It returns a string containing the largest name that can be formed from adjacent
	// code points in the stream, starting from the first.
	//
	// Note: This algorithm does not do the verification of the first few code points that
	// are necessary to ensure the returned code points would constitute an <ident-token>.
	// If that is the intended use, ensure that the stream starts with an ident sequence before
	// calling this algorithm.

	// Unescaped names already occupy one contiguous span of the filtered
	// input. Allocate a builder only when escape decoding changes that span.
	start_byte_offset := tokenizer.current_byte_offset()
	mut result := unsafe { &TokenizerNameBuilder(nil) }

	// Name code points cannot advance the line. Scan the initial unescaped
	// run without storing cursor state at every scalar, then publish the same
	// last-consumed and next-input positions as next_code_point().
	prefix_start := tokenizer.index
	mut prefix_end := prefix_start
	for prefix_end < tokenizer.input_arena.len {
		code_point := unsafe { tokenizer.input_arena.code_points[prefix_end] }
		if !is_ident_code_point(code_point) { break }
		prefix_end++
	}
	if prefix_end > prefix_start {
		tokenizer.prev_index = prefix_end - 1
		tokenizer.index = prefix_end
		tokenizer.prev_position = tokenizer.position
		tokenizer.prev_position.column += uint(prefix_end - prefix_start - 1)
		tokenizer.position.column += uint(prefix_end - prefix_start)
	}

	// Repeatedly consume the next input code point from the stream:
	for {
		input := tokenizer.next_code_point()

		if is_eof(input) {
			break
		}

		// name code point
		if is_ident_code_point(input) {
			// Append the code point to result.
			if result != unsafe { nil } {
				append_code_point(mut result.text, input)
			}
			continue
		}

		// Only a reverse solidus can start an escape. Other name terminators
		// already have the cursor state needed by the reconsume below.
		if is_reverse_solidus(input)
			&& Tokenizer.is_valid_escape_sequence(tokenizer.start_of_input_stream_twin()) {
			// Consume an escaped code point. Append the returned code point to result.
			if result == unsafe { nil } {
				result = &TokenizerNameBuilder{ text: strings.new_builder(16) }
				result.text.write_string(tokenizer.decoded_input[start_byte_offset..unsafe { tokenizer.input_arena.byte_offsets[tokenizer.prev_index] }])
			}
			append_code_point(mut result.text, tokenizer.consume_escaped_code_point())
			continue
		}

		// anything else
		// Reconsume the current input code point. Return result.
		tokenizer.reconsume_current_input_code_point()
		break
	}

	if result != unsafe { nil } {
		return result.text.str(), true
	}
	return tokenizer.input_since(start_byte_offset), false
}

// https://www.w3.org/TR/css-syntax-3/#consume-url-token
fn (mut tokenizer Tokenizer) consume_a_url_token(start_byte_offset int) Token {
	// This section describes how to consume a url token from a stream of code points.
	// It returns either a <url-token> or a <bad-url-token>.
	//
	// Note: This algorithm assumes that the initial "url(" has already been consumed.
	// This algorithm also assumes that it's being called to consume an "unquoted" value,
	// like url(foo). A quoted value, like url("foo"), is parsed as a <function-token>.
	// Consume an ident-like token automatically handles this distinction; this algorithm
	// shouldn't be called directly otherwise.

	// 1. Initially create a <url-token> with its value set to the empty string.
	mut builder := strings.new_builder(16)

	// 2. Consume as much whitespace as possible.
	tokenizer.consume_as_much_whitespace_as_possible()

	// 3. Repeatedly consume the next input code point from the stream:
	for {
		mut input := tokenizer.next_code_point()

		// U+0029 RIGHT PARENTHESIS ())
		if is_right_paren(input) {
			// Return the <url-token>.
			return Token.create_url(builder.str(), tokenizer.input_since(start_byte_offset))
		}

		// EOF
		if is_eof(input) {
			// This is a parse error. Return the <url-token>.
			log_parse_error()
			return Token.create_url(builder.str(), tokenizer.input_since(start_byte_offset))
		}

		// whitespace
		if is_whitespace(input) {
			// Consume as much whitespace as possible.
			tokenizer.consume_as_much_whitespace_as_possible()

			// If the next input code point is U+0029 RIGHT PARENTHESIS ()) or EOF, consume it
			// and return the <url-token> (if EOF was encountered, this is a parse error);
			input = tokenizer.peek_code_point(0)

			if is_right_paren(input) {
				_ = tokenizer.next_code_point()
				return Token.create_url(builder.str(), tokenizer.input_since(start_byte_offset))
			}

			if is_eof(input) {
				_ = tokenizer.next_code_point()
				log_parse_error()
				return Token.create_url(builder.str(), tokenizer.input_since(start_byte_offset))
			}

			// otherwise, consume the remnants of a bad url, create a <bad-url-token>, and return it.
			tokenizer.consume_the_remnants_of_a_bad_url()
			return Token.create(.bad_url, tokenizer.input_since(start_byte_offset))
		}

		// U+0022 QUOTATION MARK (")
		// U+0027 APOSTROPHE (')
		// U+0028 LEFT PARENTHESIS (()
		// non-printable code point
		if is_quotation_mark(input) || is_apostrophe(input) || is_left_paren(input)
			|| is_non_printable_code_point(input) {
			// This is a parse error. Consume the remnants of a bad url, create a <bad-url-token>, and return it.
			log_parse_error()
			tokenizer.consume_the_remnants_of_a_bad_url()
			return Token.create(.bad_url, tokenizer.input_since(start_byte_offset))
		}

		// U+005C REVERSE SOLIDUS (\)
		if is_reverse_solidus(input) {
			// If the stream starts with a valid escape,
			if Tokenizer.is_valid_escape_sequence(tokenizer.start_of_input_stream_twin()) {
				// consume an escaped code point and append the returned code point to the <url-token>'s value.
				append_code_point(mut builder, tokenizer.consume_escaped_code_point())
				continue
			} else {
				// Otherwise, this is a parse error.
				log_parse_error()
				// Consume the remnants of a bad url, create a <bad-url-token>, and return it.
				tokenizer.consume_the_remnants_of_a_bad_url()
				return Token.create(.bad_url, tokenizer.input_since(start_byte_offset))
			}
		}

		// anything else
		// Append the current input code point to the <url-token>'s value.
		append_code_point(mut builder, input)
	}
	return Token.create(.bad_url, tokenizer.input_since(start_byte_offset))
}

// https://www.w3.org/TR/css-syntax-3/#consume-remnants-of-bad-url
fn (mut tokenizer Tokenizer) consume_the_remnants_of_a_bad_url() {
	// This section describes how to consume the remnants of a bad url from a stream of code points,
	// "cleaning up" after the tokenizer realizes that it's in the middle of a <bad-url-token> rather
	// than a <url-token>. It returns nothing; its sole use is to consume enough of the input stream
	// to reach a recovery point where normal tokenizing can resume.

	// Repeatedly consume the next input code point from the stream:
	for {
		input := tokenizer.next_code_point()

		// U+0029 RIGHT PARENTHESIS ())
		// EOF
		if is_eof(input) || is_right_paren(input) {
			// Return.
			return
		}

		// the input stream starts with a valid escape
		if Tokenizer.is_valid_escape_sequence(tokenizer.start_of_input_stream_twin()) {
			// Consume an escaped code point.
			// This allows an escaped right parenthesis ("\)") to be encountered without ending
			// the <bad-url-token>. This is otherwise identical to the "anything else" clause.
			_ = tokenizer.consume_escaped_code_point()
		}

		// anything else
		// Do nothing.
	}
}

fn (mut tokenizer Tokenizer) consume_as_much_whitespace_as_possible() {
	for is_whitespace(tokenizer.peek_code_point(0)) {
		_ = tokenizer.next_code_point()
	}
}

fn (mut tokenizer Tokenizer) reconsume_current_input_code_point() {
	tokenizer.index = tokenizer.prev_index
	tokenizer.position = tokenizer.prev_position
}

// https://www.w3.org/TR/css-syntax-3/#consume-numeric-token
fn (mut tokenizer Tokenizer) consume_a_numeric_token() Token {
	// This section describes how to consume a numeric token from a stream of code points.
	// It returns either a <number-token>, <percentage-token>, or <dimension-token>.

	start_byte_offset := tokenizer.current_byte_offset()

	// Consume a number and let number be the result.
	number := tokenizer.consume_a_number()

	// If the next 3 input code points would start an ident sequence, then:
	if Tokenizer.would_start_an_ident_sequence(tokenizer.peek_triplet()) {
		// 1. Create a <dimension-token> with the same value and type flag as number,
		//    and a unit set initially to the empty string.

		// 2. Consume an ident sequence. Set the <dimension-token>'s unit to the returned value.
		unit := tokenizer.consume_an_ident_sequence()
		assert unit.len > 0
		// NOTE: We intentionally store this in the `value`, to save space.

		// 3. Return the <dimension-token>.
		return Token.create_dimension(number, unit, tokenizer.input_since(start_byte_offset))
	}

	// Otherwise, if the next input code point is U+0025 PERCENTAGE SIGN (%), consume it.
	if is_percent(tokenizer.peek_code_point(0)) {
		_ = tokenizer.next_code_point()

		// Create a <percentage-token> with the same value as number, and return it.
		return Token.create_percentage(number, tokenizer.input_since(start_byte_offset))
	}

	// Otherwise, create a <number-token> with the same value and type flag as number, and return it.
	return Token.create_number(number, tokenizer.input_since(start_byte_offset))
}

// https://www.w3.org/TR/css-syntax-3/#starts-with-a-number
pub fn Tokenizer.would_start_a_number(values U32Triplet) bool {
	// This section describes how to check if three code points would start a number.
	// The algorithm described here can be called explicitly with three code points,
	// or can be called with the input stream itself. In the latter case, the three
	// code points in question are the current input code point and the next two input
	// code points, in that order.
	//
	// Note: This algorithm will not consume any additional code points.

	// Look at the first code point:

	// U+002B PLUS SIGN (+)
	// U+002D HYPHEN-MINUS (-)
	if is_plus_sign(values.first) || is_hyphen_minus(values.first) {
		// If the second code point is a digit, return true.
		if is_digit(values.second) {
			return true
		}

		// Otherwise, if the second code point is a U+002E FULL STOP (.) and the third
		// code point is a digit, return true.
		if is_full_stop(values.second) && is_digit(values.third) {
			return true
		}

		// Otherwise, return false.
		return false
	}

	// U+002E FULL STOP (.)
	if is_full_stop(values.first) {
		// If the second code point is a digit, return true. Otherwise, return false.
		return is_digit(values.second)
	}

	// digit
	if is_digit(values.first) {
		// Return true.
		return true
	}

	// anything else
	// Return false.
	return false
}

// https://www.w3.org/TR/css-syntax-3/#starts-with-a-valid-escape
pub fn Tokenizer.is_valid_escape_sequence(values U32Twin) bool {
	// This section describes how to check if two code points are a valid escape.
	// The algorithm described here can be called explicitly with two code points,
	// or can be called with the input stream itself. In the latter case, the two
	// code points in question are the current input code point and the next input
	// code point, in that order.
	//
	// Note: This algorithm will not consume any additional code point.

	// If the first code point is not U+005C REVERSE SOLIDUS (\), return false.
	if !is_reverse_solidus(values.first) {
		return false
	}

	// Otherwise, if the second code point is a newline, return false.
	if is_newline(values.second) {
		return false
	}

	// Otherwise, return true.
	return true
}

// https://www.w3.org/TR/css-syntax-3/#would-start-an-identifier
pub fn Tokenizer.would_start_an_ident_sequence(values U32Triplet) bool {
	// This section describes how to check if three code points would start an ident sequence.
	// The algorithm described here can be called explicitly with three code points, or
	// can be called with the input stream itself. In the latter case, the three code
	// points in question are the current input code point and the next two input code
	// points, in that order.
	//
	// Note: This algorithm will not consume any additional code points.

	// Look at the first code point:

	// U+002D HYPHEN-MINUS
	if is_hyphen_minus(values.first) {
		// If the second code point is a name-start code point or a U+002D HYPHEN-MINUS,
		// or the second and third code points are a valid escape, return true.
		if is_ident_start_code_point(values.second) || is_hyphen_minus(values.second)
			|| Tokenizer.is_valid_escape_sequence(values.to_twin_23()) {
			return true
		}
		// Otherwise, return false.
		return false
	}

	// name-start code point
	if is_ident_start_code_point(values.first) {
		// Return true.
		return true
	}

	// U+005C REVERSE SOLIDUS (\)
	if is_reverse_solidus(values.first) {
		// If the first and second code points are a valid escape, return true.
		if Tokenizer.is_valid_escape_sequence(values.to_twin_12()) {
			return true
		}
		// Otherwise, return false.
		return false
	}

	// anything else
	// Return false.
	return false
}

// https://www.w3.org/TR/css-syntax-3/#consume-string-token
fn (mut tokenizer Tokenizer) consume_string_token(ending_code_point u32) Token {
	// This section describes how to consume a string token from a stream of code points.
	// It returns either a <string-token> or <bad-string-token>.
	//
	// This algorithm may be called with an ending code point, which denotes the code point
	// that ends the string. If an ending code point is not specified, the current input
	// code point is used.

	// Initially create a <string-token> with its value set to the empty string.
	original_source_text_start_byte_offset_including_quotation_mark := tokenizer.current_byte_offset() - 1
	mut builder := strings.new_builder(16)

	// Repeatedly consume the next input code point from the stream:
	for {
		input := tokenizer.next_code_point()

		// ending code point
		if input == ending_code_point {
			return Token.create_string(builder.str(),
				tokenizer.input_since(original_source_text_start_byte_offset_including_quotation_mark))
		}

		// EOF
		if is_eof(input) {
			// This is a parse error. Return the <string-token>.
			log_parse_error()
			return Token.create_string(builder.str(),
				tokenizer.input_since(original_source_text_start_byte_offset_including_quotation_mark))
		}

		// newline
		if is_newline(input) {
			// This is a parse error. Reconsume the current input code point, create a
			// <bad-string-token>, and return it.
			tokenizer.reconsume_current_input_code_point()
			return Token.create(.bad_string,
				tokenizer.input_since(original_source_text_start_byte_offset_including_quotation_mark))
		}

		// U+005C REVERSE SOLIDUS (\)
		if is_reverse_solidus(input) {
			// If the next input code point is EOF, do nothing.
			next_input := tokenizer.peek_code_point(0)
			if is_eof(next_input) {
				continue
			}

			// Otherwise, if the next input code point is a newline, consume it.
			if is_newline(next_input) {
				_ = tokenizer.next_code_point()
				continue
			}

			// Otherwise, (the stream starts with a valid escape) consume an escaped code
			// point and append the returned code point to the <string-token>'s value.
			escaped := tokenizer.consume_escaped_code_point()
			append_code_point(mut builder, escaped)
			continue
		}

		// anything else
		// Append the current input code point to the <string-token>'s value.
		append_code_point(mut builder, input)
	}
	return Token.create(.bad_string,
		tokenizer.input_since(original_source_text_start_byte_offset_including_quotation_mark))
}

// https://www.w3.org/TR/css-syntax-3/#consume-comment
fn (mut tokenizer Tokenizer) consume_comments() {
	// This section describes how to consume comments from a stream of code points.
	// It returns nothing.

	for {
		// If the next two input code point are U+002F SOLIDUS (/) followed by a U+002A ASTERISK (*),
		// consume them and all following code points up to and including the first U+002A ASTERISK (*)
		// followed by a U+002F SOLIDUS (/), or up to an EOF code point. Return to the start of this step.
		//
		// If the preceding paragraph ended by consuming an EOF code point, this is a parse error.
		//
		// Return nothing.
		twin := tokenizer.peek_twin()
		if !(is_solidus(twin.first) && is_asterisk(twin.second)) {
			return
		}

		_ = tokenizer.next_code_point()
		_ = tokenizer.next_code_point()

		for {
			twin_inner := tokenizer.peek_twin()
			if is_eof(twin_inner.first) || is_eof(twin_inner.second) {
				log_parse_error()
				return
			}

			if is_asterisk(twin_inner.first) && is_solidus(twin_inner.second) {
				_ = tokenizer.next_code_point()
				_ = tokenizer.next_code_point()
				break
			}

			_ = tokenizer.next_code_point()
		}
	}
}

// https://www.w3.org/TR/css-syntax-3/#consume-token
fn (mut tokenizer Tokenizer) consume_a_token() Token {
	// This section describes how to consume a token from a stream of code points.
	// It will return a single token of any type.

	start_byte_offset := tokenizer.current_byte_offset()

	// A comment always consumes its two opening code points. Keep comments as
	// whitespace for custom-property serialization, and leave other tokens alone.
	if tokenizer.peek_code_point(0) == `/` && tokenizer.peek_code_point(1) == `*` {
		tokenizer.consume_comments()
		return Token.create_whitespace(tokenizer.input_since(start_byte_offset))
	}

	// Consume the next input code point.
	input := tokenizer.next_code_point()

	// whitespace
	if is_whitespace(input) {
		// Consume as much whitespace as possible. Return a <whitespace-token>.
		tokenizer.consume_as_much_whitespace_as_possible()
		return Token.create_whitespace(tokenizer.input_since(start_byte_offset))
	}

	// U+0022 QUOTATION MARK (")
	if is_quotation_mark(input) {
		// Consume a string token and return it.
		return tokenizer.consume_string_token(input)
	}

	// U+0023 NUMBER SIGN (#)
	if is_number_sign(input) {
		// If the next input code point is an ident code point or the next two input code points
		// are a valid escape, then:
		next_input := tokenizer.peek_code_point(0)
		maybe_escape := tokenizer.peek_twin()

		if is_ident_code_point(next_input) || Tokenizer.is_valid_escape_sequence(maybe_escape) {
			// 1. Create a <hash-token>.

			// 2. If the next 3 input code points would start an ident sequence, set the <hash-token>'s
			//    type flag to "id".
			mut hash_type := HashType.unrestricted
			if Tokenizer.would_start_an_ident_sequence(tokenizer.peek_triplet()) {
				hash_type = .id
			}

			// 3. Consume an ident sequence, and set the <hash-token>'s value to the returned string.
			value := tokenizer.consume_an_ident_sequence()

			// 4. Return the <hash-token>.
			return Token.create_hash(value, hash_type, tokenizer.input_since(start_byte_offset))
		}

		// Otherwise, return a <delim-token> with its value set to the current input code point.
		return Token.create_delim(input, tokenizer.input_since(start_byte_offset))
	}

	// U+0027 APOSTROPHE (')
	if is_apostrophe(input) {
		// Consume a string token and return it.
		return tokenizer.consume_string_token(input)
	}

	// U+0028 LEFT PARENTHESIS (()
	if is_left_paren(input) {
		// Return a <(-token>.
		return Token.create(.open_paren, tokenizer.input_since(start_byte_offset))
	}

	// U+0029 RIGHT PARENTHESIS ())
	if is_right_paren(input) {
		// Return a <)-token>.
		return Token.create(.close_paren, tokenizer.input_since(start_byte_offset))
	}

	// U+002B PLUS SIGN (+)
	if is_plus_sign(input) {
		// If the input stream starts with a number, reconsume the current input code point,
		// consume a numeric token and return it.
		if Tokenizer.would_start_a_number(tokenizer.start_of_input_stream_triplet()) {
			tokenizer.reconsume_current_input_code_point()
			return tokenizer.consume_a_numeric_token()
		}

		// Otherwise, return a <delim-token> with its value set to the current input code point.
		return Token.create_delim(input, tokenizer.input_since(start_byte_offset))
	}

	// U+002C COMMA (,)
	if is_comma(input) {
		// Return a <comma-token>.
		return Token.create(.comma, tokenizer.input_since(start_byte_offset))
	}

	// U+002D HYPHEN-MINUS (-)
	if is_hyphen_minus(input) {
		// If the input stream starts with a number, reconsume the current input code point,
		// consume a numeric token, and return it.
		if Tokenizer.would_start_a_number(tokenizer.start_of_input_stream_triplet()) {
			tokenizer.reconsume_current_input_code_point()
			return tokenizer.consume_a_numeric_token()
		}

		// Otherwise, if the next 2 input code points are U+002D HYPHEN-MINUS U+003E
		// GREATER-THAN SIGN (->), consume them and return a <CDC-token>.
		next_twin := tokenizer.peek_twin()
		if is_hyphen_minus(next_twin.first) && is_greater_than_sign(next_twin.second) {
			_ = tokenizer.next_code_point()
			_ = tokenizer.next_code_point()

			return Token.create(.cdc, tokenizer.input_since(start_byte_offset))
		}

		// Otherwise, if the input stream starts with an identifier, reconsume the current
		// input code point, consume an ident-like token, and return it.
		if Tokenizer.would_start_an_ident_sequence(tokenizer.start_of_input_stream_triplet()) {
			tokenizer.reconsume_current_input_code_point()
			return tokenizer.consume_an_ident_like_token()
		}

		// Otherwise, return a <delim-token> with its value set to the current input code point.
		return Token.create_delim(input, tokenizer.input_since(start_byte_offset))
	}

	// U+002E FULL STOP (.)
	if is_full_stop(input) {
		// If the input stream starts with a number, reconsume the current input code point,
		// consume a numeric token, and return it.
		if Tokenizer.would_start_a_number(tokenizer.start_of_input_stream_triplet()) {
			tokenizer.reconsume_current_input_code_point()
			return tokenizer.consume_a_numeric_token()
		}

		// Otherwise, return a <delim-token> with its value set to the current input code point.
		return Token.create_delim(input, tokenizer.input_since(start_byte_offset))
	}

	// U+003A COLON (:)
	if is_colon(input) {
		// Return a <colon-token>.
		return Token.create(.colon, tokenizer.input_since(start_byte_offset))
	}

	// U+003B SEMICOLON (;)
	if is_semicolon(input) {
		// Return a <semicolon-token>.
		return Token.create(.semicolon, tokenizer.input_since(start_byte_offset))
	}

	// U+003C LESS-THAN SIGN (<)
	if is_less_than_sign(input) {
		// If the next 3 input code points are U+0021 EXCLAMATION MARK U+002D HYPHEN-MINUS
		// U+002D HYPHEN-MINUS (!--), consume them and return a <CDO-token>.
		maybe_cdo := tokenizer.peek_triplet()
		if is_exclamation_mark(maybe_cdo.first) && is_hyphen_minus(maybe_cdo.second)
			&& is_hyphen_minus(maybe_cdo.third) {
			_ = tokenizer.next_code_point()
			_ = tokenizer.next_code_point()
			_ = tokenizer.next_code_point()

			return Token.create(.cdo, tokenizer.input_since(start_byte_offset))
		}

		// Otherwise, return a <delim-token> with its value set to the current input code point.
		return Token.create_delim(input, tokenizer.input_since(start_byte_offset))
	}

	// U+0040 COMMERCIAL AT (@)
	if is_at(input) {
		// If the next 3 input code points would start an ident sequence, consume an ident sequence, create
		// an <at-keyword-token> with its value set to the returned value, and return it.
		if Tokenizer.would_start_an_ident_sequence(tokenizer.peek_triplet()) {
			name := tokenizer.consume_an_ident_sequence()
			return Token.create_at_keyword(name, tokenizer.input_since(start_byte_offset))
		}

		// Otherwise, return a <delim-token> with its value set to the current input code point.
		return Token.create_delim(input, tokenizer.input_since(start_byte_offset))
	}

	// U+005B LEFT SQUARE BRACKET ([)
	if is_open_square_bracket(input) {
		// Return a <[-token>.
		return Token.create(.open_square, tokenizer.input_since(start_byte_offset))
	}

	// U+005C REVERSE SOLIDUS (\)
	if is_reverse_solidus(input) {
		// If the input stream starts with a valid escape, reconsume the current input code point,
		// consume an ident-like token, and return it.
		if Tokenizer.is_valid_escape_sequence(tokenizer.start_of_input_stream_twin()) {
			tokenizer.reconsume_current_input_code_point()
			return tokenizer.consume_an_ident_like_token()
		}

		// Otherwise, this is a parse error. Return a <delim-token> with its value set to the
		// current input code point.
		log_parse_error()
		return Token.create_delim(input, tokenizer.input_since(start_byte_offset))
	}

	// U+005D RIGHT SQUARE BRACKET (])
	if is_closed_square_bracket(input) {
		// Return a <]-token>.
		return Token.create(.close_square, tokenizer.input_since(start_byte_offset))
	}

	// U+007B LEFT CURLY BRACKET ({)
	if is_open_curly_bracket(input) {
		// Return a <{-token>.
		return Token.create(.open_curly, tokenizer.input_since(start_byte_offset))
	}

	// U+007D RIGHT CURLY BRACKET (})
	if is_closed_curly_bracket(input) {
		// Return a <}-token>.
		return Token.create(.close_curly, tokenizer.input_since(start_byte_offset))
	}

	// digit
	if is_digit(input) {
		// Reconsume the current input code point, consume a numeric token, and return it.
		tokenizer.reconsume_current_input_code_point()
		return tokenizer.consume_a_numeric_token()
	}

	// name-start code point
	if is_ident_start_code_point(input) {
		// Reconsume the current input code point, consume an ident-like token, and return it.
		tokenizer.reconsume_current_input_code_point()
		return tokenizer.consume_an_ident_like_token()
	}

	// EOF
	if is_eof(input) {
		// Return an <EOF-token>.
		return Tokenizer.create_eof_token()
	}

	// anything else
	// Return a <delim-token> with its value set to the current input code point.
	return Token.create_delim(input, tokenizer.input_since(start_byte_offset))
}

fn (tokenizer Tokenizer) current_byte_offset() int {
	if tokenizer.index >= tokenizer.input_arena.len {
		return tokenizer.decoded_input.len
	}
	return unsafe { tokenizer.input_arena.byte_offsets[tokenizer.index] }
}

// Common token spellings are immutable, individually terminated literals.
// Returning them avoids a heap string for each punctuation mark or ASCII name.
const tokenizer_ascii_source_text = [
	' ', '!', '"', '#', '\$', '%', '&', '\'',
	'(', ')', '*', '+', ',', '-', '.', '/',
	'0', '1', '2', '3', '4', '5', '6', '7',
	'8', '9', ':', ';', '<', '=', '>', '?',
	'@', 'A', 'B', 'C', 'D', 'E', 'F', 'G',
	'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O',
	'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W',
	'X', 'Y', 'Z', '[', '\\', ']', '^', '_',
	'`', 'a', 'b', 'c', 'd', 'e', 'f', 'g',
	'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o',
	'p', 'q', 'r', 's', 't', 'u', 'v', 'w',
	'x', 'y', 'z', '{', '|', '}', '~',
]!

fn (tokenizer Tokenizer) input_since(offset int) string {
	mut start := offset
	if start < 0 {
		start = 0
	}
	mut end := tokenizer.current_byte_offset()
	if end < start {
		end = start
	}
	if end == start {
		return ''
	}
	if end == start + 1 {
		byte := tokenizer.decoded_input[start]
		if byte >= 0x20 && byte <= 0x7e {
			return tokenizer_ascii_source_text[int(byte) - 0x20]
		}
		if byte == `\n` { return '\n' }
		if byte == `\t` { return '\t' }
	}
	return tokenizer.decoded_input[start..end]
}

pub fn tokenize_css(input string, encoding string) []Token {
	return Tokenizer.tokenize(input, encoding)
}

// --- Component values and parser types ---

pub struct InvalidRuleLocationError {
pub:
	outer_rule_name string
	inner_rule_name string
}

fn report_invalid_rule_location(error InvalidRuleLocationError) {
	parser_report_error(ParsingError(error))
}

pub type AtRuleVisitor = fn (AtRule)

pub type QualifiedRuleVisitor = fn (QualifiedRule)

pub type RuleVisitor = fn (Rule)

pub type DeclarationVisitor = fn (Declaration)

// https://drafts.csswg.org/css-syntax/#css-rule
pub type Rule = AtRule | QualifiedRule

pub type RuleOrListOfDeclarations = DeclarationList | RuleNode

pub type ComponentValuePayload = Function
	| GuaranteedInvalidValue
	| RawComponentValue
	| SimpleBlock
	| Token

pub struct RawComponentValue {
pub mut:
	text string
}

pub struct RuleNode {
pub mut:
	rule Rule
}

pub struct DeclarationList {
pub mut:
	declarations []Declaration
}

// https://drafts.csswg.org/css-syntax/#ref-for-at-rule%E2%91%A0%E2%91%A1
pub struct AtRule {
pub mut:
	name                                  string
	prelude                               []ComponentValue
	child_rules_and_lists_of_declarations []RuleOrListOfDeclarations
	is_block_rule                         bool
}

// https://drafts.csswg.org/css-syntax/#qualified-rule
pub struct QualifiedRule {
pub mut:
	prelude      []ComponentValue
	declarations []Declaration
	child_rules  []RuleOrListOfDeclarations
}

// https://drafts.csswg.org/css-syntax/#declaration
pub struct Declaration {
pub mut:
	name                string
	value               []ComponentValue
	important           Important = .no
	original_value_text ?string
	original_full_text  ?string
}

pub struct SubstitutionFunctionsPresence {
pub mut:
	attr            bool
	custom_function bool
	env             bool
	if_             bool
	inherit         bool
	var             bool
}

pub fn (presence SubstitutionFunctionsPresence) has_any() bool {
	return presence.attr || presence.custom_function || presence.env || presence.if_
		|| presence.inherit || presence.var
}

// https://drafts.csswg.org/css-syntax/#component-value
pub struct ComponentValue {
pub mut:
	value        ComponentValuePayload = Token{}
	attr_tainted bool
}

pub fn (component_value ComponentValue) contains_attr_tainted_value() bool {
	if component_value.attr_tainted {
		return true
	}
	if component_value.is_function() {
		return component_value.function().value.any(it.contains_attr_tainted_value())
	}
	if component_value.is_block() {
		return component_value.block().value.any(it.contains_attr_tainted_value())
	}
	return false
}

pub fn (mut component_value ComponentValue) set_attr_tainted() {
	component_value.attr_tainted = true
}

pub fn ComponentValue.from_token(token Token) ComponentValue {
	return ComponentValue{
		value: token
	}
}

pub fn ComponentValue.new(text string) ComponentValue {
	return ComponentValue{
		value: RawComponentValue{
			text: text
		}
	}
}

pub fn ComponentValue.from_function(function Function) ComponentValue {
	return ComponentValue{
		value: function
	}
}

pub fn ComponentValue.from_block(block SimpleBlock) ComponentValue {
	return ComponentValue{
		value: block
	}
}

pub fn ComponentValue.from_guaranteed_invalid(invalid GuaranteedInvalidValue) ComponentValue {
	return ComponentValue{
		value: invalid
	}
}

pub fn (component_value ComponentValue) is_block() bool {
	return component_value.value is SimpleBlock
}

pub fn (component_value ComponentValue) block() SimpleBlock {
	if component_value.value is SimpleBlock {
		return component_value.value
	}
	panic('component value is not a block')
}

// True if this component value is a {}-block. In this port's component-value stream, a {}-block is
// a single SimpleBlock (the normalizer pre-parses blocks), so rule consumption must detect it this
// way rather than checking for a raw <{-token>.
pub fn (component_value ComponentValue) is_curly_block() bool {
	return component_value.is_block() && component_value.block().is_curly()
}

pub fn (component_value ComponentValue) is_function() bool {
	return component_value.value is Function
}

pub fn (component_value ComponentValue) is_function_named(name string) bool {
	return component_value.is_function()
		&& equals_ignoring_ascii_case(component_value.function().name, name)
}

pub fn (component_value ComponentValue) function() Function {
	if component_value.value is Function {
		return component_value.value
	}
	panic('component value is not a function')
}

pub fn (component_value ComponentValue) is_token() bool {
	return component_value.value is Token
}

pub fn (component_value ComponentValue) is(type_ TokenType) bool {
	return component_value.is_token() && component_value.token().is(type_)
}

pub fn (component_value ComponentValue) is_delim(delim u32) bool {
	return component_value.is(.delim) && component_value.token().delim() == delim
}

pub fn (component_value ComponentValue) is_ident(ident string) bool {
	return component_value.is(.ident)
		&& equals_ignoring_ascii_case(component_value.token().ident(), ident)
}

pub fn (component_value ComponentValue) token() Token {
	if component_value.value is Token {
		return component_value.value
	}
	panic('component value is not a token')
}

pub fn (component_value ComponentValue) is_guaranteed_invalid() bool {
	return component_value.value is GuaranteedInvalidValue
}

pub fn (component_value ComponentValue) contains_guaranteed_invalid_value() bool {
	match component_value.value {
		Token {
			return false
		}
		RawComponentValue {
			return false
		}
		SimpleBlock {
			for item in component_value.value.value {
				if item.contains_guaranteed_invalid_value() {
					return true
				}
			}
			return false
		}
		Function {
			for item in component_value.value.value {
				if item.contains_guaranteed_invalid_value() {
					return true
				}
			}
			return false
		}
		GuaranteedInvalidValue {
			return true
		}
	}
}

pub fn (component_value ComponentValue) to_string() string {
	match component_value.value {
		Token {
			return component_value.value.to_string()
		}
		RawComponentValue {
			return component_value.value.text
		}
		SimpleBlock {
			return component_value.value.to_string()
		}
		Function {
			return component_value.value.to_string()
		}
		GuaranteedInvalidValue {
			return component_value.value.to_string()
		}
	}
}

pub fn (component_value ComponentValue) to_debug_string() string {
	match component_value.value {
		Token {
			return 'Token: ${component_value.value.to_debug_string()}'
		}
		RawComponentValue {
			return 'Raw: ${component_value.value.text}'
		}
		SimpleBlock {
			return 'Block: ${component_value.value.to_string()}'
		}
		Function {
			return 'Function: ${component_value.value.to_string()}'
		}
		GuaranteedInvalidValue {
			return 'Guaranteed-invalid value'
		}
	}
}

pub fn (component_value ComponentValue) original_source_text() string {
	match component_value.value {
		Token {
			return component_value.value.original_source_text()
		}
		RawComponentValue {
			return component_value.value.text
		}
		SimpleBlock {
			return component_value.value.original_source_text()
		}
		Function {
			return component_value.value.original_source_text()
		}
		GuaranteedInvalidValue {
			return component_value.value.original_source_text()
		}
	}
}

// https://drafts.csswg.org/css-syntax/#simple-block
pub struct SimpleBlock {
pub mut:
	token     Token
	value     []ComponentValue
	end_token Token
}

pub fn (block SimpleBlock) is_curly() bool {
	return block.token.is(.open_curly)
}

pub fn (block SimpleBlock) is_paren() bool {
	return block.token.is(.open_paren)
}

pub fn (block SimpleBlock) is_square() bool {
	return block.token.is(.open_square)
}

pub fn (block SimpleBlock) to_string() string {
	mut builder := strings.new_builder(16)

	builder.write_string(block.token.bracket_string())
	for item in block.value {
		builder.write_string(item.to_string())
	}
	builder.write_string(block.token.bracket_mirror_string())

	return builder.str()
}

pub fn (block SimpleBlock) original_source_text() string {
	mut builder := strings.new_builder(16)
	builder.write_string(block.token.original_source_text())
	for component_value in block.value {
		builder.write_string(component_value.original_source_text())
	}
	builder.write_string(block.end_token.original_source_text())
	return builder.str()
}

// https://drafts.csswg.org/css-syntax/#function
pub struct Function {
pub mut:
	name       string
	value      []ComponentValue
	name_token Token
	end_token  Token
}

pub fn (function Function) to_string() string {
	mut builder := strings.new_builder(16)

	builder.write_string(serialize_an_identifier(function.name))
	builder.write_u8(`(`)
	for item in function.value {
		builder.write_string(item.to_string())
	}
	builder.write_u8(`)`)

	return builder.str()
}

pub fn (function Function) original_source_text() string {
	mut builder := strings.new_builder(16)
	builder.write_string(function.name_token.original_source_text())
	for component_value in function.value {
		builder.write_string(component_value.original_source_text())
	}
	builder.write_string(function.end_token.original_source_text())
	return builder.str()
}

// https://drafts.csswg.org/css-variables/#guaranteed-invalid-value
pub struct GuaranteedInvalidValue {}

pub fn (invalid GuaranteedInvalidValue) to_string() string {
	_ = invalid
	return ''
}

pub fn (invalid GuaranteedInvalidValue) original_source_text() string {
	_ = invalid
	return ''
}

pub fn (at_rule AtRule) for_each(visit_at_rule AtRuleVisitor, visit_qualified_rule QualifiedRuleVisitor, visit_declaration DeclarationVisitor) {
	for child in at_rule.child_rules_and_lists_of_declarations {
		match child {
			RuleNode {
				match child.rule {
					AtRule {
						visit_at_rule(child.rule)
					}
					QualifiedRule {
						visit_qualified_rule(child.rule)
					}
				}
			}
			DeclarationList {
				for declaration in child.declarations {
					visit_declaration(declaration)
				}
			}
		}
	}
}

// https://drafts.csswg.org/css-syntax/#typedef-declaration-list
pub fn (at_rule AtRule) for_each_as_declaration_list(visit DeclarationVisitor) {
	// <declaration-list>: only declarations are allowed; at-rules and qualified rules are automatically invalid.
	for child in at_rule.child_rules_and_lists_of_declarations {
		match child {
			RuleNode {
				match child.rule {
					AtRule {
						report_invalid_rule_location(InvalidRuleLocationError{
							outer_rule_name: '@${at_rule.name}'
							inner_rule_name: '@${child.rule.name}'
						})
					}
					QualifiedRule {
						report_invalid_rule_location(InvalidRuleLocationError{
							outer_rule_name: '@${at_rule.name}'
							inner_rule_name: 'qualified-rule'
						})
					}
				}
			}
			DeclarationList {
				for declaration in child.declarations {
					visit(declaration)
				}
			}
		}
	}
}

// https://drafts.csswg.org/css-syntax/#typedef-qualified-rule-list
pub fn (at_rule AtRule) for_each_as_qualified_rule_list(visit QualifiedRuleVisitor) {
	// <qualified-rule-list>: only qualified rules are allowed; declarations and at-rules are automatically invalid.
	for child in at_rule.child_rules_and_lists_of_declarations {
		match child {
			RuleNode {
				match child.rule {
					AtRule {
						report_invalid_rule_location(InvalidRuleLocationError{
							outer_rule_name: '@${at_rule.name}'
							inner_rule_name: '@${child.rule.name}'
						})
					}
					QualifiedRule {
						visit(child.rule)
					}
				}
			}
			DeclarationList {
				report_invalid_rule_location(InvalidRuleLocationError{
					outer_rule_name: '@${at_rule.name}'
					inner_rule_name: 'list-of-declarations'
				})
			}
		}
	}
}

// https://drafts.csswg.org/css-syntax/#typedef-at-rule-list
pub fn (at_rule AtRule) for_each_as_at_rule_list(visit AtRuleVisitor) {
	// <at-rule-list>: only at-rules are allowed; declarations and qualified rules are automatically invalid.
	for child in at_rule.child_rules_and_lists_of_declarations {
		match child {
			RuleNode {
				match child.rule {
					AtRule {
						visit(child.rule)
					}
					QualifiedRule {
						report_invalid_rule_location(InvalidRuleLocationError{
							outer_rule_name: '@${at_rule.name}'
							inner_rule_name: 'qualified-rule'
						})
					}
				}
			}
			DeclarationList {
				report_invalid_rule_location(InvalidRuleLocationError{
					outer_rule_name: '@${at_rule.name}'
					inner_rule_name: 'list-of-declarations'
				})
			}
		}
	}
}

// https://drafts.csswg.org/css-syntax/#typedef-declaration-rule-list
pub fn (at_rule AtRule) for_each_as_declaration_rule_list(visit_at_rule AtRuleVisitor, visit_declaration DeclarationVisitor) {
	// <declaration-rule-list>: declarations and at-rules are allowed; qualified rules are automatically invalid.
	for child in at_rule.child_rules_and_lists_of_declarations {
		match child {
			RuleNode {
				match child.rule {
					AtRule {
						visit_at_rule(child.rule)
					}
					QualifiedRule {
						report_invalid_rule_location(InvalidRuleLocationError{
							outer_rule_name: '@${at_rule.name}'
							inner_rule_name: 'qualified-rule'
						})
					}
				}
			}
			DeclarationList {
				for declaration in child.declarations {
					visit_declaration(declaration)
				}
			}
		}
	}
}

// https://drafts.csswg.org/css-syntax/#typedef-rule-list
pub fn (at_rule AtRule) for_each_as_rule_list(visit RuleVisitor) {
	// <rule-list>: qualified rules and at-rules are allowed; declarations are automatically invalid.
	for child in at_rule.child_rules_and_lists_of_declarations {
		match child {
			RuleNode {
				visit(child.rule)
			}
			DeclarationList {
				report_invalid_rule_location(InvalidRuleLocationError{
					outer_rule_name: '@${at_rule.name}'
					inner_rule_name: 'list-of-declarations'
				})
			}
		}
	}
}

// https://drafts.csswg.org/css-syntax/#typedef-declaration-list
pub fn (qualified_rule QualifiedRule) for_each_as_declaration_list(rule_name string, visit DeclarationVisitor) {
	// <declaration-list>: only declarations are allowed; at-rules and qualified rules are automatically invalid.
	for declaration in qualified_rule.declarations {
		visit(declaration)
	}

	for child in qualified_rule.child_rules {
		match child {
			RuleNode {
				report_invalid_rule_location(InvalidRuleLocationError{
					outer_rule_name: rule_name
					inner_rule_name: 'qualified-rule'
				})
			}
			DeclarationList {
				for declaration in child.declarations {
					visit(declaration)
				}
			}
		}
	}
}
