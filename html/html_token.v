module html

import strings

// Translation of Libraries/LibWeb/HTML/Parser/HTMLToken.{h,cpp}.
// A single token produced by the HTML tokenizer.

pub enum TokenType {
	invalid
	doctype
	start_tag
	end_tag
	comment
	processing_instruction
	character
	end_of_file
}

pub struct Position {
pub mut:
	line   int
	column int
}

pub struct Attribute {
pub mut:
	prefix               ?string
	local_name           string
	namespace_           ?string
	value                string
	name_start_position  Position
	value_start_position Position
	name_end_position    Position
	value_end_position   Position
}

pub struct DoctypeData {
pub mut:
	// NOTE: "Missing" is a distinct state from the empty string.
	name                      string
	public_identifier         string
	system_identifier         string
	missing_name              bool = true
	missing_public_identifier bool = true
	missing_system_identifier bool = true
	force_quirks              bool
}

pub enum HTMLTokenAttributeIterationDecision {
	continue_
	@break
}

pub struct HTMLToken {
pub mut:
	type_ TokenType = .invalid

	// Type::StartTag and Type::EndTag
	tag_self_closing              bool
	tag_self_closing_acknowledged bool

	// AD-HOC: We need to know if the token had duplicate attributes, as Content Security Policy
	// disables the nonce attribute on the element that will be created from such a token.
	had_duplicate_attribute bool

	// Type::StartTag and Type::EndTag (tag name)
	tag_name string

	// Comment and processing-instruction data.
	comment_data string
	processing_instruction_target string

	// Type::Character (code point)
	code_point rune

	// Type::DOCTYPE
	doctype DoctypeData

	// Type::StartTag and Type::EndTag (attributes)
	attributes []Attribute

	start_position Position
	end_position   Position
}

pub fn HTMLToken.new(type_ TokenType) HTMLToken {
	return HTMLToken{
		type_: type_
	}
}

pub fn HTMLToken.make_character(code_point rune) HTMLToken {
	mut token := HTMLToken.new(.character)
	token.code_point = code_point
	return token
}

pub fn HTMLToken.make_start_tag(tag_name string) HTMLToken {
	mut token := HTMLToken.new(.start_tag)
	token.tag_name = tag_name
	return token
}

pub fn (t &HTMLToken) is_doctype() bool {
	return t.type_ == .doctype
}

pub fn (t &HTMLToken) is_start_tag() bool {
	return t.type_ == .start_tag
}

pub fn (t &HTMLToken) is_end_tag() bool {
	return t.type_ == .end_tag
}

pub fn (t &HTMLToken) is_comment() bool {
	return t.type_ == .comment
}

pub fn (t &HTMLToken) is_processing_instruction() bool {
	return t.type_ == .processing_instruction
}

fn (t &HTMLToken) is_comment_or_processing_instruction() bool {
	return t.is_comment() || t.is_processing_instruction()
}

pub fn (t &HTMLToken) is_character() bool {
	return t.type_ == .character
}

pub fn (t &HTMLToken) is_end_of_file() bool {
	return t.type_ == .end_of_file
}

pub fn (t &HTMLToken) type_name() TokenType {
	return t.type_
}

pub fn (t &HTMLToken) type_() TokenType {
	return t.type_
}

pub fn (t &HTMLToken) start_position() Position {
	return t.start_position
}

pub fn (t &HTMLToken) end_position() Position {
	return t.end_position
}

pub fn (mut t HTMLToken) set_start_position(position Position) {
	t.start_position = position
}

pub fn (mut t HTMLToken) set_end_position(position Position) {
	t.end_position = position
}

pub fn (t &HTMLToken) had_duplicate_attribute() bool {
	return t.had_duplicate_attribute
}

// https://html.spec.whatwg.org/multipage/parsing.html - the parser treats '\r' as whitespace,
// while the tokenizer does not.
pub fn (t &HTMLToken) is_parser_whitespace() bool {
	if !t.is_character() {
		return false
	}
	return t.code_point in [rune(`\t`), `\n`, `\f`, `\r`, ` `]
}

pub fn (mut t HTMLToken) set_code_point(code_point rune) {
	t.code_point = code_point
}

pub fn (t &HTMLToken) comment() string {
	return t.comment_data
}

pub fn (mut t HTMLToken) set_comment(comment string) {
	t.comment_data = comment
}

pub fn (mut t HTMLToken) set_tag_name(name string) {
	t.tag_name = name
}

pub fn (t &HTMLToken) is_self_closing() bool {
	return t.tag_self_closing
}

pub fn (mut t HTMLToken) set_self_closing(self_closing bool) {
	t.tag_self_closing = self_closing
}

pub fn (t &HTMLToken) has_acknowledged_self_closing_flag() bool {
	return t.tag_self_closing_acknowledged
}

pub fn (mut t HTMLToken) acknowledge_self_closing_flag_if_set() {
	if t.is_self_closing() {
		t.tag_self_closing_acknowledged = true
	}
}

pub fn (t &HTMLToken) has_attributes() bool {
	return t.attributes.len > 0
}

pub fn (t &HTMLToken) attribute_count() int {
	return t.attributes.len
}

pub fn (mut t HTMLToken) add_attribute(attribute Attribute) {
	// Copy the attribute record. Its string payloads are immutable; later
	// edits replace the string header rather than modifying shared bytes.
	t.attributes << unsafe { attribute }
}

// The native class has const and mutable overloads. V consolidates them into
// a mutable callback, which is also sufficient for read-only callbacks.
pub fn (mut t HTMLToken) for_each_attribute(callback fn (mut Attribute) HTMLTokenAttributeIterationDecision) {
	for index in 0 .. t.attributes.len {
		if callback(mut t.attributes[index]) == .@break {
			break
		}
	}
}

