// Copyright (c) 2021-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTML/SyntaxHighlighter/SyntaxHighlighter.{h,cpp}. The
// embedding can supply JS/CSS nested highlighters; without one, script/style
// contents are still returned as language-tagged spans.
module html

pub enum AugmentedTokenKind as u32 {
	attribute_name
	attribute_value
	open_tag
	close_tag
	comment
	doctype
	javascript = 1000
	css        = 2000
}

pub enum SyntaxLanguage {
	html
	javascript
	css
}

pub struct SyntaxTextRange {
pub:
	start Position
	end   Position
}

pub struct SyntaxHighlightSpan {
pub:
	range    SyntaxTextRange
	kind     AugmentedTokenKind
	language SyntaxLanguage = .html
	bold     bool
	source   string
}

pub struct SyntaxFoldingRegion {
pub:
	range SyntaxTextRange
}

pub struct SyntaxMatchingTokenPair {
pub:
	open_range  SyntaxTextRange
	close_range SyntaxTextRange
}

pub struct SyntaxHighlightResult {
pub:
	spans           []SyntaxHighlightSpan
	folding_regions []SyntaxFoldingRegion
	matching_pairs  []SyntaxMatchingTokenPair
}

pub struct NestedSyntaxHighlightResult {
pub:
	spans           []SyntaxHighlightSpan
	folding_regions []SyntaxFoldingRegion
}

pub type NestedSyntaxHighlightHook = fn (string, Position, SyntaxLanguage) NestedSyntaxHighlightResult

struct OpenSyntaxTag {
	name  string
	range SyntaxTextRange
}

@[heap]
pub struct HTMLSyntaxHighlighter {
mut:
	nested_highlight_hook_ ?NestedSyntaxHighlightHook
}

pub fn HTMLSyntaxHighlighter.create() &HTMLSyntaxHighlighter {
	return &HTMLSyntaxHighlighter{}
}

pub fn (mut highlighter HTMLSyntaxHighlighter) set_nested_highlight_hook(hook ?NestedSyntaxHighlightHook) {
	highlighter.nested_highlight_hook_ = hook
}

pub fn (highlighter &HTMLSyntaxHighlighter) is_identifier(token u64) bool {
	_ = token
	return false
}

pub fn (highlighter &HTMLSyntaxHighlighter) is_navigatable(token u64) bool {
	_ = token
	return false
}

pub fn (highlighter &HTMLSyntaxHighlighter) language() SyntaxLanguage {
	return .html
}

pub fn (highlighter &HTMLSyntaxHighlighter) comment_prefix() string {
	return '<!--'
}

pub fn (highlighter &HTMLSyntaxHighlighter) comment_suffix() string {
	return '-->'
}

pub fn (highlighter &HTMLSyntaxHighlighter) token_types_equal(first u64, second u64) bool {
	return first == second
}

pub fn (highlighter &HTMLSyntaxHighlighter) matching_token_kinds() []AugmentedTokenKind {
	return [.open_tag, .close_tag]
}

fn valid_syntax_range(start Position, end Position) bool {
	return start.line < end.line || (start.line == end.line && start.column < end.column)
}

fn append_syntax_span(mut spans []SyntaxHighlightSpan, start Position, end Position, kind AugmentedTokenKind, language SyntaxLanguage, bold bool, source string) {
	if !valid_syntax_range(start, end) {
		return
	}
	spans << SyntaxHighlightSpan{
		range:    SyntaxTextRange{
			start: start
			end:   end
		}
		kind:     kind
		language: language
		bold:     bold
		source:   source
	}
}

fn tag_name_range(token HTMLToken) SyntaxTextRange {
	return SyntaxTextRange{
		start: token.start_position
		end:   Position{
			line:   token.start_position.line
			column: token.start_position.column + token.tag_name.len
		}
	}
}

