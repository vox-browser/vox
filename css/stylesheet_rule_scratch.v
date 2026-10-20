module css

import platform

// Consume the raw rule tree separately from conversion. Qualified-rule and
// child-list vectors, growing declaration lists and parse recovery temporaries
// have no readers after conversion. Tokenizer input remains immutable and owned
// by the caller or syntax cache.
fn (mut parser RuleSelectorParser) parse_stylesheet_rules(location ?string) []&CSSRule {
	$if prealloc {
		if platform.current_retained_arena() != unsafe { nil }
			&& parser.token_stream.values.len > 0 {
			mut scratch := platform.new_arena('stylesheet rule syntax')
			entry := scratch.enter()
			mut raw_parser := RuleSelectorParser{
				...parser
				token_stream: ParserTokenStream{
					...parser.token_stream
					marks: parser.token_stream.marks.clone()
				}
				value_context: parser.value_context.clone()
				rule_context: parser.rule_context.clone()
			}
			raw := raw_parser.parse_a_stylesheet(location)
			scratch.leave(entry)
			parser.token_stream.index = raw_parser.token_stream.index
			previous := parser.raw_rules_transient
			parser.raw_rules_transient = true
			defer {
				parser.raw_rules_transient = previous
				scratch.release()
			}
			return parser.convert_rules(raw.rules)
		}
	}
	return parser.convert_rules(parser.parse_a_stylesheet(location).rules)
}

fn (parser &RuleSelectorParser) own_deferred_rule_declarations(declarations []Declaration) []Declaration {
	if !parser.raw_rules_transient { return declarations }
	mut owned := []Declaration{cap:declarations.len}
	for index in 0 .. declarations.len {
		declaration := unsafe { &declarations[index] }
		owned << Declaration{
			...declaration
			original_value_text: if text := declaration.original_value_text { ?string(text.clone()) } else { none }
			original_full_text: if text := declaration.original_full_text { ?string(text.clone()) } else { none }
		}
	}
	return owned
}
