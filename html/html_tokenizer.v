module html

import strings

// Translation of Libraries/LibWeb/HTML/Parser/HTMLTokenizer.{h,cpp}.
//
// The C++ tokenizer is a goto-based state machine (SWITCH_TO / RECONSUME_IN jump to labels). V
// has no goto, so it is restructured as a labelled `for` loop over `match state`:
//   * SWITCH_TO(x)            -> t.state = x; continue         (reads the next code point at loop top)
//   * SWITCH_TO_..UNCLEAN(x)  -> t.state = x; continue         (same; we never VERIFY the builder)
//   * RECONSUME_IN(x)         -> t.state = x; reconsume = true; continue
//   * SWITCH_TO_RETURN_STATE  -> t.state = return_state; continue start_of_function
//   * RECONSUME_IN_RETURN..   -> t.state = return_state; restore; continue start_of_function
//   * EMIT_*                  -> return t.emit_*()
// `continue start_of_function` re-enters the outer loop, which first drains queued tokens exactly
// like the C++ `goto _StartOfFunction`.

pub enum State {
	data
	rcdata
	rawtext
	script_data
	plaintext
	tag_open
	end_tag_open
	tag_name
	rcdata_less_than_sign
	rcdata_end_tag_open
	rcdata_end_tag_name
	rawtext_less_than_sign
	rawtext_end_tag_open
	rawtext_end_tag_name
	script_data_less_than_sign
	script_data_end_tag_open
	script_data_end_tag_name
	script_data_escape_start
	script_data_escape_start_dash
	script_data_escaped
	script_data_escaped_dash
	script_data_escaped_dash_dash
	script_data_escaped_less_than_sign
	script_data_escaped_end_tag_open
	script_data_escaped_end_tag_name
	script_data_double_escape_start
	script_data_double_escaped
	script_data_double_escaped_dash
	script_data_double_escaped_dash_dash
	script_data_double_escaped_less_than_sign
	script_data_double_escape_end
	before_attribute_name
	attribute_name
	after_attribute_name
	before_attribute_value
	attribute_value_double_quoted
	attribute_value_single_quoted
	attribute_value_unquoted
	after_attribute_value_quoted
	self_closing_start_tag
	bogus_comment
	markup_declaration_open
	comment_start
	comment_start_dash
	comment
	comment_less_than_sign
	comment_less_than_sign_bang
	comment_less_than_sign_bang_dash
	comment_less_than_sign_bang_dash_dash
	comment_end_dash
	comment_end
	comment_end_bang
	doctype
	before_doctype_name
	doctype_name
	after_doctype_name
	after_doctype_public_keyword
	before_doctype_public_identifier
	doctype_public_identifier_double_quoted
	doctype_public_identifier_single_quoted
	after_doctype_public_identifier
	between_doctype_public_and_system_identifiers
	after_doctype_system_keyword
	before_doctype_system_identifier
	doctype_system_identifier_double_quoted
	doctype_system_identifier_single_quoted
	after_doctype_system_identifier
	bogus_doctype
	cdata_section
	cdata_section_bracket
	cdata_section_end
	processing_instruction_open
	processing_instruction_target
	after_processing_instruction_target
	processing_instruction_data
	processing_instruction_questionable
	character_reference
	named_character_reference
	ambiguous_ampersand
	numeric_character_reference
	hexadecimal_character_reference_start
	decimal_character_reference_start
	hexadecimal_character_reference
	decimal_character_reference
	numeric_character_reference_end
}

pub enum StopAtInsertionPoint {
	no
	yes
}

enum CaseSensitivity {
	case_sensitive
	case_insensitive
}

enum ConsumeNextResult {
	consumed
	not_consumed
	ran_out_of_characters
}

pub struct HTMLTokenizer {
mut:
	parser_      ?&HTMLParser
	state        State = .data
	return_state State = .data

	temporary_buffer []rune

	source        string
	decoded_input []rune

	insertion_point      ?int
	old_insertion_points []?int

	current_offset int
	prev_offset    int

	current_token   HTMLToken
	current_builder []rune

	matcher NamedCharacterReferenceMatcher

	last_emitted_start_tag_name ?string

	explicit_eof_inserted bool
	input_stream_closed   bool
	has_emitted_eof       bool

	queued_tokens []HTMLToken

	character_reference_code u32

	blocked bool
	aborted bool

	source_positions []Position

	// Whether a parser has registered an adjusted-current-node in a non-HTML namespace. Always
	// false in the standalone tokenizer (used only for CDATA in foreign content).
	parser_in_foreign_content bool
}

pub fn HTMLTokenizer.new(input string) HTMLTokenizer {
	mut t := HTMLTokenizer{
		source:              input
		decoded_input:       input.runes()
		input_stream_closed: true
	}
	t.source_positions << Position{0, 0}
	return t
}

// The empty constructor leaves the input stream open for incremental parsing.
pub fn HTMLTokenizer.create() HTMLTokenizer {
	mut tokenizer := HTMLTokenizer{}
	tokenizer.source_positions << Position{0, 0}
	return tokenizer
}

pub fn (mut tokenizer HTMLTokenizer) set_parser(parser &HTMLParser) {
	tokenizer.parser_ = parser
}

pub fn (tokenizer &HTMLTokenizer) source() string {
	return tokenizer.source
}

pub fn (tokenizer &HTMLTokenizer) unparsed_input() string {
	if tokenizer.current_offset < 0 || tokenizer.current_offset >= tokenizer.decoded_input.len {
		return ''
	}
	return tokenizer.decoded_input[tokenizer.current_offset..].string()
}

pub fn HTMLTokenizer.state_name(state State) string {
	mut builder := strings.new_builder(32)
	for part in state.str().split('_') {
		if part.len == 0 {
			continue
		}
		builder.write_string(part[..1].to_upper())
		if part.len > 1 {
			builder.write_string(part[1..])
		}
	}
	return builder.str()
}

// ===== ASCII / Unicode classification (mirrors AK/CharacterTypes.h) =====

fn is_ascii(c rune) bool {
	return c >= 0 && c <= 0x7f
}

fn is_ascii_alpha(c rune) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)
}

fn is_ascii_digit(c rune) bool {
	return c >= `0` && c <= `9`
}

fn is_ascii_alphanumeric(c rune) bool {
	return is_ascii_alpha(c) || is_ascii_digit(c)
}

fn is_ascii_upper_alpha(c rune) bool {
	return c >= `A` && c <= `Z`
}

fn is_ascii_lower_alpha(c rune) bool {
	return c >= `a` && c <= `z`
}

fn is_ascii_hex_digit(c rune) bool {
	return is_ascii_digit(c) || (c >= `a` && c <= `f`) || (c >= `A` && c <= `F`)
}

fn to_ascii_lowercase(c rune) rune {
	if is_ascii_upper_alpha(c) {
		return c + 0x20
	}
	return c
}

fn to_ascii_uppercase(c rune) rune {
	if is_ascii_lower_alpha(c) {
		return c - 0x20
	}
	return c
}

// The four ASCII whitespace code points the tokenizer treats as whitespace (NOT '\r', which is
// normalized to '\n', and NOT '\v').
fn is_html_whitespace(c rune) bool {
	return c == `\t` || c == `\n` || c == `\f` || c == ` `
}

fn is_ascii_space_u32(code_point u32) bool {
	return code_point == ` ` || code_point == `\t` || code_point == `\n` || code_point == 0x0b
		|| code_point == `\f` || code_point == `\r`
}

fn is_unicode_control(code_point u32) bool {
	return code_point < 0x20 || (code_point >= 0x7e && code_point <= 0x9f)
}

fn is_unicode_surrogate(code_point u32) bool {
	return code_point >= 0xd800 && code_point <= 0xdfff
}

fn runes_to_string(runes []rune) string {
	length := runes.len
	if length == 0 { return '' }
	// Copy the byte candidates and accumulate their high bits in one pass.
	// Only ASCII publishes this storage; other values keep the original encoder.
	// Keep the borrowed input bounds fixed while writing the separate owner.
	// Neither the array header nor its elements are changed by this function.
	source := unsafe { &rune(runes.data) }
	mut bytes := unsafe { malloc_noscan(length + 1) }
	mut bits := u32(0)
	for index in 0 .. length {
		code_point := unsafe { source[index] }
		bits |= u32(code_point)
		unsafe { bytes[index] = u8(code_point) }
	}
	if bits <= 0x7f {
		unsafe {
			bytes[length] = 0
			return tos(bytes, length)
		}
	}
	// The candidate never escaped. Release it before encoding non-ASCII or
	// invalid internal values through the same rune writer as before.
	unsafe { free(bytes) }
	mut b := strings.new_builder(runes.len)
	for r in runes {
		b.write_rune(r)
	}
	return b.str()
}

// ===== Input stream =====

fn (t &HTMLTokenizer) peek_code_point(offset int, stop StopAtInsertionPoint) ?rune {
	it := t.current_offset + offset
	if it >= t.decoded_input.len {
		return none
	}
	if stop == .yes {
		if ip := t.insertion_point {
			if it >= ip {
				return none
			}
		}
	}
	return t.decoded_input[it]
}