fn append_nested_syntax(mut spans []SyntaxHighlightSpan, mut folding_regions []SyntaxFoldingRegion, hook ?NestedSyntaxHighlightHook, source string, start Position, end Position, language SyntaxLanguage) {
	if source == '' || !valid_syntax_range(start, end) {
		return
	}
	if nested_hook := hook {
		result := nested_hook(source, start, language)
		spans << result.spans
		folding_regions << result.folding_regions
		return
	}
	kind := if language == .javascript {
		AugmentedTokenKind.javascript
	} else {
		AugmentedTokenKind.css
	}
	append_syntax_span(mut spans, start, end, kind, language, false, source)
}

pub fn (highlighter &HTMLSyntaxHighlighter) rehighlight(text string) SyntaxHighlightResult {
	mut tokenizer := HTMLTokenizer.new(text)
	mut spans := []SyntaxHighlightSpan{}
	mut folding_regions := []SyntaxFoldingRegion{}
	mut matching_pairs := []SyntaxMatchingTokenPair{}
	mut open_tags := []OpenSyntaxTag{}
	mut state := SyntaxLanguage.html
	mut nested_source := []rune{}
	mut nested_start := Position{}

	for {
		token := tokenizer.next_token() or { break }
		if token.is_end_of_file() {
			break
		}

		if token.is_start_tag() {
			if token.tag_name == 'script' {
				tokenizer.switch_to(.script_data)
				state = .javascript
				nested_start = Position{
					line:   token.end_position.line
					column: token.end_position.column + 1
				}
			} else if token.tag_name == 'style' {
				tokenizer.switch_to(.rawtext)
				state = .css
				nested_start = Position{
					line:   token.end_position.line
					column: token.end_position.column + 1
				}
			}
		} else if token.is_end_tag() && token.tag_name in ['script', 'style'] {
			append_nested_syntax(mut spans, mut folding_regions,
				highlighter.nested_highlight_hook_, nested_source.string(), nested_start,
				token.start_position, state)
			nested_source.clear()
			state = .html
		} else if state != .html {
			if token.is_character() {
				nested_source << token.code_point
			}
			continue
		}

		if token.is_comment() {
			append_syntax_span(mut spans, token.start_position, token.end_position, .comment,
				.html, false, token.comment_data)
			start := Position{
				line:   token.start_position.line
				column: token.start_position.column + highlighter.comment_prefix().len
			}
			end := Position{
				line:   token.end_position.line
				column: token.end_position.column - highlighter.comment_suffix().len
			}
			if valid_syntax_range(start, end) {
				folding_regions << SyntaxFoldingRegion{
					range: SyntaxTextRange{
						start: start
						end:   end
					}
				}
			}
		} else if token.is_start_tag() || token.is_end_tag() {
			range := tag_name_range(token)
			append_syntax_span(mut spans, range.start, range.end, if token.is_start_tag() {
				.open_tag
			} else {
				.close_tag
			}, .html, true, token.tag_name)
			for attribute in token.attributes {
				append_syntax_span(mut spans, attribute.name_start_position,
					attribute.name_end_position, .attribute_name, .html, false,
					attribute.local_name)
				append_syntax_span(mut spans, attribute.value_start_position,
					attribute.value_end_position, .attribute_value, .html, false, attribute.value)
			}
			if token.is_start_tag() && !token.is_self_closing() {
				open_tags << OpenSyntaxTag{
					name:  token.tag_name
					range: range
				}
			} else if token.is_end_tag() {
				for index := open_tags.len - 1; index >= 0; index-- {
					if open_tags[index].name == token.tag_name {
						matching_pairs << SyntaxMatchingTokenPair{
							open_range:  open_tags[index].range
							close_range: range
						}
						open_tags.delete(index)
						break
					}
				}
			}
		} else if token.is_doctype() {
			append_syntax_span(mut spans, token.start_position, token.end_position, .doctype,
				.html, false, token.doctype.name)
		}
	}

	return SyntaxHighlightResult{
		spans:           spans
		folding_regions: folding_regions
		matching_pairs:  matching_pairs
	}
}
