module css

import dom
import math
import os

__global (
	computed_longhand_extension_mode int
	computed_longhand_extension_diagnostics bool
	computed_longhand_extension_reported bool
	computed_longhand_color_mode int
	computed_longhand_color_reported bool
	computed_longhand_constant_mode int
	computed_longhand_constant_diagnostics bool
	computed_longhand_constant_reported bool
)

fn computed_longhand_constants_enabled() bool {
	if computed_longhand_constant_mode == 0 {
		computed_longhand_constant_mode = if os.getenv('VOX_DISABLE_CONSTANT_LONGHAND_REUSE') == '' { 1 } else { 2 }
		computed_longhand_constant_diagnostics = os.getenv('VOX_CONSTANT_LONGHAND_REUSE_DIAGNOSTICS') != ''
	}
	return computed_longhand_constant_mode == 1
}

fn computed_longhand_extensions_enabled() bool {
	if computed_longhand_extension_mode == 0 {
		computed_longhand_extension_mode = if os.getenv('VOX_DISABLE_EXTENDED_LONGHAND_REUSE') == '' { 1 } else { 2 }
		computed_longhand_extension_diagnostics = os.getenv('VOX_EXTENDED_LONGHAND_REUSE_DIAGNOSTICS') != ''
	}
	return computed_longhand_extension_mode == 1
}

fn computed_longhand_colors_enabled() bool {
	if computed_longhand_color_mode == 0 {
		computed_longhand_color_mode = if os.getenv('VOX_DISABLE_COLOR_LONGHAND_REUSE') == '' { 1 } else { 2 }
	}
	return computed_longhand_extensions_enabled() && computed_longhand_color_mode == 1
}

// Reuse only the longhand computation loop, before custom properties,
// animations, box transformations and element-specific adjustments. Every hit
// keeps a fresh style object, mutation token, subject and mutable property
// store. Published pages remain immutable through the existing COW protocol.
// The outer synchronous style batch bounds both the environment and lifetime.
// Snapshot only the supported payload, never the 288-byte StyleValue union.
// The tag preserves typed equality, including values with equal serialization.
enum ComputedLonghandReuseValueKind as u8 {
	unsupported
	keyword
	length
	color
	number
	integer
	percentage
	display
	string_
	custom_ident
	list
	border_image_slice
	rgb
	ratio
	font_style
	time
	angle
	grid_auto_flow
	grid_auto
	grid_line
	grid_span
	border_radius
}

struct ComputedLonghandReuseValue {
	kind        ComputedLonghandReuseValueKind
	number      f64
	integer     i64
	keyword     Keyword
	length_unit LengthUnit
	color       Color
	display     Display
	text        string
	value_type  string
	children    []ComputedLonghandReuseValue
	separator   StyleValueListSeparator
	collapsible StyleValueListCollapsible
	color_syntax ColorSyntax
	has_name bool
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
	parent_hashes map[u64]ComputedLonghandParentHashHint
}

// Copy scalar payloads rather than retaining their mutable sum-type boxes.
// Composite parent values keep a conservative serialization guard as well as
// their wrapper and typed handle identities. The reuse batch runs synchronously.
fn computed_longhand_reuse_snapshot(value &dom.StyleValue) ComputedLonghandReuseValue {
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	return computed_longhand_reuse_typed_snapshot(&typed.value)
}

