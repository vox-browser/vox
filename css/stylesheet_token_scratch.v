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

// A match expression initializes the sum type's first (Function) variant in
// current V before selecting a branch. Return from each branch instead: token
// leaves must allocate their actual payload once, without an unused Function.
fn own_stylesheet_component(component &ComponentValue) ComponentValue {
	match component.value {
		Token {
			return ComponentValue{value:ComponentValuePayload(own_stylesheet_token(component.value)), attr_tainted:component.attr_tainted}
		}
		SimpleBlock {
			return ComponentValue{
				value:ComponentValuePayload(SimpleBlock{
					token:own_stylesheet_token(component.value.token)
					end_token:own_stylesheet_token(component.value.end_token)
					value:own_stylesheet_components(component.value.value)
				})
				attr_tainted:component.attr_tainted
			}
		}
		Function {
			return ComponentValue{
				value:ComponentValuePayload(Function{
					name:component.value.name.clone()
					name_token:own_stylesheet_token(component.value.name_token)
					end_token:own_stylesheet_token(component.value.end_token)
					value:own_stylesheet_components(component.value.value)
				})
				attr_tainted:component.attr_tainted
			}
		}
		RawComponentValue {
			return ComponentValue{value:ComponentValuePayload(RawComponentValue{text:component.value.text.clone()}), attr_tainted:component.attr_tainted}
		}
		GuaranteedInvalidValue {
			return ComponentValue{value:ComponentValuePayload(GuaranteedInvalidValue{}), attr_tainted:component.attr_tainted}
		}
	}
}

fn own_stylesheet_components(values []ComponentValue) []ComponentValue {
	mut owned := []ComponentValue{cap:values.len}
	for index in 0 .. values.len {
		owned << own_stylesheet_component(unsafe { &values[index] })
	}
	return owned
}
