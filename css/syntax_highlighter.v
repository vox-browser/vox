module css

// Translated from LibWeb/CSS/SyntaxHighlighter/SyntaxHighlighter.cpp/.h.

pub enum SyntaxLanguage {
	css
}

pub enum SyntaxColorRole {
	identifier
	string
	comment
	keyword
	punctuation
	number
	error
}

pub struct SyntaxTextAttributes {
pub mut:
	color SyntaxColorRole
	bold  bool
}

pub struct SyntaxTextPosition {
pub mut:
	line   uint
	column uint
}

pub struct SyntaxTextRange {
pub mut:
	start SyntaxTextPosition
	end   SyntaxTextPosition
}

pub struct SyntaxTextDocumentSpan {
pub mut:
	range       SyntaxTextRange
	attributes  SyntaxTextAttributes
	data        TokenType
	navigatable bool
}

pub struct SyntaxTextDocumentFoldingRegion {
pub mut:
	range SyntaxTextRange
}

pub struct SyntaxMatchingTokenPair {
pub mut:
	open  TokenType
	close TokenType
}

pub struct SyntaxHighlightResult {
pub mut:
	spans           []SyntaxTextDocumentSpan
	folding_regions []SyntaxTextDocumentFoldingRegion
}

pub struct Palette {}

pub fn (palette Palette) syntax_identifier() SyntaxColorRole {
	_ = palette
	return .identifier
}

pub fn (palette Palette) syntax_string() SyntaxColorRole {
	_ = palette
	return .string
}

pub fn (palette Palette) syntax_comment() SyntaxColorRole {
	_ = palette
	return .comment
}

pub fn (palette Palette) syntax_keyword() SyntaxColorRole {
	_ = palette
	return .keyword
}

pub fn (palette Palette) syntax_punctuation() SyntaxColorRole {
	_ = palette
	return .punctuation
}

pub fn (palette Palette) syntax_number() SyntaxColorRole {
	_ = palette
	return .number
}

pub struct SyntaxHighlighter {}

pub fn SyntaxHighlighter.create() SyntaxHighlighter {
	return SyntaxHighlighter{}
}

pub fn (highlighter SyntaxHighlighter) is_identifier(token TokenType) bool {
	_ = highlighter
	return token == .ident
}

pub fn (highlighter SyntaxHighlighter) is_navigatable(token TokenType) bool {
	_ = highlighter
	_ = token
	return false
}

pub fn (highlighter SyntaxHighlighter) language() SyntaxLanguage {
	_ = highlighter
	return .css
}

pub fn (highlighter SyntaxHighlighter) comment_prefix() ?string {
	_ = highlighter
	return '/*'
}

pub fn (highlighter SyntaxHighlighter) comment_suffix() ?string {
	_ = highlighter
	return '*/'
}

