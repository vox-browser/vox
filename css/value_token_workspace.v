module css

$if prealloc {
	import platform
}

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

// Component payloads may be shared by cached syntax or custom-property input.
// Publish new headers and vectors; changing a borrowed header would transfer a
// document-owned string into the shared input and shorten its lifetime.
fn own_value_component_text(mut components []ComponentValue) {
	components = own_value_components(components)
}

fn own_value_components(components []ComponentValue) []ComponentValue {
	mut owned := []ComponentValue{cap: components.len}
	for component in components {
		owned << own_value_component(component)
	}
	return owned
}

fn own_value_component(component ComponentValue) ComponentValue {
	match component.value {
		&Token {
			token := component.token()
			return ComponentValue{
				value: ComponentValuePayload(&Token{
					...token
					value: token.value.clone()
					// Typed values never retain whitespace. Unresolved values
					// separately own their entire component tree.
					original_source_text_: if token.is(.whitespace) {
						token.original_source_text_
					} else { token.original_source_text_.clone() }
				})
				attr_tainted: component.attr_tainted
			}
		}
		&Function {
			function := component.function()
			children := own_value_components(function.value)
			return ComponentValue{
				value: ComponentValuePayload(&Function{
					...function
					name: function.name.clone()
					name_token: own_stylesheet_token(function.name_token)
					end_token: own_stylesheet_token(function.end_token)
					value: children
				})
				attr_tainted: component.attr_tainted
			}
		}
		&SimpleBlock {
			block := component.block()
			children := own_value_components(block.value)
			return ComponentValue{
				value: ComponentValuePayload(&SimpleBlock{
					...block
					token: own_stylesheet_token(block.token)
					end_token: own_stylesheet_token(block.end_token)
					value: children
				})
				attr_tainted: component.attr_tainted
			}
		}
		RawComponentValue {
			return ComponentValue{
				value: ComponentValuePayload(RawComponentValue{text: component.value.text.clone()})
				attr_tainted: component.attr_tainted
			}
		}
		GuaranteedInvalidValue { return component }
	}
}
