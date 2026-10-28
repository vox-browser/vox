module css

import dom
import math

// Reuse only the longhand computation loop, before custom properties,
// animations, box transformations and element-specific adjustments. Every hit
// keeps a fresh style object, mutation token, subject and mutable property
// store. Published pages remain immutable through the existing COW protocol.
// The outer synchronous style batch bounds both the environment and lifetime.
struct ComputedLonghandReuseValue {
	value       StyleValue
	text        string
	value_type  string
	simple      bool
	children    []ComputedLonghandReuseValue
	separator   StyleValueListSeparator
	collapsible StyleValueListCollapsible
	list        bool
}

struct ComputedLonghandReuseInput {
	id           PropertyID
	value        &dom.StyleValue
	typed_handle voidptr
	snapshot     ComputedLonghandReuseValue
	semantic     bool
	important    Important
}

struct ComputedLonghandReuseKey {
	parent               &ComputedProperties
	initial_pages        [computed_property_page_count]&ComputedPropertyPage
	parent_font_viewport bool
	viewport             CSSPixelRect
	root_font_size       f64
	root_line_height     f64
	root_font_viewport   bool
	count                int
	hash                 u64
}

@[heap]
struct ComputedLonghandReuseEntry {
	key           ComputedLonghandReuseKey
	parent_inputs []ComputedLonghandReuseInput
	inputs        []ComputedLonghandReuseInput
	computed      &ComputedProperties
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
	return computed_longhand_reuse_typed_snapshot(&typed.value)
}

fn computed_longhand_reuse_typed_snapshot(value &StyleValue) ComputedLonghandReuseValue {
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
			for index in 0 .. value.values_.len {
				children << computed_longhand_reuse_typed_snapshot(&value.values_[index])
			}
			return ComputedLonghandReuseValue{ children: children, separator: value.separator_, collapsible: value.collapsible_, list: true }
		}
		else {
			return ComputedLonghandReuseValue{ text: value.serialize(.normal), value_type: value.type_name() }
		}
	}
	return ComputedLonghandReuseValue{ value: copy, simple: true }
}

fn computed_longhand_reuse_snapshot_matches(snapshot &ComputedLonghandReuseValue, value &dom.StyleValue) bool {
	if value.css_value_handle == unsafe { nil } { return false }
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	return computed_longhand_reuse_typed_snapshot_matches(snapshot, &typed.value)
}