fn computed_longhand_reuse_typed_snapshot(value &StyleValue) ComputedLonghandReuseValue {
	return match value {
		KeywordStyleValue { ComputedLonghandReuseValue{ kind: .keyword, keyword: value.keyword_ } }
		LengthStyleValue {
			ComputedLonghandReuseValue{ kind: .length, number: value.length_.value_, length_unit: value.length_.unit_ }
		}
		ColorStyleValue { ComputedLonghandReuseValue{ kind: .color, color: value.color_ } }
		NumberStyleValue { ComputedLonghandReuseValue{ kind: .number, number: value.value_ } }
		IntegerStyleValue { ComputedLonghandReuseValue{ kind: .integer, integer: value.value_ } }
		PercentageStyleValue {
			ComputedLonghandReuseValue{ kind: .percentage, number: value.percentage_.value_ }
		}
		DisplayStyleValue { ComputedLonghandReuseValue{ kind: .display, display: value.display_ } }
		StringStyleValue { ComputedLonghandReuseValue{ kind: .string_, text: value.string_value_ } }
		CustomIdentStyleValue {
			ComputedLonghandReuseValue{ kind: .custom_ident, text: value.custom_ident_ }
		}
		StyleValueList {
			mut children := []ComputedLonghandReuseValue{cap: value.values_.len}
			for index in 0 .. value.values_.len {
				children << computed_longhand_reuse_typed_snapshot(&value.values_[index])
			}
			ComputedLonghandReuseValue{ kind: .list, children: children, separator: value.separator_, collapsible: value.collapsible_ }
		}
		BorderImageSliceStyleValue {
			if value.top_.len != 1 || value.right_.len != 1 || value.bottom_.len != 1 || value.left_.len != 1 {
				ComputedLonghandReuseValue{}
			} else {
				ComputedLonghandReuseValue{ kind: .border_image_slice, integer: if value.fill_ { 1 } else { 0 }, children: [
					computed_longhand_reuse_typed_snapshot(&value.top_[0]),
					computed_longhand_reuse_typed_snapshot(&value.right_[0]),
					computed_longhand_reuse_typed_snapshot(&value.bottom_[0]),
					computed_longhand_reuse_typed_snapshot(&value.left_[0]),
				] }
			}
		}
		RGBColorStyleValue {
			if value.r_.len != 1 || value.g_.len != 1 || value.b_.len != 1 || value.alpha_.len != 1 {
				ComputedLonghandReuseValue{}
			} else {
				ComputedLonghandReuseValue{ kind: .rgb, color_syntax: value.color_syntax_,
					has_name: value.name_ != none, text: value.name_ or { '' }, children: [
					computed_longhand_reuse_typed_snapshot(&value.r_[0]),
					computed_longhand_reuse_typed_snapshot(&value.g_[0]),
					computed_longhand_reuse_typed_snapshot(&value.b_[0]),
					computed_longhand_reuse_typed_snapshot(&value.alpha_[0]),
				] }
			}
		}
		RatioStyleValue {
			if value.numerator_.len != 1 || value.denominator_.len != 1 {
				ComputedLonghandReuseValue{}
			} else {
				ComputedLonghandReuseValue{ kind: .ratio, children: [
					computed_longhand_reuse_typed_snapshot(&value.numerator_[0]),
					computed_longhand_reuse_typed_snapshot(&value.denominator_[0]),
				] }
			}
		}
		FontStyleStyleValue {
			mut children := []ComputedLonghandReuseValue{}
			if angles := value.angle_value_ {
				for index in 0 .. angles.len {
					children << computed_longhand_reuse_typed_snapshot(&angles[index])
				}
			}
			ComputedLonghandReuseValue{ kind: .font_style, integer: i64(value.font_style_),
				has_name: value.angle_value_ != none, children: children }
		}
		TimeStyleValue {
			ComputedLonghandReuseValue{ kind: .time, number: value.time_.value_, integer: i64(value.time_.unit_) }
		}
		AngleStyleValue {
			ComputedLonghandReuseValue{ kind: .angle, number: value.angle_.value_, integer: i64(value.angle_.unit_) }
		}
		else {
			longhand_shape_snapshot(value) or { ComputedLonghandReuseValue{ text: value.serialize(.normal), value_type: value.type_name() } }
		}
	}
}

fn computed_longhand_reuse_snapshot_matches(snapshot &ComputedLonghandReuseValue, value &dom.StyleValue) bool {
	if value.css_value_handle == unsafe { nil } { return false }
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	return computed_longhand_reuse_typed_snapshot_matches(snapshot, &typed.value)
}

