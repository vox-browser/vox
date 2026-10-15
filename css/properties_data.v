module css

import dom

// Compare two optional strings for equality without using `?string == ?string`, which triggers a V
// codegen bug (the auto-generated `builtin___option_string__eq` is sometimes emitted as a call but never
// defined, breaking the C build). Both none is equal; a value vs none is not.
fn option_string_equal(a ?string, b ?string) bool {
	if a_value := a {
		b_value := b or { return false }
		return a_value == b_value
	}
	if _ := b {
		return false
	}
	return true
}

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
	own_values_                          StylePropertyMap
	parent_                              ?&CustomPropertyData
	ancestor_count_                      u8
	cached_inheritable_document_identity voidptr = unsafe { nil }
	cached_inheritable_generation        u64 = max_u64
	cached_inheritable_data              ?&CustomPropertyData
	cached_inheritable_is_self           bool
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
			own_values_: own_values_copy
			parent_: grandparent
			ancestor_count_: ancestor_count
		}
	}

	ancestor_count := parent_data.ancestor_count_ + 1
	return &CustomPropertyData{
		own_values_: own_values_copy
		parent_: parent_data
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

pub fn (c &CustomPropertyData) for_each_property(callback fn(string, StyleProperty)) {
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

fn optional_custom_property_data_equal(left ?&CustomPropertyData, right ?&CustomPropertyData) bool {
	if left_data := left {
		right_data := right or { return false }
		return voidptr(left_data) == voidptr(right_data)
	}
	return right == none
}

pub fn (c &CustomPropertyData) inheritable(document &dom.Document) ?&CustomPropertyData {
	document_identity := voidptr(document)
	generation := document.custom_property_registration_generation()
	if c.cached_inheritable_document_identity == document_identity
		&& c.cached_inheritable_generation == generation {
		if c.cached_inheritable_is_self {
			return c
		}
		return c.cached_inheritable_data
	}

	mut inheritable_parent := ?&CustomPropertyData(none)
	if parent := c.parent_ {
		inheritable_parent = parent.inheritable(document)
	}
	mut inheritable_own_values := StylePropertyMap{}
	mut filtered_any_own_values := false
	for name, property in c.own_values_ {
		if registration := document.get_registered_custom_property(name) {
			if !registration.inherits {
				filtered_any_own_values = true
				continue
			}
		}
		inheritable_own_values[name] = property
	}

	mut mutable_data := unsafe { &CustomPropertyData(c) }
	mutable_data.cached_inheritable_document_identity = document_identity
	mutable_data.cached_inheritable_generation = generation
	if !filtered_any_own_values && optional_custom_property_data_equal(inheritable_parent, c.parent_) {
		mutable_data.cached_inheritable_data = none
		mutable_data.cached_inheritable_is_self = true
		return c
	}

	mutable_data.cached_inheritable_is_self = false
	if inheritable_own_values.len == 0 && inheritable_parent == none {
		mutable_data.cached_inheritable_data = none
		return none
	}
	result := CustomPropertyData.create(inheritable_own_values, inheritable_parent)
	mutable_data.cached_inheritable_data = result
	return result
}

// --- CascadedProperties ---
pub enum CascadeOrigin {
	user_agent
	user
	author
	author_presentational_hint
	transition
	animation
}

pub struct CascadedPropertiesEntry {
pub mut:
	property           StyleProperty
	origin             CascadeOrigin
	layer_name         ?string
	source             voidptr
	source_shadow_root ?&dom.ShadowRoot
}

@[heap]
pub struct CascadedProperties {
pub mut:
	properties_                 map[PropertyID][]CascadedPropertiesEntry
	contained_properties_cache_ []u8
}

pub fn CascadedProperties.new() &CascadedProperties {
	return &CascadedProperties{
		properties_: map[PropertyID][]CascadedPropertiesEntry{}
		// Upstream's PropertyID places shorthands before its contiguous
		// longhands, so FixedBitmap<last_longhand + 1> also covers unresolved
		// shorthand entries. V groups longhands first for dense computed-value
		// storage and puts shorthands afterwards; size this cache by the complete
		// PropertyID range to preserve the CascadedProperties contract.
		contained_properties_cache_: []u8{len: int(PropertyID.container) + 1}
	}
}

fn cascaded_property_index(property_id PropertyID) int {
	return int(property_id)
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
		// Presentational hints cascade independently, but `revert` at the
		// author origin also rolls them back as part of the author origin.
		origin_matches := cascade_origin == entry.origin
			|| (cascade_origin == .author && entry.origin == .author_presentational_hint)
		if entry.property.property_id == property_id && entry.property.important == important
			&& origin_matches {
			continue
		}
		filtered << entry
	}
	if filtered.len == 0 {
		c.contained_properties_cache_[cascaded_property_index(property_id)] = 0
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
		if entry.property.property_id == property_id && entry.property.important == important && option_string_equal(entry.layer_name, layer_name) {
			continue
		}
		filtered << entry
	}
	if filtered.len == 0 {
		c.contained_properties_cache_[cascaded_property_index(property_id)] = 0
		c.properties_.delete(property_id)
		return
	}
	c.properties_[property_id] = filtered
}

// https://drafts.csswg.org/css-values-5/#property-replacement
fn resolve_unresolved_style_value_for_property(abstract_element dom.AbstractElement, property_id PropertyID, unresolved UnresolvedStyleValue) &dom.StyleValue {
	mut guarded_contexts := GuardedSubstitutionContexts{}
	return resolve_unresolved_style_value_for_property_with_context(abstract_element, property_id, unresolved, mut guarded_contexts)
}

fn resolve_unresolved_style_value_for_property_with_context(abstract_element dom.AbstractElement, property_id PropertyID, unresolved UnresolvedStyleValue, mut guarded_contexts GuardedSubstitutionContexts) &dom.StyleValue {
	// AD-HOC: Report that we might rely on custom properties.
	mut element := unsafe { &dom.Element(abstract_element.element()) }
	if unresolved.includes_attr_function() {
		element.set_style_uses_attr_css_function()
	}
	if unresolved.includes_if_function() {
		element.set_style_uses_if_css_function()
	}
	if unresolved.includes_inherit_function() {
		element.set_style_uses_inherit_css_function()
	}
	if unresolved.includes_var_function() {
		element.set_style_uses_var_css_function()
	}

	// To replace substitution functions in a property prop:

	// 1. Substitute arbitrary substitution functions in prop's value, given << "property", prop's name >> as the
	//    substitution context. Let result be the returned component value sequence.
	result := substitute_arbitrary_substitution_functions_for_element(abstract_element, mut guarded_contexts, unresolved.tokens, SubstitutionContext{
		dependency_type: .property
		first: string_from_property_id(property_id)
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

pub fn (mut c CascadedProperties) set_property(property_id PropertyID, value &dom.StyleValue, important Important, origin CascadeOrigin, layer_name ?string, source voidptr, source_shadow_root ?&dom.ShadowRoot) {
	c.contained_properties_cache_[cascaded_property_index(property_id)] = 1

	mut entries := c.properties_[property_id]
	for index := entries.len - 1; index >= 0; index-- {
		mut entry := entries[index]
		if entry.origin == origin && option_string_equal(entry.layer_name, layer_name) {
			if entry.property.important == .yes && important == .no {
				return
			}
			entry.property = StyleProperty{
				important: important
				property_id: property_id
				value: unsafe { value }
			}
			entry.source = source
			entry.source_shadow_root = source_shadow_root
			entries[index] = entry
			c.properties_[property_id] = entries
			return
		}
	}

	entries << CascadedPropertiesEntry{
		property: StyleProperty{
			important: important
			property_id: property_id
			value: unsafe { value }
		}
		origin: origin
		layer_name: layer_name
		source: source
		source_shadow_root: source_shadow_root
	}
	c.properties_[property_id] = entries
}

fn for_each_typed_property_expanding_shorthands(property_id PropertyID, value StyleValue, set_longhand_property fn(PropertyID, StyleValue)) {
	if property_is_shorthand(property_id) && (value.type_() == .unresolved || value.type_() == .pending_substitution) {
		// If a shorthand property contains an arbitrary substitution function in its value, the longhand properties
		// it's associated with must instead be filled in with a special, unobservable-to-authors pending-substitution
		// value that indicates the shorthand contains an arbitrary substitution function, and thus the longhand's
		// value can't be determined until after substituted.
		// https://drafts.csswg.org/css-values-5/#pending-substitution-value
		// Ensure we keep the longhand around until it can be resolved.
		set_longhand_property(property_id, value)
		pending_substitution_value := StyleValue(PendingSubstitutionStyleValue.create(value))
		for longhand_id in longhands_for_shorthand_local(property_id) {
			for_each_typed_property_expanding_shorthands(longhand_id, pending_substitution_value, set_longhand_property)
		}
		return
	}

	if value is ShorthandStyleValue {
		properties := value.sub_properties()
		values := value.values()
		for i := 0; i < properties.len && i < values.len; i++ {
			for_each_typed_property_expanding_shorthands(properties[i], values[i], set_longhand_property)
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
	return generated_longhands_for_shorthand(property_id)
}

pub fn (c &CascadedProperties) property(property_id PropertyID) ?&dom.StyleValue {
	if c.contained_properties_cache_[cascaded_property_index(property_id)] == 0 {
		return none
	}
	entries := c.properties_[property_id] or { return none }
	if entries.len == 0 {
		return none
	}
	return entries[entries.len - 1].property.value
}

pub fn (c &CascadedProperties) property_source(property_id PropertyID) voidptr {
	if c.contained_properties_cache_[cascaded_property_index(property_id)] == 0 {
		return unsafe { nil }
	}
	entries := c.properties_[property_id] or { return unsafe { nil } }
	if entries.len == 0 {
		return unsafe { nil }
	}
	return entries[entries.len - 1].source
}

pub fn (c &CascadedProperties) property_source_shadow_root(property_id PropertyID) ?&dom.ShadowRoot {
	if c.contained_properties_cache_[cascaded_property_index(property_id)] == 0 {
		return none
	}
	entries := c.properties_[property_id] or { return none }
	if entries.len == 0 {
		return none
	}
	return entries[entries.len - 1].source_shadow_root
}

pub fn (c &CascadedProperties) style_property(property_id PropertyID) ?StyleProperty {
	if c.contained_properties_cache_[cascaded_property_index(property_id)] == 0 {
		return none
	}
	entries := c.properties_[property_id] or { return none }
	if entries.len == 0 {
		return none
	}
	return entries[entries.len - 1].property
}