fn computed_longhand_reuse_typed_snapshot_matches(snapshot &ComputedLonghandReuseValue, value &StyleValue) bool {
	if snapshot.simple {
		// These are the same payloads copied by the snapshot constructor. Compare
		// through borrowed boxes: copying the large StyleValue union at every
		// inherited input makes a cache hit unnecessarily allocate and collect.
		return match value {
			KeywordStyleValue {
				snapshot.value is KeywordStyleValue && snapshot.value.keyword_ == value.keyword_
			}
			LengthStyleValue {
				snapshot.value is LengthStyleValue && snapshot.value.length_ == value.length_
			}
			ColorStyleValue {
				snapshot.value is ColorStyleValue && snapshot.value.color_ == value.color_
			}
			NumberStyleValue {
				snapshot.value is NumberStyleValue && snapshot.value.value_ == value.value_
			}
			IntegerStyleValue {
				snapshot.value is IntegerStyleValue && snapshot.value.value_ == value.value_
			}
			PercentageStyleValue {
				snapshot.value is PercentageStyleValue && snapshot.value.percentage_ == value.percentage_
			}
			DisplayStyleValue {
				snapshot.value is DisplayStyleValue && snapshot.value.display_ == value.display_
			}
			StringStyleValue {
				snapshot.value is StringStyleValue && snapshot.value.string_value_ == value.string_value_
			}
			CustomIdentStyleValue {
				snapshot.value is CustomIdentStyleValue && snapshot.value.custom_ident_ == value.custom_ident_
			}
			else { false }
		}
	}
	if snapshot.list {
		if value is StyleValueList {
			if snapshot.separator != value.separator_ || snapshot.collapsible != value.collapsible_
				|| snapshot.children.len != value.values_.len {
				return false
			}
			for index in 0 .. value.values_.len {
				if !computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[index], &value.values_[index]) {
					return false
				}
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
	return computed_longhand_reuse_typed_value_is_simple(&typed.value)
}

fn computed_longhand_reuse_typed_value_is_simple(value &StyleValue) bool {
	match value {
		KeywordStyleValue {
			return value.keyword() !in [.initial, .inherit, .unset, .revert, .revert_layer, .larger,
				.smaller, .bolder, .lighter, .math]
		}
		LengthStyleValue { return value.length().is_absolute() }
		ColorStyleValue, NumberStyleValue, IntegerStyleValue, PercentageStyleValue,
		DisplayStyleValue, StringStyleValue, CustomIdentStyleValue {
			return true
		}
		StyleValueList {
			for index in 0 .. value.values_.len {
				if !computed_longhand_reuse_typed_value_is_simple(&value.values_[index]) {
					return false
				}
			}
			return true
		}
		else { return false }
	}
}

// Equal scalar/list payloads need not have the same DOM wrapper or typed box.
// Hash only these fully copied payloads; other inherited values retain their
// identity guard. A hash is only an index: restore compares the saved payload.
fn computed_longhand_reuse_value_hash(value &dom.StyleValue) ?u64 {
	if value.css_value_handle == unsafe { nil } { return none }
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	return computed_longhand_reuse_typed_hash(&typed.value)
}

fn computed_longhand_reuse_number_hash(value f64) u64 {
	// Typed equality treats both signs of zero as equal.
	return if value == 0 { u64(0) } else { math.f64_bits(value) }
}

fn computed_longhand_reuse_typed_hash(value &StyleValue) ?u64 {
	return match value {
		KeywordStyleValue { u64(1) ^ (u64(value.keyword_) * u64(0x100000001b3)) }
		LengthStyleValue {
			u64(2) ^ computed_longhand_reuse_number_hash(value.length_.value_) ^
				(u64(value.length_.unit_) * u64(0x100000001b3))
		}
		ColorStyleValue {
			color := value.color_
			u64(3) ^ ((u64(color.r) << 24 | u64(color.g) << 16 | u64(color.b) << 8 | u64(color.a)) * u64(0x100000001b3))
		}
		NumberStyleValue { u64(4) ^ computed_longhand_reuse_number_hash(value.value_) }
		IntegerStyleValue { u64(5) ^ (u64(value.value_) * u64(0x100000001b3)) }
		PercentageStyleValue {
			u64(6) ^ computed_longhand_reuse_number_hash(value.percentage_.value_)
		}
		DisplayStyleValue {
			display := value.display_
			mut hash := u64(7)
			hash = (hash ^ u64(display.type_)) * u64(0x100000001b3)
			hash = (hash ^ u64(display.outside_)) * u64(0x100000001b3)
			hash = (hash ^ u64(display.inside_)) * u64(0x100000001b3)
			hash = (hash ^ u64(display.list_item)) * u64(0x100000001b3)
			hash = (hash ^ u64(display.internal_)) * u64(0x100000001b3)
			hash = (hash ^ u64(display.box_)) * u64(0x100000001b3)
			hash
		}
		StringStyleValue { u64(8) ^ (u64(value.string_value_.hash()) * u64(0x100000001b3)) }
		CustomIdentStyleValue { u64(9) ^ (u64(value.custom_ident_.hash()) * u64(0x100000001b3)) }
		StyleValueList {
			mut hash := (u64(10) ^ u64(value.separator_) ^ (u64(value.collapsible_) << 8) ^
				(u64(value.values_.len) << 16)) * u64(0x100000001b3)
			for index in 0 .. value.values_.len {
				hash = (hash ^ computed_longhand_reuse_typed_hash(&value.values_[index])?) * u64(0x100000001b3)
			}
			hash
		}
		else { return none }
	}
}

fn computed_longhand_reuse_input_matches(input &ComputedLonghandReuseInput, value &dom.StyleValue) bool {
	if input.value == unsafe { nil } { return value == unsafe { nil } }
	if value == unsafe { nil } || value.css_value_handle == unsafe { nil } { return false }
	if !input.semantic && (voidptr(value) != voidptr(input.value)
		|| value.css_value_handle != input.typed_handle) {
		return false
	}
	return computed_longhand_reuse_snapshot_matches(&input.snapshot, value)
}

fn (s &StyleComputer) computed_longhand_reuse_key(element dom.AbstractElement,
	cascaded &CascadedProperties, inherited ?&ComputedProperties, recascaded_font bool) ?ComputedLonghandReuseKey {
	if s.computed_property_page_batch_depth_ == 0 || recascaded_font
		|| element.pseudo_element() != none || !element.element().is_html_element()
		|| element.element().local_name() == 'html' {
		return none
	}
	parent := inherited or { return none }
	if parent.property_store_ == unsafe { nil } || parent.has_animated_properties() {
		return none
	}
	mut hash := u64(0x9e3779b97f4a7c15)
	// Eligible cascades cannot explicitly inherit a non-inherited property or
	// contain context-dependent substitutions. Only inherited parent inputs
	// participate in this loop; element adjustments still run after every hit.
	ensure_computed_interpolation_inherited_cache()
	for index in 0 .. number_of_longhand_properties {
		if computed_interpolation_inherited_cache[index] == 0 { continue }
		value := parent.raw_property_at_index(index)
		mut value_hash := u64(0)
		if value != unsafe { nil } {
			if value.css_value_handle == unsafe { nil } { return none }
			value_hash = computed_longhand_reuse_value_hash(value) or { u64(usize(value.css_value_handle)) }
		}
		hash = (hash ^ value_hash) * u64(0x100000001b3)
	}
	mut count := 0
	for id, _ in cascaded.entry_heads_ {
		if !computed_interpolation_is_longhand_property(id) { continue }
		property := cascaded.style_property(id) or { continue }
		count++
		if !computed_longhand_reuse_value_is_simple(property.value) { return none }
		// Commutative contribution: entry-head maps need not have equal order.
		value_hash := computed_longhand_reuse_value_hash(property.value) or { return none }
		hash ^= ((value_hash ^ (u64(id) * u64(0x9e3779b97f4a7c15))) * u64(0x100000001b3))
	}
	for page in computed_initial_property_store.pages {
		hash = (hash ^ u64(usize(page))) * u64(0x100000001b3)
	}
	return ComputedLonghandReuseKey{
		parent:               parent
		initial_pages:        computed_initial_property_store.pages
		parent_font_viewport: parent.font_metrics_depend_on_viewport_metrics()
		viewport:             s.viewport_rect_
		root_font_size:       s.root_element_font_metrics.font_size.to_double()
		root_line_height:     s.root_element_font_metrics.line_height.to_double()
		root_font_viewport:   s.root_element_font_metrics_depend_on_viewport_metrics
		count:                count
		hash:                 hash
	}
}

fn computed_longhand_reuse_keys_equal(first &ComputedLonghandReuseKey,
	second &ComputedLonghandReuseKey) bool {
	if first.count != second.count || first.parent_font_viewport != second.parent_font_viewport
		|| first.viewport != second.viewport || first.root_font_size != second.root_font_size
		|| first.root_line_height != second.root_line_height
		|| first.root_font_viewport != second.root_font_viewport {
		return false
	}
	for index in 0 .. computed_property_page_count {
		if voidptr(first.initial_pages[index]) != voidptr(second.initial_pages[index]) {
			return false
		}
	}
	return true
}

fn (s &StyleComputer) restore_computed_longhands(key &ComputedLonghandReuseKey,
	cascaded &CascadedProperties, mut properties ComputedProperties) bool {
	if s.longhand_reuse_cache_ == unsafe { nil } { return false }
	entry := s.longhand_reuse_cache_.entries[key.hash] or { return false }
	if !computed_longhand_reuse_keys_equal(key, &entry.key) { return false }
	for input_index in 0 .. entry.parent_inputs.len {
		input := &entry.parent_inputs[input_index]
		index := int(input.id) - int(first_longhand_property_id())
		value := key.parent.raw_property_at_index(index)
		if !computed_longhand_reuse_input_matches(input, value) { return false }
	}
	for input_index in 0 .. entry.inputs.len {
		input := &entry.inputs[input_index]
		property := cascaded.style_property(input.id) or { return false }
		if !computed_longhand_reuse_input_matches(input, property.value)
			|| property.important != input.important {
			return false
		}
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
		|| computed.has_animated_properties() {
		return
	}
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
		inputs << ComputedLonghandReuseInput{ id: id, value: property.value, typed_handle: property.value.css_value_handle, snapshot: computed_longhand_reuse_snapshot(property.value), semantic: true, important: property.important }
	}
	mut parent_inputs := []ComputedLonghandReuseInput{cap: 64}
	for index in 0 .. number_of_longhand_properties {
		if computed_interpolation_inherited_cache[index] == 0 { continue }
		value := key.parent.raw_property_at_index(index)
		id := unsafe { PropertyID(index + int(first_longhand_property_id())) }
		// Include absent slots as well: hash collisions must not hide a later
		// transition from an absent inherited input to a present one.
		if value == unsafe { nil } {
			parent_inputs << ComputedLonghandReuseInput{ id: id, value: unsafe { nil } }
			continue
		}
		parent_inputs << ComputedLonghandReuseInput{
			id:           id
			value:        value
			typed_handle: value.css_value_handle
			snapshot:     computed_longhand_reuse_snapshot(value)
			semantic:     computed_longhand_reuse_value_hash(value) != none
		}
	}
	snapshot := &ComputedProperties{ ...computed, property_store_: computed.clone_raw_property_store() }
	owner.longhand_reuse_cache_.entries[key.hash] = &ComputedLonghandReuseEntry{
		key:           key
		parent_inputs: parent_inputs
		inputs:        inputs
		computed:      snapshot
	}
}