fn computed_longhand_reuse_typed_snapshot_matches(snapshot &ComputedLonghandReuseValue, value &StyleValue) bool {
	return match value {
		KeywordStyleValue { snapshot.kind == .keyword && snapshot.keyword == value.keyword_ }
		LengthStyleValue {
			snapshot.kind == .length && snapshot.number == value.length_.value_ && snapshot.length_unit == value.length_.unit_
		}
		ColorStyleValue { snapshot.kind == .color && snapshot.color == value.color_ }
		NumberStyleValue { snapshot.kind == .number && snapshot.number == value.value_ }
		IntegerStyleValue { snapshot.kind == .integer && snapshot.integer == value.value_ }
		PercentageStyleValue {
			snapshot.kind == .percentage && snapshot.number == value.percentage_.value_
		}
		DisplayStyleValue { snapshot.kind == .display && snapshot.display == value.display_ }
		StringStyleValue { snapshot.kind == .string_ && snapshot.text == value.string_value_ }
		CustomIdentStyleValue {
			snapshot.kind == .custom_ident && snapshot.text == value.custom_ident_
		}
		StyleValueList {
			if snapshot.kind != .list || snapshot.separator != value.separator_ || snapshot.collapsible != value.collapsible_
				|| snapshot.children.len != value.values_.len {
				return false
			}
			for index in 0 .. value.values_.len {
				if !computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[index], &value.values_[index]) {
					return false
				}
			}
			true
		}
		BorderImageSliceStyleValue {
			snapshot.kind == .border_image_slice && snapshot.children.len == 4
				&& snapshot.integer == if value.fill_ { 1 } else { 0 }
				&& value.top_.len == 1 && value.right_.len == 1 && value.bottom_.len == 1 && value.left_.len == 1
				&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[0], &value.top_[0])
				&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[1], &value.right_[0])
				&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[2], &value.bottom_[0])
				&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[3], &value.left_[0])
		}
		RGBColorStyleValue {
			snapshot.kind == .rgb && snapshot.children.len == 4
				&& snapshot.color_syntax == value.color_syntax_
				&& snapshot.has_name == (value.name_ != none) && snapshot.text == (value.name_ or { '' })
				&& value.r_.len == 1 && value.g_.len == 1 && value.b_.len == 1 && value.alpha_.len == 1
				&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[0], &value.r_[0])
				&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[1], &value.g_[0])
				&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[2], &value.b_[0])
				&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[3], &value.alpha_[0])
		}
		RatioStyleValue {
			snapshot.kind == .ratio && snapshot.children.len == 2
				&& value.numerator_.len == 1 && value.denominator_.len == 1
				&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[0], &value.numerator_[0])
				&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[1], &value.denominator_[0])
		}
		FontStyleStyleValue {
			if snapshot.kind != .font_style || snapshot.integer != i64(value.font_style_)
				|| snapshot.has_name != (value.angle_value_ != none) {
				false
			} else if angles := value.angle_value_ {
				angles.len == 1 && snapshot.children.len == 1
					&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[0], &angles[0])
			} else {
				snapshot.children.len == 0
			}
		}
		TimeStyleValue {
			snapshot.kind == .time && snapshot.number == value.time_.value_
				&& snapshot.integer == i64(value.time_.unit_)
		}
		AngleStyleValue {
			snapshot.kind == .angle && snapshot.number == value.angle_.value_
				&& snapshot.integer == i64(value.angle_.unit_)
		}
		else {
			longhand_shape_snapshot_matches(snapshot, value) || (snapshot.kind == .unsupported && snapshot.value_type == value.type_name() && snapshot.text == value.serialize(.normal))
		}
	}
}

// Deliberately exclude functions, substitutions, attr(), URLs, font-relative
// lengths and composites other than the explicitly snapshotted values.
// Such computations retain the ordinary path.
fn computed_longhand_reuse_value_is_simple(value &dom.StyleValue) bool {
	if value.css_value_handle == unsafe { nil } { return false }
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	return computed_longhand_reuse_typed_value_is_simple(&typed.value)
}

// CSS-wide initial/unset values use the same defaults as an absent declaration.
// Explicit inheritance is safe only for properties whose parent inputs the key
// already snapshots. Non-inherited parent values deliberately remain excluded.
fn computed_longhand_reuse_property_is_simple(id PropertyID, value &dom.StyleValue) bool {
	if computed_longhand_extensions_enabled() && value.css_value_handle != unsafe { nil } {
		typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		if typed.value is KeywordStyleValue {
			keyword := typed.value.keyword_
			if keyword in [.initial, .unset] { return true }
			if keyword == .inherit { return computed_interpolation_is_inherited_property(id) }
		}
	}
	return computed_longhand_reuse_value_is_simple(value)
}

