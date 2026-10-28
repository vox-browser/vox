module css

import dom

// Reuse only the longhand computation loop, before custom properties,
// animations, box transformations and element-specific adjustments. Every hit
// keeps a fresh style object, mutation token, subject and mutable property
// store. Published pages remain immutable through the existing COW protocol.
// The outer synchronous style batch bounds both the environment and lifetime.
struct ComputedLonghandReuseValue {
	value StyleValue
	text string
	value_type string
	simple bool
	children []ComputedLonghandReuseValue
	separator StyleValueListSeparator
	collapsible StyleValueListCollapsible
	list bool
}

struct ComputedLonghandReuseInput {
	id PropertyID
	value &dom.StyleValue
	typed_handle voidptr
	snapshot ComputedLonghandReuseValue
	important Important
}

struct ComputedLonghandReuseKey {
	parent &ComputedProperties
	parent_pages [computed_property_page_count]&ComputedPropertyPage
	parent_typed_handles [number_of_longhand_properties]voidptr
	initial_pages [computed_property_page_count]&ComputedPropertyPage
	parent_font_viewport bool
	viewport CSSPixelRect
	root_font_size f64
	root_line_height f64
	root_font_viewport bool
	count int
	hash u64
}

@[heap]
struct ComputedLonghandReuseEntry {
	key ComputedLonghandReuseKey
	parent_inputs []ComputedLonghandReuseInput
	inputs []ComputedLonghandReuseInput
	computed &ComputedProperties
}

@[heap]
struct ComputedLonghandReuseCache {
mut:
	entries map[u64]&ComputedLonghandReuseEntry
}

// Copy scalar payloads rather than retaining their mutable sum-type boxes.
// Composite parent values keep a conservative serialization guard as well as
// their wrapper and typed handle identities. The reuse batch runs synchronously.
fn computed_longhand_reuse_snapshot(value &dom.StyleValue) ComputedLonghandReuseValue {
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	return computed_longhand_reuse_typed_snapshot(typed.value)
}

fn computed_longhand_reuse_typed_snapshot(value StyleValue) ComputedLonghandReuseValue {
	copy := match value {
		KeywordStyleValue { StyleValue(KeywordStyleValue.create(value.keyword_)) }
		LengthStyleValue { StyleValue(LengthStyleValue.create(value.length_)) }
		ColorStyleValue { StyleValue(ColorStyleValue.create(value.color_)) }
		NumberStyleValue { StyleValue(NumberStyleValue.create(value.value_)) }
		IntegerStyleValue { StyleValue(IntegerStyleValue.create(value.value_)) }
		PercentageStyleValue { StyleValue(PercentageStyleValue.create(value.percentage_)) }
		DisplayStyleValue { StyleValue(DisplayStyleValue.create(value.display_)) }
		StringStyleValue { StyleValue(StringStyleValue.create(value.string_value_)) }
		CustomIdentStyleValue { StyleValue(CustomIdentStyleValue.create(value.custom_ident_)) }
		StyleValueList {
			mut children := []ComputedLonghandReuseValue{cap: value.values_.len}
			for child in value.values_ { children << computed_longhand_reuse_typed_snapshot(child) }
			return ComputedLonghandReuseValue{children: children, separator: value.separator_, collapsible: value.collapsible_, list: true}
		}
		else { return ComputedLonghandReuseValue{ text: value.serialize(.normal), value_type: value.type_name() } }
	}
	return ComputedLonghandReuseValue{value: copy, simple: true}
}

fn computed_longhand_reuse_snapshot_matches(snapshot &ComputedLonghandReuseValue, value &dom.StyleValue) bool {
	if value.css_value_handle == unsafe { nil } { return false }
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	return computed_longhand_reuse_typed_snapshot_matches(snapshot, typed.value)
}

fn computed_longhand_reuse_typed_snapshot_matches(snapshot &ComputedLonghandReuseValue, value StyleValue) bool {
	if snapshot.simple { return snapshot.value.equals(value) }
	if snapshot.list {
		if value is StyleValueList {
			if snapshot.separator != value.separator_ || snapshot.collapsible != value.collapsible_
				|| snapshot.children.len != value.values_.len { return false }
			for index, child in value.values_ {
				if !computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[index], child) { return false }
			}
			return true
		}
		return false
	}
	return snapshot.value_type == value.type_name() && snapshot.text == value.serialize(.normal)
}

