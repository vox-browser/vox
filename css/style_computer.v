module css

import dom

// Faithful translation of Ladybird's CSS/StyleComputer.cpp and the generated property metadata used
// by its cascade.

// Generated from Properties.json's `logical-alias-for` entries.
fn property_is_logical_alias(property_id PropertyID) bool {
	return property_id in [
		.block_size,
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
			map_border_radius(physical_corner_for_logical_edges(.block_start, .inline_start,
				context))
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
		'text-decoration-style', 'text-decoration-thickness']
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
		'border-block-start-style', 'border-block-start-width', 'border-bottom',
		'border-bottom-color', 'border-bottom-left-radius', 'border-bottom-right-radius',
		'border-bottom-style', 'border-bottom-width', 'border-color', 'border-image-outset',
		'border-image-repeat', 'border-image-slice', 'border-image-source', 'border-image-width',
		'border-inline-end', 'border-inline-end-color', 'border-inline-end-style',
		'border-inline-end-width', 'border-inline-start', 'border-inline-start-color',
		'border-inline-start-style', 'border-inline-start-width', 'border-left', 'border-left-color',
		'border-left-style', 'border-left-width', 'border-radius', 'border-right',
		'border-right-color', 'border-right-style', 'border-right-width', 'border-style',
		'border-top', 'border-top-color', 'border-top-left-radius', 'border-top-right-radius',
		'border-top-style', 'border-top-width', 'border-width']
}

fn pseudo_element_supports_common_text_properties(name string, include_inline_layout bool) bool {
	return is_pseudo_font_property(name) || name in ['color', 'opacity']
		|| is_pseudo_background_property(name)
		|| is_pseudo_inline_typesetting_property(name)
		|| is_pseudo_text_decoration_property(name)
		|| (include_inline_layout && is_pseudo_inline_layout_property(name))
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
			pseudo_element_supports_common_text_properties(name, true)
				|| is_pseudo_margin_property(name) || is_pseudo_padding_property(name)
				|| is_pseudo_border_property(name) || name == 'box-shadow'
		}
		.selection {
			name in ['color', 'background-color', 'text-shadow', 'stroke-width']
				|| is_pseudo_text_decoration_property(name)
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

fn resolve_cascade_declaration_value(abstract_element dom.AbstractElement, property_id PropertyID, value &dom.StyleValue) &dom.StyleValue {
	typed := parse_css_value_logic(property_id, value.css_text) or { return unsafe { value } }
	if typed is UnresolvedStyleValue {
		return resolve_unresolved_style_value_for_property(abstract_element, property_id, typed)
	}
	return unsafe { value }
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
		resolved_property_value := resolve_cascade_declaration_value(abstract_element,
			property.property_id, property.value)
		for longhand in expand_property_longhands(property.property_id, resolved_property_value) {
			mut physical_property_id := longhand.id
			if property_is_logical_alias(longhand.id) {
				context := logical_alias_mapping_context or { continue }
				physical_property_id = map_logical_alias_to_physical_property(longhand.id, context)
			}

			if opaque_is_revert(longhand.id, longhand.value) {
				cascaded_properties.revert_property(physical_property_id, important, cascade_origin)
			} else if opaque_is_revert_layer(longhand.id, longhand.value) {
				cascaded_properties.revert_layer_property(physical_property_id, important,
					layer_name)
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

// The `normalize_value` lambda of StyleComputer::compute_logical_alias_mapping_context.
fn logical_alias_normalize_value(abstract_element dom.AbstractElement, property_id PropertyID, value ?&dom.StyleValue) &dom.StyleValue {
	initial := computed_interpolation_property_initial_value(property_id)
	if current := value {
		if computed_interpolation_style_value_is_inherit(current)
			|| computed_interpolation_style_value_is_unset(current) {
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
// mirrored fields off the placeholder. The DOM-side Element.recompute_style is a stub because dom cannot
// import css; this is its CSS half, meant to be driven top-down over the tree (parents before children).
// Invalidation diffing and display-change animation replay remain owned by the
// layout/embedder boundary; the computed main and generated pseudo styles are
// both installed here.
pub fn (s &StyleComputer) recompute_style(mut abstract_element dom.AbstractElement) &ComputedProperties {
	mut element := unsafe { &dom.Element(abstract_element.element()) }
	element.reset_style_dependency_flags()
	mut had_list_marker := false
	if old_dom_style := abstract_element.computed_properties() {
		if old_style := computed_properties_from_dom(old_dom_style) {
			had_list_marker = old_style.display().is_list_item()
		}
	}
	computed := s.compute_style(abstract_element)
	abstract_element.set_computed_properties(computed_properties_to_dom(computed))

	mut pseudo_elements := [dom.PseudoElement.before, .after, .selection]
	if had_list_marker || computed.display().is_list_item() {
		pseudo_elements << dom.PseudoElement.marker
	}
	mut mutable_computer := unsafe { &StyleComputer(s) }
	for pseudo_element in pseudo_elements {
		mutable_computer.push_ancestor(abstract_element.element())
		mut pseudo_abstract := dom.AbstractElement.new(abstract_element.element(), pseudo_element)
		if pseudo_style := s.compute_pseudo_element_style_if_needed(pseudo_abstract) {
			pseudo_abstract.set_computed_properties(computed_properties_to_dom(pseudo_style))
		} else {
			pseudo_abstract.set_computed_properties(none)
		}
		mutable_computer.pop_ancestor(abstract_element.element())
	}
	return computed
}

// Recompute style for `node` and its whole subtree, top-down — the recursive core of
// DOM::update_style_recursively (Document.cpp:1646). For each element: push it onto the ancestor filter,
// recompute+store its style, recurse into its children (so each child inherits from its just-stored
// parent), then pop it off the filter.
// This correctness-first path recomputes the whole requested subtree; it also
// traverses shadow roots before light-DOM children, matching Document's
// shadow-including style walk.
pub fn recompute_style_for_subtree(mut style_computer StyleComputer, node &dom.Node) {
	element_opt := node.as_element()
	if element := element_opt {
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

// The computed value of `property_id` for `element`, serialized — the real-StyleComputer equivalent of the
// from-scratch minimal `cascaded_value_for`. Runs a full style pass over the element's document (so
// inheritance from ancestors resolves), then reads the element's stored computed value.
// NOTE: UA-default rules are NOT applied yet (the UA stylesheet is not embedded — user_agent_style_sheet_source
// returns none), so this reflects inline styles + author stylesheets (when attached to the document) +
// inheritance + initial values, but not user-agent display/etc. defaults.
pub fn computed_value_for(element &dom.Element, property_id PropertyID) ?string {
	mut document := element.as_node().document()
	css_style_computer_for(document)

	abstract_element := dom.AbstractElement.new(element, none)
	// Style the document once (a full UA + author + inline pass over the tree is expensive), then read the
	// Re-run the document pass whenever DOM invalidation says this element or an
	// inheritance ancestor is stale.
	if abstract_element.computed_properties() == none
		|| document.element_needs_style_update(element) {
		document.needs_full_style_update = true
		document.update_style()
	}

	dom_computed := abstract_element.computed_properties() or { return none }
	computed := computed_properties_from_dom(dom_computed) or { return none }
	value := computed.property(property_id, .no) or { return none }
	return value.css_text
}
