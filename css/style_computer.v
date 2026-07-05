module css

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