pub fn (t &HTMLToken) last_attribute() ?Attribute {
	if t.attributes.len == 0 {
		return none
	}
	return t.attributes.last()
}

pub fn (t &HTMLToken) tag_attributes() []Attribute {
	return t.attributes.clone()
}

pub fn (mut t HTMLToken) ensure_tag_attributes() []Attribute {
	return t.attributes
}

pub fn (mut t HTMLToken) drop_attributes() {
	t.attributes = []
}

// https://html.spec.whatwg.org/multipage/parsing.html#attribute-name-state - a value for the
// named attribute, if present.
pub fn (t &HTMLToken) attribute(attribute_name string) ?string {
	attr := t.raw_attribute(attribute_name)?
	return attr.value
}

pub fn (t &HTMLToken) raw_attribute(attribute_name string) ?Attribute {
	for attribute in t.attributes {
		if attribute_name == attribute.local_name {
			return attribute
		}
	}
	return none
}

pub fn (t &HTMLToken) has_attribute(attribute_name string) bool {
	return t.attribute(attribute_name) != none
}

// Used by the parser's foreign-content adjustments (MathML/SVG).
pub fn (mut t HTMLToken) adjust_tag_name(old_name string, new_name string) {
	if old_name == t.tag_name {
		t.tag_name = new_name
	}
}

pub fn (mut t HTMLToken) adjust_attribute_name(old_name string, new_name string) {
	for i in 0 .. t.attributes.len {
		if t.attributes[i].local_name == old_name {
			t.attributes[i].local_name = new_name
		}
	}
}

pub fn (mut t HTMLToken) adjust_foreign_attribute(old_name string, prefix ?string, local_name string, namespace_ ?string) {
	for i in 0 .. t.attributes.len {
		if t.attributes[i].local_name == old_name {
			t.attributes[i].prefix = prefix
			t.attributes[i].local_name = local_name
			t.attributes[i].namespace_ = namespace_
		}
	}
}

pub fn (mut t HTMLToken) ensure_doctype_data() &DoctypeData {
	return &t.doctype
}

pub fn (t &HTMLToken) doctype_data() &DoctypeData {
	return &t.doctype
}

// https://html.spec.whatwg.org/multipage/parsing.html#attribute-name-state - remove duplicate
// attributes, keeping the first occurrence of each name.
pub fn (mut t HTMLToken) normalize_attributes() {
	if t.attributes.len < 2 {
		return
	}
	// Most tags have only a few attributes. Check them without a hash table or
	// replacement array, keeping the existing token storage when names are unique.
	if t.attributes.len <= 16 {
		for index in 1 .. t.attributes.len {
			mut duplicate := false
			for previous in 0 .. index {
				if t.attributes[previous].local_name == t.attributes[index].local_name {
					duplicate = true
					break
				}
			}
			if !duplicate {
				continue
			}
			t.had_duplicate_attribute = true
			// Preserve aliases to the original array, as the hash-based path does.
			mut result := []Attribute{cap: t.attributes.len}
			for previous in 0 .. index {
				result << t.attributes[previous]
			}
			for remaining in index + 1 .. t.attributes.len {
				mut seen := false
				for attribute in result {
					if attribute.local_name == t.attributes[remaining].local_name {
						seen = true
						break
					}
				}
				if !seen {
					result << t.attributes[remaining]
				}
			}
			t.attributes = result
			return
		}
		return
	}
	// Bound work for unusually large or adversarial attribute lists.
	mut seen_attributes := map[string]bool{}
	mut result := []Attribute{cap: t.attributes.len}
	for attribute in t.attributes {
		if attribute.local_name in seen_attributes {
			// This is a duplicate attribute, remove it.
			t.had_duplicate_attribute = true
			continue
		}
		seen_attributes[attribute.local_name] = true
		result << attribute
	}
	t.attributes = result
}

pub fn (t &HTMLToken) to_string() string {
	mut builder := strings.new_builder(64)

	match t.type_ {
		.doctype {
			builder.write_string('DOCTYPE')
			builder.write_string(" { name: '")
			builder.write_string(t.doctype.name)
			builder.write_string("' }")
		}
		.start_tag {
			builder.write_string('StartTag')
		}
		.end_tag {
			builder.write_string('EndTag')
		}
		.comment {
			builder.write_string('Comment')
		}
		.processing_instruction {
			builder.write_string('ProcessingInstruction { target: ${t.processing_instruction_target} }')
		}
		.character {
			builder.write_string('Character')
		}
		.end_of_file {
			builder.write_string('EndOfFile')
		}
		.invalid {}
	}

	if t.type_ == .start_tag || t.type_ == .end_tag {
		builder.write_string(" { name: '")
		builder.write_string(t.tag_name)
		builder.write_string("', { ")
		for attribute in t.attributes {
			builder.write_string(attribute.local_name)
			builder.write_string('="')
			builder.write_string(attribute.value)
			builder.write_string('" ')
		}
		builder.write_string('} }')
	}

	if t.is_comment_or_processing_instruction() {
		builder.write_string(" { data: '")
		builder.write_string(t.comment_data)
		builder.write_string("' }")
	}

	if t.is_character() {
		builder.write_string(" { data: '")
		builder.write_rune(t.code_point)
		builder.write_string("' }")
	}

	if t.type_ == .character {
		builder.write_string('@${t.start_position.line}:${t.start_position.column}')
	} else {
		builder.write_string('@${t.start_position.line}:${t.start_position.column}-${t.end_position.line}:${t.end_position.column}')
	}

	return builder.str()
}
