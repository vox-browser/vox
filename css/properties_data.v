module css

import dom
import platform

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

	// The result is cached on this data for every later lookup.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
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

// Each property keeps a newest-first chain through scanned entry chunks. This
// follows the upstream Rust CascadedPropertyStore arena without allocating a
// separate growable array for every property matched on an element.
const cascaded_property_entry_chunk_size = 4

struct CascadedPropertiesEntryNode {
mut:
	entry    CascadedPropertiesEntry
	previous int = -1
}

@[heap]
struct CascadedPropertiesEntryChunk {
mut:
	nodes [cascaded_property_entry_chunk_size]CascadedPropertiesEntryNode
}

@[heap]
pub struct CascadedProperties {
pub mut:
	contained_properties_cache_ []u8
mut:
	entry_heads_           map[PropertyID]int
	entry_chunks_          []&CascadedPropertiesEntryChunk
	allocated_entry_count_ int
	free_entry_index_      int = -1
	scratch_arena_ &platform.Arena = unsafe { nil }
}

pub fn CascadedProperties.new() &CascadedProperties {
	return &CascadedProperties{
		entry_heads_: map[PropertyID]int{}
		// V puts shorthands after the contiguous longhands. Keep presence bits
		// for the complete PropertyID range, including unresolved shorthands.
		contained_properties_cache_: []u8{len: int(PropertyID.container) + 1}
	}
}

fn (c &CascadedProperties) entry_node(index int) &CascadedPropertiesEntryNode {
	return unsafe { &c.entry_chunks_[index / cascaded_property_entry_chunk_size].nodes[index % cascaded_property_entry_chunk_size] }
}

fn (mut c CascadedProperties) allocate_entry(entry CascadedPropertiesEntry, previous int) int {
	mut index := c.free_entry_index_
	if index >= 0 {
		c.free_entry_index_ = c.entry_node(index).previous
	} else {
		index = c.allocated_entry_count_
		c.allocated_entry_count_++
		if index / cascaded_property_entry_chunk_size >= c.entry_chunks_.len {
			// Allocate scanned storage without eagerly constructing unused slots.
			// Every slot is initialized before its index enters a property chain.
			c.entry_chunks_ << unsafe { &CascadedPropertiesEntryChunk(vcalloc(int(sizeof(CascadedPropertiesEntryChunk)))) }
		}
	}
	mut node := c.entry_node(index)
	node.entry = entry
	node.previous = previous
	return index
}

fn (c &CascadedProperties) winning_entry_index(property_id PropertyID) int {
	if c.contained_properties_cache_[cascaded_property_index(property_id)] == 0 {
		return -1
	}
	return c.entry_heads_[property_id] or { -1 }
}

fn cascaded_property_index(property_id PropertyID) int {
	return int(property_id)
}

pub fn (mut c CascadedProperties) visit_edges() {
	// Base::visit_edges(visitor);
	// for each entry: visitor.visit(entry.source);
}

pub fn (mut c CascadedProperties) revert_property(property_id PropertyID, important Important, cascade_origin CascadeOrigin) {
	c.revert_entries(property_id, important, cascade_origin, none, false)
}

pub fn (mut c CascadedProperties) revert_layer_property(property_id PropertyID, important Important, layer_name ?string) {
	c.revert_entries(property_id, important, .author, layer_name, true)
}

