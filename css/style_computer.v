module css

import dom

// Faithful translation of Ladybird's CSS/StyleComputer.cpp, built up bottom-up (see the
// libweb-v-stylecomputer-translation plan). This replaces the from-scratch minimal cascade
// (cascade_minimal.v) as each real piece lands; until then the minimal cascade stays in use.
//
// This file starts with STUBS for the small helpers the cascade needs that aren't translated yet
// (per the translate-only rule: stub the untranslated rather than reimplement from scratch).

// STUB. Whether a longhand property is a logical alias (e.g. `margin-inline-start`) that must be
// mapped to a physical property (`margin-left`/`margin-right`) using the writing mode + direction.
// In Ladybird this is generated from Properties.json's `logical-property-group`.
// FIXME: translate the generated `property_is_logical_alias` (currently always false, so logical
// aliases fall through to their own id in the cascade).
fn property_is_logical_alias(property_id PropertyID) bool {
	_ = property_id
	return false
}

// STUB. Map a logical-alias property (`margin-inline-start`, `inset-block-end`, ...) to its physical
// property given the flow-relative `context` (writing mode + direction). In Ladybird this is a
// generated switch over the logical-property groups.
// FIXME: translate the generated `map_logical_alias_to_physical_property` (currently identity).
fn map_logical_alias_to_physical_property(property_id PropertyID, context LogicalAliasMappingContext) PropertyID {
	_ = context
	return property_id
}

// STUB. Whether `property_id` applies to the given pseudo-element (e.g. `::before`/`::after` support
// most properties; `::marker` supports a restricted set). In Ladybird this is a generated lookup.
// FIXME: translate the generated `pseudo_element_supports_property` (currently permissive).
fn pseudo_element_supports_property(pseudo_element PseudoElement, property_id PropertyID) bool {
	_ = pseudo_element
	_ = property_id
	return true
}

// The typed declaration properties of `declaration`, mirroring Ladybird's
// CSSStyleProperties::properties() (Vector<StyleProperty>). The port stores each declaration entry as
// a serialized CSSStyleProperty{name, value, important, style_value?}; this re-types it into the
// StyleProperty{property_id, value: &dom.StyleValue, important} the cascade iterates over — using the
// already-parsed opaque `style_value` when present, else parsing the serialized text. Custom
// properties (`--*`, kept separately in `custom_properties`) are not included; entries whose name
// isn't a known property, or whose value fails to parse, are skipped.
fn declaration_style_properties(declaration &CSSStyleProperties) []StyleProperty {
	mut result := []StyleProperty{}
	for property in declaration.properties {
		property_id := property_id_from_string(property.name) or { continue }
		mut value := &dom.StyleValue(unsafe { nil })
		if style_value := property.style_value {
			value = style_value
		} else {
			typed := parse_css_value_logic(property_id, property.value) or { continue }
			value = dom_style_value_from_value_logic(typed)
		}
		result << StyleProperty{
			property_id: property_id
			value:       value
			important:   if property.important { Important.yes } else { Important.no }
		}
	}
	return result
}
