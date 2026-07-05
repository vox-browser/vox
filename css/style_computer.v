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
// NOTE: takes `dom.PseudoElement` (the type AbstractElement carries; dom can't import css so the
// pseudo-element enum is duplicated in dom.document.v and css.selectors.v) rather than Ladybird's
// CSS::PseudoElement.
fn pseudo_element_supports_property(pseudo_element dom.PseudoElement, property_id PropertyID) bool {
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

// One expanded longhand from a shorthand expansion: its property id and (opaque) value.
struct ExpandedLonghand {
	id    PropertyID
	value &dom.StyleValue = unsafe { nil }
}

// Expand `value` for `property_id` into its longhands, collected into a list. Wraps
// StyleComputer.for_each_property_expanding_shorthands; the callback appends through a captured
// pointer (V closures capture value-types by value, so mutating a captured list needs a pointer).
fn expand_property_longhands(property_id PropertyID, value &dom.StyleValue) []ExpandedLonghand {
	mut longhands := []ExpandedLonghand{}
	longhands_ptr := &longhands
	StyleComputer.for_each_property_expanding_shorthands(property_id, value, fn [longhands_ptr] (longhand_id PropertyID, longhand_value &dom.StyleValue) {
		unsafe {
			mut list := *longhands_ptr
			list << ExpandedLonghand{
				id:    longhand_id
				value: longhand_value
			}
			*longhands_ptr = list
		}
	})
	return longhands
}

// Whether the opaque cascaded `value` for `property_id` is the CSS-wide `revert`/`revert-layer`
// keyword. The port's dom.StyleValue only carries serialized text, so re-type it to test the typed
// StyleValue predicate.
fn opaque_is_revert(property_id PropertyID, value &dom.StyleValue) bool {
	typed := parse_css_value_logic(property_id, value.css_text) or { return false }
	return typed.is_revert()
}

fn opaque_is_revert_layer(property_id PropertyID, value &dom.StyleValue) bool {
	typed := parse_css_value_logic(property_id, value.css_text) or { return false }
	return typed.is_revert_layer()
}

// Cascade one declaration block into `cascaded_properties` — the inner `cascade_style_declaration`
// lambda of Ladybird's StyleComputer::cascade_declarations. For each property (of the requested
// importance / supported by the pseudo-element / in `properties_to_cascade` when non-empty), expand
// shorthands and, per longhand, map a logical alias to its physical property and either revert it or
// set it in the cascade.
// FIXME: the inline `is_unresolved`/`is_guaranteed_invalid` resolution (StyleComputer.cpp:505-525) and
// the pending-substitution "seen" optimization are omitted — the port defers var()/env() resolution to
// CascadedProperties.resolve_unresolved_properties, so those cases don't arise at cascade time here.
fn cascade_one_declaration(mut cascaded_properties CascadedProperties, abstract_element dom.AbstractElement, declaration &CSSStyleProperties, cascade_origin CascadeOrigin, important Important, layer_name ?string, logical_alias_mapping_context ?LogicalAliasMappingContext, properties_to_cascade []PropertyID) {
	pseudo_element := abstract_element.pseudo_element()
	for property in declaration_style_properties(declaration) {
		// OPTIMIZATION: only cascade the requested properties, when a set was given.
		if properties_to_cascade.len > 0 && property.property_id !in properties_to_cascade {
			continue
		}
		if important != property.important {
			continue
		}
		if pe := pseudo_element {
			if !pseudo_element_supports_property(pe, property.property_id) {
				continue
			}
		}
		for longhand in expand_property_longhands(property.property_id, property.value) {
			mut physical_property_id := longhand.id
			if property_is_logical_alias(longhand.id) {
				context := logical_alias_mapping_context or { continue }
				physical_property_id = map_logical_alias_to_physical_property(longhand.id, context)
			}

			if opaque_is_revert(longhand.id, longhand.value) {
				cascaded_properties.revert_property(physical_property_id, important, cascade_origin)
			} else if opaque_is_revert_layer(longhand.id, longhand.value) {
				cascaded_properties.revert_layer_property(physical_property_id, important, layer_name)
			} else {
				cascaded_properties.set_property(physical_property_id, longhand.value, important,
					cascade_origin, layer_name, voidptr(declaration))
			}
		}
	}
}

// NOTE: the outer `cascade_declarations` (StyleComputer.cpp:476, the matching-rules + inline-style
// driver) is the method `(s &StyleComputer) cascade_declarations` in computed_interpolation.v — it
// delegates each declaration to cascade_one_declaration above.

// Map a CSS `writing-mode` keyword to the WritingMode enum (Ladybird's generated keyword_to_writing_mode).
fn keyword_to_writing_mode(keyword Keyword) ?WritingMode {
	return match keyword {
		.horizontal_tb { WritingMode.horizontal_tb }
		.vertical_rl { WritingMode.vertical_rl }
		.vertical_lr { WritingMode.vertical_lr }
		.sideways_rl { WritingMode.sideways_rl }
		.sideways_lr { WritingMode.sideways_lr }
		else { none }
	}
}

// Map a CSS `direction` keyword to the Direction enum (Ladybird's generated keyword_to_direction).
fn keyword_to_direction(keyword Keyword) ?Direction {
	return match keyword {
		.ltr { Direction.ltr }
		.rtl { Direction.rtl }
		else { none }
	}
}

// The `normalize_value` lambda of StyleComputer::compute_logical_alias_mapping_context (StyleComputer.cpp:1409):
// resolve a cascaded writing-mode/direction value to a concrete keyword, turning absent/inherit/unset/initial
// into a usable value.
// FIXME (boundary): upstream resolves inherit/unset to the inheritance parent's computed value; the parent's
// full ComputedProperties isn't retrievable across the port's DOM surface (only a placeholder), so we fall
// back to the property's initial value.
fn logical_alias_normalize_value(abstract_element dom.AbstractElement, property_id PropertyID, value ?&dom.StyleValue) &dom.StyleValue {
	_ = abstract_element
	initial := computed_interpolation_property_initial_value(property_id)
	if current := value {
		if computed_interpolation_style_value_is_inherit(current)
			|| computed_interpolation_style_value_is_unset(current) {
			return initial
		}
		if computed_interpolation_style_value_is_initial(current) {
			return initial
		}
		return current
	}
	return initial
}

// The compute-and-store core of DOM::Element::recompute_style (Element.cpp:855): compute the element's
// style and store it (bridged) on the element, so descendants inherit through it and layout can read the
// mirrored fields off the placeholder. The DOM-side Element.recompute_style is a stub because dom cannot
// import css; this is its CSS half, meant to be driven top-down over the tree (parents before children).
// FIXME: the style-flag resets, invalidation diffing (compute_required_invalidation), the
// HTMLTableElement text-align fixup, display-change animation replay, and pseudo-element
// (::before/::after/::selection/::backdrop) styles are omitted.
pub fn (s &StyleComputer) recompute_style(mut abstract_element dom.AbstractElement) &ComputedProperties {
	computed := s.compute_style(abstract_element)
	abstract_element.set_computed_properties(computed_properties_to_dom(computed))
	return computed
}

// Recompute style for `node` and its whole subtree, top-down — the recursive core of
// DOM::update_style_recursively (Document.cpp:1646). For each element: push it onto the ancestor filter,
// recompute+store its style, recurse into its children (so each child inherits from its just-stored
// parent), then pop it off the filter.
// FIXME: the needs-style-update / child-needs-update / custom-property / display-change invalidation
// gating (which lets upstream SKIP unchanged subtrees) is omitted — this always recomputes the whole
// subtree. Shadow roots and the invalidation return value are also not handled.
pub fn recompute_style_for_subtree(mut style_computer StyleComputer, node &dom.Node) {
	element_opt := node.as_element()
	if element := element_opt {
		style_computer.push_ancestor(element)
		mut abstract_element := dom.AbstractElement.new(element, none)
		style_computer.recompute_style(mut abstract_element)
	}

	mut child := node.first_child()
	for {
		current := child or { break }
		recompute_style_for_subtree(mut style_computer, current)
		child = current.next_sibling()
	}

	if element := element_opt {
		style_computer.pop_ancestor(element)
	}
}