// Deliberately exclude functions, substitutions, attr(), URLs, font-relative
// lengths and composites other than lists of context-independent values.
// Such computations retain the ordinary path.
fn computed_longhand_reuse_value_is_simple(value &dom.StyleValue) bool {
	if value.css_value_handle == unsafe { nil } { return false }
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	return computed_longhand_reuse_typed_value_is_simple(typed.value)
}

fn computed_longhand_reuse_typed_value_is_simple(value StyleValue) bool {
	match value {
		KeywordStyleValue {
			return value.keyword() !in [.initial, .inherit, .unset, .revert,
				.revert_layer, .larger, .smaller, .bolder, .lighter, .math]
		}
		LengthStyleValue { return value.length().is_absolute() }
		ColorStyleValue, NumberStyleValue, IntegerStyleValue, PercentageStyleValue,
		DisplayStyleValue, StringStyleValue, CustomIdentStyleValue { return true }
		StyleValueList {
			for child in value.values_ {
				if !computed_longhand_reuse_typed_value_is_simple(child) { return false }
			}
			return true
		}
		else { return false }
	}
}

fn (s &StyleComputer) computed_longhand_reuse_key(element dom.AbstractElement,
	cascaded &CascadedProperties, inherited ?&ComputedProperties, recascaded_font bool) ?ComputedLonghandReuseKey {
	if s.computed_property_page_batch_depth_ == 0 || recascaded_font
		|| element.pseudo_element() != none || !element.element().is_html_element()
		|| element.element().local_name() == 'html' { return none }
	parent := inherited or { return none }
	if parent.property_store_ == unsafe { nil } || parent.has_animated_properties() {
		return none
	}
	mut hash := u64(0x9e3779b97f4a7c15)
	for page in parent.property_store_.pages {
		hash = (hash ^ u64(usize(page))) * u64(0x100000001b3)
	}
	mut parent_typed_handles := [number_of_longhand_properties]voidptr{}
	for index in 0 .. number_of_longhand_properties {
		value := parent.raw_property_at_index(index)
		if value != unsafe { nil } {
			if value.css_value_handle == unsafe { nil } { return none }
			parent_typed_handles[index] = value.css_value_handle
			hash = (hash ^ u64(usize(value.css_value_handle))) * u64(0x100000001b3)
		}
	}
	mut count := 0
	for id, _ in cascaded.entry_heads_ {
		if !computed_interpolation_is_longhand_property(id) { continue }
		property := cascaded.style_property(id) or { continue }
		count++
		if !computed_longhand_reuse_value_is_simple(property.value) { return none }
		// Commutative contribution: entry-head maps need not have equal order.
		hash ^= ((u64(usize(property.value)) ^ u64(usize(property.value.css_value_handle)) ^ (u64(id) * u64(0x9e3779b97f4a7c15))) * u64(0x100000001b3))
	}
	// A key may retain these pages across later mutations of the parent.
	mut parent_store := unsafe { &ComputedPropertyStore(parent.property_store_) }
	parent_store.writable = 0
	for page in computed_initial_property_store.pages {
		hash = (hash ^ u64(usize(page))) * u64(0x100000001b3)
	}
	return ComputedLonghandReuseKey{
		parent: parent
		parent_pages: parent.property_store_.pages
		parent_typed_handles: parent_typed_handles
		initial_pages: computed_initial_property_store.pages
		parent_font_viewport: parent.font_metrics_depend_on_viewport_metrics()
		viewport: s.viewport_rect_
		root_font_size: s.root_element_font_metrics.font_size.to_double()
		root_line_height: s.root_element_font_metrics.line_height.to_double()
		root_font_viewport: s.root_element_font_metrics_depend_on_viewport_metrics
		count: count
		hash: hash
	}
}

fn computed_longhand_reuse_keys_equal(first &ComputedLonghandReuseKey,
	second &ComputedLonghandReuseKey) bool {
	if first.count != second.count || first.parent_font_viewport != second.parent_font_viewport
		|| first.viewport != second.viewport || first.root_font_size != second.root_font_size
		|| first.root_line_height != second.root_line_height
		|| first.root_font_viewport != second.root_font_viewport { return false }
	for index in 0 .. computed_property_page_count {
		if voidptr(first.parent_pages[index]) != voidptr(second.parent_pages[index])
			|| voidptr(first.initial_pages[index]) != voidptr(second.initial_pages[index]) { return false }
	}
	for index in 0 .. number_of_longhand_properties {
		if first.parent_typed_handles[index] != second.parent_typed_handles[index] { return false }
	}
	return true
}

