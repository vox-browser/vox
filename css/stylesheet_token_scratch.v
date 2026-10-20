module css

import platform

// The syntax cache owns the immutable component tree, while tokenizer builders,
// raw token copies and growing temporary vectors can retire after construction.
// Native document scopes prove origin-thread ownership; concurrent standalone
// parser callers keep their existing allocation path.
fn stylesheet_components_from_source(input string) []ComponentValue {
	$if prealloc {
		if input.len >= stylesheet_syntax_minimum_bytes
			&& platform.current_retained_arena() != unsafe { nil } {
			mut scratch := platform.new_arena('stylesheet tokenization')
			entry := scratch.enter()
			values := ParserTokenStream.from_source(input, 'utf-8').values
			scratch.leave(entry)
			owned := own_stylesheet_components(values)
			scratch.release()
			return owned
		}
	}
	return ParserTokenStream.from_source(input, 'utf-8').values
}

fn own_stylesheet_token(token Token) Token {
	return Token{
		...token
		value: token.value.clone()
		original_source_text_: token.original_source_text_.clone()
	}
}

fn own_stylesheet_components(values []ComponentValue) []ComponentValue {
	mut owned := []ComponentValue{cap: values.len}
	for component in values {
		payload := match component.value {
			Token { ComponentValuePayload(own_stylesheet_token(component.value)) }
			SimpleBlock {
				ComponentValuePayload(SimpleBlock{
					token: own_stylesheet_token(component.value.token)
					end_token: own_stylesheet_token(component.value.end_token)
					value: own_stylesheet_components(component.value.value)
				})
			}
			Function {
				ComponentValuePayload(Function{
					name: component.value.name.clone()
					name_token: own_stylesheet_token(component.value.name_token)
					end_token: own_stylesheet_token(component.value.end_token)
					value: own_stylesheet_components(component.value.value)
				})
			}
			RawComponentValue { ComponentValuePayload(RawComponentValue{text:component.value.text.clone()}) }
			GuaranteedInvalidValue { ComponentValuePayload(GuaranteedInvalidValue{}) }
		}
		owned << ComponentValue{value:payload, attr_tainted:component.attr_tainted}
	}
	return owned
}