fn (mut c CascadedProperties) revert_entries(property_id PropertyID, important Important, origin CascadeOrigin, layer_name ?string, layer_only bool) {
	mut index := c.entry_heads_[property_id] or { return }
	mut first_kept := -1
	mut last_kept := -1
	for index >= 0 {
		mut node := c.entry_node(index)
		previous := node.previous
		entry := node.entry
		// Author revert also rolls back presentational hints, as before.
		origin_matches := origin == entry.origin
			|| (origin == .author && entry.origin == .author_presentational_hint)
		remove := entry.property.property_id == property_id
			&& entry.property.important == important
			&& if layer_only { option_string_equal(entry.layer_name, layer_name) } else { origin_matches }
		if remove {
			// Clear retained values, sources and layer names before recycling the
			// slot. Repeated revert/re-add cycles reuse the same bounded storage.
			node.entry = CascadedPropertiesEntry{}
			node.previous = c.free_entry_index_
			c.free_entry_index_ = index
		} else {
			if first_kept < 0 { first_kept = index }
			if last_kept >= 0 {
				mut last := c.entry_node(last_kept)
				last.previous = index
			}
			last_kept = index
		}
		index = previous
	}
	if last_kept < 0 {
		if c.scratch_arena_ != unsafe { nil } { c.entry_heads_[property_id] = -1 }
		else { c.entry_heads_.delete(property_id) }
		c.contained_properties_cache_[cascaded_property_index(property_id)] = 0
	} else {
		mut last := c.entry_node(last_kept)
		last.previous = -1
		c.entry_heads_[property_id] = first_kept
	}
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

	$if prealloc {
		// A top-level property resolution publishes only its typed value. The
		// argument grammar, intermediate tokens and function-local scopes all
		// expire together. Keep an enclosing function's mutable scopes on the
		// existing path instead of putting temporary tokens in its caches.
		if guarded_contexts.contexts.len == 0 && guarded_contexts.function_local_scopes.len == 0 {
			return resolve_property_in_substitution_workspace(abstract_element, property_id,
				unresolved, mut guarded_contexts)
		}
	}

	// To replace substitution functions in a property prop:

	// 1. Substitute arbitrary substitution functions in prop's value, given << "property", prop's name >> as the
	//    substitution context. Let result be the returned component value sequence.
	result := substitute_arbitrary_substitution_functions_for_element(abstract_element, mut guarded_contexts, unresolved.tokens, SubstitutionContext{
		dependency_type: .property
		first: string_from_property_id(property_id)
	})

	return parse_substituted_property_value(property_id, result, false)
}

fn parse_substituted_property_value(property_id PropertyID, result []ComponentValue, transient bool) &dom.StyleValue {
	// 2. If result contains the guaranteed-invalid value, prop is invalid at computed-value time; return.
	if contains_guaranteed_invalid_value(result) {
		return dom_style_value_from_value_logic(StyleValue(GuaranteedInvalidStyleValue.create()))
	}

	// 3. Parse result according to prop's grammar. If this returns failure, prop is invalid at computed-value time; return.
	// NB: Custom properties have no grammar as such, so we skip this step for them.
	// FIXME: Parse according to @property syntax once we support that.
	// Substitution has already materialized this immutable input. The parser
	// only advances a separate cursor, so it need not copy the component slots.
	mut parsed_value := parse_property_components_with_export(ParsingParams{}, property_id,
		result, false) or {
		return dom_style_value_from_value_logic(StyleValue(GuaranteedInvalidStyleValue.create()))
	}
	if transient {
		if mut parsed_value is UnresolvedStyleValue {
			parsed_value.tokens = own_stylesheet_components(parsed_value.tokens)
			if original := parsed_value.original_source_text {
				parsed_value.original_source_text = original.clone()
			}
		}
	}

	// 4. Otherwise, replace prop's value with the parsed result.
	return dom_style_value_from_value_logic(parsed_value)
}

pub fn (mut c CascadedProperties) set_property(property_id PropertyID, value &dom.StyleValue, important Important, origin CascadeOrigin, layer_name ?string, source voidptr, source_shadow_root ?&dom.ShadowRoot) {
	entry := if c.scratch_arena_ != unsafe { nil } { c.scratch_arena_.enter() } else { platform.ArenaEntry{} }
	defer { if c.scratch_arena_ != unsafe { nil } { c.scratch_arena_.leave(entry) } }
	c.contained_properties_cache_[cascaded_property_index(property_id)] = 1
	head := c.entry_heads_[property_id] or { -1 }
	mut index := head
	for index >= 0 {
		mut node := c.entry_node(index)
		if node.entry.origin == origin && option_string_equal(node.entry.layer_name, layer_name) {
			if node.entry.property.important == .yes && important == .no {
				return
			}
			node.entry.property = StyleProperty{
				important: important
				property_id: property_id
				value: unsafe { value }
			}
			node.entry.source = source
			node.entry.source_shadow_root = source_shadow_root
			return
		}
		index = node.previous
	}
	index = c.allocate_entry(CascadedPropertiesEntry{
		property: StyleProperty{
			important: important
			property_id: property_id
			value: unsafe { value }
		}
		origin: origin
		layer_name: layer_name
		source: source
		source_shadow_root: source_shadow_root
	}, head)
	c.entry_heads_[property_id] = index
}

