module css

import dom

// --- CustomPropertyData ---

const custom_property_data_max_ancestor_count = 32
const custom_property_data_absorb_threshold = 8

pub type StylePropertyMap = map[string]StyleProperty

// Chain of custom property maps with structural sharing.
// Each node stores only the properties declared directly on its element,
// with a parent pointer to the inherited chain.
@[heap]
pub struct CustomPropertyData {
pub mut:
	own_values_     StylePropertyMap
	parent_         ?&CustomPropertyData
	ancestor_count_ u8
}

pub fn CustomPropertyData.create(own_values StylePropertyMap, parent ?&CustomPropertyData) &CustomPropertyData {
	mut own_values_copy := own_values.clone()
	if parent == none {
		return &CustomPropertyData{
			own_values_: own_values_copy
		}
	}

	parent_data := parent

	// If parent chain is too deep, flatten by copying all ancestor values into own.
	if parent_data.ancestor_count_ >= custom_property_data_max_ancestor_count - 1 {
		parent_data.for_each_property(fn [mut own_values_copy] (name string, property StyleProperty) {
			if name !in own_values_copy {
				own_values_copy[name] = property
			}
		})
		return &CustomPropertyData{
			own_values_: own_values_copy
		}
	}

	// If parent has few own values, absorb them to shorten the chain.
	if parent_data.own_values_.len <= custom_property_data_absorb_threshold {
		for name, property in parent_data.own_values_ {
			if name !in own_values_copy {
				own_values_copy[name] = property
			}
		}
		grandparent := parent_data.parent_
		ancestor_count := if gp := grandparent { gp.ancestor_count_ + 1 } else { u8(0) }
		return &CustomPropertyData{
			own_values_:     own_values_copy
			parent_:         grandparent
			ancestor_count_: ancestor_count
		}
	}

	ancestor_count := parent_data.ancestor_count_ + 1
	return &CustomPropertyData{
		own_values_:     own_values_copy
		parent_:         parent_data
		ancestor_count_: ancestor_count
	}
}

pub fn (c &CustomPropertyData) get(name string) ?StyleProperty {
	if name in c.own_values_ {
		return c.own_values_[name] or { return none }
	}
	if parent := c.parent_ {
		return parent.get(name)
	}
	return none
}

pub fn (c &CustomPropertyData) own_values() StylePropertyMap {
	return c.own_values_
}

pub fn (c &CustomPropertyData) for_each_property(callback fn (string, StyleProperty)) {
	mut seen := map[string]bool{}
	mut current := ?&CustomPropertyData(c)
	for {
		node := current or { break }
		for name, property in node.own_values_ {
			if name in seen {
				continue
			}
			seen[name] = true
			callback(name, property)
		}
		current = node.parent_
	}
}

pub fn (c &CustomPropertyData) parent() ?&CustomPropertyData {
	return c.parent_
}

pub fn (c &CustomPropertyData) is_empty() bool {
	if c.own_values_.len != 0 {
		return false
	}
	if parent := c.parent_ {
		return parent.is_empty()
	}
	return true
}

// --- CascadedProperties ---

pub enum CascadeOrigin {
	user_agent
	user
	author
	transition
	animation
}

pub struct CascadedPropertiesEntry {
pub mut:
	property   StyleProperty
	origin     CascadeOrigin
	layer_name ?string
	source     voidptr
}

@[heap]
pub struct CascadedProperties {
pub mut:
	properties_                 map[PropertyID][]CascadedPropertiesEntry
	contained_properties_cache_ map[PropertyID]bool
}

pub fn CascadedProperties.new() &CascadedProperties {
	return &CascadedProperties{}
}

pub fn (mut c CascadedProperties) visit_edges() {
	// Base::visit_edges(visitor);
	// for each entry: visitor.visit(entry.source);
}

pub fn (mut c CascadedProperties) revert_property(property_id PropertyID, important Important, cascade_origin CascadeOrigin) {
	if property_id !in c.properties_ {
		return
	}
	mut entries := c.properties_[property_id] or { return }
	mut filtered := []CascadedPropertiesEntry{}
	for entry in entries {
		if entry.property.property_id == property_id && entry.property.important == important
			&& cascade_origin == entry.origin {
			continue
		}
		filtered << entry
	}
	if filtered.len == 0 {
		c.contained_properties_cache_[property_id] = false
		c.properties_.delete(property_id)
		return
	}
	c.properties_[property_id] = filtered
}