fn computed_longhand_reuse_typed_value_is_simple(value &StyleValue) bool {
	match value {
		KeywordStyleValue {
			return value.keyword() !in [.initial, .inherit, .unset, .revert, .revert_layer, .larger,
				.smaller, .bolder, .lighter, .math]
		}
		LengthStyleValue { return value.length().is_absolute() || longhand_shape_length_is_viewport(value.length_) }
		RatioStyleValue {
			// Numeric components require no resolution context. Calculated ratios
			// can depend on fonts or containers and keep the ordinary path.
			return computed_longhand_constants_enabled()
				&& value.numerator_.len == 1 && value.denominator_.len == 1
				&& value.numerator_[0] is NumberStyleValue && value.denominator_[0] is NumberStyleValue
		}
		FontStyleStyleValue { return computed_longhand_constants_enabled() && value.angle_value_ == none }
		TimeStyleValue { return computed_longhand_constants_enabled() }
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
		BorderImageSliceStyleValue {
			return computed_longhand_extensions_enabled()
				&& value.top_.len == 1 && value.right_.len == 1 && value.bottom_.len == 1 && value.left_.len == 1
				&& computed_longhand_reuse_typed_value_is_simple(&value.top_[0])
				&& computed_longhand_reuse_typed_value_is_simple(&value.right_[0])
				&& computed_longhand_reuse_typed_value_is_simple(&value.bottom_[0])
				&& computed_longhand_reuse_typed_value_is_simple(&value.left_[0])
		}
		RGBColorStyleValue {
			return computed_longhand_colors_enabled()
				&& value.r_.len == 1 && value.g_.len == 1 && value.b_.len == 1 && value.alpha_.len == 1
				&& computed_longhand_reuse_color_component_is_simple(&value.r_[0])
				&& computed_longhand_reuse_color_component_is_simple(&value.g_[0])
				&& computed_longhand_reuse_color_component_is_simple(&value.b_[0])
				&& computed_longhand_reuse_color_component_is_simple(&value.alpha_[0])
		}
		else { return longhand_shape_is_simple(value) }
	}
}

