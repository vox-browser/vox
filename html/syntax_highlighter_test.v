module html

fn spans_have_kind(spans []SyntaxHighlightSpan, kind AugmentedTokenKind) bool {
	for span in spans {
		if span.kind == kind {
			return true
		}
	}
	return false
}

fn test_html_syntax_highlighter_emits_markup_attributes_and_pairs() {
	highlighter := HTMLSyntaxHighlighter.create()
	result := highlighter.rehighlight('<div class="box"><span id=x>text</span></div>')
	literal_result := syntax_highlighter_rehighlight(highlighter, '<b>x</b>')
	assert literal_result.matching_pairs.len == 1
	assert spans_have_kind(result.spans, .open_tag)
	assert spans_have_kind(result.spans, .close_tag)
	assert spans_have_kind(result.spans, .attribute_name)
	assert spans_have_kind(result.spans, .attribute_value)
	assert result.matching_pairs.len == 2
	assert highlighter.language() == .html
	assert highlighter.comment_prefix() == '<!--'
	assert highlighter.comment_suffix() == '-->'
	assert !highlighter.is_identifier(u64(AugmentedTokenKind.open_tag))
	assert !highlighter.is_navigatable(u64(AugmentedTokenKind.open_tag))
}

fn test_html_syntax_highlighter_delegates_script_and_style_content() {
	highlighter := HTMLSyntaxHighlighter.create()
	result :=
		highlighter.rehighlight('<script>let answer = 42;</script><style>a { color: red }</style>')
	mut javascript_source := ''
	mut css_source := ''
	for span in result.spans {
		if span.kind == .javascript {
			javascript_source = span.source
		}
		if span.kind == .css {
			css_source = span.source
		}
	}
	assert javascript_source == 'let answer = 42;'
	assert css_source == 'a { color: red }'
	assert result.matching_pairs.len == 2
}

fn test_html_syntax_highlighter_comments_and_doctype() {
	highlighter := HTMLSyntaxHighlighter.create()
	result := highlighter.rehighlight('<!doctype html><!-- first\nsecond -->')
	assert spans_have_kind(result.spans, .doctype)
	assert spans_have_kind(result.spans, .comment)
	assert result.folding_regions.len == 1
}

fn test_html_syntax_highlighter_accepts_nested_highlighter_hook() {
	mut highlighter := HTMLSyntaxHighlighter.create()
	highlighter.set_nested_highlight_hook(fn (source string, start Position, language SyntaxLanguage) NestedSyntaxHighlightResult {
		return NestedSyntaxHighlightResult{
			spans: [
				SyntaxHighlightSpan{
					range:    SyntaxTextRange{
						start: start
						end:   Position{
							line:   start.line
							column: start.column + source.len
						}
					}
					kind:     if language == .javascript { .javascript } else { .css }
					language: language
					source:   'delegated:${source}'
				},
			]
		}
	})
	result := highlighter.rehighlight('<script>x()</script>')
	mut delegated := false
	for span in result.spans {
		if span.source == 'delegated:x()' {
			delegated = true
		}
	}
	assert delegated
}