pub fn (mut c CascadedProperties) revert_layer_property(property_id PropertyID, important Important, layer_name ?string) {
	if property_id !in c.properties_ {
		return
	}
	mut entries := c.properties_[property_id] or { return }
	mut filtered := []CascadedPropertiesEntry{}
	for entry in entries {
		if entry.property.property_id == property_id && entry.property.important == important
			&& entry.layer_name == layer_name {
			continue
		}
		filtered << entry
	}
	if filtered.len == 0 {
		c.contained_properties_cache_[property_id] = false
		c.properties_.delete(property_id)
		return
	}
	c.properties_[property_id] = filtered
}

pub fn (mut c CascadedProperties) resolve_unresolved_properties(abstract_element &dom.AbstractElement) {
	_ = abstract_element
	// DOM::StyleValue is currently an opaque DOM-side placeholder in this V port, so entries cannot be inspected for
	// UnresolvedStyleValue here. The translated resolver below is used by CSS-side callers that still have typed values.
	// FIXME: Replace this boundary once dom.StyleValue carries or exposes the CSS StyleValue variant.
}

// https://drafts.csswg.org/css-values-5/#property-replacement
fn resolve_unresolved_style_value_for_property(abstract_element dom.AbstractElement, property_id PropertyID, unresolved UnresolvedStyleValue) &dom.StyleValue {
	mut guarded_contexts := GuardedSubstitutionContexts{}
	return resolve_unresolved_style_value_for_property_with_context(abstract_element, property_id,
		unresolved, mut guarded_contexts)
}

fn resolve_unresolved_style_value_for_property_with_context(abstract_element dom.AbstractElement, property_id PropertyID, unresolved UnresolvedStyleValue, mut guarded_contexts GuardedSubstitutionContexts) &dom.StyleValue {
	// AD-HOC: Report that we might rely on custom properties.
	// FIXME: DOM::Element exposes these flags internally, but the setter methods are not translated for attr()/var()/if()/inherit().

	// To replace substitution functions in a property prop:

	// 1. Substitute arbitrary substitution functions in prop's value, given << "property", prop's name >> as the
	//    substitution context. Let result be the returned component value sequence.
	result := substitute_arbitrary_substitution_functions_for_element(abstract_element, mut
		guarded_contexts, unresolved.tokens, SubstitutionContext{
		dependency_type: .property
		first:           string_from_property_id(property_id)
	})

	// 2. If result contains the guaranteed-invalid value, prop is invalid at computed-value time; return.
	if contains_guaranteed_invalid_value(result) {
		return dom_style_value_from_value_logic(StyleValue(GuaranteedInvalidStyleValue.create()))
	}

	// 3. Parse result according to prop's grammar. If this returns failure, prop is invalid at computed-value time; return.
	// NB: Custom properties have no grammar as such, so we skip this step for them.
	// FIXME: Parse according to @property syntax once we support that.
	mut parser := Parser.from_component_values(result)
	parsed_value := parser.parse_css_value(property_id) or {
		return dom_style_value_from_value_logic(StyleValue(GuaranteedInvalidStyleValue.create()))
	}

	// 4. Otherwise, replace prop's value with the parsed result.
	return dom_style_value_from_value_logic(parsed_value)
}

pub fn (mut c CascadedProperties) set_property(property_id PropertyID, value &dom.StyleValue, important Important, origin CascadeOrigin, layer_name ?string, source voidptr) {
	c.contained_properties_cache_[property_id] = true

	mut entries := c.properties_[property_id] or { []CascadedPropertiesEntry{} }
	for index := entries.len - 1; index >= 0; index-- {
		mut entry := entries[index]
		if entry.origin == origin && entry.layer_name == layer_name {
			if entry.property.important == .yes && important == .no {
				return
			}
			entry.property = StyleProperty{
				important:   important
				property_id: property_id
				value:       unsafe { value }
			}
			entries[index] = entry
			c.properties_[property_id] = entries
			return
		}
	}

	entries << CascadedPropertiesEntry{
		property:   StyleProperty{
			important:   important
			property_id: property_id
			value:       unsafe { value }
		}
		origin:     origin
		layer_name: layer_name
		source:     source
	}
	c.properties_[property_id] = entries
}