fn (mut t HTMLTokenizer) skip(count int) {
	for _ in 0 .. count {
		if t.source_positions.len > 0 {
			t.source_positions << t.source_positions[t.source_positions.len - 1]
		}
		t.prev_offset = t.current_offset
		code_point := t.decoded_input[t.current_offset]
		if t.source_positions.len > 0 {
			li := t.source_positions.len - 1
			if code_point == `\n` {
				t.source_positions[li].column = 0
				t.source_positions[li].line++
			} else {
				t.source_positions[li].column++
			}
		}
		t.current_offset++
	}
}

fn (mut t HTMLTokenizer) next_code_point(stop StopAtInsertionPoint) ?rune {
	if t.current_offset >= t.decoded_input.len {
		return none
	}
	// https://infra.spec.whatwg.org/#normalize-newlines
	if t.peek_code_point(0, stop) or { rune(0) } == `\r` && t.peek_code_point(1, stop) or {
		rune(0)
	} == `\n` {
		t.skip(2)
		return `\n`
	} else if t.peek_code_point(0, stop) or { rune(0) } == `\r` {
		t.skip(1)
		return `\n`
	}
	t.skip(1)
	return t.decoded_input[t.prev_offset]
}

fn (mut t HTMLTokenizer) restore_to(new_iterator int) {
	diff := t.current_offset - new_iterator
	if diff > 0 {
		for _ in 0 .. diff {
			if t.source_positions.len > 0 {
				t.source_positions.delete_last()
			}
		}
	}
	t.current_offset = new_iterator
}

fn (t &HTMLTokenizer) nth_last_position(n int) Position {
	if n + 1 > t.source_positions.len {
		return Position{0, 0}
	}
	return t.source_positions[t.source_positions.len - 1 - n]
}

fn (mut t HTMLTokenizer) consume_next_if_match(s string, stop StopAtInsertionPoint, case_sensitivity CaseSensitivity) ConsumeNextResult {
	for i in 0 .. s.len {
		code_point := t.peek_code_point(i, stop) or {
			if t.can_run_out_of_characters(stop) {
				return .ran_out_of_characters
			}
			return .not_consumed
		}
		if case_sensitivity == .case_insensitive {
			if code_point < 0x80 {
				if to_ascii_lowercase(code_point) != to_ascii_lowercase(rune(s[i])) {
					return .not_consumed
				}
				continue
			}
		}
		if code_point != rune(s[i]) {
			return .not_consumed
		}
	}
	t.skip(s.len)
	return .consumed
}

// ===== Token / builder helpers =====

fn (mut t HTMLTokenizer) dequeue() ?HTMLToken {
	if t.queued_tokens.len == 0 {
		return none
	}
	token := t.queued_tokens[0]
	t.queued_tokens.delete(0)
	// A paused token can still rewind an overconsumed character reference
	// after more input arrives. Drop its position history only once a token
	// has actually been emitted, rather than on each unsuccessful next_token.
	if t.source_positions.len > 0 {
		last_position := t.source_positions[t.source_positions.len - 1]
		t.source_positions.clear()
		t.source_positions << last_position
	}
	return token
}

fn (mut t HTMLTokenizer) enqueue(token HTMLToken) {
	// Emission transfers this completed token's immutable payloads. The next
	// token gets a fresh attribute vector; builders own separate storage.
	index := t.queued_tokens.len
	unsafe {
		t.queued_tokens.grow_len(1)
		vmemcpy(&t.queued_tokens[index], &token, int(sizeof(HTMLToken)))
	}
}

fn (mut t HTMLTokenizer) create_new_token(type_ TokenType) {
	t.current_token = HTMLToken.new(type_)
	is_start_or_end_tag := type_ == .start_tag || type_ == .end_tag
	t.current_token.start_position = t.nth_last_position(if is_start_or_end_tag { 1 } else { 0 })
}

fn (mut t HTMLTokenizer) processing_instruction_target_to_comment() {
	position := t.current_token.start_position
	t.create_new_token(.comment)
	t.current_token.start_position = position
	t.current_builder << `?`
	t.current_builder << t.temporary_buffer
}

fn (mut t HTMLTokenizer) will_emit_current() {
	mut token := t.current_token
	t.will_emit(mut token)
	t.current_token = token
}

// TOKENIZER_TRACE_DEBUG is a compile-time diagnostic in C++; these hooks are
// intentionally side-effect-free when tracing is disabled.
pub fn (_ &HTMLTokenizer) will_switch_to(_ State) {}

pub fn (_ &HTMLTokenizer) will_reconsume_in(_ State) {}

pub fn (mut t HTMLTokenizer) will_emit(mut token HTMLToken) {
	if token.is_start_tag() {
		t.last_emitted_start_tag_name = token.tag_name
	}
	is_start_or_end_tag := token.type_ == .start_tag || token.type_ == .end_tag
	token.end_position = t.nth_last_position(if is_start_or_end_tag { 1 } else { 0 })
	if is_start_or_end_tag {
		token.normalize_attributes()
	}
}

fn (t &HTMLTokenizer) current_end_tag_token_is_appropriate() bool {
	name := t.last_emitted_start_tag_name or { return false }
	return t.current_token.tag_name == name
}

fn (t &HTMLTokenizer) consumed_as_part_of_an_attribute() bool {
	return t.return_state == .attribute_value_unquoted
		|| t.return_state == .attribute_value_single_quoted
		|| t.return_state == .attribute_value_double_quoted
}

fn (mut t HTMLTokenizer) consume_current_builder() string {
	s := runes_to_string(t.current_builder)
	// runes_to_string owns its output, so the tokenizer can immediately reuse
	// its private rune storage for the next tag, attribute, or comment.
	t.current_builder.clear()
	return s
}

fn (mut t HTMLTokenizer) append_string_to_builder(s string) {
	for r in s.runes() {
		t.current_builder << r
	}
}

fn (t &HTMLTokenizer) temporary_buffer_equal_to_script() bool {
	if t.temporary_buffer.len != 6 {
		return false
	}
	return t.temporary_buffer[0] == `s` && t.temporary_buffer[1] == `c`
		&& t.temporary_buffer[2] == `r` && t.temporary_buffer[3] == `i`
		&& t.temporary_buffer[4] == `p` && t.temporary_buffer[5] == `t`
}

// ===== EMIT_* macros =====

fn (mut t HTMLTokenizer) emit_character(code_point rune) ?HTMLToken {
	t.create_new_token(.character)
	t.current_token.code_point = code_point
	t.enqueue(t.current_token)
	return t.dequeue()
}

fn (mut t HTMLTokenizer) emit_eof() ?HTMLToken {
	if t.has_emitted_eof {
		return none
	}
	t.has_emitted_eof = true
	t.create_new_token(.end_of_file)
	t.will_emit_current()
	t.enqueue(t.current_token)
	return t.dequeue()
}

fn (mut t HTMLTokenizer) emit_current_token_followed_by_eof() ?HTMLToken {
	t.will_emit_current()
	t.enqueue(t.current_token)
	t.has_emitted_eof = true
	t.create_new_token(.end_of_file)
	t.will_emit_current()
	t.enqueue(t.current_token)
	return t.dequeue()
}

fn (mut t HTMLTokenizer) switch_to_and_emit_current_token(new_state State) ?HTMLToken {
	t.state = new_state
	t.will_emit_current()
	t.enqueue(t.current_token)
	return t.dequeue()
}

fn (mut t HTMLTokenizer) flush_codepoints_consumed_as_a_character_reference() {
	for code_point in t.temporary_buffer {
		if t.consumed_as_part_of_an_attribute() {
			t.current_builder << code_point
		} else {
			t.create_new_token(.character)
			t.current_token.code_point = code_point
			t.enqueue(t.current_token)
		}
	}
}

pub fn (t &HTMLTokenizer) is_insertion_point_defined() bool {
	return t.insertion_point != none
}

fn (t &HTMLTokenizer) is_insertion_point_reached() bool {
	if ip := t.insertion_point {
		return t.current_offset >= ip
	}
	return false
}

fn (t &HTMLTokenizer) should_pause_before_next_input_character(stop StopAtInsertionPoint) bool {
	if stop == .yes {
		if insertion_point := t.insertion_point {
			if t.current_offset >= insertion_point {
				return true
			}
			// Newline normalization needs one character of lookahead to distinguish
			// CRLF from a standalone CR. A later document.write() may provide that LF.
			if t.current_offset < t.decoded_input.len
				&& t.decoded_input[t.current_offset] == `\r`
				&& t.current_offset + 1 == insertion_point {
				return true
			}
		}
	}
	if t.input_stream_closed {
		return false
	}
	if t.current_offset >= t.decoded_input.len {
		return true
	}
	// A network chunk can also end between the CR and LF of a CRLF pair.
	return t.decoded_input[t.current_offset] == `\r`
		&& t.current_offset + 1 >= t.decoded_input.len
}

