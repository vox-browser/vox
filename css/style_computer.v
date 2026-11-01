module css

import dom
import math
import platform

// Faithful translation of Ladybird's CSS/StyleComputer.cpp and the generated property metadata used
// by its cascade.

// Generated from Properties.json's `logical-alias-for` entries.
fn property_is_logical_alias(property_id PropertyID) bool {
	return property_id in [
		.block_size,
		.contain_intrinsic_block_size,
		.contain_intrinsic_inline_size,
		.border_block_end_color,
		.border_block_end_style,
		.border_block_end_width,
		.border_block_start_color,
		.border_block_start_style,
		.border_block_start_width,
		.border_end_end_radius,
		.border_end_start_radius,
		.border_inline_end_color,
		.border_inline_end_style,
		.border_inline_end_width,
		.border_inline_start_color,
		.border_inline_start_style,
		.border_inline_start_width,
		.border_start_end_radius,
		.border_start_start_radius,
		.corner_end_end_shape,
		.corner_end_start_shape,
		.corner_start_end_shape,
		.corner_start_start_shape,
		.inline_size,
		.inset_block_end,
		.inset_block_start,
		.inset_inline_end,
		.inset_inline_start,
		.margin_block_end,
		.margin_block_start,
		.margin_inline_end,
		.margin_inline_start,
		.scroll_margin_block_end,
		.scroll_margin_block_start,
		.scroll_margin_inline_end,
		.scroll_margin_inline_start,
		.scroll_padding_block_end,
		.scroll_padding_block_start,
		.scroll_padding_inline_end,
		.scroll_padding_inline_start,
		.max_block_size,
		.max_inline_size,
		.min_block_size,
		.min_inline_size,
		.overflow_block,
		.overflow_clip_margin_block_end,
		.overflow_clip_margin_block_start,
		.overflow_clip_margin_inline_end,
		.overflow_clip_margin_inline_start,
		.overflow_inline,
		.padding_block_end,
		.padding_block_start,
		.padding_inline_end,
		.padding_inline_start,
	]
}

enum LogicalPropertyGroup {
	border_color
	border_radius
	border_style
	border_width
	contain_intrinsic_size
	corner_shape
	inset
	margin
	scroll_margin
	scroll_padding
	max_size
	min_size
	overflow
	overflow_clip_margin
	padding
	size
}

// Generated from LogicalPropertyGroups.json and Properties.json's
// `logical-alias-for` entries. Physical and logical declarations in the same
// group can map to the same used property, so CSSOM mutation has to preserve
// their relative order.
fn logical_property_group_for_property(property_id PropertyID) ?LogicalPropertyGroup {
	return match property_id {
		.border_top_color, .border_right_color, .border_bottom_color, .border_left_color, .border_block_start_color, .border_block_end_color, .border_inline_start_color, .border_inline_end_color {
			LogicalPropertyGroup.border_color
		}
		.border_top_left_radius, .border_top_right_radius, .border_bottom_right_radius, .border_bottom_left_radius, .border_start_start_radius, .border_start_end_radius, .border_end_start_radius, .border_end_end_radius {
			LogicalPropertyGroup.border_radius
		}
		.border_top_style, .border_right_style, .border_bottom_style, .border_left_style, .border_block_start_style, .border_block_end_style, .border_inline_start_style, .border_inline_end_style {
			LogicalPropertyGroup.border_style
		}
		.border_top_width, .border_right_width, .border_bottom_width, .border_left_width, .border_block_start_width, .border_block_end_width, .border_inline_start_width, .border_inline_end_width {
			LogicalPropertyGroup.border_width
		}
		.corner_top_left_shape, .corner_top_right_shape, .corner_bottom_right_shape, .corner_bottom_left_shape, .corner_start_start_shape, .corner_start_end_shape, .corner_end_start_shape, .corner_end_end_shape {
			LogicalPropertyGroup.corner_shape
		}
		.contain_intrinsic_width, .contain_intrinsic_height, .contain_intrinsic_block_size, .contain_intrinsic_inline_size {
			LogicalPropertyGroup.contain_intrinsic_size
		}
		.top, .right, .bottom, .left, .inset_block_start, .inset_block_end, .inset_inline_start, .inset_inline_end {
			LogicalPropertyGroup.inset
		}
		.margin_top, .margin_right, .margin_bottom, .margin_left, .margin_block_start, .margin_block_end, .margin_inline_start, .margin_inline_end {
			LogicalPropertyGroup.margin
		}
		.scroll_margin_top, .scroll_margin_right, .scroll_margin_bottom, .scroll_margin_left, .scroll_margin_block_start, .scroll_margin_block_end, .scroll_margin_inline_start, .scroll_margin_inline_end {
			LogicalPropertyGroup.scroll_margin
		}
		.scroll_padding_top, .scroll_padding_right, .scroll_padding_bottom, .scroll_padding_left, .scroll_padding_block_start, .scroll_padding_block_end, .scroll_padding_inline_start, .scroll_padding_inline_end {
			LogicalPropertyGroup.scroll_padding
		}
		.max_width, .max_height, .max_block_size, .max_inline_size {
			LogicalPropertyGroup.max_size
		}
		.min_width, .min_height, .min_block_size, .min_inline_size {
			LogicalPropertyGroup.min_size
		}
		.overflow_x, .overflow_y, .overflow_block, .overflow_inline {
			LogicalPropertyGroup.overflow
		}
		.overflow_clip_margin_top, .overflow_clip_margin_right, .overflow_clip_margin_bottom, .overflow_clip_margin_left, .overflow_clip_margin_block_start, .overflow_clip_margin_block_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_inline_end {
			LogicalPropertyGroup.overflow_clip_margin
		}
		.padding_top, .padding_right, .padding_bottom, .padding_left, .padding_block_start, .padding_block_end, .padding_inline_start, .padding_inline_end {
			LogicalPropertyGroup.padding
		}
		.width, .height, .block_size, .inline_size {
			LogicalPropertyGroup.size
		}
		else {
			none
		}
	}
}

enum LogicalEdge {
	block_start
	block_end
	inline_start
	inline_end
}

enum PhysicalEdge {
	top
	right
	bottom
	left
}

enum PhysicalCorner {
	top_left
	top_right
	bottom_left
	bottom_right
}

// https://drafts.csswg.org/css-writing-modes-4/#logical-to-physical
fn physical_edge_for_logical_edge(edge LogicalEdge, context LogicalAliasMappingContext) PhysicalEdge {
	return match edge {
		.block_start {
			match context.writing_mode {
				.horizontal_tb { .top }
				.vertical_rl, .sideways_rl { .right }
				.vertical_lr, .sideways_lr { .left }
			}
		}
		.block_end {
			match context.writing_mode {
				.horizontal_tb { .bottom }
				.vertical_rl, .sideways_rl { .left }
				.vertical_lr, .sideways_lr { .right }
			}
		}
		.inline_start {
			match context.writing_mode {
				.horizontal_tb {
					if context.direction == .ltr {
						PhysicalEdge.left
					} else {
						PhysicalEdge.right
					}
				}
				.vertical_rl, .sideways_rl, .vertical_lr {
					if context.direction == .ltr {
						PhysicalEdge.top
					} else {
						PhysicalEdge.bottom
					}
				}
				.sideways_lr {
					if context.direction == .ltr {
						PhysicalEdge.bottom
					} else {
						PhysicalEdge.top
					}
				}
			}
		}
		.inline_end {
			match context.writing_mode {
				.horizontal_tb {
					if context.direction == .ltr {
						PhysicalEdge.right
					} else {
						PhysicalEdge.left
					}
				}
				.vertical_rl, .sideways_rl, .vertical_lr {
					if context.direction == .ltr {
						PhysicalEdge.bottom
					} else {
						PhysicalEdge.top
					}
				}
				.sideways_lr {
					if context.direction == .ltr {
						PhysicalEdge.top
					} else {
						PhysicalEdge.bottom
					}
				}
			}
		}
	}
}

fn physical_corner_for_logical_edges(block_edge LogicalEdge, inline_edge LogicalEdge, context LogicalAliasMappingContext) PhysicalCorner {
	first := physical_edge_for_logical_edge(block_edge, context)
	second := physical_edge_for_logical_edge(inline_edge, context)
	if (first == .top && second == .left) || (first == .left && second == .top) {
		return .top_left
	}
	if (first == .top && second == .right) || (first == .right && second == .top) {
		return .top_right
	}
	if (first == .bottom && second == .left) || (first == .left && second == .bottom) {
		return .bottom_left
	}
	return .bottom_right
}

fn map_border_color(edge PhysicalEdge) PropertyID {
	return match edge {
		.top { .border_top_color }
		.right { .border_right_color }
		.bottom { .border_bottom_color }
		.left { .border_left_color }
	}
}

fn map_border_style(edge PhysicalEdge) PropertyID {
	return match edge {
		.top { .border_top_style }
		.right { .border_right_style }
		.bottom { .border_bottom_style }
		.left { .border_left_style }
	}
}

fn map_border_width(edge PhysicalEdge) PropertyID {
	return match edge {
		.top { .border_top_width }
		.right { .border_right_width }
		.bottom { .border_bottom_width }
		.left { .border_left_width }
	}
}

fn map_inset(edge PhysicalEdge) PropertyID {
	return match edge {
		.top { .top }
		.right { .right }
		.bottom { .bottom }
		.left { .left }
	}
}

fn map_margin(edge PhysicalEdge) PropertyID {
	return match edge {
		.top { .margin_top }
		.right { .margin_right }
		.bottom { .margin_bottom }
		.left { .margin_left }
	}
}

fn map_scroll_margin(edge PhysicalEdge) PropertyID {
	return match edge {
		.top { .scroll_margin_top }
		.right { .scroll_margin_right }
		.bottom { .scroll_margin_bottom }
		.left { .scroll_margin_left }
	}
}

fn map_scroll_padding(edge PhysicalEdge) PropertyID {
	return match edge {
		.top { .scroll_padding_top }
		.right { .scroll_padding_right }
		.bottom { .scroll_padding_bottom }
		.left { .scroll_padding_left }
	}
}

fn map_padding(edge PhysicalEdge) PropertyID {
	return match edge {
		.top { .padding_top }
		.right { .padding_right }
		.bottom { .padding_bottom }
		.left { .padding_left }
	}
}