pub fn (mut c CascadedProperties) set_property_from_presentational_hint(property_id PropertyID, value &dom.StyleValue) {
	cascaded_properties_for_each_property_expanding_shorthands(property_id, value, fn [mut c] (longhand_property_id PropertyID, longhand_value &dom.StyleValue) {
		c.contained_properties_cache_[longhand_property_id] = true
		mut entries := c.properties_[longhand_property_id] or { []CascadedPropertiesEntry{} }
		entries << CascadedPropertiesEntry{
			property:   StyleProperty{
				important:   .no
				property_id: longhand_property_id
				value:       unsafe { longhand_value }
			}
			origin:     .author
			layer_name: none
			source:     unsafe { nil }
		}
		c.properties_[longhand_property_id] = entries
	})
}

fn cascaded_properties_for_each_property_expanding_shorthands(property_id PropertyID, value &dom.StyleValue, set_longhand_property fn (PropertyID, &dom.StyleValue)) {
	// The typed StyleValue overload below translates StyleComputer::for_each_property_expanding_shorthands. Cascaded
	// properties currently store opaque DOM values, so only the direct longhand path is observable until DOM values expose
	// ShorthandStyleValue/UnresolvedStyleValue/PendingSubstitutionStyleValue.
	set_longhand_property(property_id, value)
}

fn for_each_typed_property_expanding_shorthands(property_id PropertyID, value StyleValue, set_longhand_property fn (PropertyID, StyleValue)) {
	if property_is_shorthand(property_id)
		&& (value.type_() == .unresolved || value.type_() == .pending_substitution) {
		// If a shorthand property contains an arbitrary substitution function in its value, the longhand properties
		// it's associated with must instead be filled in with a special, unobservable-to-authors pending-substitution
		// value that indicates the shorthand contains an arbitrary substitution function, and thus the longhand's
		// value can't be determined until after substituted.
		// https://drafts.csswg.org/css-values-5/#pending-substitution-value
		// Ensure we keep the longhand around until it can be resolved.
		set_longhand_property(property_id, value)
		pending_substitution_value := StyleValue(PendingSubstitutionStyleValue.create(value))
		for longhand_id in longhands_for_shorthand_local(property_id) {
			for_each_typed_property_expanding_shorthands(longhand_id, pending_substitution_value,
				set_longhand_property)
		}
		return
	}

	if value is ShorthandStyleValue {
		properties := value.sub_properties()
		values := value.values()
		for i := 0; i < properties.len && i < values.len; i++ {
			for_each_typed_property_expanding_shorthands(properties[i], values[i],
				set_longhand_property)
		}
		return
	}

	if property_is_shorthand(property_id) {
		// ShorthandStyleValue was handled already, as were unresolved shorthands.
		// That means the only values we should see are the CSS-wide keywords, or the guaranteed-invalid value.
		// Both should be applied to our longhand properties.
		// We don't directly call `set_longhand_property()` because the longhands might have longhands of their own.
		// (eg `grid` -> `grid-template` -> `grid-template-areas` & `grid-template-rows` & `grid-template-columns`)
		if !value.is_css_wide_keyword() && value.type_() != .guaranteed_invalid {
			return
		}
		for longhand in longhands_for_shorthand_local(property_id) {
			for_each_typed_property_expanding_shorthands(longhand, value, set_longhand_property)
		}
		return
	}

	set_longhand_property(property_id, value)
}

fn longhands_for_shorthand_local(property_id PropertyID) []PropertyID {
	_ = property_id
	// The current translated PropertyID set contains only longhands.
	return []PropertyID{}
}

pub fn (c &CascadedProperties) property(property_id PropertyID) ?&dom.StyleValue {
	if property_id !in c.contained_properties_cache_ || !c.contained_properties_cache_[property_id] {
		return none
	}
	entries := c.properties_[property_id] or { return none }
	if entries.len == 0 {
		return none
	}
	return entries[entries.len - 1].property.value
}

pub fn (c &CascadedProperties) property_source(property_id PropertyID) voidptr {
	if property_id !in c.contained_properties_cache_ || !c.contained_properties_cache_[property_id] {
		return unsafe { nil }
	}
	entries := c.properties_[property_id] or { return unsafe { nil } }
	if entries.len == 0 {
		return unsafe { nil }
	}
	return entries[entries.len - 1].source
}

pub fn (c &CascadedProperties) style_property(property_id PropertyID) ?StyleProperty {
	if property_id !in c.contained_properties_cache_ || !c.contained_properties_cache_[property_id] {
		return none
	}
	entries := c.properties_[property_id] or { return none }
	if entries.len == 0 {
		return none
	}
	return entries[entries.len - 1].property
}