struct TypedLonghandExpansionCallback {
	@[required]
	callback fn (PropertyID, StyleValue)
}

fn invoke_legacy_typed_longhand(context voidptr, property_id PropertyID, value StyleValue) {
	state := unsafe { &TypedLonghandExpansionCallback(context) }
	state.callback(property_id, value)
}

$if test {
	fn for_each_typed_property_expanding_shorthands(property_id PropertyID, value StyleValue, set_longhand_property fn (PropertyID, StyleValue)) {
		state := TypedLonghandExpansionCallback{callback: set_longhand_property}
		for_each_typed_property_expanding_shorthands_with_context(property_id, value, voidptr(&state), invoke_legacy_typed_longhand)
	}
}

fn for_each_typed_property_expanding_shorthands_with_context(property_id PropertyID, value StyleValue, context voidptr, set_longhand_property fn (voidptr, PropertyID, StyleValue)) {
	if property_is_shorthand(property_id) && (value.type_() == .unresolved || value.type_() == .pending_substitution) {
		// If a shorthand property contains an arbitrary substitution function in its value, the longhand properties
		// it's associated with must instead be filled in with a special, unobservable-to-authors pending-substitution
		// value that indicates the shorthand contains an arbitrary substitution function, and thus the longhand's
		// value can't be determined until after substituted.
		// https://drafts.csswg.org/css-values-5/#pending-substitution-value
		// Ensure we keep the longhand around until it can be resolved.
		set_longhand_property(context, property_id, value)
		pending_substitution_value := StyleValue(PendingSubstitutionStyleValue.create(value))
		for longhand_id in longhands_for_shorthand_local(property_id) {
			for_each_typed_property_expanding_shorthands_with_context(longhand_id, pending_substitution_value, context, set_longhand_property)
		}
		return
	}

	if value is ShorthandStyleValue {
		properties := value.sub_properties()
		values := value.values()
		for i := 0; i < properties.len && i < values.len; i++ {
			for_each_typed_property_expanding_shorthands_with_context(properties[i], values[i], context, set_longhand_property)
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
			for_each_typed_property_expanding_shorthands_with_context(longhand, value, context, set_longhand_property)
		}
		return
	}

	set_longhand_property(context, property_id, value)
}

fn longhands_for_shorthand_local(property_id PropertyID) []PropertyID {
	return generated_longhands_for_shorthand(property_id)
}

pub fn (c &CascadedProperties) property(property_id PropertyID) ?&dom.StyleValue {
	index := c.winning_entry_index(property_id)
	if index < 0 { return none }
	return c.entry_node(index).entry.property.value
}

pub fn (c &CascadedProperties) property_source(property_id PropertyID) voidptr {
	index := c.winning_entry_index(property_id)
	if index < 0 { return unsafe { nil } }
	return c.entry_node(index).entry.source
}

pub fn (c &CascadedProperties) property_source_shadow_root(property_id PropertyID) ?&dom.ShadowRoot {
	index := c.winning_entry_index(property_id)
	if index < 0 { return none }
	return c.entry_node(index).entry.source_shadow_root
}

pub fn (c &CascadedProperties) style_property(property_id PropertyID) ?StyleProperty {
	index := c.winning_entry_index(property_id)
	if index < 0 { return none }
	return c.entry_node(index).entry.property
}
