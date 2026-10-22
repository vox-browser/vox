module css

import platform

// A property parse publishes typed values, not its tokenizer or component tree.
// Keep those inputs in a retiring workspace. Simple typed graphs are exported
// from a second workspace; complex values keep their decoded strings, and
// unresolved values additionally retain their complete component tree.
fn parse_css_value_in_workspace(context ParsingParams, property PropertyID, text string) ?StyleValue {
	$if prealloc {
		scratch := platform.begin_thread_scratch('CSS value tokens')
		components := parse_component_values_for_value_logic(text)
		scratch.leave()
		defer { scratch.finish() }
		return parse_property_components_with_export(context, property, components, true)
	}
	mut parser := Parser.with_context(context, text)
	return parser.parse_css_value(property)
}

fn own_value_component_text(mut components []ComponentValue) {
	for mut component in components {
		mut payload := component.value
		match mut payload {
			Token {
				payload.value = payload.value.clone()
				// Typed values never retain whitespace. Comments can occupy a large
				// whitespace token; borrow that text until the parse completes.
				// Unresolved values own their entire token tree above.
				if !payload.is(.whitespace) {
					payload.original_source_text_ = payload.original_source_text_.clone()
				}
			}
			Function {
				payload.name = payload.name.clone()
				payload.name_token = own_stylesheet_token(payload.name_token)
				payload.end_token = own_stylesheet_token(payload.end_token)
				own_value_component_text(mut payload.value)
			}
			SimpleBlock {
				payload.token = own_stylesheet_token(payload.token)
				payload.end_token = own_stylesheet_token(payload.end_token)
				own_value_component_text(mut payload.value)
			}
			RawComponentValue { payload.text = payload.text.clone() }
			GuaranteedInvalidValue {}
		}
	}
}