fn map_overflow_clip_margin(edge PhysicalEdge) PropertyID {
	return match edge {
		.top { .overflow_clip_margin_top }
		.right { .overflow_clip_margin_right }
		.bottom { .overflow_clip_margin_bottom }
		.left { .overflow_clip_margin_left }
	}
}

fn map_border_radius(corner PhysicalCorner) PropertyID {
	return match corner {
		.top_left { .border_top_left_radius }
		.top_right { .border_top_right_radius }
		.bottom_left { .border_bottom_left_radius }
		.bottom_right { .border_bottom_right_radius }
	}
}

fn map_corner_shape(corner PhysicalCorner) PropertyID {
	return match corner {
		.top_left { .corner_top_left_shape }
		.top_right { .corner_top_right_shape }
		.bottom_left { .corner_bottom_left_shape }
		.bottom_right { .corner_bottom_right_shape }
	}
}

// Generated from Properties.json and LogicalPropertyGroups.json.
fn map_logical_alias_to_physical_property(property_id PropertyID, context LogicalAliasMappingContext) PropertyID {
	return match property_id {
		.block_size {
			if context.writing_mode == .horizontal_tb {
				PropertyID.height
			} else {
				PropertyID.width
			}
		}
		.contain_intrinsic_block_size {
			if context.writing_mode == .horizontal_tb {
				PropertyID.contain_intrinsic_height
			} else {
				PropertyID.contain_intrinsic_width
			}
		}
		.contain_intrinsic_inline_size {
			if context.writing_mode == .horizontal_tb {
				PropertyID.contain_intrinsic_width
			} else {
				PropertyID.contain_intrinsic_height
			}
		}
		.inline_size {
			if context.writing_mode == .horizontal_tb {
				PropertyID.width
			} else {
				PropertyID.height
			}
		}
		.max_block_size {
			if context.writing_mode == .horizontal_tb {
				PropertyID.max_height
			} else {
				PropertyID.max_width
			}
		}
		.max_inline_size {
			if context.writing_mode == .horizontal_tb {
				PropertyID.max_width
			} else {
				PropertyID.max_height
			}
		}
		.min_block_size {
			if context.writing_mode == .horizontal_tb {
				PropertyID.min_height
			} else {
				PropertyID.min_width
			}
		}
		.min_inline_size {
			if context.writing_mode == .horizontal_tb {
				PropertyID.min_width
			} else {
				PropertyID.min_height
			}
		}
		.overflow_block {
			if context.writing_mode == .horizontal_tb {
				PropertyID.overflow_y
			} else {
				PropertyID.overflow_x
			}
		}
		.overflow_inline {
			if context.writing_mode == .horizontal_tb {
				PropertyID.overflow_x
			} else {
				PropertyID.overflow_y
			}
		}
		.border_block_start_color {
			map_border_color(physical_edge_for_logical_edge(.block_start, context))
		}
		.border_block_end_color {
			map_border_color(physical_edge_for_logical_edge(.block_end, context))
		}
		.border_inline_start_color {
			map_border_color(physical_edge_for_logical_edge(.inline_start, context))
		}
		.border_inline_end_color {
			map_border_color(physical_edge_for_logical_edge(.inline_end, context))
		}
		.border_block_start_style {
			map_border_style(physical_edge_for_logical_edge(.block_start, context))
		}
		.border_block_end_style {
			map_border_style(physical_edge_for_logical_edge(.block_end, context))
		}
		.border_inline_start_style {
			map_border_style(physical_edge_for_logical_edge(.inline_start, context))
		}
		.border_inline_end_style {
			map_border_style(physical_edge_for_logical_edge(.inline_end, context))
		}
		.border_block_start_width {
			map_border_width(physical_edge_for_logical_edge(.block_start, context))
		}
		.border_block_end_width {
			map_border_width(physical_edge_for_logical_edge(.block_end, context))
		}
		.border_inline_start_width {
			map_border_width(physical_edge_for_logical_edge(.inline_start, context))
		}
		.border_inline_end_width {
			map_border_width(physical_edge_for_logical_edge(.inline_end, context))
		}
		.inset_block_start {
			map_inset(physical_edge_for_logical_edge(.block_start, context))
		}
		.inset_block_end {
			map_inset(physical_edge_for_logical_edge(.block_end, context))
		}
		.inset_inline_start {
			map_inset(physical_edge_for_logical_edge(.inline_start, context))
		}
		.inset_inline_end {
			map_inset(physical_edge_for_logical_edge(.inline_end, context))
		}
		.margin_block_start {
			map_margin(physical_edge_for_logical_edge(.block_start, context))
		}
		.margin_block_end {
			map_margin(physical_edge_for_logical_edge(.block_end, context))
		}
		.margin_inline_start {
			map_margin(physical_edge_for_logical_edge(.inline_start, context))
		}
		.margin_inline_end {
			map_margin(physical_edge_for_logical_edge(.inline_end, context))
		}
		.scroll_margin_block_start {
			map_scroll_margin(physical_edge_for_logical_edge(.block_start, context))
		}
		.scroll_margin_block_end {
			map_scroll_margin(physical_edge_for_logical_edge(.block_end, context))
		}
		.scroll_margin_inline_start {
			map_scroll_margin(physical_edge_for_logical_edge(.inline_start, context))
		}
		.scroll_margin_inline_end {
			map_scroll_margin(physical_edge_for_logical_edge(.inline_end, context))
		}
		.scroll_padding_block_start {
			map_scroll_padding(physical_edge_for_logical_edge(.block_start, context))
		}
		.scroll_padding_block_end {
			map_scroll_padding(physical_edge_for_logical_edge(.block_end, context))
		}
		.scroll_padding_inline_start {
			map_scroll_padding(physical_edge_for_logical_edge(.inline_start, context))
		}
		.scroll_padding_inline_end {
			map_scroll_padding(physical_edge_for_logical_edge(.inline_end, context))
		}
		.padding_block_start {
			map_padding(physical_edge_for_logical_edge(.block_start, context))
		}
		.padding_block_end {
			map_padding(physical_edge_for_logical_edge(.block_end, context))
		}
		.padding_inline_start {
			map_padding(physical_edge_for_logical_edge(.inline_start, context))
		}
		.padding_inline_end {
			map_padding(physical_edge_for_logical_edge(.inline_end, context))
		}
		.overflow_clip_margin_block_start {
			map_overflow_clip_margin(physical_edge_for_logical_edge(.block_start, context))
		}
		.overflow_clip_margin_block_end {
			map_overflow_clip_margin(physical_edge_for_logical_edge(.block_end, context))
		}
		.overflow_clip_margin_inline_start {
			map_overflow_clip_margin(physical_edge_for_logical_edge(.inline_start, context))
		}
		.overflow_clip_margin_inline_end {
			map_overflow_clip_margin(physical_edge_for_logical_edge(.inline_end, context))
		}
		.border_start_start_radius {
			map_border_radius(physical_corner_for_logical_edges(.block_start, .inline_start, context))
		}
		.border_start_end_radius {
			map_border_radius(physical_corner_for_logical_edges(.block_start, .inline_end, context))
		}
		.border_end_start_radius {
			map_border_radius(physical_corner_for_logical_edges(.block_end, .inline_start, context))
		}
		.border_end_end_radius {
			map_border_radius(physical_corner_for_logical_edges(.block_end, .inline_end, context))
		}
		.corner_start_start_shape {
			map_corner_shape(physical_corner_for_logical_edges(.block_start, .inline_start, context))
		}
		.corner_start_end_shape {
			map_corner_shape(physical_corner_for_logical_edges(.block_start, .inline_end, context))
		}
		.corner_end_start_shape {
			map_corner_shape(physical_corner_for_logical_edges(.block_end, .inline_start, context))
		}
		.corner_end_end_shape {
			map_corner_shape(physical_corner_for_logical_edges(.block_end, .inline_end, context))
		}
		else {
			property_id
		}
	}
}

fn is_pseudo_font_property(name string) bool {
	return name in ['font', 'font-family', 'font-feature-settings', 'font-language-override',
		'font-size', 'font-style', 'font-variant', 'font-variant-alternates', 'font-variant-caps',
		'font-variant-east-asian', 'font-variant-emoji', 'font-variant-ligatures',
		'font-variant-numeric', 'font-variant-position', 'font-variation-settings', 'font-weight',
		'font-width']
}

fn is_pseudo_background_property(name string) bool {
	return name in ['background', 'background-attachment', 'background-clip', 'background-color',
		'background-image', 'background-origin', 'background-position', 'background-position-x',
		'background-position-y', 'background-repeat', 'background-size']
}

fn is_pseudo_inline_typesetting_property(name string) bool {
	return name in ['letter-spacing', 'overflow-wrap', 'tab-size', 'text-align', 'text-indent',
		'text-justify', 'text-transform', 'text-wrap', 'text-wrap-mode', 'text-wrap-style',
		'white-space', 'white-space-collapse', 'white-space-trim', 'word-break', 'word-spacing']
}

fn is_pseudo_text_decoration_property(name string) bool {
	return name in ['text-decoration', 'text-decoration-color', 'text-decoration-line',
		'text-decoration-skip-ink', 'text-decoration-style', 'text-decoration-thickness']
}

fn is_pseudo_inline_layout_property(name string) bool {
	return name in ['line-height', 'vertical-align']
}

fn is_pseudo_margin_property(name string) bool {
	return name in ['margin', 'margin-block', 'margin-block-end', 'margin-block-start',
		'margin-bottom', 'margin-inline', 'margin-inline-end', 'margin-inline-start', 'margin-left',
		'margin-right', 'margin-top']
}

fn is_pseudo_padding_property(name string) bool {
	return name in ['padding', 'padding-block', 'padding-block-end', 'padding-block-start',
		'padding-bottom', 'padding-inline', 'padding-inline-end', 'padding-inline-start',
		'padding-left', 'padding-right', 'padding-top']
}

