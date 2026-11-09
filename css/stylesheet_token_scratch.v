module css

$if prealloc {
	import platform
}

// The syntax cache owns the immutable component tree, while tokenizer builders,
// raw token copies and growing temporary vectors can retire after construction.
// The workspace is thread-local, including for shared user-agent sheets parsed
// before any document exists. Only the owned result escapes its lifetime.
fn stylesheet_components_from_source(input string) []ComponentValue {
	$if prealloc {
		if input.len >= stylesheet_syntax_minimum_bytes {
			mut scratch := platform.begin_thread_scratch('stylesheet tokenization')
			values := ParserTokenStream.from_transient_source(input, 'utf-8').values
			scratch.leave()
			owned := own_stylesheet_components(values)
			scratch.finish()
			return owned
		}
	}
	return ParserTokenStream.from_source(input, 'utf-8').values
}

fn own_stylesheet_token(token Token) Token {
	// Unescaped identifiers and delimiters already share their immutable
	// source spelling. Preserve that sharing in the new owner, without
	// conflating escaped values or different spans of the same source.
	source := token.original_source_text_.clone()
	value := if token.value.str == token.original_source_text_.str
		&& token.value.len == token.original_source_text_.len {
		source
	} else {
		token.value.clone()
	}
	return Token{
		...token
		value: value
		original_source_text_: source
	}
}

// Export each payload and its text recursively into the retained owner.
// Explicit branch returns avoid constructing an unused default sum variant.
fn own_stylesheet_component(component &ComponentValue) ComponentValue {
	if component.value is &Token {
		return ComponentValue{value:ComponentValuePayload(&Token{...own_stylesheet_token(*component.value)}), attr_tainted:component.attr_tainted}
	} else if component.value is &SimpleBlock {
		return ComponentValue{
			value:ComponentValuePayload(&SimpleBlock{
				token:own_stylesheet_token(component.value.token)
				end_token:own_stylesheet_token(component.value.end_token)
				value:own_stylesheet_components(component.value.value)
			})
			attr_tainted:component.attr_tainted
		}
	} else if component.value is &Function {
		name_token := own_stylesheet_token(component.value.name_token)
		name := if component.value.name.str == component.value.name_token.value.str
			&& component.value.name.len == component.value.name_token.value.len {
			name_token.value
		} else {
			component.value.name.clone()
		}
		return ComponentValue{
			value:ComponentValuePayload(&Function{
				name:name
				name_token:name_token
				end_token:own_stylesheet_token(component.value.end_token)
				value:own_stylesheet_components(component.value.value)
			})
			attr_tainted:component.attr_tainted
		}
	} else if component.value is RawComponentValue {
		return ComponentValue{value:ComponentValuePayload(RawComponentValue{text:component.value.text.clone()}), attr_tainted:component.attr_tainted}
	} else if component.value is GuaranteedInvalidValue {
		return ComponentValue{value:ComponentValuePayload(GuaranteedInvalidValue{}), attr_tainted:component.attr_tainted}
	}
	panic('invalid CSS component payload')
}

fn own_stylesheet_components(values []ComponentValue) []ComponentValue {
	mut owned := []ComponentValue{cap:values.len}
	for index in 0 .. values.len {
		owned << own_stylesheet_component(unsafe { &values[index] })
	}
	return owned
}