fn computed_longhand_reuse_color_component_is_simple(value &StyleValue) bool {
	return match value {
		NumberStyleValue, PercentageStyleValue { true }
		KeywordStyleValue { value.keyword_ == .none_ }
		else { false }
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
		BorderImageSliceStyleValue {
			if value.top_.len != 1 || value.right_.len != 1 || value.bottom_.len != 1 || value.left_.len != 1 {
				return none
			}
			mut hash := u64(11) ^ if value.fill_ { u64(0x100000001b3) } else { u64(0) }
			hash = (hash ^ computed_longhand_reuse_typed_hash(&value.top_[0])?) * u64(0x100000001b3)
			hash = (hash ^ computed_longhand_reuse_typed_hash(&value.right_[0])?) * u64(0x100000001b3)
			hash = (hash ^ computed_longhand_reuse_typed_hash(&value.bottom_[0])?) * u64(0x100000001b3)
			(hash ^ computed_longhand_reuse_typed_hash(&value.left_[0])?) * u64(0x100000001b3)
		}
		RGBColorStyleValue {
			// The control retains identity hashing for inherited parsed colors too.
			if !computed_longhand_colors_enabled() || !computed_longhand_reuse_typed_value_is_simple(value) {
				return none
			}
			mut hash := (u64(12) ^ u64(value.color_syntax_) ^ if value.name_ != none { u64(256) } else { u64(0) }) * u64(0x100000001b3)
			hash = (hash ^ u64((value.name_ or { '' }).hash())) * u64(0x100000001b3)
			hash = (hash ^ computed_longhand_reuse_typed_hash(&value.r_[0])?) * u64(0x100000001b3)
			hash = (hash ^ computed_longhand_reuse_typed_hash(&value.g_[0])?) * u64(0x100000001b3)
			hash = (hash ^ computed_longhand_reuse_typed_hash(&value.b_[0])?) * u64(0x100000001b3)
			(hash ^ computed_longhand_reuse_typed_hash(&value.alpha_[0])?) * u64(0x100000001b3)
		}
		RatioStyleValue {
			if !computed_longhand_reuse_typed_value_is_simple(value) { return none }
			mut hash := u64(13)
			hash = (hash ^ computed_longhand_reuse_typed_hash(&value.numerator_[0])?) * u64(0x100000001b3)
			(hash ^ computed_longhand_reuse_typed_hash(&value.denominator_[0])?) * u64(0x100000001b3)
		}
		FontStyleStyleValue {
			if !computed_longhand_reuse_typed_value_is_simple(value) { return none }
			u64(14) ^ (u64(value.font_style_) * u64(0x100000001b3))
		}
		TimeStyleValue {
			if !computed_longhand_constants_enabled() { return none }
			u64(15) ^ computed_longhand_reuse_number_hash(value.time_.value_)
				^ (u64(value.time_.unit_) * u64(0x100000001b3))
		}
		else { return longhand_shape_hash(value) }
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

struct ComputedLonghandCascadeKey {
	count int
	hash u64
}

fn computed_longhand_cascade_key(cascaded &CascadedProperties) ?ComputedLonghandCascadeKey {
	mut count := 0
	mut hash := u64(0)
	for id, _ in cascaded.entry_heads_ {
		if !computed_interpolation_is_longhand_property(id) { continue }
		property := cascaded.style_property(id) or { continue }
		count++
		if !computed_longhand_reuse_property_is_simple(id, property.value) {
			record_diagnostic_longhand_rejection(id, property.value)
			return none
		}
		value_hash := computed_longhand_reuse_value_hash(property.value) or { return none }
		hash ^= ((value_hash ^ (u64(id) * u64(0x9e3779b97f4a7c15))) * u64(0x100000001b3))
	}
	return ComputedLonghandCascadeKey{count:count, hash:hash}
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
	mut cascade_key := ComputedLonghandCascadeKey{}
	if !disable_longhand_eligibility_first {
		cascade_key = computed_longhand_cascade_key(cascaded) or {
			report_longhand_eligibility_rejection()
			return none
		}
	}
	mut hash := s.inherited_longhand_hash_hint(parent, element) or { return none }
	if disable_longhand_eligibility_first {
		cascade_key = computed_longhand_cascade_key(cascaded) or { return none }
	}
	// Own contributions are XOR-combined, preserving the original key exactly.
	hash ^= cascade_key.hash
	for page in computed_initial_property_store.pages {
		hash = (hash ^ u64(voidptr(page))) * u64(0x100000001b3)
	}
	return ComputedLonghandReuseKey{
		parent:               parent
		initial_pages:        computed_initial_property_store.pages
		parent_font_viewport: parent.font_metrics_depend_on_viewport_metrics()
		viewport:             s.viewport_rect_
		root_font_size:       s.root_element_font_metrics.font_size.to_double()
		root_line_height:     s.root_element_font_metrics.line_height.to_double()
		root_font_viewport:   s.root_element_font_metrics_depend_on_viewport_metrics
		count:                cascade_key.count
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
		// A computed composite can retain arrays from its original specified
		// value. A later equal, independently boxed input must not revive that
		// entry after the retained original was mutated in place.
		if !computed_longhand_reuse_input_matches(input, input.value) { return false }
		index := int(input.id) - int(first_longhand_property_id())
		value := key.parent.raw_property_at_index(index)
		if !computed_longhand_reuse_input_matches(input, value) { return false }
	}
	for input_index in 0 .. entry.inputs.len {
		input := &entry.inputs[input_index]
		if !computed_longhand_reuse_input_matches(input, input.value) { return false }
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
	report_longhand_shape_restore(entry.inputs)
	if computed_longhand_constant_diagnostics && !computed_longhand_constant_reported
		&& computed_longhand_constants_enabled() {
		for input in entry.inputs {
			if input.snapshot.kind in [.ratio, .font_style, .time] {
				computed_longhand_constant_reported = true
				eprintln('Vox constant longhand reuse: restored ${input.snapshot.kind}')
				break
			}
		}
	}
	if computed_longhand_extension_diagnostics && !computed_longhand_extension_reported {
		for input in entry.inputs {
			typed := unsafe { &TypedStyleValueBox(input.value.css_value_handle) }
			if typed.value is BorderImageSliceStyleValue
				|| (typed.value is KeywordStyleValue && typed.value.keyword_ in [.initial, .unset, .inherit]) {
				computed_longhand_extension_reported = true
				eprintln('Vox extended longhand reuse: restored')
				break
			}
		}
	}
	if computed_longhand_extension_diagnostics && !computed_longhand_color_reported && computed_longhand_colors_enabled() {
		for inputs in [entry.inputs, entry.parent_inputs] {
			for input in inputs {
				if input.value == unsafe { nil } || input.value.css_value_handle == unsafe { nil } { continue }
				typed := unsafe { &TypedStyleValueBox(input.value.css_value_handle) }
				if typed.value is RGBColorStyleValue {
					computed_longhand_color_reported = true
					eprintln('Vox color longhand reuse: restored')
					break
				}
			}
			if computed_longhand_color_reported { break }
		}
	}
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
		// A hash hint is not an eligibility or equality proof. A caller can
		// mutate a DOM bridge directly without bumping its graph epoch. Exact
		// restore guards reject that entry; do not publish an untyped snapshot.
		if value.css_value_handle == unsafe { nil } { return }
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