fn (s &StyleComputer) restore_computed_longhands(key ComputedLonghandReuseKey,
	cascaded &CascadedProperties, mut properties ComputedProperties) bool {
	if s.longhand_reuse_cache_ == unsafe { nil } { return false }
	entry := s.longhand_reuse_cache_.entries[key.hash] or { return false }
	if !computed_longhand_reuse_keys_equal(&key, &entry.key) { return false }
	for input in entry.parent_inputs {
		index := int(input.id) - int(first_longhand_property_id())
		value := key.parent.raw_property_at_index(index)
		if value == unsafe { nil } || voidptr(value) != voidptr(input.value)
			|| value.css_value_handle != input.typed_handle
			|| !computed_longhand_reuse_snapshot_matches(&input.snapshot, value) { return false }
	}
	for input in entry.inputs {
		property := cascaded.style_property(input.id) or { return false }
		if voidptr(property.value) != voidptr(input.value)
			|| property.value.css_value_handle != input.typed_handle
			|| !computed_longhand_reuse_snapshot_matches(&input.snapshot, property.value)
			|| property.important != input.important { return false }
	}
	cached := entry.computed
	properties.note_raw_computed_property_graph_mutation()
	properties.property_store_ = cached.clone_raw_property_store()
	properties.property_important_ = cached.property_important_
	properties.property_inherited_ = cached.property_inherited_
	properties.raw_cascaded_font_size_ = cached.raw_cascaded_font_size_
	properties.depends_on_viewport_metrics_ = cached.depends_on_viewport_metrics_
	properties.font_metrics_depend_on_viewport_metrics_ = cached.font_metrics_depend_on_viewport_metrics_
	properties.font_input_refresh_safe_ = cached.font_input_refresh_safe_
	properties.font_input_depends_on_font_size_ = cached.font_input_depends_on_font_size_
	return true
}

fn (s &StyleComputer) remember_computed_longhands(key ComputedLonghandReuseKey,
	cascaded &CascadedProperties, computed &ComputedProperties) {
	// Keep inheritance-dependent specified-value records on their original path.
	if computed.inheritance_specified_storage_ != unsafe { nil }
		|| computed.has_animated_properties() { return }
	mut index_arena := s.computed_property_page_index_arena()
	allocation := index_arena.enter()
	defer { index_arena.leave(allocation) }
	mut owner := unsafe { &StyleComputer(s) }
	if owner.longhand_reuse_cache_ == unsafe { nil } {
		owner.longhand_reuse_cache_ = &ComputedLonghandReuseCache{}
	}
	if owner.longhand_reuse_cache_.entries.len >= 256 { return }
	mut inputs := []ComputedLonghandReuseInput{cap: key.count}
	for id, _ in cascaded.entry_heads_ {
		if !computed_interpolation_is_longhand_property(id) { continue }
		property := cascaded.style_property(id) or { continue }
		inputs << ComputedLonghandReuseInput{id: id, value: property.value, typed_handle: property.value.css_value_handle, snapshot: computed_longhand_reuse_snapshot(property.value), important: property.important}
	}
	mut parent_inputs := []ComputedLonghandReuseInput{cap: number_of_longhand_properties}
	for index in 0 .. number_of_longhand_properties {
		value := key.parent.raw_property_at_index(index)
		if value == unsafe { nil } { continue }
		parent_inputs << ComputedLonghandReuseInput{
			id: unsafe { PropertyID(index + int(first_longhand_property_id())) }
			value: value
			typed_handle: value.css_value_handle
			snapshot: computed_longhand_reuse_snapshot(value)
		}
	}
	snapshot := &ComputedProperties{...computed, property_store_: computed.clone_raw_property_store()}
	owner.longhand_reuse_cache_.entries[key.hash] = &ComputedLonghandReuseEntry{
		key: key, parent_inputs: parent_inputs, inputs: inputs, computed: snapshot
	}
}
