module css

import dom
import os

// Each element resolved its var() declarations again: substitute the custom
// properties, fingerprint the substituted tokens, then find or parse the
// value (substituted_value_reuse.v). That was about 9% of the style pass on
// the archived github.com/vlang/v page. A declaration value whose only
// substitution functions are var() and env() resolves to the same value for
// every element with the same custom property environment, and elements
// without custom property declarations share their parent's environment
// object. Within one style batch the result is kept by declaration value,
// environment and property. attr(), if(), inherit() and custom functions
// depend on more than the environment and always resolve.
const disable_environment_substitution_reuse = os.getenv('VOX_DISABLE_ENVIRONMENT_SUBSTITUTION_REUSE') != ''
const environment_substitution_reuse_limit = 16384

struct EnvironmentSubstitutionEntry {
	value       &dom.StyleValue = unsafe { nil }
	environment voidptr
	property    PropertyID
	result      &dom.StyleValue = unsafe { nil }
}

@[heap]
struct EnvironmentSubstitutionCache {
mut:
	entries map[u64]EnvironmentSubstitutionEntry
}

// The document's style computer inside a style batch, without installing the
// document hooks css_style_computer_for() maintains.
fn batch_style_computer_for(element &dom.Element) ?&StyleComputer {
	document := element.document()
	if document == unsafe { nil } || document.style_computer == unsafe { nil }
		|| document.style_computer.css_handle == unsafe { nil } {
		return none
	}
	computer := unsafe { &StyleComputer(document.style_computer.css_handle) }
	if computer.computed_property_page_batch_depth_ == 0 {
		return none
	}
	return computer
}

fn environment_substitution_key(value &dom.StyleValue, environment voidptr, property PropertyID) u64 {
	mut hash := (u64(voidptr(value)) ^ u64(0x9e3779b97f4a7c15)) * u64(0x100000001b3)
	hash = (hash ^ u64(environment)) * u64(0x100000001b3)
	return (hash ^ u64(property)) * u64(0x100000001b3)
}

fn environment_substitution_applies(unresolved UnresolvedStyleValue) bool {
	presence := unresolved.substitution_functions_presence
	return !disable_environment_substitution_reuse && !presence.attr && !presence.custom_function
		&& !presence.if_ && !presence.inherit
}

fn lookup_environment_substitution(abstract_element dom.AbstractElement, property_id PropertyID, value &dom.StyleValue, unresolved UnresolvedStyleValue) ?&dom.StyleValue {
	if !environment_substitution_applies(unresolved) { return none }
	computer := batch_style_computer_for(abstract_element.element()) or { return none }
	cache := computer.environment_substitutions_
	if cache == unsafe { nil } { return none }
	environment := if data := abstract_element.custom_property_data() { voidptr(data) } else { unsafe { nil } }
	entry := cache.entries[environment_substitution_key(value, environment, property_id)] or { return none }
	if voidptr(entry.value) != voidptr(value) || entry.environment != environment
		|| entry.property != property_id {
		return none
	}
	// The ordinary resolution records the element's var() use.
	if unresolved.includes_var_function() {
		mut element := unsafe { &dom.Element(abstract_element.element()) }
		element.set_style_uses_var_css_function()
	}
	return entry.result
}

fn store_environment_substitution(abstract_element dom.AbstractElement, property_id PropertyID, value &dom.StyleValue, unresolved UnresolvedStyleValue, result &dom.StyleValue) {
	if !environment_substitution_applies(unresolved) { return }
	computer := batch_style_computer_for(abstract_element.element()) or { return }
	mut owner := unsafe { &StyleComputer(computer) }
	if owner.environment_substitutions_ == unsafe { nil } {
		owner.environment_substitutions_ = &EnvironmentSubstitutionCache{}
	}
	mut cache := owner.environment_substitutions_
	if cache.entries.len >= environment_substitution_reuse_limit { return }
	environment := if data := abstract_element.custom_property_data() { voidptr(data) } else { unsafe { nil } }
	cache.entries[environment_substitution_key(value, environment, property_id)] = EnvironmentSubstitutionEntry{
		value:       unsafe { value }
		environment: environment
		property:    property_id
		result:      unsafe { result }
	}
}
