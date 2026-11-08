module css

import dom
import os

const disable_simple_var_property_reuse = os.getenv('VOX_DISABLE_SIMPLE_VAR_PROPERTY_REUSE') != ''
const simple_var_property_diagnostics = os.getenv('VOX_SIMPLE_VAR_PROPERTY_DIAGNOSTICS') != ''
__global simple_var_property_reported bool

struct SimpleVarPropertyEntry {
	property PropertyID
	input voidptr
	tokens []Token
	value &dom.StyleValue
}

@[heap]
struct SimpleVarPropertyCache {
mut:
	entries map[u64]SimpleVarPropertyEntry
}

fn single_var_name(tokens []ComponentValue) ?string {
	mut stream := ParserTokenStream.from_values(tokens)
	stream.discard_whitespace()
	value := stream.consume_a_token()
	stream.discard_whitespace()
	if stream.has_next_token() || !value.is_function_named('var') { return none }
	mut arguments := ParserTokenStream.from_values(value.function().value)
	arguments.discard_whitespace()
	name := arguments.consume_a_token()
	arguments.discard_whitespace()
	if arguments.has_next_token() || !name.is(.ident)
		|| !is_a_custom_property_name_string(name.token().ident()) { return none }
	return name.token().ident()
}

// Follow only a single, fallback-free var() chain ending in a small immutable
// token sequence. Missing/registered values, cycles, CSS-wide keywords and all
// element/environment/function-dependent substitution retain the full path.
fn simple_var_leaf_tokens(element dom.AbstractElement, tokens []ComponentValue,
	depth int) ?[]ComponentValue {
	if depth == 16 { return none }
	name := single_var_name(tokens) or { return none }
	if element.document().get_registered_custom_property(name) != none { return none }
	bridge := element.get_custom_property(name) or { return none }
	if bridge.guaranteed_invalid { return none }
	value := dom_style_value_from_custom_property_bridge(bridge) or { return none }
	typed := typed_style_value_logic_from_dom(value) or { return none }
	if typed !is UnresolvedStyleValue { return none }
	presence := typed.substitution_functions_presence
	if presence.attr || presence.custom_function || presence.env || presence.if_ || presence.inherit { return none }
	if presence.var { return simple_var_leaf_tokens(element, typed.tokens, depth + 1) }
	if typed.tokens.len == 0 || typed.tokens.len > 12 { return none }
	for token in typed.tokens {
		if !token.is_token() || token.attr_tainted || token.is(.bad_string) || token.is(.bad_url)
			|| token.is(.invalid) || token.is(.url) { return none }
	}
	return typed.tokens
}

fn reuse_simple_var_property(element dom.AbstractElement, property PropertyID,
	unresolved UnresolvedStyleValue) ?&dom.StyleValue {
	if disable_simple_var_property_reuse { return none }
	computer := css_style_computer_for(element.document())
	if computer.computed_property_page_batch_depth_ == 0 { return none }
	tokens := simple_var_leaf_tokens(element, unresolved.tokens, 0) or { return none }
	mut owner := unsafe { &StyleComputer(computer) }
	if owner.simple_var_properties_ == unsafe { nil } {
		owner.simple_var_properties_ = &SimpleVarPropertyCache{}
	}
	mut cache := owner.simple_var_properties_
	identity := tokens.data
	key := u64(identity) ^ (u64(property) * u64(0x9e3779b97f4a7c15))
	if entry := cache.entries[key] {
		if entry.property == property && entry.input == identity && entry.tokens.len == tokens.len {
			mut equal := true
			for index, token in tokens {
				if entry.tokens[index] != token.token() { equal = false; break }
			}
			if equal {
				if simple_var_property_diagnostics && !simple_var_property_reported {
					simple_var_property_reported = true
					eprintln('Vox var properties: reused parsed single-var leaf tokens')
				}
				return entry.value
			}
		}
	}
	if cache.entries.len >= 512 { return none }
	// Keep the ordinary property grammar and immutable exported value. Only
// substitution bookkeeping and a repeated parse are elided on a later hit.
	value := parse_substituted_property_value(property, tokens, false)
	mut snapshot := []Token{cap:tokens.len}
	for token in tokens { snapshot << token.token() }
	cache.entries[key] = SimpleVarPropertyEntry{property:property,input:identity,tokens:snapshot,value:value}
	return value
}