fn is_pseudo_border_property(name string) bool {
	return name in ['border', 'border-block-end', 'border-block-end-color', 'border-block-end-style',
		'border-block-end-width', 'border-block-start', 'border-block-start-color',
		'border-block-start-style', 'border-block-start-width', 'border-bottom', 'border-bottom-color',
		'border-bottom-left-radius', 'border-bottom-right-radius', 'border-bottom-style',
		'border-bottom-width', 'border-color', 'border-image-outset', 'border-image-repeat',
		'border-image-slice', 'border-image-source', 'border-image-width', 'border-inline-end',
		'border-inline-end-color', 'border-inline-end-style', 'border-inline-end-width',
		'border-inline-start', 'border-inline-start-color', 'border-inline-start-style',
		'border-inline-start-width', 'border-left', 'border-left-color', 'border-left-style',
		'border-left-width', 'border-radius', 'border-right', 'border-right-color',
		'border-right-style', 'border-right-width', 'border-style', 'border-top', 'border-top-color',
		'border-top-left-radius', 'border-top-right-radius', 'border-top-style', 'border-top-width',
		'border-width']
}

fn pseudo_element_supports_common_text_properties(name string, include_inline_layout bool) bool {
	return is_pseudo_font_property(name) || name in ['color', 'opacity'] || is_pseudo_background_property(name) || is_pseudo_inline_typesetting_property(name) || is_pseudo_text_decoration_property(name) || (include_inline_layout && is_pseudo_inline_layout_property(name))
}

// Generated from PseudoElements.json. The DOM-side enum currently exposes the pseudo-elements that
// participate in style computation; pseudo-elements without a whitelist accept every property.
fn pseudo_element_supports_property(pseudo_element dom.PseudoElement, property_id PropertyID) bool {
	name := string_from_property_id(property_id)
	return match pseudo_element {
		.first_line {
			pseudo_element_supports_common_text_properties(name, true)
		}
		.placeholder {
			pseudo_element_supports_common_text_properties(name, false)
		}
		.first_letter {
			pseudo_element_supports_common_text_properties(name, true) || is_pseudo_margin_property(name) || is_pseudo_padding_property(name) || is_pseudo_border_property(name) || name in ['box-shadow', 'float']
		}
		.selection {
			name in ['color', 'background-color', 'text-shadow', 'stroke-width'] || is_pseudo_text_decoration_property(name)
		}
		else {
			true
		}
	}
}

// The typed declaration properties of `declaration`, mirroring Ladybird's
// CSSStyleProperties::properties() (Vector<StyleProperty>). The port stores each declaration entry as
// a serialized CSSStyleProperty{name, value, important, style_value?}; this re-types it into the
// StyleProperty{property_id, value: &dom.StyleValue, important} the cascade iterates over — using the
// already-parsed opaque `style_value` when present, else parsing the serialized text. Custom
// properties (`--*`, kept separately in `custom_properties`) are not included; entries whose name
// isn't a known property, or whose value fails to parse, are skipped.
fn declaration_style_properties(declaration &CSSStyleProperties) []StyleProperty {
	if cached := declaration.typed_properties_cache_ {
		return unsafe { cached }
	}
	persistent := platform.enter_persistent_if(declaration.has_process_lifetime_sheet())
	defer { platform.leave_persistent(persistent) }
	mut result := []StyleProperty{cap: declaration.properties.len}
	mut importance_mask := u8(0)
	mut may_have_logical_aliases := false
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
			value: value
			important: if property.important { Important.yes } else { Important.no }
		}
		importance_mask |= if property.important { u8(2) } else { u8(1) }
		// Unexpanded shorthands are conservative: substitution can produce logical longhands.
		may_have_logical_aliases = may_have_logical_aliases
			|| property_is_logical_alias(property_id) || property_is_shorthand(property_id)
	}
	mut mutable_declaration := unsafe { &CSSStyleProperties(declaration) }
	mutable_declaration.typed_properties_cache_ = result
	mutable_declaration.typed_importance_mask_ = importance_mask
	mutable_declaration.typed_may_have_logical_aliases_ = may_have_logical_aliases
	return result
}

// One expanded longhand from a shorthand expansion: its property id and (opaque) value.
struct ExpandedLonghand {
	id    PropertyID
	value &dom.StyleValue = unsafe { nil }
}

struct ExpandedLonghandCollection {
	base_url ?string
mut:
	longhands []ExpandedLonghand
}

fn collect_expanded_longhand(context voidptr, property_id PropertyID, value &dom.StyleValue) {
	mut collection := unsafe { &ExpandedLonghandCollection(context) }
	mut value_with_base := unsafe { &dom.StyleValue(value) }
	if value_with_base.base_url == none {
		value_with_base.base_url = collection.base_url
	}
	unsafe {
		collection.longhands << ExpandedLonghand{id: property_id, value: value}
	}
}

// Collect expanded values without creating an independently stored executable callback.
fn expand_property_longhands(property_id PropertyID, value &dom.StyleValue) []ExpandedLonghand {
	mut collection := ExpandedLonghandCollection{base_url: value.base_url}
	StyleComputer.for_each_property_expanding_shorthands_with_context(property_id, value, voidptr(&collection), collect_expanded_longhand)
	return collection.longhands
}

// Whether the opaque cascaded `value` for `property_id` is the CSS-wide `revert`/`revert-layer`
// keyword. The port's dom.StyleValue only carries serialized text, so re-type it to test the typed
// StyleValue predicate.
fn opaque_is_revert(property_id PropertyID, value &dom.StyleValue) bool {
	typed := style_value_logic_from_dom(property_id, value) or { return false }
	return typed.is_revert()
}

fn opaque_is_revert_layer(property_id PropertyID, value &dom.StyleValue) bool {
	typed := style_value_logic_from_dom(property_id, value) or { return false }
	return typed.is_revert_layer()
}

fn resolve_cascade_declaration_value(abstract_element dom.AbstractElement, property_id PropertyID, value &dom.StyleValue) &dom.StyleValue {
	typed := style_value_logic_from_dom(property_id, value) or { return unsafe { value } }
	if typed is UnresolvedStyleValue {
		mut resolved := resolve_unresolved_style_value_for_property(abstract_element, property_id, typed)
		resolved.base_url = value.base_url
		if opaque_is_guaranteed_invalid(resolved) {
			return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.unset)))
		}
		return resolved
	}
	if typed is GuaranteedInvalidStyleValue {
		return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.unset)))
	}
	return unsafe { value }
}

fn opaque_is_guaranteed_invalid(value &dom.StyleValue) bool {
	typed := typed_style_value_logic_from_dom(value) or { return false }
	return typed is GuaranteedInvalidStyleValue
}

fn opaque_is_unresolved(value &dom.StyleValue) bool {
	typed := typed_style_value_logic_from_dom(value) or { return false }
	return typed is UnresolvedStyleValue
}

fn opaque_is_pending_substitution(value &dom.StyleValue) bool {
	typed := typed_style_value_logic_from_dom(value) or { return false }
	return typed is PendingSubstitutionStyleValue
}

// Apply an arbitrary property list to `cascaded_properties`. For each property
// (of the requested importance / supported by the pseudo-element / in
// `properties_to_cascade` when non-empty), expand shorthands and, per longhand,
// map a logical alias to its physical property and either revert it or set it
// in the cascade. Keeping this independent of CSSStyleProperties lets HTML,
// SVG, and MathML presentational hints use the same cascade pipeline.
// Unresolved var()/env() values are resolved before shorthand expansion by
// resolve_cascade_declaration_value(), including invalid-at-computed-value-time fallback.
fn apply_property_list_to_cascade(mut cascaded_properties CascadedProperties, abstract_element dom.AbstractElement, properties []StyleProperty, cascade_origin CascadeOrigin, important Important, layer_name ?string, source voidptr, source_shadow_root ?&dom.ShadowRoot, logical_alias_mapping_context ?LogicalAliasMappingContext, properties_to_cascade []PropertyID) {
	pseudo_element := abstract_element.pseudo_element()
	// CSSStyleProperties retains an unresolved shorthand and pending-substitution
	// placeholders for its longhands. Once the shorthand has resolved and set a
	// longhand, a later placeholder must not overwrite that real value.
	mut seen_properties := [int(PropertyID.mask) + 1]u8{}
	for property in properties {
		// OPTIMIZATION: only cascade the requested properties, when a set was given.
		if properties_to_cascade.len > 0 && property.property_id !in properties_to_cascade && !property_is_shorthand(property.property_id) {
			continue
		}
		if important != property.important {
			continue
		}
		if pe := pseudo_element {
			// An unresolved shorthand must survive this first filter so var()/env()
			// can be substituted and the resulting longhands can be checked below.
			if !pseudo_element_supports_property(pe, property.property_id)
				&& !opaque_is_unresolved(property.value) {
				continue
			}
		}
		// Pending-substitution longhands are placeholders for an unresolved
		// shorthand. The resolved shorthand itself supplies their real values.
		if opaque_is_pending_substitution(property.value) {
			continue
		}
		resolved_property_value := resolve_cascade_declaration_value(abstract_element, property.property_id, property.value)
		if computed_interpolation_is_longhand_property(property.property_id) {
			longhand_id := property.property_id
			if pe := pseudo_element {
				if !pseudo_element_supports_property(pe, longhand_id) {
					continue
				}
			}
			if seen_properties[int(longhand_id)] != 0
				&& opaque_is_pending_substitution(resolved_property_value) {
				continue
			}
			seen_properties[int(longhand_id)] = 1
			mut physical_property_id := longhand_id
			if property_is_logical_alias(longhand_id) {
				context := logical_alias_mapping_context or { continue }
				physical_property_id = map_logical_alias_to_physical_property(longhand_id, context)
			}

			if opaque_is_revert(longhand_id, resolved_property_value) {
				cascaded_properties.revert_property(physical_property_id, important, cascade_origin)
			} else if opaque_is_revert_layer(longhand_id, resolved_property_value) {
				cascaded_properties.revert_layer_property(physical_property_id, important, layer_name)
			} else {
				cascaded_properties.set_property(physical_property_id, resolved_property_value, important, cascade_origin, layer_name, source, source_shadow_root)
			}
			continue
		}
		for longhand in expand_property_longhands(property.property_id, resolved_property_value) {
			if pe := pseudo_element {
				if !pseudo_element_supports_property(pe, longhand.id) {
					continue
				}
			}
			if properties_to_cascade.len > 0 && longhand.id !in properties_to_cascade {
				continue
			}
			if seen_properties[int(longhand.id)] != 0
				&& opaque_is_pending_substitution(resolved_property_value) {
				continue
			}
			seen_properties[int(longhand.id)] = 1
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
				cascaded_properties.set_property(physical_property_id, longhand.value, important, cascade_origin, layer_name, source, source_shadow_root)
			}
		}
	}
}