pub fn (highlighter SyntaxHighlighter) rehighlight_text(text string, palette Palette) SyntaxHighlightResult {
	_ = highlighter
	mut folding_region_start_tokens := []Token{}
	mut folding_regions := []SyntaxTextDocumentFoldingRegion{}
	mut spans := []SyntaxTextDocumentSpan{}

	// V function values capture dynamic-array headers by value. Keep a pointer
	// to the caller's header so appends remain visible in the returned result.
	spans_ptr := &spans
	highlight := fn [spans_ptr] (start_line uint, start_column uint, end_line uint, end_column uint, attributes SyntaxTextAttributes, type_ TokenType) {
		if start_line > end_line || (start_line == end_line && start_column >= end_column) {
			return
		}
		mut updated_spans := unsafe { *spans_ptr }
		updated_spans << SyntaxTextDocumentSpan{
			range: SyntaxTextRange{
				start: SyntaxTextPosition{
					line: start_line
					column: start_column
				}
				end: SyntaxTextPosition{
					line: end_line
					column: end_column
				}
			}
			attributes: attributes
			data: type_
			navigatable: false
		}
		unsafe {
			*spans_ptr = updated_spans
		}
	}

	tokens := Tokenizer.tokenize(text, 'utf-8')
	for token in tokens {
		if token.is(.end_of_file) {
			break
		}

		if token.is(.open_curly) {
			folding_region_start_tokens << token
		} else if token.is(.close_curly) {
			if folding_region_start_tokens.len != 0 {
				start_token := folding_region_start_tokens.pop()
				folding_regions << SyntaxTextDocumentFoldingRegion{
					range: SyntaxTextRange{
						start: SyntaxTextPosition{
							line: start_token.end_position().line
							column: start_token.end_position().column
						}
						end: SyntaxTextPosition{
							line: token.start_position().line
							column: token.start_position().column
						}
					}
				}
			}
		}

		match token.token_type() {
			.ident {
				highlight(token.start_position().line, token.start_position().column, token.end_position().line, token.end_position().column, SyntaxTextAttributes{
					color: palette.syntax_identifier()
				}, token.token_type())
			}
			.string {
				highlight(token.start_position().line, token.start_position().column, token.end_position().line, token.end_position().column, SyntaxTextAttributes{
					color: palette.syntax_string()
				}, token.token_type())
			}
			.whitespace {
				// CSS doesn't produce comment tokens, they're just included as part of whitespace.
				highlight(token.start_position().line, token.start_position().column, token.end_position().line, token.end_position().column, SyntaxTextAttributes{
					color: palette.syntax_comment()
				}, token.token_type())
			}
			.at_keyword {
				highlight(token.start_position().line, token.start_position().column, token.end_position().line, token.end_position().column, SyntaxTextAttributes{
					color: palette.syntax_keyword()
				}, token.token_type())
			}
			.function {
				// Function tokens include the opening '(', so we split that into two tokens for highlighting purposes.
				highlight(token.start_position().line, token.start_position().column, token.end_position().line, token.end_position().column - 1, SyntaxTextAttributes{
					color: palette.syntax_keyword()
				}, token.token_type())
				highlight(token.end_position().line, token.end_position().column - 1, token.end_position().line, token.end_position().column, SyntaxTextAttributes{
					color: palette.syntax_punctuation()
				}, .open_paren)
			}
			.url {
				// An Url token is a `url()` function with its parameter string unquoted.
				// url
				highlight(token.start_position().line, token.start_position().column, token.start_position().line, token.start_position().column + 3, SyntaxTextAttributes{
					color: palette.syntax_keyword()
				}, token.token_type())
				// (
				highlight(token.start_position().line, token.start_position().column + 3, token.start_position().line, token.start_position().column + 4, SyntaxTextAttributes{
					color: palette.syntax_punctuation()
				}, .open_paren)
				// <string>
				highlight(token.start_position().line, token.start_position().column + 4, token.end_position().line, token.end_position().column - 1, SyntaxTextAttributes{
					color: palette.syntax_string()
				}, .string)
				// )
				highlight(token.end_position().line, token.end_position().column - 1, token.end_position().line, token.end_position().column, SyntaxTextAttributes{
					color: palette.syntax_punctuation()
				}, .close_paren)
			}
			.number, .dimension, .percentage {
				highlight(token.start_position().line, token.start_position().column, token.end_position().line, token.end_position().column, SyntaxTextAttributes{
					color: palette.syntax_number()
				}, token.token_type())
			}
			.delim, .colon, .comma, .semicolon, .open_curly, .open_paren, .open_square, .close_curly, .close_paren, .close_square {
				highlight(token.start_position().line, token.start_position().column, token.end_position().line, token.end_position().column, SyntaxTextAttributes{
					color: palette.syntax_punctuation()
				}, token.token_type())
			}
			.cdo, .cdc {
				highlight(token.start_position().line, token.start_position().column, token.end_position().line, token.end_position().column, SyntaxTextAttributes{
					color: palette.syntax_comment()
				}, token.token_type())
			}
			.hash {
				// FIXME: Hash tokens can be ID selectors or colors, we don't know which without parsing properly.
				highlight(token.start_position().line, token.start_position().column, token.end_position().line, token.end_position().column, SyntaxTextAttributes{
					color: palette.syntax_number()
				}, token.token_type())
			}
			.invalid, .bad_url, .bad_string {
				// FIXME: Error highlighting color in palette?
				highlight(token.start_position().line, token.start_position().column, token.end_position().line, token.end_position().column, SyntaxTextAttributes{
					color: .error
					bold: true
				}, token.token_type())
			}
			.end_of_file {}
		}
	}

	return SyntaxHighlightResult{
		spans: spans
		folding_regions: folding_regions
	}
}

pub fn (highlighter SyntaxHighlighter) matching_token_pairs_impl() []SyntaxMatchingTokenPair {
	_ = highlighter
	return [
		SyntaxMatchingTokenPair{
			open: .open_curly
			close: .close_curly
		},
		SyntaxMatchingTokenPair{
			open: .open_paren
			close: .close_paren
		},
		SyntaxMatchingTokenPair{
			open: .open_square
			close: .close_square
		},
		SyntaxMatchingTokenPair{
			open: .cdo
			close: .cdc
		},
	]
}

pub fn (highlighter SyntaxHighlighter) token_types_equal(token0 TokenType, token1 TokenType) bool {
	_ = highlighter
	return token0 == token1
}