fn (t &HTMLTokenizer) can_run_out_of_characters(stop StopAtInsertionPoint) bool {
	return (stop == .yes && t.insertion_point != none) || !t.input_stream_closed
}

pub fn (t &HTMLTokenizer) is_blocked() bool {
	return t.blocked
}

pub fn (mut t HTMLTokenizer) set_blocked(b bool) {
	t.blocked = b
}

pub fn (mut t HTMLTokenizer) switch_to(new_state State) {
	t.state = new_state
}

pub fn (mut t HTMLTokenizer) abort() {
	t.aborted = true
}

// Append input to the tokenizer's decoded input stream. This is used by the
// DOM/html module bridge; document.write() uses the insertion-point operation
// below so its ordering remains spec-accurate.
pub fn (mut t HTMLTokenizer) append_to_input_stream(input string) {
	t.source += input
	t.decoded_input << input.runes()
	t.has_emitted_eof = false
}

pub fn (mut t HTMLTokenizer) feed(input string) {
	t.append_to_input_stream(input)
}

pub fn (mut t HTMLTokenizer) close_input_stream() {
	t.input_stream_closed = true
}

pub fn (t &HTMLTokenizer) is_input_stream_closed() bool {
	return t.input_stream_closed
}

// HTMLTokenizer::update_insertion_point().
pub fn (mut t HTMLTokenizer) update_insertion_point() {
	t.insertion_point = t.current_offset
}

// HTMLTokenizer::undefine/store/restore_insertion_point().
pub fn (mut t HTMLTokenizer) undefine_insertion_point() {
	t.insertion_point = none
}

pub fn (mut t HTMLTokenizer) store_insertion_point() {
	t.old_insertion_points << t.insertion_point
}

pub fn (mut t HTMLTokenizer) restore_insertion_point() {
	assert t.old_insertion_points.len > 0
	t.insertion_point = t.old_insertion_points.pop()
}

// Compatibility names retained by upstream for the parser call sites.
pub fn (mut t HTMLTokenizer) store_old_insertion_point() {
	t.store_insertion_point()
}

pub fn (mut t HTMLTokenizer) restore_old_insertion_point() {
	t.restore_insertion_point()
}

// HTMLTokenizer::insert_input_at_insertion_point(). The insertion point is a
// code-point offset, just like decoded_input/current_offset.
pub fn (mut t HTMLTokenizer) insert_input_at_insertion_point(input string) {
	insertion_point := t.insertion_point or {
		panic('HTMLTokenizer::insert_input_at_insertion_point() with no insertion point')
	}

	inserted := input.runes()
	mut new_decoded_input := []rune{cap: t.decoded_input.len + inserted.len}
	new_decoded_input << t.decoded_input[..insertion_point]
	new_decoded_input << inserted
	new_decoded_input << t.decoded_input[insertion_point..]
	t.decoded_input = new_decoded_input
	t.insertion_point = insertion_point + inserted.len
	for index, old_insertion_point in t.old_insertion_points {
		if value := old_insertion_point {
			if insertion_point <= value {
				t.old_insertion_points[index] = value + inserted.len
			}
		}
	}
}

pub fn (mut t HTMLTokenizer) insert_eof() {
	t.close_input_stream()
	t.explicit_eof_inserted = true
}

pub fn (t &HTMLTokenizer) is_eof_inserted() bool {
	return t.explicit_eof_inserted
}

// HTMLTokenizer::parser_did_run(). Reclaim fully consumed input while keeping
// the logical insertion-point state intact.
pub fn (mut t HTMLTokenizer) parser_did_run() {
	insertion_point_is_at_start := if insertion_point := t.insertion_point {
		insertion_point == 0
	} else {
		true
	}
	if t.current_offset > 0 && t.current_offset == t.decoded_input.len
		&& insertion_point_is_at_start && t.old_insertion_points.len == 0 {
		t.decoded_input.clear()
		t.current_offset = 0
		t.prev_offset = 0
	}
}