fn cascade_one_declaration(mut cascaded_properties CascadedProperties, abstract_element dom.AbstractElement, declaration &CSSStyleProperties, source_shadow_root ?&dom.ShadowRoot, cascade_origin CascadeOrigin, important Important, layer_name ?string, logical_alias_mapping_context ?LogicalAliasMappingContext, properties_to_cascade []PropertyID) {
	properties := declaration_style_properties(declaration)
	importance_bit := if important == .yes { u8(2) } else { u8(1) }
	if declaration.typed_importance_mask_ & importance_bit == 0 {
		return
	}
	apply_property_list_to_cascade(mut cascaded_properties, abstract_element, properties, cascade_origin, important, layer_name, voidptr(declaration), source_shadow_root, logical_alias_mapping_context, properties_to_cascade)
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

// The `normalize_value` lambda of StyleComputer::compute_logical_alias_mapping_context.
fn logical_alias_normalize_value(abstract_element dom.AbstractElement, property_id PropertyID, value ?&dom.StyleValue) &dom.StyleValue {
	initial := computed_interpolation_property_initial_value(property_id)
	if current := value {
		if computed_interpolation_style_value_is_inherit(current) || computed_interpolation_style_value_is_unset(current) {
			if parent := parent_computed_properties(abstract_element) {
				return parent.property(property_id, .yes) or { initial }
			}
			return initial
		}
		if computed_interpolation_style_value_is_initial(current) {
			return initial
		}
		return current
	}
	if parent := parent_computed_properties(abstract_element) {
		return parent.property(property_id, .yes) or { initial }
	}
	return initial
}

// The compute-and-store core of DOM::Element::recompute_style (Element.cpp:855): compute the element's
// style and store it (bridged) on the element, so descendants inherit through it and layout can read the
// mirrored fields off the module-cycle boundary object. This is its CSS half,
// driven top-down over the tree (parents before children); invalidation diffing,
// display-change animation replay, and generated pseudo styles all run here.
pub fn (s &StyleComputer) recompute_style(mut abstract_element dom.AbstractElement) &ComputedProperties {
	mut did_change_custom_properties := false
	_, computed := s.recompute_style_with_invalidation(mut abstract_element, &did_change_custom_properties)
	return computed
}

fn counter_style_dependencies_equal(left []?CounterStyle, right []?CounterStyle) bool {
	if left.len != right.len {
		return false
	}
	for index, left_dependency in left {
		left_style := left_dependency or {
			if _ := right[index] {
				return false
			}
			continue
		}
		right_style := right[index] or { return false }
		if !left_style.equals(right_style) {
			return false
		}
	}
	return true
}

fn counter_style_options_equal(left ?CounterStyle, right ?CounterStyle) bool {
	left_style := left or {
		if _ := right {
			return false
		}
		return true
	}
	right_style := right or { return false }
	return left_style.equals(right_style)
}

pub fn compute_required_invalidation(old_style &ComputedProperties, new_style &ComputedProperties, font_computer &FontComputer, old_layout_node ?&dom.LayoutNodeWithStyle_, abstract_element dom.AbstractElement) RequiredInvalidationAfterStyleChange {
 diagnostic_scope_start := begin_diagnostic_instruction_scope()
 defer { record_diagnostic_instruction_scope(11, diagnostic_scope_start) }

	mut invalidation := RequiredInvalidationAfterStyleChange{}
	mut mutable_old_style := unsafe { &ComputedProperties(old_style) }
	mut mutable_new_style := unsafe { &ComputedProperties(new_style) }
	// A pending cascade cannot be compared by value upstream. Preserve its
	// identity across unrelated style updates while its font inputs and owning
	// font environment remain unchanged; loading/display transitions advance
	// that environment and must continue to invalidate geometry.
	reused_font_cache := mutable_new_style.reuse_unchanged_font_cache(old_style, font_computer)
	old_font_list := mutable_old_style.computed_font_list(font_computer)
	new_font_list := mutable_new_style.computed_font_list(font_computer)
	if !reused_font_cache && !old_font_list.equals(new_font_list) {
		invalidation.ensure_at_least(.relayout)
	}
	invalidation = required_invalidation_after_style_change_or(invalidation,
		compute_raw_property_invalidation(old_style, new_style))
	// A counter style is resolved from the element's current style scope. Its effective
	// definition can therefore change while the computed property text remains identical.
	// Generated pseudo-elements do not expose an independently addressable layout-node
	// handle through the V bridge, but their ComputedValues retain the dependency snapshot
	// captured while building generated content. Compare it independently of that handle,
	// matching ElementDependentInvalidationState upstream.
	if old_content := unsafe { &ComputedValues(old_style) }.computed_content() {
		// Literal generated text has no counter definitions to recheck. A
		// changed content property already carries its raw-property invalidation.
		if old_content.counter_style_dependencies.len > 0 {
			registered_counter_styles := registered_counter_styles_for_abstract_element(abstract_element)
			new_content := new_style.content(&abstract_element, 0, registered_counter_styles).content_data
			if !counter_style_dependencies_equal(old_content.counter_style_dependencies, new_content.counter_style_dependencies) {
				invalidation.ensure_at_least(.rebuild_layout_tree)
			}
		}
	}
	if _ := old_layout_node {
		old_list_style_type := unsafe { &ComputedValues(old_style) }.computed_list_style_type()
		if old_list_style_type.kind == .counter_style {
			new_list_style_type := new_style.list_style_type_for_scope(css_style_scope_for(abstract_element))
			if new_list_style_type.kind == .counter_style
				&& !counter_style_options_equal(old_list_style_type.counter_style, new_list_style_type.counter_style) {
				invalidation.ensure_at_least(.rebuild_layout_tree)
			}
		}
	}
	return invalidation
}

// DOM::Element::recompute_style(). It computes and installs main and pseudo
// styles, diffs every longhand through CSS::compute_property_invalidation(),
// and applies retained style to an existing layout tree when no rebuild is
// required.
fn (s &StyleComputer) recompute_style_with_invalidation(mut abstract_element dom.AbstractElement, did_change_custom_properties &bool) (RequiredInvalidationAfterStyleChange, &ComputedProperties) {
	s.begin_computed_property_page_batch()
	defer { s.end_computed_property_page_batch() }
	platform.cooperative_work_checkpoint()
	mut element := unsafe { &dom.Element(abstract_element.element()) }
	element.set_pending_font_input_update(false)
	mut document := unsafe { &dom.Document(element.document()) }
	document.record_element_style_recomputation()
	element.reset_style_dependency_flags()
	mut had_list_marker := false
	mut old_style := ?&ComputedProperties(none)
	if old_dom_style := abstract_element.computed_properties() {
		old_style = computed_properties_from_dom(old_dom_style)
	}
	if previous := old_style {
		had_list_marker = previous.display().is_list_item()
	}
	old_non_animated_display_is_none := if previous := old_style {
		computed_display_is_none_ignoring_animations(previous)
	} else {
		true
	}
	computed := s.compute_style_tracking_custom_property_changes(abstract_element, did_change_custom_properties)
	mut invalidation := if previous := old_style {
		compute_required_invalidation(previous, computed, s.font_computer(), abstract_element.unsafe_layout_node(), abstract_element)
	} else {
		required_invalidation_after_style_change_full()
	}
	element_style_changed := !invalidation.is_none()
	element_custom_properties_changed := unsafe { *did_change_custom_properties }
	abstract_element.set_computed_properties(computed_properties_to_dom(computed))
	new_non_animated_display_is_none := computed_display_is_none_ignoring_animations(computed)
	if old_non_animated_display_is_none != new_non_animated_display_is_none {
		element.as_node().for_each_shadow_including_inclusive_descendant(fn (node &dom.Node) dom.TraversalDecision {
			if node.is_element() {
				mut descendant := unsafe { &dom.Element(node) }
				descendant.play_or_cancel_animations_after_display_property_change()
			}
			return .@continue
		})
	}

	pseudo_elements := [dom.PseudoElement.before, .after, .selection, .first_letter,
		.backdrop, .marker]!
	process_backdrop := element.rendered_in_top_layer()
	process_marker := had_list_marker || computed.display().is_list_item()
	mut mutable_computer := unsafe { &StyleComputer(s) }
	for pseudo_element in pseudo_elements {
		if (pseudo_element == .backdrop && !process_backdrop)
			|| (pseudo_element == .marker && !process_marker) { continue }
		pseudo_abstract := dom.AbstractElement.new(abstract_element.element(), pseudo_element)
		mut old_pseudo_style := ?&ComputedProperties(none)
		if old_dom_pseudo_style := pseudo_abstract.computed_properties() {
			old_pseudo_style = computed_properties_from_dom(old_dom_pseudo_style)
		}
		css_pseudo_element := style_scope_pseudo_element_from_abstract_element(pseudo_abstract) or {
			continue
		}
		scope := css_style_scope_for(pseudo_abstract)
		mut new_pseudo_style := ?&ComputedProperties(none)
		has_candidate := scope.has_candidate_rule_for_pseudo_element(pseudo_abstract, css_pseudo_element)
		if has_candidate {
			// Bucket admission does not match selectors. Only a cascade needs
			// the originating element in the ancestor filter for its pseudo.
			mutable_computer.push_ancestor(abstract_element.element())
			new_pseudo_style = s.compute_pseudo_element_style_if_needed_tracking_custom_property_changes(pseudo_abstract, did_change_custom_properties)
		}
		if pseudo_style := new_pseudo_style {
			if previous := old_pseudo_style {
				invalidation = required_invalidation_after_style_change_or(invalidation, compute_required_invalidation(previous, pseudo_style, s.font_computer(), pseudo_abstract.unsafe_layout_node(), pseudo_abstract))
			} else {
				invalidation = required_invalidation_after_style_change_full()
			}
			pseudo_abstract.set_computed_properties(computed_properties_to_dom(pseudo_style))
		} else {
			if old_pseudo_style != none {
				invalidation = required_invalidation_after_style_change_full()
			}
			pseudo_abstract.set_computed_properties(none)
		}
		if has_candidate {
			mutable_computer.pop_ancestor(abstract_element.element())
		}
	}

	if old_style != none && (element_style_changed || element_custom_properties_changed) {
		element.invalidate_descendant_styles_depending_on_style_container_query()
	}

	if !invalidation.is_none() && !invalidation.needs_layout_tree_rebuild() {
		if layout_node := abstract_element.unsafe_layout_node() {
			if dom_style := abstract_element.computed_properties() {
				layout_node.apply_style(dom_style)
			}
		}
		for pseudo_element in pseudo_elements {
			if (pseudo_element == .backdrop && !process_backdrop)
				|| (pseudo_element == .marker && !process_marker) { continue }
			pseudo_abstract := dom.AbstractElement.new(abstract_element.element(), pseudo_element)
			if layout_node := pseudo_abstract.unsafe_layout_node() {
				if dom_style := pseudo_abstract.computed_properties() {
					layout_node.apply_style(dom_style)
				}
			}
		}
	}
	if invalidation.is_none() {
		document.record_element_style_noop_recomputation()
	}
	return invalidation, computed
}

struct InheritedStyleOldValue {
	property_id PropertyID
	old_value   &dom.StyleValue
}

// DOM::Element::recompute_inherited_style(). This is the narrow inherited-style
// update used when an ancestor changed but the element itself did not need a
// fresh cascade. It updates inherited and font-relative computed values in
// place, preserving the cascaded-property and computed-style objects exactly as
// upstream does.
fn (s &StyleComputer) recompute_inherited_style_with_invalidation(mut abstract_element dom.AbstractElement) RequiredInvalidationAfterStyleChange {
	s.begin_computed_property_page_batch()
	defer { s.end_computed_property_page_batch() }
	dom_computed := abstract_element.computed_properties() or {
		return RequiredInvalidationAfterStyleChange{}
	}
	mut computed := computed_properties_from_dom(dom_computed) or {
		return RequiredInvalidationAfterStyleChange{}
	}
	defer { s.publish_computed_property_pages(computed) }
	mut document := unsafe { &dom.Document(abstract_element.element().document()) }
	document.record_element_inherited_style_recomputation()

	mut invalidation := RequiredInvalidationAfterStyleChange{}
	mut only_color_changes := true
	// This runs for every descendant of an animated element on every sample, so
	// it reads the retained maps in place instead of cloning them; an unchanged
	// element allocates nothing.
	mut values_affected_by_inherited_style := []InheritedStyleOldValue{}
	if computed.inheritance_specified_storage_ != unsafe { nil } {
		for property_id, specified_value in computed.inheritance_specified_storage_.values {
			if old_value := computed.property(property_id, .no) {
				values_affected_by_inherited_style << InheritedStyleOldValue{property_id, old_value}
			}
			computed.set_property_without_modifying_flags(property_id, specified_value)
		}
	}
	for property_id in computed.inherited_property_iterator() {
		// Compare the values the element uses, animations applied: an
		// inherited animated value can change while the base value stays.
		old_value := computed.property(property_id, .yes)

		// Each iteration changes only its own property's animated value, so the
		// live map answers what a snapshot taken before the loop would.
		was_animated := computed.has_animated_property(property_id)
		if computed.is_animated_property_inherited(property_id) || !was_animated {
			if animated_inherit := StyleComputer.get_animated_inherit_value(property_id, abstract_element) {
				computed.set_animated_property(property_id, animated_inherit.value, animated_inherit.is_result_of_transition, .yes)
			} else if was_animated {
				computed.remove_animated_property(property_id)
			}
		}

		new_value := StyleComputer.get_non_animated_inherit_value(property_id, abstract_element)
		computed.set_property(property_id, new_value, .yes, .no)
		property_invalidation := compute_property_invalidation(property_id, old_value, computed.property(property_id, .yes))
		only_color_changes = only_color_changes && (property_id == .color || property_invalidation.is_none())
		invalidation = required_invalidation_after_style_change_or(invalidation, property_invalidation)
	}

	if invalidation.is_none() && values_affected_by_inherited_style.len == 0 {
		document.record_element_inherited_style_noop_recomputation()
		return invalidation
	}

	s.compute_property_values(mut computed, *abstract_element)
	for affected in values_affected_by_inherited_style {
		property_invalidation := compute_property_invalidation(affected.property_id, affected.old_value, computed.property(affected.property_id, .no))
		only_color_changes = only_color_changes && (affected.property_id == .color || property_invalidation.is_none())
		invalidation = required_invalidation_after_style_change_or(invalidation, property_invalidation)
	}
	if !invalidation.is_none() {
		mut element := unsafe { &dom.Element(abstract_element.element()) }
		element.invalidate_descendant_styles_depending_on_style_container_query()
	}
	if invalidation.is_none() {
		document.record_element_inherited_style_noop_recomputation()
		return invalidation
	}

	// Refresh the DOM-side mirror after mutating the retained ComputedProperties
	// and apply the same object to a retained Layout::Node, if one exists.
	computed_dom_mirror := computed_properties_to_dom(computed)
	abstract_element.set_computed_properties(computed_dom_mirror)
	if layout_node := abstract_element.unsafe_layout_node() {
		if only_color_changes {
			layout_node.apply_inherited_color_style(computed_dom_mirror)
		} else {
			layout_node.apply_style(computed_dom_mirror)
		}
	}
	return invalidation
}

fn animated_property_maps_invalidation(old_values map[PropertyID]&dom.StyleValue, new_values map[PropertyID]&dom.StyleValue) RequiredInvalidationAfterStyleChange {
	mut invalidation := RequiredInvalidationAfterStyleChange{}
	// Animation maps contain only the affected properties. Visit their union
	// directly instead of probing every longhand and allocating errors on misses.
	for property_id, old_value in old_values {
		if !computed_interpolation_is_longhand_property(property_id) {
			continue
		}
		mut new_value := ?&dom.StyleValue(none)
		if property_id in new_values {
			new_value = unsafe { new_values[property_id] }
		}
		invalidation = required_invalidation_after_style_change_or(invalidation, compute_property_invalidation(property_id, old_value, new_value))
	}
	for property_id, new_value in new_values {
		if !computed_interpolation_is_longhand_property(property_id) || property_id in old_values {
			continue
		}
		invalidation = required_invalidation_after_style_change_or(invalidation, compute_property_invalidation(property_id, none, new_value))
	}
	return invalidation
}

fn animated_custom_property_maps_differ(old_values map[string]&dom.StyleValue, new_values map[string]&dom.StyleValue) bool {
	if old_values.len != new_values.len {
		return true
	}
	for name, old_value in old_values {
		new_value := new_values[name] or { return true }
		old_typed := typed_style_value_logic_from_dom(old_value) or {
			if voidptr(old_value) != voidptr(new_value) {
				return true
			}
			continue
		}
		new_typed := typed_style_value_logic_from_dom(new_value) or { return true }
		if !old_typed.equals(new_typed) {
			return true
		}
	}
	return false
}

// A match, not `in` with an array literal: this runs for every sampled
// property on every animation frame, and the literal is allocated per test.
fn property_is_compositor_animated(property PropertyID) bool {
	return match property {
		.transform, .translate, .rotate, .scale, .transform_origin, .opacity { true }
		else { false }
	}
}

fn animated_values_reach_descendants(old_values map[PropertyID]&dom.StyleValue,
	computed &ComputedProperties, target &dom.Node) bool {
	if old_values.len == 0 && !computed.has_animated_properties() {
		return false
	}
	for property_id, _ in old_values {
		if animated_property_reaches_children(property_id, target) {
			return true
		}
	}
	if computed.animated_property_storage_ != unsafe { nil } {
		for property_id, _ in computed.animated_property_storage_.values {
			if animated_property_reaches_children(property_id, target) {
				return true
			}
		}
	}
	return false
}

fn animated_property_reaches_children(property_id PropertyID, target &dom.Node) bool {
	if !computed_interpolation_is_longhand_property(property_id)
		|| computed_interpolation_is_inherited_property(property_id) {
		return true
	}
	mut child := target.first_child()
	for {
		current := child or { break }
		if element := current.as_element() {
			if child_computed := computed_properties_for_element(element) {
				// For a non-inherited property this records an explicit
				// `inherit` from the parent.
				if child_computed.is_property_inherited(property_id) {
					return true
				}
			}
		}
		child = current.next_sibling()
	}
	return false
}

// Colors the retained paint tree refreshes per box without rebuilding the
// transport (see layout/local_paint_style_refresh.v).
fn property_is_local_paint_animated(property PropertyID) bool {
	return match property {
		.background_color, .color, .outline_color { true }
		else { false }
	}
}

// Whether the samples changed only colors that a local paint refresh applies,
// and whether the background color is the only one: text then keeps its lines.
fn animated_changes_are_local_paint(old_values map[PropertyID]&dom.StyleValue,
	new_values map[PropertyID]&dom.StyleValue) (bool, bool) {
	mut background_only := true
	for property, old_value in old_values {
		new_value := if value := new_values[property] { ?&dom.StyleValue(value) } else { ?&dom.StyleValue(none) }
		if compute_property_invalidation(property, old_value, new_value).is_none() {
			continue
		}
		if !property_is_local_paint_animated(property) {
			return false, false
		}
		if property != .background_color {
			background_only = false
		}
	}
	for property, _ in new_values {
		if property in old_values {
			continue
		}
		if !property_is_local_paint_animated(property) {
			return false, false
		}
		if property != .background_color {
			background_only = false
		}
	}
	return true, background_only
}

// Set while an animation sample that changed only background colors is
// applied to its layout node, so the paint refresh can keep text lines.
__global css_animated_background_only_update = false

pub fn animated_background_only_update() bool {
	return css_animated_background_only_update
}

fn animated_changes_are_compositor_only(old_values map[PropertyID]&dom.StyleValue,
	new_values map[PropertyID]&dom.StyleValue) bool {
	for property, old_value in old_values {
		if property_is_compositor_animated(property) { continue }
		new_value := if value := new_values[property] { ?&dom.StyleValue(value) } else { ?&dom.StyleValue(none) }
		if !compute_property_invalidation(property, old_value, new_value).is_none() { return false }
	}
	for property, _ in new_values {
		if property !in old_values
			&& !property_is_compositor_animated(property) { return false }
	}
	return true
}

fn (s &StyleComputer) recompute_inherited_style_for_animated_descendants(node &dom.Node) RequiredInvalidationAfterStyleChange {
	mut invalidation := RequiredInvalidationAfterStyleChange{}
	if element := node.as_element() {
		mut abstract_element := dom.AbstractElement.new(element, none)
		element_invalidation := s.recompute_inherited_style_with_invalidation(mut abstract_element)
		if element_invalidation.is_none() {
			return invalidation
		}
		invalidation = required_invalidation_after_style_change_or(invalidation, element_invalidation)
		if shadow_root := element.shadow_root() {
			invalidation = required_invalidation_after_style_change_or(invalidation, s.recompute_inherited_style_for_animated_descendants(unsafe { &dom.Node(shadow_root) }))
		}
	}

	mut child := node.first_child()
	for {
		current := child or { break }
		invalidation = required_invalidation_after_style_change_or(invalidation, s.recompute_inherited_style_for_animated_descendants(current))
		child = current.next_sibling()
	}
	return invalidation
}

fn computed_display_is_none_ignoring_animations(computed &ComputedProperties) bool {
	value := computed.property(.display, .no) or { return false }
	typed := style_value_logic_from_dom(.display, value) or { return false }
	if typed is DisplayStyleValue {
		return typed.display().is_none()
	}
	return false
}

pub fn is_in_display_none_subtree_ignoring_animations(abstract_element dom.AbstractElement) bool {
	if abstract_element.pseudo_element() != none {
		if pseudo_style := abstract_element.computed_properties() {
			if computed := computed_properties_from_dom(pseudo_style) {
				if computed_display_is_none_ignoring_animations(computed) {
					return true
				}
			}
		}
	}
	mut ancestor := ?&dom.Node(abstract_element.element().as_node())
	for ancestor != none {
		current := ancestor or { break }
		if element := current.as_element() {
			if style := element.el_computed_properties() {
				if computed := computed_properties_from_dom(style) {
					if computed_display_is_none_ignoring_animations(computed) {
						return true
					}
				}
			}
		}
		ancestor = current.parent_or_shadow_host()
	}
	return false
}

fn keyframe_effect_animates_property(effect &KeyframeEffect, property_id PropertyID) bool {
	key_frame_set := effect.key_frame_set or { return false }
	for _, keyframe in key_frame_set.keyframes_by_key {
		if property_id in keyframe.properties || property_id in keyframe.use_initial_properties {
			return true
		}
	}
	return false
}

pub fn (effect &KeyframeEffect) update_computed_properties_for_style(mut style_computer StyleComputer, abstract_element dom.AbstractElement, mut computed ComputedProperties) {
	style_computer.collect_animation_into(abstract_element, voidptr(effect), mut computed)
}

fn (style_computer &StyleComputer) target_has_animation_for_property(abstract_element dom.AbstractElement, property_id PropertyID) bool {
	for effect in web_animation_effects_for_style(abstract_element) {
		if keyframe_effect_animates_property(effect, property_id) { return true }
	}
	// Hidden animated targets ask this on every sample; walk the stores in
	// place rather than collecting per-target lists.
	if style_computer.css_animation_storage_ != unsafe { nil } {
		for entry in style_computer.css_animation_storage_.entries {
			if !abstract_elements_equal(entry.abstract_element, abstract_element) {
				continue
			}
			if effect := entry.animation.effect() {
				if keyframe_effect_animates_property(effect, property_id) {
					return true
				}
			}
		}
	}
	if style_computer.css_transition_storage_ != unsafe { nil } {
		if bucket := style_computer.css_transition_storage_.associated_transitions[abstract_element_storage_key(abstract_element)] {
			for entry in bucket.entries {
				if effect := entry.transition.effect() {
					if keyframe_effect_animates_property(effect, property_id) {
						return true
					}
				}
			}
		}
	}
	return false
}

// Document::update_animated_style_if_needed() and AnimationUpdateContext's
// destructor. Group active effects by target, reset non-inherited animated
// values once, sample every CSS animation/transition, diff the animated
// property maps, update inherited descendants, and propagate the resulting
// layout/paint invalidation.
// INTEROP: Other engines suppress main-thread style sampling for invisible
// transform animations (KeyframeEffect::can_skip_per_frame_style_update()).
// This port has no off-thread compositor, so apply that rule to pseudo-element
// targets whose infinite CSS animations only drive transform-family properties
// while an ancestor clip keeps them outside the viewport. Pseudo-elements own no
// observable elements, and the check is repeated for every rendering update, so
// a target resumes sampling as soon as its clip can intersect the viewport.
fn (s &StyleComputer) animated_target_is_offscreen_throttled(target dom.AbstractElement) bool {
	if target.pseudo_element() == none || s.css_animation_storage_ == unsafe { nil } {
		return false
	}
	document := target.document()
	if !document.layout_is_up_to_date() {
		return false
	}
	// Effect lists are read-only queries; during an animation frame they are
	// built among its samples.
	mut samples := if s.sampling_animation_frame_ { s.animation_samples_ } else { unsafe { &AnimationSampleStorage(nil) } }
	samples.enter()
	has_transitions := s.css_transition_storage_ != unsafe { nil }
		&& s.css_transition_storage_.transitions_for(target).len > 0
	animations := s.css_animation_storage_.animations_for(target)
	samples.leave()
	has_web_effects := web_animation_effects_for_style(target).len > 0
	if has_transitions || has_web_effects {
		return false
	}
	if animations.len == 0 {
		return false
	}
	for animation in animations {
		effect := animation.effect_
		if effect == unsafe { nil } || !math.is_inf(effect.iteration_count, 1) {
			return false
		}
		key_frame_set := effect.key_frame_set or { return false }
		mut animates_property := false
		for _, keyframe in key_frame_set.keyframes_by_key {
			if keyframe.custom_properties.len > 0 || keyframe.use_initial_custom_properties.len > 0 {
				return false
			}
			for property, _ in keyframe.properties {
				if property !in [.transform, .translate, .rotate, .scale] {
					return false
				}
				animates_property = true
			}
			for property, _ in keyframe.use_initial_properties {
				if property !in [.transform, .translate, .rotate, .scale] {
					return false
				}
				animates_property = true
			}
		}
		if !animates_property {
			return false
		}
	}
	styled := target.unsafe_layout_node() or { return false }
	layout_node := styled.layout_node_ or { return false }
	paintable := document.unsafe_paintable() or { return false }
	return paintable.layout_subtree_is_clipped_outside_viewport(layout_node.layout_handle)
}

fn style_computer_update_animated_style_callback(target voidptr) {
	if target == unsafe { nil } {
		return
	}
	mut style_computer := unsafe { &StyleComputer(target) }
	// Samples go into bounded arenas under -prealloc. When the current one is
	// full, this update re-installs every target so the old one can be reused.
	mut samples := style_computer.animation_sample_storage()
	full_refresh := if samples != unsafe { nil } {
		samples.begin_update(style_computer.document_)
	} else {
		false
	}
	style_computer.sampling_animation_frame_ = samples != unsafe { nil }
	defer {
		style_computer.sampling_animation_frame_ = false
	}
	// Per-update working data (target lists, previous-value snapshots and
	// change comparisons) lives with the samples.
	samples.enter()
	mut targets := []dom.AbstractElement{}
	mut seen := map[i64]bool{}
	if hook := style_computer.document_.animations_hook_ {
		if hook.effect_targets != unsafe { nil } {
			for target_element in hook.effect_targets(hook.target) {
				key := abstract_element_storage_key(target_element)
				if key !in seen {
					seen[key] = true
					targets << target_element
				}
			}
		}
	}
	if style_computer.css_animation_storage_ != unsafe { nil } {
		for entry in style_computer.css_animation_storage_.entries {
			key := abstract_element_storage_key(entry.abstract_element)
			if key !in seen {
				seen[key] = true
				targets << entry.abstract_element
			}
		}
	}
	if style_computer.css_transition_storage_ != unsafe { nil } {
		for _, bucket in style_computer.css_transition_storage_.associated_transitions {
			for entry in bucket.entries {
				key := abstract_element_storage_key(entry.abstract_element)
				if key !in seen {
					seen[key] = true
					targets << entry.abstract_element
				}
			}
		}
	}

	samples.leave()
	for target_element in targets {
		target_node := target_element.element().as_node()
		if !target_node.is_connected() {
			continue
		}
		if is_in_display_none_subtree_ignoring_animations(target_element)
			&& !style_computer.target_has_animation_for_property(target_element, .display) {
			continue
		}
		if !full_refresh && style_computer.animated_target_is_offscreen_throttled(target_element) {
			continue
		}
		dom_computed := target_element.computed_properties() or { continue }
		mut computed := computed_properties_from_dom(dom_computed) or { continue }
		samples.enter()
		old_animated_values := computed.animated_property_values()
		old_animated_custom_values := computed.animated_custom_property_values()
		computed.reset_non_inherited_animated_properties()
		computed.reset_animated_custom_properties()
		samples.leave()

		// The target's effect lists are read-only queries for this update.
		samples.enter()
		animations := if style_computer.css_animation_storage_ != unsafe { nil } {
			style_computer.css_animation_storage_.animations_for(target_element)
		} else {
			[]&CSSAnimation{}
		}
		transitions := if style_computer.css_transition_storage_ != unsafe { nil } {
			style_computer.css_transition_storage_.transitions_for(target_element)
		} else {
			[]&CSSTransition{}
		}
		samples.leave()
		// Web Animations effects create their CSS view lazily and keep it.
		web_effects := web_animation_effects_for_style(target_element)
		for existing in animations {
			mut animation := unsafe { existing }
			if animation.sample_at(style_computer.animation_time_ms_) != none {
				animation.effect_.update_computed_properties_for_style(mut style_computer, target_element, mut computed)
			}
		}
		for existing in transitions {
			mut transition := unsafe { existing }
			if transition.sample_at(style_computer.animation_time_ms_) != none {
				transition.keyframe_effect_.update_computed_properties_for_style(mut style_computer, target_element, mut computed)
			}
		}
		for effect in web_effects {
			effect.update_computed_properties_for_style(mut style_computer, target_element, mut computed)
		}
		installs_inherited_values := computed_installs_inherited_animated_values(computed)
		if samples != unsafe { nil } {
			samples.note_target(target_element, installs_inherited_values)
		}
		publish_animated_custom_properties(computed, target_element)

		samples.enter()
		mut invalidation := animated_property_maps_invalidation(old_animated_values, computed.animated_property_values())
		custom_properties_changed := animated_custom_property_maps_differ(old_animated_custom_values,
			computed.animated_custom_property_values())
		compositor_only_changes := animated_changes_are_compositor_only(old_animated_values,
			computed.animated_property_values())
		local_paint, background_only := animated_changes_are_local_paint(old_animated_values,
			computed.animated_property_values())
		local_paint_changes := !compositor_only_changes && local_paint
		samples.leave()
		if full_refresh {
			// Every value derived from the previous samples is rebuilt: paint
			// data, visual contexts and, for inherited values, descendants.
			invalidation.ensure_at_least(.repaint)
			invalidation.ensure_accumulated_visual_contexts_at_least(.rebuild)
		} else if invalidation.is_none() && !custom_properties_changed {
			continue
		}
		mut target_was_recomputed := false
		if custom_properties_changed
			&& (target_element.element().style_uses_var_css_function()
				|| target_element.element().style_uses_inherit_css_function()) {
			mut mutable_target := target_element
			mut did_change_custom_properties := false
			target_invalidation, _ := style_computer.recompute_style_with_invalidation(mut mutable_target,
				&did_change_custom_properties)
			invalidation = required_invalidation_after_style_change_or(invalidation,
				target_invalidation)
			target_was_recomputed = true
		}
		// As upstream, descendants are revisited only when they can observe an
		// animated value: an inherited property, or one a child inherits
		// explicitly. Otherwise every frame would recompute their styles.
		visits_descendants := custom_properties_changed || (full_refresh && installs_inherited_values)
			|| animated_values_reach_descendants(old_animated_values, computed, target_node)
		mut child := if visits_descendants { target_node.first_child() } else { ?&dom.Node(none) }
		for {
			current := child or { break }
			if custom_properties_changed || (full_refresh && installs_inherited_values) {
				invalidation = required_invalidation_after_style_change_or(invalidation,
					update_style_recursively(mut style_computer, current, false, true, false,
						full_refresh, false))
			} else {
				invalidation = required_invalidation_after_style_change_or(invalidation,
					style_computer.recompute_inherited_style_for_animated_descendants(current))
			}
			child = current.next_sibling()
		}

		mut retained_compositor_paint := false
		mut retained_local_paint := false
		if !target_was_recomputed {
			// The DOM mirror is rebuilt on every install and kept by the element
			// and its layout node until the next one.
			samples.enter()
			computed_dom_mirror := computed_properties_to_dom(computed)
			samples.leave()
			mut mutable_target := target_element
			mutable_target.set_computed_properties(computed_dom_mirror)
			if layout_node := target_element.unsafe_layout_node() {
				only_compositor_changes := !custom_properties_changed
					&& !invalidation.needs_relayout() && !invalidation.needs_layout_tree_rebuild()
					&& compositor_only_changes
				style_computer.animation_layout_style_ = computed
				style_computer.animation_layout_compositor_only_ = !full_refresh && only_compositor_changes
				if !full_refresh && !custom_properties_changed && local_paint_changes
					&& !invalidation.needs_relayout() && !invalidation.needs_layout_tree_rebuild() {
					// The retained paint tree refreshes this box's colors and
					// re-records only its phase commands; otherwise the style is
					// applied normally.
					css_animated_background_only_update = background_only
					retained_local_paint = layout_node.apply_inherited_color_style(computed_dom_mirror)
					css_animated_background_only_update = false
				} else {
					retained_compositor_paint = layout_node.apply_animated_style(computed_dom_mirror,
						only_compositor_changes)
				}
				style_computer.animation_layout_style_ = unsafe { nil }
				style_computer.animation_layout_compositor_only_ = false
			}
		}

		mut mutable_target_node := unsafe { &dom.Node(target_node) }
		if invalidation.needs_relayout() {
			mutable_target_node.set_needs_layout_update(.keyframe_effect)
		}
		if invalidation.needs_layout_tree_rebuild() {
			if parent_element := target_node.parent_element() {
				mut parent_node := unsafe { &dom.Node(parent_element.as_node()) }
				parent_node.set_needs_layout_tree_update(true, .keyframe_effect)
			} else {
				mutable_target_node.set_needs_layout_tree_update(true, .keyframe_effect)
			}
		}
		mut document := unsafe { &dom.Document(target_element.document()) }
		if invalidation.needs_repaint() && retained_local_paint {
			document.set_needs_repaint_with_invalidation(.paint_commands)
		} else if invalidation.needs_repaint() {
			if retained_compositor_paint {
				// The retained paint transport resamples this compositor value, so
				// only the assembled display list needs recording again.
				document.set_needs_repaint_with_invalidation(.paint_commands)
			} else {
				mutable_target_node.set_needs_repaint(if invalidation.invalidates_hit_test_display_list() {
					.paint_commands_and_hit_test_list
				} else {
					.paint_commands
				})
			}
			if invalidation.accumulated_visual_contexts() == .rebuild {
				if retained_compositor_paint {
					// The retained transport patches the sampled values into the
					// existing visual-context tree when its shape is unchanged.
					document.set_needs_compositor_visual_contexts_update()
				} else {
					document.set_needs_accumulated_visual_contexts_update(true)
				}
			}
		}
		if invalidation.needs_stacking_context_tree_rebuild() {
			document.invalidate_stacking_context_tree()
		}
	}
}

// Whether animation values for inherited properties, or custom properties,
// were installed: descendants can hold such values.
fn computed_installs_inherited_animated_values(computed &ComputedProperties) bool {
	if computed.animated_custom_storage_ != unsafe { nil }
		&& computed.animated_custom_storage_.values.len > 0 {
		return true
	}
	if computed.animated_property_storage_ != unsafe { nil } {
		for property_id, _ in computed.animated_property_storage_.values {
			if computed_interpolation_is_inherited_property(property_id) {
				return true
			}
		}
	}
	return false
}

// Recompute style for `node` and its whole subtree, top-down — the recursive core of
// DOM::update_style_recursively (Document.cpp:1646). For each element: push it onto the ancestor filter,
// recompute+store its style, recurse into its children (so each child inherits from its just-stored
// parent), then pop it off the filter.
// This correctness-first path recomputes the whole requested subtree; it also
// traverses shadow roots before light-DOM children, matching Document's
// shadow-including style walk.
pub fn recompute_style_for_subtree(mut style_computer StyleComputer, node &dom.Node) {
	style_computer.begin_computed_property_page_batch()
	defer { style_computer.end_computed_property_page_batch() }
	element_opt := node.as_element()
	if element := element_opt {
		style_computer.deferred_hidden_styles_.delete(u64(node.unique_id().value()))
		style_computer.push_ancestor(element)
		mut abstract_element := dom.AbstractElement.new(element, none)
		style_computer.recompute_style(mut abstract_element)
	}

	if element := element_opt {
		if shadow_root := element.shadow_root() {
			recompute_style_for_subtree(mut style_computer, unsafe { &dom.Node(shadow_root) })
		}
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
	mut mutable_node := unsafe { &dom.Node(node) }
	mutable_node.set_needs_style_update(false)
	mutable_node.set_child_needs_style_update(false)
	mutable_node.set_entire_subtree_needs_style_update(false)
}

fn update_style_recursively(mut style_computer StyleComputer, node &dom.Node, needs_inherited_style_update bool, recompute_elements_depending_on_custom_properties bool, parent_display_changed bool, ancestor_needs_descendant_style_recompute bool, ancestor_is_display_none bool) RequiredInvalidationAfterStyleChange {
	needs_full_style_update := node.document().needs_full_style_update()
	mut invalidation := RequiredInvalidationAfterStyleChange{}
	element_opt := node.as_element()
	if element := element_opt {
		style_computer.push_ancestor(element)
	}

	mut is_display_none := false
	mut did_change_custom_properties := false
	mut node_invalidation := RequiredInvalidationAfterStyleChange{}
	if element := element_opt {
		needs_style_update_due_to_if_media := element.style_uses_if_css_function()
		should_recompute := needs_full_style_update || node.needs_style_update()
			|| parent_display_changed
			|| ancestor_needs_descendant_style_recompute
			|| (recompute_elements_depending_on_custom_properties
				&& (element.style_uses_var_css_function() || element.style_uses_inherit_css_function()))
			|| needs_style_update_due_to_if_media
		if should_recompute {
            reason := if needs_full_style_update { 0 } else if node.needs_style_update() { 1 }
                else if parent_display_changed { 2 } else if ancestor_needs_descendant_style_recompute { 3 }
                else if recompute_elements_depending_on_custom_properties { 4 } else { 5 }
            record_diagnostic_style_update_cause(reason)
            record_diagnostic_style_update_element(reason, element)
			mut abstract_element := dom.AbstractElement.new(element, none)
			node_invalidation, _ = style_computer.recompute_style_with_invalidation(mut abstract_element, &did_change_custom_properties)
		} else {
			mut font_inputs_refreshed := false
			if element.has_pending_font_input_update() {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.set_pending_font_input_update(false)
				if font_invalidation := style_computer.try_refresh_font_inputs(element) {
                    record_diagnostic_style_update_cause(6)
					node_invalidation = font_invalidation
					font_inputs_refreshed = true
				} else {
                    record_diagnostic_style_update_cause(7)
					mut abstract_element := dom.AbstractElement.new(element, none)
					node_invalidation, _ = style_computer.recompute_style_with_invalidation(mut abstract_element, &did_change_custom_properties)
					font_inputs_refreshed = true
				}
			}
			if needs_inherited_style_update && !font_inputs_refreshed {
				mut abstract_element := dom.AbstractElement.new(element, none)
				node_invalidation = style_computer.recompute_inherited_style_with_invalidation(mut abstract_element)
			}
			if recompute_elements_depending_on_custom_properties {
				mut mutable_element := unsafe { &dom.Element(element) }
				if mutable_element.refresh_inherited_custom_property_data() {
					did_change_custom_properties = true
					mutable_element.invalidate_descendant_styles_depending_on_style_container_query()
				}
			}
		}
		if dom_computed := element.el_computed_properties() {
			if computed := computed_properties_from_dom(dom_computed) {
				is_display_none = computed.display().is_none()
			}
		}

		// Slotted nodes inherit from their slot in the flat tree, rather than
		// their light-DOM parent.
		if !node_invalidation.is_none() && element.is_html_element()
			&& element.local_name() == 'slot' {
			slot := unsafe { &dom.HTMLSlotElement(element) }
			for assigned_node in slot.assigned_nodes_internal() {
				mut mutable_assigned_node := unsafe { &dom.Node(assigned_node) }
				mutable_assigned_node.set_needs_style_update(true)
			}
		}
	}

	mut mutable_node := unsafe { &dom.Node(node) }
	if node_invalidation.needs_relayout() {
		mutable_node.set_needs_layout_update(.style_change)
	}
	if node_invalidation.needs_layout_tree_rebuild() {
		if parent_element := node.parent_element() {
			mut mutable_parent := unsafe { &dom.Node(parent_element.as_node()) }
			mutable_parent.set_needs_layout_tree_update(true, .style_change)
		} else {
			mutable_node.set_needs_layout_tree_update(true, .style_change)
		}
	}
	mutable_node.set_needs_style_update(false)
	invalidation = required_invalidation_after_style_change_or(invalidation, node_invalidation)

	mut recompute_custom_property_dependents := recompute_elements_depending_on_custom_properties
	if did_change_custom_properties {
		recompute_custom_property_dependents = true
	}
	children_need_inherited_style_update := !invalidation.is_none()
	descendant_style_recompute_needed := ancestor_needs_descendant_style_recompute
		|| node_invalidation.recompute_descendant_styles
	descendants_need_update := needs_full_style_update || node.child_needs_style_update()
		|| children_need_inherited_style_update || recompute_custom_property_dependents
		|| node_invalidation.needs_layout_tree_rebuild() || descendant_style_recompute_needed
	hidden := ancestor_is_display_none || is_display_none
	deferred, needs_deferred_refresh := style_computer.prepare_hidden_child_style_update(node,
		hidden, descendants_need_update)
	children_need_full_style_recompute := node_invalidation.needs_layout_tree_rebuild() || needs_deferred_refresh
	if !deferred && (descendants_need_update || needs_deferred_refresh) {
		if element := element_opt {
			if shadow_root := element.shadow_root() {
				shadow_node := unsafe { &dom.Node(shadow_root) }
				if needs_full_style_update || shadow_node.needs_style_update()
					|| shadow_node.child_needs_style_update() || children_need_inherited_style_update
					|| recompute_custom_property_dependents || children_need_full_style_recompute
					|| descendant_style_recompute_needed {
					subtree_invalidation := update_style_recursively(mut style_computer, shadow_node, children_need_inherited_style_update, recompute_custom_property_dependents, children_need_full_style_recompute, descendant_style_recompute_needed, hidden)
					if !is_display_none {
						invalidation = required_invalidation_after_style_change_or(invalidation, subtree_invalidation)
					}
				}
			}
		}

		mut child := node.first_child()
		for {
			current := child or { break }
			if needs_full_style_update || current.needs_style_update()
				|| children_need_inherited_style_update || current.child_needs_style_update()
				|| recompute_custom_property_dependents || children_need_full_style_recompute
				|| descendant_style_recompute_needed {
				subtree_invalidation := update_style_recursively(mut style_computer, current, children_need_inherited_style_update, recompute_custom_property_dependents, children_need_full_style_recompute, descendant_style_recompute_needed, hidden)
				if !is_display_none {
					invalidation = required_invalidation_after_style_change_or(invalidation, subtree_invalidation)
				}
			}
			child = current.next_sibling()
		}
	}

	mutable_node.set_child_needs_style_update(false)
	mutable_node.set_entire_subtree_needs_style_update(false)
	if element := element_opt {
		style_computer.pop_ancestor(element)
	}
	return invalidation
}

fn update_style_for_document_from_upstream(document &dom.Document) RequiredInvalidationAfterStyleChange {
	mut mutable_document := unsafe { &dom.Document(document) }
	if mutable_document.needs_invalidation_of_elements_affected_by_has {
		mutable_document.needs_invalidation_of_elements_affected_by_has = false
		mut document_scope := css_style_scope_for_document(document)
		document_scope.invalidate_style_of_elements_affected_by_has()
		root := unsafe { &dom.Node(document) }
		root.for_each_shadow_including_inclusive_descendant(fn (node &dom.Node) dom.TraversalDecision {
			if element := node.as_element() {
				if shadow_root := element.shadow_root() {
					mut scope := css_style_scope_for_shadow_root(shadow_root)
					scope.invalidate_style_of_elements_affected_by_has()
				}
			}
			return .@continue
		})
		// The :has() ancestor walk can enqueue descendant plans after
		// Document.update_style() has drained the original mutation plans.
		// Apply that fanout before recomputing style in this same pass.
		mut invalidator := mutable_document.style_invalidator()
		mut document_node := unsafe { &dom.Node(document) }
		// A whole-subtree fallback marks node flags directly without a pending
		// plan. Drain those flags as well, before the cascade clears them.
		if document.needs_full_style_update() {
			document_node.set_entire_subtree_needs_style_update(true)
		}
		invalidator.invalidate(mut document_node)
	}

	mut style_computer := css_style_computer_for(document)
	style_computer.begin_computed_property_page_batch()
	defer { style_computer.end_computed_property_page_batch() }
	viewport := document.viewport_rect()
	style_computer.set_viewport_rect(CSSPixelRect.new(viewport.x, viewport.y, viewport.width, viewport.height))
	evaluate_media_rules_for_document(document)
	style_computer.reset_has_result_cache()
	style_computer.reset_ancestor_filter()
	mutable_document.build_registered_properties_cache()
	return update_style_recursively(mut style_computer, unsafe { &dom.Node(document) }, false, false, false, false, false)
}

// The computed value of `property_id` for `element`, serialized from the retained StyleComputer result.
// Flushes pending document style work (so inheritance from ancestors resolves),
// then reads the element's stored computed value.
// This reflects the same UA, user, author, inline, inheritance, and initial-value
// inputs as the document's StyleComputer pass.
pub fn computed_value_for(element &dom.Element, property_id PropertyID) ?string {
	computed := up_to_date_computed_properties_for_element(element)
	value := computed.property(property_id, .no) or { return none }
	return value.css_text
}

// The element's computed properties after any pending style update, as read
// by the resolved-value algorithms (Editing's resolved_value(), for example).
pub fn up_to_date_computed_properties_for_element(element &dom.Element) &ComputedProperties {
	mut document := element.as_node().document()
	mut computer := css_style_computer_for(document)

	abstract_element := dom.AbstractElement.new(element, none)
	// Bootstrap missing styles, then let the document retain the scope of later
	// invalidations, including font-only updates and stale inheritance ancestors.
	if abstract_element.computed_properties() == none {
		prepare_missing_style_for_query(element)
	} else if document.element_needs_style_update(element) {
		document.update_style()
	}
	computer.materialize_hidden_styles_for_query(element)

	return if dom_computed := abstract_element.computed_properties() {
		computed_properties_from_dom(dom_computed) or {
			mut style_computer := css_style_computer_for(document)
			style_computer.compute_style_with_seeded_ancestors(abstract_element)
		}
	} else {
		mut style_computer := css_style_computer_for(document)
		style_computer.compute_style_with_seeded_ancestors(abstract_element)
	}
}

pub struct ComputedStylePair {
pub:
	with_inline    &ComputedProperties
	without_inline &ComputedProperties
}

// Compute the element's style with its inline declaration excluded without
// changing the live style attribute. The declaration and custom-property cache
// are restored before returning, matching StyleComputer's read-only comparison
// path used by editing cleanup.
pub fn computed_styles_with_and_without_inline(element &dom.Element) ?ComputedStylePair {
	mut document := element.as_node().document()
	css_style_computer_for(document)
	abstract_element := dom.AbstractElement.new(element, none)
	if abstract_element.computed_properties() == none {
		prepare_missing_style_for_query(element)
	} else if document.element_needs_style_update(element) {
		document.update_style()
	}

	mut style_computer := css_style_computer_for(document)
	style_computer.materialize_hidden_styles_for_query(element)
	with_inline := if dom_computed := abstract_element.computed_properties() {
		computed_properties_from_dom(dom_computed) or {
			style_computer.compute_style_with_seeded_ancestors(abstract_element)
		}
	} else {
		style_computer.compute_style_with_seeded_ancestors(abstract_element)
	}
	element_inline_style := inline_style_for_abstract_element(abstract_element) or { return none }
	saved_properties := element_inline_style.properties.clone()
	saved_custom_properties := element_inline_style.custom_properties.clone()
	saved_typed_properties_cache := element_inline_style.typed_properties_cache_
	saved_typed_importance_mask := element_inline_style.typed_importance_mask_
	saved_typed_logical_aliases := element_inline_style.typed_may_have_logical_aliases_
	saved_custom_property_data := abstract_element.custom_property_data()

	mut mutable_inline_style := unsafe { &CSSStyleProperties(element_inline_style) }
	mutable_inline_style.properties = []CSSStyleProperty{}
	mutable_inline_style.custom_properties = map[string]StyleProperty{}
	mutable_inline_style.typed_properties_cache_ = none
	mutable_inline_style.typed_importance_mask_ = 0
	without_inline := style_computer.compute_style_with_seeded_ancestors(abstract_element)

	mutable_inline_style.properties = saved_properties
	mutable_inline_style.custom_properties = saved_custom_properties.clone()
	mutable_inline_style.typed_properties_cache_ = saved_typed_properties_cache
	mutable_inline_style.typed_importance_mask_ = saved_typed_importance_mask
	mutable_inline_style.typed_may_have_logical_aliases_ = saved_typed_logical_aliases
	mut mutable_abstract_element := abstract_element
	mutable_abstract_element.set_custom_property_data(saved_custom_property_data)

	return ComputedStylePair{
		with_inline: with_inline
		without_inline: without_inline
	}
}
