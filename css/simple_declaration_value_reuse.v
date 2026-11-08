module css

import dom
import os

const disable_simple_declaration_value_reuse = os.getenv('VOX_DISABLE_SIMPLE_DECLARATION_VALUE_REUSE') != ''
const simple_declaration_value_diagnostics = os.getenv('VOX_SIMPLE_DECLARATION_VALUE_DIAGNOSTICS') != ''
__global simple_declaration_value_reported bool

// These spellings have no URL, escape, namespace, function-definition or
// document parsing dependencies. The ordinary property grammar still validates
// every cache miss. A single fallback-free var() retains its unresolved tokens;
// substitution and element-specific computation still happen in the cascade.
fn simple_declaration_spelling(text string) bool {
	if text.len == 0 || text.len > 128 { return false }
	if text.starts_with('var(') && text.ends_with(')') {
		mut start := 4
		mut end := text.len - 1
		for start < end && text[start] in [` `, `\t`, `\n`, `\r`, `\f`] { start++ }
		for end > start && text[end - 1] in [` `, `\t`, `\n`, `\r`, `\f`] { end-- }
		if end - start <= 2 || text[start] != `-` || text[start + 1] != `-` { return false }
		for byte in text[start + 2..end] {
			if !((byte >= `a` && byte <= `z`) || (byte >= `A` && byte <= `Z`)
				|| (byte >= `0` && byte <= `9`) || byte in [`-`, `_`]) { return false }
		}
		return true
	}
	for byte in text {
		if !((byte >= `a` && byte <= `z`) || (byte >= `A` && byte <= `Z`)
			|| (byte >= `0` && byte <= `9`) || byte in [`-`, `_`, `.`, `%`, `#`, `+`, ` `, `\t`, `\n`, `\r`, `\f`]) { return false }
	}
	return true
}

fn parse_simple_source_declaration(params ParsingParams, source DeferredPropertySource) ?&dom.StyleValue {
	if disable_simple_declaration_value_reuse || !css_parsed_value_cache_enabled
		|| params.document == unsafe { nil } || params.document.in_quirks_mode()
		|| params.mode != .normal || params.is_ua_style_sheet != .no
		|| params.value_context.len != 0 || params.declared_namespaces.len != 0
		|| is_a_custom_property_name_string(source.name) || !simple_declaration_spelling(source.text) { return none }
	property := PropertyNameAndID.from_name(source.name) or { return none }
	id := property.id() or { return none }
	if simple_declaration_value_diagnostics && !simple_declaration_value_reported {
		if _ := css_parsed_value_cache[int(id)][source.text] {
			simple_declaration_value_reported = true
			eprintln('Vox declaration values: reused validated literal/var grammar before tokenization')
		}
	}
	value := parse_css_value_logic(id, source.text) or { return none }
	return dom_style_value_from_value_logic(value)
}