fn convert_numeric_control_code(code u32) u32 {
	return match code {
		0x80 { u32(0x20ac) }
		0x82 { u32(0x201a) }
		0x83 { u32(0x0192) }
		0x84 { u32(0x201e) }
		0x85 { u32(0x2026) }
		0x86 { u32(0x2020) }
		0x87 { u32(0x2021) }
		0x88 { u32(0x02c6) }
		0x89 { u32(0x2030) }
		0x8a { u32(0x0160) }
		0x8b { u32(0x2039) }
		0x8c { u32(0x0152) }
		0x8e { u32(0x017d) }
		0x91 { u32(0x2018) }
		0x92 { u32(0x2019) }
		0x93 { u32(0x201c) }
		0x94 { u32(0x201d) }
		0x95 { u32(0x2022) }
		0x96 { u32(0x2013) }
		0x97 { u32(0x2014) }
		0x98 { u32(0x02dc) }
		0x99 { u32(0x2122) }
		0x9a { u32(0x0161) }
		0x9b { u32(0x203a) }
		0x9c { u32(0x0153) }
		0x9e { u32(0x017e) }
		0x9f { u32(0x0178) }
		else { code }
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#tokenization
pub fn (mut t HTMLTokenizer) next_token() ?HTMLToken {
	return t.next_token_impl(.no)
}

fn (mut t HTMLTokenizer) next_token_impl(stop StopAtInsertionPoint) ?HTMLToken {
	start_of_function: for {
		if t.queued_tokens.len > 0 {
			return t.dequeue()
		}
		if t.aborted {
			return none
		}

		mut current := ?rune(none)
		mut reconsume := false

		for {
			if !reconsume {
				if t.should_pause_before_next_input_character(stop) {
					return none
				}
				current = t.next_code_point(stop)
			}
			reconsume = false

			match t.state {
				.data {
					if c := current {
						if c == `&` {
							t.return_state = .data
							t.state = .character_reference
							continue
						} else if c == `<` {
							t.state = .tag_open
							continue
						} else if c == 0 {
							return t.emit_character(c)
						} else {
							return t.emit_character(c)
						}
					}
					return t.emit_eof()
				}
				.tag_open {
					if c := current {
						if c == `!` {
							t.state = .markup_declaration_open
							continue
						} else if c == `/` {
							t.state = .end_tag_open
							continue
						} else if is_ascii_alpha(c) {
							t.create_new_token(.start_tag)
							t.state = .tag_name
							reconsume = true
							continue
						} else if c == `?` {
							t.create_new_token(.processing_instruction)
							t.current_token.start_position = t.nth_last_position(2)
							t.temporary_buffer.clear()
							t.state = .processing_instruction_open
							continue
						} else {
							t.enqueue(HTMLToken.make_character(`<`))
							t.state = .data
							reconsume = true
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`<`))
					return t.emit_eof()
				}
				.tag_name {
					if c := current {
						if is_html_whitespace(c) {
							t.current_token.tag_name = t.consume_current_builder()
							t.current_token.end_position = t.nth_last_position(1)
							t.state = .before_attribute_name
							continue
						} else if c == `/` {
							t.current_token.tag_name = t.consume_current_builder()
							t.current_token.end_position = t.nth_last_position(0)
							t.state = .self_closing_start_tag
							continue
						} else if c == `>` {
							t.current_token.tag_name = t.consume_current_builder()
							return t.switch_to_and_emit_current_token(.data)
						} else if is_ascii_upper_alpha(c) {
							t.current_builder << to_ascii_lowercase(c)
							t.current_token.end_position = t.nth_last_position(0)
							continue
						} else if c == 0 {
							t.current_builder << rune(0xfffd)
							t.current_token.end_position = t.nth_last_position(0)
							continue
						} else {
							t.current_builder << c
							t.current_token.end_position = t.nth_last_position(0)
							continue
						}
					}
					return t.emit_eof()
				}
				.end_tag_open {
					if c := current {
						if is_ascii_alpha(c) {
							t.create_new_token(.end_tag)
							t.state = .tag_name
							reconsume = true
							continue
						} else if c == `>` {
							t.state = .data
							continue
						} else {
							t.create_new_token(.comment)
							t.state = .bogus_comment
							reconsume = true
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`<`))
					t.enqueue(HTMLToken.make_character(`/`))
					return t.emit_eof()
				}
				.markup_declaration_open {
					if current != none {
						t.restore_to(t.prev_offset)
					}
					match t.consume_next_if_match('--', stop, .case_sensitive) {
						.consumed {
							t.create_new_token(.comment)
							t.current_token.start_position = t.nth_last_position(3)
							t.state = .comment_start
							continue
						}
						.not_consumed {}
						.ran_out_of_characters {
							return none
						}
					}
					match t.consume_next_if_match('DOCTYPE', stop, .case_insensitive) {
						.consumed {
							t.state = .doctype
							continue
						}
						.not_consumed {}
						.ran_out_of_characters {
							return none
						}
					}
					match t.consume_next_if_match('[CDATA[', stop, .case_sensitive) {
						.consumed {
							if t.parser_in_foreign_content {
								t.state = .cdata_section
								continue
							} else {
								t.create_new_token(.comment)
								t.append_string_to_builder('[CDATA[')
								t.state = .bogus_comment
								continue
							}
						}
						.not_consumed {}
						.ran_out_of_characters {
							return none
						}
					}
					t.create_new_token(.comment)
					t.state = .bogus_comment
					continue
				}
				.processing_instruction_open {
					if c := current {
						if is_ascii_alpha(c) || c == `_` {
							t.state = .processing_instruction_target
						} else {
							t.processing_instruction_target_to_comment()
							t.state = .bogus_comment
						}
						reconsume = true
						continue
					}
					return t.emit_eof()
				}
				.processing_instruction_target {
					if c := current {
						if is_html_whitespace(c) || c == `?` || c == `>` {
							target := runes_to_string(t.temporary_buffer)
							if target.to_lower() in ['xml', 'xml-stylesheet'] {
								t.processing_instruction_target_to_comment()
								t.state = .bogus_comment
							} else {
								t.current_token.processing_instruction_target = target.to_lower()
								t.state = .after_processing_instruction_target
							}
							reconsume = true
							continue
						}
						if is_ascii_alpha(c) || is_ascii_digit(c) || c == `-` || c == `_` {
							t.temporary_buffer << c
							continue
						}
						t.processing_instruction_target_to_comment()
						t.state = .bogus_comment
						reconsume = true
						continue
					}
					return t.emit_eof()
				}
				.after_processing_instruction_target {
					if c := current {
						if is_html_whitespace(c) { continue }
					}
					t.state = .processing_instruction_data
					reconsume = true
					continue
				}
				.processing_instruction_data {
					if c := current {
						if c == `?` {
							t.state = .processing_instruction_questionable
							continue
						}
						if c == `>` {
							t.current_token.set_comment(t.consume_current_builder())
							return t.switch_to_and_emit_current_token(.data)
						}
						t.current_builder << c
						continue
					}
					return t.emit_eof()
				}
				.processing_instruction_questionable {
					if c := current {
						if c == `>` {
							t.current_token.set_comment(t.consume_current_builder())
							return t.switch_to_and_emit_current_token(.data)
						}
						t.current_builder << `?`
						t.state = .processing_instruction_data
						reconsume = true
						continue
					}
					return t.emit_eof()
				}
				.bogus_comment {
					if c := current {
						if c == `>` {
							t.current_token.set_comment(t.consume_current_builder())
							return t.switch_to_and_emit_current_token(.data)
						} else if c == 0 {
							t.current_builder << rune(0xfffd)
							continue
						} else {
							t.current_builder << c
							continue
						}
					}
					t.current_token.set_comment(t.consume_current_builder())
					return t.emit_current_token_followed_by_eof()
				}
				.doctype {
					if c := current {
						if is_html_whitespace(c) {
							t.state = .before_doctype_name
							continue
						} else if c == `>` {
							t.state = .before_doctype_name
							reconsume = true
							continue
						} else {
							t.state = .before_doctype_name
							reconsume = true
							continue
						}
					}
					t.create_new_token(.doctype)
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.before_doctype_name {
					if c := current {
						if is_html_whitespace(c) {
							continue
						} else if is_ascii_upper_alpha(c) {
							t.create_new_token(.doctype)
							t.current_builder << to_ascii_lowercase(c)
							t.current_token.doctype.missing_name = false
							t.state = .doctype_name
							continue
						} else if c == 0 {
							t.create_new_token(.doctype)
							t.current_builder << rune(0xfffd)
							t.current_token.doctype.missing_name = false
							t.state = .doctype_name
							continue
						} else if c == `>` {
							t.create_new_token(.doctype)
							t.current_token.doctype.force_quirks = true
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.create_new_token(.doctype)
							t.current_builder << c
							t.current_token.doctype.missing_name = false
							t.state = .doctype_name
							continue
						}
					}
					t.create_new_token(.doctype)
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.doctype_name {
					if c := current {
						if is_html_whitespace(c) {
							t.current_token.doctype.name = t.consume_current_builder()
							t.state = .after_doctype_name
							continue
						} else if c == `>` {
							t.current_token.doctype.name = t.consume_current_builder()
							return t.switch_to_and_emit_current_token(.data)
						} else if is_ascii_upper_alpha(c) {
							t.current_builder << to_ascii_lowercase(c)
							continue
						} else if c == 0 {
							t.current_builder << rune(0xfffd)
							continue
						} else {
							t.current_builder << c
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.after_doctype_name {
					if c := current {
						if is_html_whitespace(c) {
							continue
						} else if c == `>` {
							return t.switch_to_and_emit_current_token(.data)
						} else {
							if to_ascii_uppercase(c) == `P` {
								match t.consume_next_if_match('UBLIC', stop, .case_insensitive) {
									.consumed {
										t.state = .after_doctype_public_keyword
										continue
									}
									.not_consumed {}
									.ran_out_of_characters {
										if current != none {
											t.restore_to(t.prev_offset)
										}
										return none
									}
								}
							}
							if to_ascii_uppercase(c) == `S` {
								match t.consume_next_if_match('YSTEM', stop, .case_insensitive) {
									.consumed {
										t.state = .after_doctype_system_keyword
										continue
									}
									.not_consumed {}
									.ran_out_of_characters {
										if current != none {
											t.restore_to(t.prev_offset)
										}
										return none
									}
								}
							}
							t.current_token.doctype.force_quirks = true
							t.state = .bogus_doctype
							reconsume = true
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.after_doctype_public_keyword {
					if c := current {
						if is_html_whitespace(c) {
							t.state = .before_doctype_public_identifier
							continue
						} else if c == `"` {
							t.current_token.doctype.missing_public_identifier = false
							t.state = .doctype_public_identifier_double_quoted
							continue
						} else if c == `'` {
							t.current_token.doctype.missing_public_identifier = false
							t.state = .doctype_public_identifier_single_quoted
							continue
						} else if c == `>` {
							t.current_token.doctype.force_quirks = true
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.current_token.doctype.force_quirks = true
							t.state = .bogus_doctype
							reconsume = true
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.after_doctype_system_keyword {
					if c := current {
						if is_html_whitespace(c) {
							t.state = .before_doctype_system_identifier
							continue
						} else if c == `"` {
							t.current_token.doctype.system_identifier = ''
							t.current_token.doctype.missing_system_identifier = false
							t.state = .doctype_system_identifier_double_quoted
							continue
						} else if c == `'` {
							t.current_token.doctype.system_identifier = ''
							t.current_token.doctype.missing_system_identifier = false
							t.state = .doctype_system_identifier_single_quoted
							continue
						} else if c == `>` {
							t.current_token.doctype.force_quirks = true
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.current_token.doctype.force_quirks = true
							t.state = .bogus_doctype
							reconsume = true
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.before_doctype_public_identifier {
					if c := current {
						if is_html_whitespace(c) {
							continue
						} else if c == `"` {
							t.current_token.doctype.missing_public_identifier = false
							t.state = .doctype_public_identifier_double_quoted
							continue
						} else if c == `'` {
							t.current_token.doctype.missing_public_identifier = false
							t.state = .doctype_public_identifier_single_quoted
							continue
						} else if c == `>` {
							t.current_token.doctype.force_quirks = true
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.current_token.doctype.force_quirks = true
							t.state = .bogus_doctype
							reconsume = true
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.before_doctype_system_identifier {
					if c := current {
						if is_html_whitespace(c) {
							continue
						} else if c == `"` {
							t.current_token.doctype.missing_system_identifier = false
							t.state = .doctype_system_identifier_double_quoted
							continue
						} else if c == `'` {
							t.current_token.doctype.missing_system_identifier = false
							t.state = .doctype_system_identifier_single_quoted
							continue
						} else if c == `>` {
							t.current_token.doctype.force_quirks = true
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.current_token.doctype.force_quirks = true
							t.state = .bogus_doctype
							reconsume = true
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.doctype_public_identifier_double_quoted {
					if c := current {
						if c == `"` {
							t.current_token.doctype.public_identifier = t.consume_current_builder()
							t.state = .after_doctype_public_identifier
							continue
						} else if c == 0 {
							t.current_builder << rune(0xfffd)
							continue
						} else if c == `>` {
							t.current_token.doctype.public_identifier = t.consume_current_builder()
							t.current_token.doctype.force_quirks = true
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.current_builder << c
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.doctype_public_identifier_single_quoted {
					if c := current {
						if c == `'` {
							t.current_token.doctype.public_identifier = t.consume_current_builder()
							t.state = .after_doctype_public_identifier
							continue
						} else if c == 0 {
							t.current_builder << rune(0xfffd)
							continue
						} else if c == `>` {
							t.current_token.doctype.public_identifier = t.consume_current_builder()
							t.current_token.doctype.force_quirks = true
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.current_builder << c
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.doctype_system_identifier_double_quoted {
					if c := current {
						if c == `"` {
							t.current_token.doctype.system_identifier = t.consume_current_builder()
							t.state = .after_doctype_system_identifier
							continue
						} else if c == 0 {
							t.current_builder << rune(0xfffd)
							continue
						} else if c == `>` {
							t.current_token.doctype.system_identifier = t.consume_current_builder()
							t.current_token.doctype.force_quirks = true
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.current_builder << c
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.doctype_system_identifier_single_quoted {
					if c := current {
						if c == `'` {
							t.current_token.doctype.system_identifier = t.consume_current_builder()
							t.state = .after_doctype_system_identifier
							continue
						} else if c == 0 {
							t.current_builder << rune(0xfffd)
							continue
						} else if c == `>` {
							t.current_token.doctype.system_identifier = t.consume_current_builder()
							t.current_token.doctype.force_quirks = true
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.current_builder << c
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.after_doctype_public_identifier {
					if c := current {
						if is_html_whitespace(c) {
							t.state = .between_doctype_public_and_system_identifiers
							continue
						} else if c == `>` {
							return t.switch_to_and_emit_current_token(.data)
						} else if c == `"` {
							t.current_token.doctype.missing_system_identifier = false
							t.state = .doctype_system_identifier_double_quoted
							continue
						} else if c == `'` {
							t.current_token.doctype.missing_system_identifier = false
							t.state = .doctype_system_identifier_single_quoted
							continue
						} else {
							t.current_token.doctype.force_quirks = true
							t.state = .bogus_doctype
							reconsume = true
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.between_doctype_public_and_system_identifiers {
					if c := current {
						if is_html_whitespace(c) {
							continue
						} else if c == `>` {
							return t.switch_to_and_emit_current_token(.data)
						} else if c == `"` {
							t.current_token.doctype.missing_system_identifier = false
							t.state = .doctype_system_identifier_double_quoted
							continue
						} else if c == `'` {
							t.current_token.doctype.missing_system_identifier = false
							t.state = .doctype_system_identifier_single_quoted
							continue
						} else {
							t.current_token.doctype.force_quirks = true
							t.state = .bogus_doctype
							reconsume = true
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.after_doctype_system_identifier {
					if c := current {
						if is_html_whitespace(c) {
							continue
						} else if c == `>` {
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.state = .bogus_doctype
							reconsume = true
							continue
						}
					}
					t.current_token.doctype.force_quirks = true
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.bogus_doctype {
					if c := current {
						if c == `>` {
							return t.switch_to_and_emit_current_token(.data)
						} else if c == 0 {
							continue
						} else {
							continue
						}
					}
					t.enqueue(t.current_token)
					return t.emit_eof()
				}
				.before_attribute_name {
					if c := current {
						if is_html_whitespace(c) {
							continue
						} else if c == `/` {
							t.state = .after_attribute_name
							reconsume = true
							continue
						} else if c == `>` {
							t.state = .after_attribute_name
							reconsume = true
							continue
						} else if c == `=` {
							mut new_attribute := Attribute{}
							new_attribute.name_start_position = t.nth_last_position(1)
							t.current_builder << c
							t.current_token.add_attribute(new_attribute)
							t.state = .attribute_name
							continue
						} else {
							mut new_attribute := Attribute{}
							new_attribute.name_start_position = t.nth_last_position(1)
							t.current_token.add_attribute(new_attribute)
							t.state = .attribute_name
							reconsume = true
							continue
						}
					}
					t.state = .after_attribute_name
					reconsume = true
					continue
				}
				.self_closing_start_tag {
					if c := current {
						if c == `>` {
							t.current_token.set_self_closing(true)
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.state = .before_attribute_name
							reconsume = true
							continue
						}
					}
					return t.emit_eof()
				}
				.attribute_name {
					if c := current {
						if is_html_whitespace(c) || c == `/` || c == `>` {
							li := t.current_token.attributes.len - 1
							t.current_token.attributes[li].name_end_position =
								t.nth_last_position(1)
							t.current_token.attributes[li].local_name = t.consume_current_builder()
							t.state = .after_attribute_name
							reconsume = true
							continue
						} else if c == `=` {
							li := t.current_token.attributes.len - 1
							t.current_token.attributes[li].name_end_position =
								t.nth_last_position(1)
							t.current_token.attributes[li].local_name = t.consume_current_builder()
							t.state = .before_attribute_value
							continue
						} else if is_ascii_upper_alpha(c) {
							t.current_builder << to_ascii_lowercase(c)
							continue
						} else if c == 0 {
							t.current_builder << rune(0xfffd)
							continue
						} else {
							// '"', '\'', '<' are parse errors but handled as anything-else.
							t.current_builder << c
							continue
						}
					}
					// EOF -> reconsume in AfterAttributeName.
					li := t.current_token.attributes.len - 1
					t.current_token.attributes[li].name_end_position = t.nth_last_position(1)
					t.current_token.attributes[li].local_name = t.consume_current_builder()
					t.state = .after_attribute_name
					reconsume = true
					continue
				}
				.after_attribute_name {
					if c := current {
						if is_html_whitespace(c) {
							continue
						} else if c == `/` {
							t.state = .self_closing_start_tag
							continue
						} else if c == `=` {
							li := t.current_token.attributes.len - 1
							t.current_token.attributes[li].name_end_position =
								t.nth_last_position(1)
							t.state = .before_attribute_value
							continue
						} else if c == `>` {
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.current_token.add_attribute(Attribute{})
							if t.source_positions.len > 0 {
								li := t.current_token.attributes.len - 1
								t.current_token.attributes[li].name_start_position =
									t.nth_last_position(1)
							}
							t.state = .attribute_name
							reconsume = true
							continue
						}
					}
					return t.emit_eof()
				}
				.before_attribute_value {
					li0 := t.current_token.attributes.len - 1
					t.current_token.attributes[li0].value_start_position = t.nth_last_position(1)
					if c := current {
						if is_html_whitespace(c) {
							continue
						} else if c == `"` {
							t.state = .attribute_value_double_quoted
							continue
						} else if c == `'` {
							t.state = .attribute_value_single_quoted
							continue
						} else if c == `>` {
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.state = .attribute_value_unquoted
							reconsume = true
							continue
						}
					}
					t.state = .attribute_value_unquoted
					reconsume = true
					continue
				}
				.attribute_value_double_quoted {
					if c := current {
						if c == `"` {
							li := t.current_token.attributes.len - 1
							t.current_token.attributes[li].value = t.consume_current_builder()
							t.state = .after_attribute_value_quoted
							continue
						} else if c == `&` {
							t.return_state = .attribute_value_double_quoted
							t.state = .character_reference
							continue
						} else if c == 0 {
							t.current_builder << rune(0xfffd)
							continue
						} else {
							t.current_builder << c
							continue
						}
					}
					return t.emit_eof()
				}
				.attribute_value_single_quoted {
					if c := current {
						if c == `'` {
							li := t.current_token.attributes.len - 1
							t.current_token.attributes[li].value = t.consume_current_builder()
							t.state = .after_attribute_value_quoted
							continue
						} else if c == `&` {
							t.return_state = .attribute_value_single_quoted
							t.state = .character_reference
							continue
						} else if c == 0 {
							t.current_builder << rune(0xfffd)
							continue
						} else {
							t.current_builder << c
							continue
						}
					}
					return t.emit_eof()
				}
				.attribute_value_unquoted {
					if c := current {
						if is_html_whitespace(c) {
							li := t.current_token.attributes.len - 1
							t.current_token.attributes[li].value = t.consume_current_builder()
							t.current_token.attributes[li].value_end_position =
								t.nth_last_position(1)
							t.state = .before_attribute_name
							continue
						} else if c == `&` {
							t.return_state = .attribute_value_unquoted
							t.state = .character_reference
							continue
						} else if c == `>` {
							li := t.current_token.attributes.len - 1
							t.current_token.attributes[li].value = t.consume_current_builder()
							t.current_token.attributes[li].value_end_position =
								t.nth_last_position(1)
							return t.switch_to_and_emit_current_token(.data)
						} else if c == 0 {
							t.current_builder << rune(0xfffd)
							continue
						} else {
							// '"', '\'', '<', '=', '`' are parse errors but handled as anything-else.
							t.current_builder << c
							continue
						}
					}
					return t.emit_eof()
				}
				.after_attribute_value_quoted {
					li0 := t.current_token.attributes.len - 1
					t.current_token.attributes[li0].value_end_position = t.nth_last_position(1)
					if c := current {
						if is_html_whitespace(c) {
							t.state = .before_attribute_name
							continue
						} else if c == `/` {
							t.state = .self_closing_start_tag
							continue
						} else if c == `>` {
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.state = .before_attribute_name
							reconsume = true
							continue
						}
					}
					return t.emit_eof()
				}
				.comment_start {
					if c := current {
						if c == `-` {
							t.state = .comment_start_dash
							continue
						} else if c == `>` {
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.state = .comment
							reconsume = true
							continue
						}
					}
					t.state = .comment
					reconsume = true
					continue
				}
				.comment_start_dash {
					if c := current {
						if c == `-` {
							t.state = .comment_end
							continue
						} else if c == `>` {
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.current_builder << `-`
							t.state = .comment
							reconsume = true
							continue
						}
					}
					t.current_token.set_comment(t.consume_current_builder())
					return t.emit_current_token_followed_by_eof()
				}
				.comment {
					if c := current {
						if c == `<` {
							t.current_builder << c
							t.state = .comment_less_than_sign
							continue
						} else if c == `-` {
							t.state = .comment_end_dash
							continue
						} else if c == 0 {
							t.current_builder << rune(0xfffd)
							continue
						} else {
							t.current_builder << c
							continue
						}
					}
					t.current_token.set_comment(t.consume_current_builder())
					return t.emit_current_token_followed_by_eof()
				}
				.comment_less_than_sign {
					if c := current {
						if c == `!` {
							t.current_builder << c
							t.state = .comment_less_than_sign_bang
							continue
						} else if c == `<` {
							t.current_builder << c
							continue
						} else {
							t.state = .comment
							reconsume = true
							continue
						}
					}
					t.state = .comment
					reconsume = true
					continue
				}
				.comment_less_than_sign_bang {
					if c := current {
						if c == `-` {
							t.state = .comment_less_than_sign_bang_dash
							continue
						} else {
							t.state = .comment
							reconsume = true
							continue
						}
					}
					t.state = .comment
					reconsume = true
					continue
				}
				.comment_less_than_sign_bang_dash {
					if c := current {
						if c == `-` {
							t.state = .comment_less_than_sign_bang_dash_dash
							continue
						} else {
							t.state = .comment_end_dash
							reconsume = true
							continue
						}
					}
					t.state = .comment_end_dash
					reconsume = true
					continue
				}
				.comment_less_than_sign_bang_dash_dash {
					if c := current {
						if c == `>` {
							t.state = .comment_end
							reconsume = true
							continue
						} else {
							t.state = .comment_end
							reconsume = true
							continue
						}
					}
					t.state = .comment_end
					reconsume = true
					continue
				}
				.comment_end_dash {
					if c := current {
						if c == `-` {
							t.state = .comment_end
							continue
						} else {
							t.current_builder << `-`
							t.state = .comment
							reconsume = true
							continue
						}
					}
					t.current_token.set_comment(t.consume_current_builder())
					return t.emit_current_token_followed_by_eof()
				}
				.comment_end {
					if c := current {
						if c == `>` {
							t.current_token.set_comment(t.consume_current_builder())
							return t.switch_to_and_emit_current_token(.data)
						} else if c == `!` {
							t.state = .comment_end_bang
							continue
						} else if c == `-` {
							t.current_builder << `-`
							continue
						} else {
							t.append_string_to_builder('--')
							t.state = .comment
							reconsume = true
							continue
						}
					}
					t.current_token.set_comment(t.consume_current_builder())
					return t.emit_current_token_followed_by_eof()
				}
				.comment_end_bang {
					if c := current {
						if c == `-` {
							t.append_string_to_builder('--!')
							t.state = .comment_end_dash
							continue
						} else if c == `>` {
							t.current_token.set_comment(t.consume_current_builder())
							return t.switch_to_and_emit_current_token(.data)
						} else {
							t.append_string_to_builder('--!')
							t.state = .comment
							reconsume = true
							continue
						}
					}
					t.current_token.set_comment(t.consume_current_builder())
					return t.emit_current_token_followed_by_eof()
				}
				.character_reference {
					t.temporary_buffer.clear()
					t.temporary_buffer << rune(`&`)
					if c := current {
						if is_ascii_alphanumeric(c) {
							t.matcher.reset()
							t.state = .named_character_reference
							reconsume = true
							continue
						} else if c == `#` {
							t.temporary_buffer << c
							t.state = .numeric_character_reference
							continue
						} else {
							t.flush_codepoints_consumed_as_a_character_reference()
							t.state = t.return_state
							t.restore_to(t.prev_offset)
							continue start_of_function
						}
					}
					t.flush_codepoints_consumed_as_a_character_reference()
					t.state = t.return_state
					continue start_of_function
				}
				.named_character_reference {
					if t.can_run_out_of_characters(stop) {
						if c := current {
							if t.matcher.try_consume_code_point(c) {
								t.temporary_buffer << c
								continue
							} else {
								t.restore_to(t.prev_offset)
							}
						}
					} else {
						starting_consumed_count := t.temporary_buffer.len
						mut idx := t.prev_offset
						for idx < t.decoded_input.len {
							code_point := t.decoded_input[idx]
							if t.matcher.try_consume_code_point(code_point) {
								t.temporary_buffer << code_point
								idx++
							} else {
								break
							}
						}
						num_consumed := t.temporary_buffer.len - starting_consumed_count
						if num_consumed == 0 {
							if current != none {
								t.restore_to(t.prev_offset)
							}
						} else if num_consumed > 1 {
							t.skip(num_consumed - 1)
						}
					}

					overconsumed := t.matcher.overconsumed_code_points()
					if overconsumed > 0 {
						t.restore_to(t.current_offset - overconsumed)
						t.temporary_buffer.trim(t.temporary_buffer.len - overconsumed)
					}

					if mapped := t.matcher.code_points() {
						if t.consumed_as_part_of_an_attribute()
							&& !t.matcher.last_match_ends_with_semicolon() {
							if next_cp := t.peek_code_point(0, stop) {
								if next_cp == `=` || is_ascii_alphanumeric(next_cp) {
									t.flush_codepoints_consumed_as_a_character_reference()
									t.state = t.return_state
									continue start_of_function
								}
							}
						}
						t.temporary_buffer.clear()
						t.temporary_buffer << rune(mapped.first)
						if mapped.second != 0 {
							t.temporary_buffer << rune(mapped.second)
						}
						t.flush_codepoints_consumed_as_a_character_reference()
						t.state = t.return_state
						continue start_of_function
					} else {
						t.flush_codepoints_consumed_as_a_character_reference()
						t.state = .ambiguous_ampersand
						continue
					}
				}
				.ambiguous_ampersand {
					if c := current {
						if is_ascii_alphanumeric(c) {
							if t.consumed_as_part_of_an_attribute() {
								t.current_builder << c
								continue
							} else {
								return t.emit_character(c)
							}
						} else if c == `;` {
							t.state = t.return_state
							t.restore_to(t.prev_offset)
							continue start_of_function
						} else {
							t.state = t.return_state
							t.restore_to(t.prev_offset)
							continue start_of_function
						}
					}
					t.state = t.return_state
					continue start_of_function
				}
				.numeric_character_reference {
					t.character_reference_code = 0
					if c := current {
						if c == `X` || c == `x` {
							t.temporary_buffer << c
							t.state = .hexadecimal_character_reference_start
							continue
						} else {
							t.state = .decimal_character_reference_start
							reconsume = true
							continue
						}
					}
					t.state = .decimal_character_reference_start
					reconsume = true
					continue
				}
				.hexadecimal_character_reference_start {
					if c := current {
						if is_ascii_hex_digit(c) {
							t.state = .hexadecimal_character_reference
							reconsume = true
							continue
						} else {
							t.flush_codepoints_consumed_as_a_character_reference()
							t.state = t.return_state
							t.restore_to(t.prev_offset)
							continue start_of_function
						}
					}
					t.flush_codepoints_consumed_as_a_character_reference()
					t.state = t.return_state
					continue start_of_function
				}
				.decimal_character_reference_start {
					if c := current {
						if is_ascii_digit(c) {
							t.state = .decimal_character_reference
							reconsume = true
							continue
						} else {
							t.flush_codepoints_consumed_as_a_character_reference()
							t.state = t.return_state
							t.restore_to(t.prev_offset)
							continue start_of_function
						}
					}
					t.flush_codepoints_consumed_as_a_character_reference()
					t.state = t.return_state
					continue start_of_function
				}
				.hexadecimal_character_reference {
					if c := current {
						if is_ascii_digit(c) {
							t.character_reference_code = t.character_reference_code * 16 + u32(c -
								0x30)
							continue
						} else if is_ascii_hex_digit(c) {
							hex_min := if is_ascii_upper_alpha(c) { rune(0x37) } else { rune(0x57) }
							t.character_reference_code = t.character_reference_code * 16 + u32(c -
								hex_min)
							continue
						} else if c == `;` {
							t.state = .numeric_character_reference_end
							continue
						} else {
							t.state = .numeric_character_reference_end
							reconsume = true
							continue
						}
					}
					t.state = .numeric_character_reference_end
					reconsume = true
					continue
				}
				.decimal_character_reference {
					if c := current {
						if is_ascii_digit(c) {
							t.character_reference_code = t.character_reference_code * 10 + u32(c -
								0x30)
							continue
						} else if c == `;` {
							t.state = .numeric_character_reference_end
							continue
						} else {
							t.state = .numeric_character_reference_end
							reconsume = true
							continue
						}
					}
					t.state = .numeric_character_reference_end
					reconsume = true
					continue
				}
				.numeric_character_reference_end {
					if current != none {
						t.restore_to(t.prev_offset)
					}
					mut code := t.character_reference_code
					if code == 0 {
						code = 0xfffd
					}
					if code > 0x10ffff {
						code = 0xfffd
					}
					if is_unicode_surrogate(code) {
						code = 0xfffd
					}
					if code == 0x0d || (is_unicode_control(code) && !is_ascii_space_u32(code)) {
						code = convert_numeric_control_code(code)
					}
					t.temporary_buffer.clear()
					t.temporary_buffer << rune(code)
					t.flush_codepoints_consumed_as_a_character_reference()
					t.state = t.return_state
					continue start_of_function
				}
				.rcdata {
					if c := current {
						if c == `&` {
							t.return_state = .rcdata
							t.state = .character_reference
							continue
						} else if c == `<` {
							t.state = .rcdata_less_than_sign
							continue
						} else if c == 0 {
							return t.emit_character(rune(0xfffd))
						} else {
							return t.emit_character(c)
						}
					}
					return t.emit_eof()
				}
				.rcdata_less_than_sign {
					if c := current {
						if c == `/` {
							t.temporary_buffer.clear()
							t.state = .rcdata_end_tag_open
							continue
						} else {
							t.enqueue(HTMLToken.make_character(`<`))
							t.state = .rcdata
							reconsume = true
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`<`))
					t.state = .rcdata
					reconsume = true
					continue
				}
				.rcdata_end_tag_open {
					if c := current {
						if is_ascii_alpha(c) {
							t.create_new_token(.end_tag)
							t.state = .rcdata_end_tag_name
							reconsume = true
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`<`))
					t.enqueue(HTMLToken.make_character(`/`))
					t.state = .rcdata
					reconsume = true
					continue
				}
				.rcdata_end_tag_name {
					if c := current {
						if is_html_whitespace(c) {
							t.current_token.tag_name = t.consume_current_builder()
							if !t.current_end_tag_token_is_appropriate() {
								t.emit_temporary_buffer_as_end_tag_fallback(.rcdata)
								reconsume = true
								continue
							}
							t.state = .before_attribute_name
							continue
						} else if c == `/` {
							t.current_token.tag_name = t.consume_current_builder()
							if !t.current_end_tag_token_is_appropriate() {
								t.emit_temporary_buffer_as_end_tag_fallback(.rcdata)
								reconsume = true
								continue
							}
							t.state = .self_closing_start_tag
							continue
						} else if c == `>` {
							t.current_token.tag_name = t.consume_current_builder()
							if !t.current_end_tag_token_is_appropriate() {
								t.emit_temporary_buffer_as_end_tag_fallback(.rcdata)
								reconsume = true
								continue
							}
							return t.switch_to_and_emit_current_token(.data)
						} else if is_ascii_upper_alpha(c) {
							t.current_builder << to_ascii_lowercase(c)
							t.temporary_buffer << c
							continue
						} else if is_ascii_lower_alpha(c) {
							t.current_builder << c
							t.temporary_buffer << c
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`<`))
					t.enqueue(HTMLToken.make_character(`/`))
					t.current_builder.clear()
					for code_point in t.temporary_buffer {
						t.enqueue(HTMLToken.make_character(code_point))
					}
					t.state = .rcdata
					reconsume = true
					continue
				}
				.rawtext {
					if c := current {
						if c == `<` {
							t.state = .rawtext_less_than_sign
							continue
						} else if c == 0 {
							return t.emit_character(rune(0xfffd))
						} else {
							return t.emit_character(c)
						}
					}
					return t.emit_eof()
				}
				.rawtext_less_than_sign {
					if c := current {
						if c == `/` {
							t.temporary_buffer.clear()
							t.state = .rawtext_end_tag_open
							continue
						} else {
							t.enqueue(HTMLToken.make_character(`<`))
							t.state = .rawtext
							reconsume = true
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`<`))
					t.state = .rawtext
					reconsume = true
					continue
				}
				.rawtext_end_tag_open {
					if c := current {
						if is_ascii_alpha(c) {
							t.create_new_token(.end_tag)
							t.state = .rawtext_end_tag_name
							reconsume = true
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`<`))
					t.enqueue(HTMLToken.make_character(`/`))
					t.state = .rawtext
					reconsume = true
					continue
				}
				.rawtext_end_tag_name {
					if c := current {
						if is_html_whitespace(c) {
							t.current_token.tag_name = t.consume_current_builder()
							if !t.current_end_tag_token_is_appropriate() {
								t.emit_temporary_buffer_as_end_tag_fallback(.rawtext)
								reconsume = true
								continue
							}
							t.state = .before_attribute_name
							continue
						} else if c == `/` {
							t.current_token.tag_name = t.consume_current_builder()
							if !t.current_end_tag_token_is_appropriate() {
								t.emit_temporary_buffer_as_end_tag_fallback(.rawtext)
								reconsume = true
								continue
							}
							t.state = .self_closing_start_tag
							continue
						} else if c == `>` {
							t.current_token.tag_name = t.consume_current_builder()
							if !t.current_end_tag_token_is_appropriate() {
								t.emit_temporary_buffer_as_end_tag_fallback(.rawtext)
								reconsume = true
								continue
							}
							return t.switch_to_and_emit_current_token(.data)
						} else if is_ascii_upper_alpha(c) {
							t.current_builder << to_ascii_lowercase(c)
							t.temporary_buffer << c
							continue
						} else if is_ascii_lower_alpha(c) {
							t.current_builder << c
							t.temporary_buffer << c
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`<`))
					t.enqueue(HTMLToken.make_character(`/`))
					t.current_builder.clear()
					for code_point in t.temporary_buffer {
						t.enqueue(HTMLToken.make_character(code_point))
					}
					t.state = .rawtext
					reconsume = true
					continue
				}
				.script_data {
					if c := current {
						if c == `<` {
							t.state = .script_data_less_than_sign
							continue
						} else if c == 0 {
							return t.emit_character(rune(0xfffd))
						} else {
							return t.emit_character(c)
						}
					}
					return t.emit_eof()
				}
				.plaintext {
					if c := current {
						if c == 0 {
							return t.emit_character(rune(0xfffd))
						} else {
							return t.emit_character(c)
						}
					}
					return t.emit_eof()
				}
				.script_data_less_than_sign {
					if c := current {
						if c == `/` {
							t.temporary_buffer.clear()
							t.state = .script_data_end_tag_open
							continue
						} else if c == `!` {
							t.enqueue(HTMLToken.make_character(`<`))
							t.enqueue(HTMLToken.make_character(`!`))
							t.state = .script_data_escape_start
							continue
						} else {
							t.enqueue(HTMLToken.make_character(`<`))
							t.state = .script_data
							reconsume = true
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`<`))
					t.state = .script_data
					reconsume = true
					continue
				}
				.script_data_end_tag_open {
					if c := current {
						if is_ascii_alpha(c) {
							t.create_new_token(.end_tag)
							t.state = .script_data_end_tag_name
							reconsume = true
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`<`))
					t.enqueue(HTMLToken.make_character(`/`))
					t.state = .script_data
					reconsume = true
					continue
				}
				.script_data_end_tag_name {
					if c := current {
						if is_html_whitespace(c) {
							t.current_token.tag_name = t.consume_current_builder()
							if t.current_end_tag_token_is_appropriate() {
								t.state = .before_attribute_name
								continue
							}
							t.emit_temporary_buffer_as_end_tag_fallback(.script_data)
							reconsume = true
							continue
						} else if c == `/` {
							t.current_token.tag_name = t.consume_current_builder()
							if t.current_end_tag_token_is_appropriate() {
								t.state = .self_closing_start_tag
								continue
							}
							t.emit_temporary_buffer_as_end_tag_fallback(.script_data)
							reconsume = true
							continue
						} else if c == `>` {
							t.current_token.tag_name = t.consume_current_builder()
							if t.current_end_tag_token_is_appropriate() {
								return t.switch_to_and_emit_current_token(.data)
							}
							t.emit_temporary_buffer_as_end_tag_fallback(.script_data)
							reconsume = true
							continue
						} else if is_ascii_upper_alpha(c) {
							t.current_builder << to_ascii_lowercase(c)
							t.temporary_buffer << c
							continue
						} else if is_ascii_lower_alpha(c) {
							t.current_builder << c
							t.temporary_buffer << c
							continue
						}
					}
					t.emit_temporary_buffer_as_end_tag_fallback(.script_data)
					reconsume = true
					continue
				}
				.script_data_escape_start {
					if c := current {
						if c == `-` {
							t.state = .script_data_escape_start_dash
							return t.emit_character(`-`)
						} else {
							t.state = .script_data
							reconsume = true
							continue
						}
					}
					t.state = .script_data
					reconsume = true
					continue
				}
				.script_data_escape_start_dash {
					if c := current {
						if c == `-` {
							t.state = .script_data_escaped_dash_dash
							return t.emit_character(`-`)
						} else {
							t.state = .script_data
							reconsume = true
							continue
						}
					}
					t.state = .script_data
					reconsume = true
					continue
				}
				.script_data_escaped {
					if c := current {
						if c == `-` {
							t.state = .script_data_escaped_dash
							return t.emit_character(`-`)
						} else if c == `<` {
							t.state = .script_data_escaped_less_than_sign
							continue
						} else if c == 0 {
							return t.emit_character(rune(0xfffd))
						} else {
							return t.emit_character(c)
						}
					}
					return t.emit_eof()
				}
				.script_data_escaped_dash {
					if c := current {
						if c == `-` {
							t.state = .script_data_escaped_dash_dash
							return t.emit_character(`-`)
						} else if c == `<` {
							t.state = .script_data_escaped_less_than_sign
							continue
						} else if c == 0 {
							t.state = .script_data_escaped
							return t.emit_character(rune(0xfffd))
						} else {
							t.state = .script_data_escaped
							return t.emit_character(c)
						}
					}
					return t.emit_eof()
				}
				.script_data_escaped_dash_dash {
					if c := current {
						if c == `-` {
							return t.emit_character(`-`)
						} else if c == `<` {
							t.state = .script_data_escaped_less_than_sign
							continue
						} else if c == `>` {
							t.state = .script_data
							return t.emit_character(`>`)
						} else if c == 0 {
							t.state = .script_data_escaped
							return t.emit_character(rune(0xfffd))
						} else {
							t.state = .script_data_escaped
							return t.emit_character(c)
						}
					}
					return t.emit_eof()
				}
				.script_data_escaped_less_than_sign {
					if c := current {
						if c == `/` {
							t.temporary_buffer.clear()
							t.state = .script_data_escaped_end_tag_open
							continue
						} else if is_ascii_alpha(c) {
							t.temporary_buffer.clear()
							t.enqueue(HTMLToken.make_character(`<`))
							t.state = .script_data_double_escape_start
							reconsume = true
							continue
						} else {
							t.enqueue(HTMLToken.make_character(`<`))
							t.state = .script_data_escaped
							reconsume = true
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`<`))
					t.state = .script_data_escaped
					reconsume = true
					continue
				}
				.script_data_escaped_end_tag_open {
					if c := current {
						if is_ascii_alpha(c) {
							t.create_new_token(.end_tag)
							t.state = .script_data_escaped_end_tag_name
							reconsume = true
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`<`))
					t.enqueue(HTMLToken.make_character(`/`))
					t.state = .script_data_escaped
					reconsume = true
					continue
				}
				.script_data_escaped_end_tag_name {
					if c := current {
						if is_html_whitespace(c) {
							t.current_token.tag_name = t.consume_current_builder()
							if t.current_end_tag_token_is_appropriate() {
								t.state = .before_attribute_name
								continue
							}
							t.emit_temporary_buffer_as_end_tag_fallback(.script_data_escaped)
							reconsume = true
							continue
						} else if c == `/` {
							t.current_token.tag_name = t.consume_current_builder()
							if t.current_end_tag_token_is_appropriate() {
								t.state = .self_closing_start_tag
								continue
							}
							t.emit_temporary_buffer_as_end_tag_fallback(.script_data_escaped)
							reconsume = true
							continue
						} else if c == `>` {
							t.current_token.tag_name = t.consume_current_builder()
							if t.current_end_tag_token_is_appropriate() {
								return t.switch_to_and_emit_current_token(.data)
							}
							t.emit_temporary_buffer_as_end_tag_fallback(.script_data_escaped)
							reconsume = true
							continue
						} else if is_ascii_upper_alpha(c) {
							t.current_builder << to_ascii_lowercase(c)
							t.temporary_buffer << c
							continue
						} else if is_ascii_lower_alpha(c) {
							t.current_builder << c
							t.temporary_buffer << c
							continue
						}
					}
					t.emit_temporary_buffer_as_end_tag_fallback(.script_data_escaped)
					reconsume = true
					continue
				}
				.script_data_double_escape_start {
					if c := current {
						if is_html_whitespace(c) || c == `/` || c == `>` {
							if t.temporary_buffer_equal_to_script() {
								t.state = .script_data_double_escaped
							} else {
								t.state = .script_data_escaped
							}
							return t.emit_character(c)
						} else if is_ascii_upper_alpha(c) {
							t.temporary_buffer << to_ascii_lowercase(c)
							return t.emit_character(c)
						} else if is_ascii_lower_alpha(c) {
							t.temporary_buffer << c
							return t.emit_character(c)
						} else {
							t.state = .script_data_escaped
							reconsume = true
							continue
						}
					}
					t.state = .script_data_escaped
					reconsume = true
					continue
				}
				.script_data_double_escaped {
					if c := current {
						if c == `-` {
							t.state = .script_data_double_escaped_dash
							return t.emit_character(`-`)
						} else if c == `<` {
							t.state = .script_data_double_escaped_less_than_sign
							return t.emit_character(`<`)
						} else if c == 0 {
							return t.emit_character(rune(0xfffd))
						} else {
							return t.emit_character(c)
						}
					}
					return t.emit_eof()
				}
				.script_data_double_escaped_dash {
					if c := current {
						if c == `-` {
							t.state = .script_data_double_escaped_dash_dash
							return t.emit_character(`-`)
						} else if c == `<` {
							t.state = .script_data_double_escaped_less_than_sign
							return t.emit_character(`<`)
						} else if c == 0 {
							t.state = .script_data_double_escaped
							return t.emit_character(rune(0xfffd))
						} else {
							t.state = .script_data_double_escaped
							return t.emit_character(c)
						}
					}
					return t.emit_eof()
				}
				.script_data_double_escaped_dash_dash {
					if c := current {
						if c == `-` {
							return t.emit_character(`-`)
						} else if c == `<` {
							t.state = .script_data_double_escaped_less_than_sign
							return t.emit_character(`<`)
						} else if c == `>` {
							t.state = .script_data
							return t.emit_character(`>`)
						} else if c == 0 {
							t.state = .script_data_double_escaped
							return t.emit_character(rune(0xfffd))
						} else {
							t.state = .script_data_double_escaped
							return t.emit_character(c)
						}
					}
					return t.emit_eof()
				}
				.script_data_double_escaped_less_than_sign {
					if c := current {
						if c == `/` {
							t.temporary_buffer.clear()
							t.state = .script_data_double_escape_end
							return t.emit_character(`/`)
						} else {
							t.state = .script_data_double_escaped
							reconsume = true
							continue
						}
					}
					t.state = .script_data_double_escaped
					reconsume = true
					continue
				}
				.script_data_double_escape_end {
					if c := current {
						if is_html_whitespace(c) || c == `/` || c == `>` {
							if t.temporary_buffer_equal_to_script() {
								t.state = .script_data_escaped
							} else {
								t.state = .script_data_double_escaped
							}
							return t.emit_character(c)
						} else if is_ascii_upper_alpha(c) {
							t.temporary_buffer << to_ascii_lowercase(c)
							return t.emit_character(c)
						} else if is_ascii_lower_alpha(c) {
							t.temporary_buffer << c
							return t.emit_character(c)
						} else {
							t.state = .script_data_double_escaped
							reconsume = true
							continue
						}
					}
					t.state = .script_data_double_escaped
					reconsume = true
					continue
				}
				.cdata_section {
					if c := current {
						if c == `]` {
							t.state = .cdata_section_bracket
							continue
						} else {
							return t.emit_character(c)
						}
					}
					return t.emit_eof()
				}
				.cdata_section_bracket {
					if c := current {
						if c == `]` {
							t.state = .cdata_section_end
							continue
						} else {
							t.enqueue(HTMLToken.make_character(`]`))
							t.state = .cdata_section
							reconsume = true
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`]`))
					t.state = .cdata_section
					reconsume = true
					continue
				}
				.cdata_section_end {
					if c := current {
						if c == `]` {
							return t.emit_character(`]`)
						} else if c == `>` {
							t.state = .data
							continue
						} else {
							t.enqueue(HTMLToken.make_character(`]`))
							t.enqueue(HTMLToken.make_character(`]`))
							t.state = .cdata_section
							reconsume = true
							continue
						}
					}
					t.enqueue(HTMLToken.make_character(`]`))
					t.enqueue(HTMLToken.make_character(`]`))
					t.state = .cdata_section
					reconsume = true
					continue
				}
			}
		}
	}
	return none
}

// Shared fallback for *EndTagName states: when the end tag is inappropriate, emit '<', '/', and the
// temporary buffer as character tokens, drop the current token, and reconsume in `fallback_state`.
fn (mut t HTMLTokenizer) emit_temporary_buffer_as_end_tag_fallback(fallback_state State) {
	t.enqueue(HTMLToken.make_character(`<`))
	t.enqueue(HTMLToken.make_character(`/`))
	t.current_builder.clear()
	for code_point in t.temporary_buffer {
		t.enqueue(HTMLToken.make_character(code_point))
	}
	t.state = fallback_state
}
