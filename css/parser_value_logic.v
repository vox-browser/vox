module css

import dom
import math
import strconv

// This file is a local V translation layer for the LibWeb parser logic in:
// - Libraries/LibWeb/CSS/Parser/ValueParsing.cpp
// - Libraries/LibWeb/CSS/Parser/PropertyParsing.cpp
// - Libraries/LibWeb/CSS/Parser/DescriptorParsing.cpp
// - Libraries/LibWeb/CSS/Parser/MediaParsing.cpp
// - Libraries/LibWeb/CSS/Parser/GradientParsing.cpp
//
// The upstream C++ parser depends on generated property grammar tables and on
// style/layout types that are not fully present in this port yet. Those gaps are
// intentionally represented by explicit stubs in this file instead of spreading
// parser-specific assumptions through parser_core.v.

pub struct Parser {
pub mut:
	component_values []ComponentValue
	context          ParsingParams
}

pub fn Parser.from_component_values(component_values []ComponentValue) Parser {
	return Parser{
		component_values: component_values.clone()
	}
}

pub fn Parser.from_css_text(text string) Parser {
	return Parser.from_component_values(parse_component_values_for_value_logic(text))
}

pub fn Parser.with_context(context ParsingParams, text string) Parser {
	return Parser{
		component_values: parse_component_values_for_value_logic(text)
		context:          context
	}
}

pub struct ComponentValueStream {
mut:
	values []ComponentValue
	index  int
}

fn ComponentValueStream.new(values []ComponentValue) ComponentValueStream {
	return ComponentValueStream{
		values: values.clone()
	}
}

fn (stream ComponentValueStream) clone() ComponentValueStream {
	return ComponentValueStream{
		values: stream.values.clone()
		index:  stream.index
	}
}

fn (stream ComponentValueStream) is_empty() bool {
	return stream.index >= stream.values.len
}

fn (stream ComponentValueStream) remaining_count() int {
	return stream.values.len - stream.index
}

fn (stream ComponentValueStream) peek() ?ComponentValue {
	if stream.is_empty() {
		return none
	}
	return stream.values[stream.index]
}

fn (mut stream ComponentValueStream) consume() ?ComponentValue {
	value := stream.peek() or { return none }
	stream.index++
	return value
}

fn (mut stream ComponentValueStream) reconsume() {
	if stream.index > 0 {
		stream.index--
	}
}

fn (mut stream ComponentValueStream) consume_whitespace() {
	for {
		value := stream.peek() or { return }
		if !value.is(.whitespace) {
			return
		}
		stream.index++
	}
}

fn (mut stream ComponentValueStream) consume_a_comma() bool {
	stream.consume_whitespace()
	value := stream.peek() or { return false }
	if !value.is(.comma) {
		return false
	}
	stream.index++
	stream.consume_whitespace()
	return true
}

fn (stream ComponentValueStream) has_more_tokens() bool {
	mut copy := stream
	copy.consume_whitespace()
	return !copy.is_empty()
}

fn (stream ComponentValueStream) has_one_token() bool {
	mut copy := stream
	copy.consume_whitespace()
	if copy.consume() == none {
		return false
	}
	copy.consume_whitespace()
	return copy.is_empty()
}

fn parse_component_values_for_value_logic(text string) []ComponentValue {
	tokens := tokenize_css(text, 'utf-8')
	mut state := ValueLogicTokenIndex{}
	return consume_component_value_list_for_value_logic(tokens, mut state, .end_of_file)
}

struct ValueLogicTokenIndex {
mut:
	value int
}

fn consume_component_value_list_for_value_logic(tokens []Token, mut state ValueLogicTokenIndex, ending TokenType) []ComponentValue {
	mut values := []ComponentValue{}
	for state.value < tokens.len {
		token := tokens[state.value]
		if token.is(.end_of_file) || (ending != .end_of_file && token.is(ending)) {
			break
		}
		state.value++
		if token.is(.open_curly) || token.is(.open_square) || token.is(.open_paren) {
			end_type := token.mirror_variant()
			block_values := consume_component_value_list_for_value_logic(tokens, mut state,
				end_type)
			mut end_token := Token.create(end_type, '')
			if state.value < tokens.len && tokens[state.value].is(end_type) {
				end_token = tokens[state.value]
				state.value++
			}
			values << ComponentValue.from_block(SimpleBlock{
				token:     token
				value:     block_values
				end_token: end_token
			})
			continue
		}
		if token.is(.function) {
			function_values := consume_component_value_list_for_value_logic(tokens, mut state,
				.close_paren)
			mut end_token := Token.create(.close_paren, '')
			if state.value < tokens.len && tokens[state.value].is(.close_paren) {
				end_token = tokens[state.value]
				state.value++
			}
			values << ComponentValue.from_function(Function{
				name:       token.function_name()
				value:      function_values
				name_token: token
				end_token:  end_token
			})
			continue
		}
		values << ComponentValue.from_token(token)
	}
	return values
}

pub fn (mut parser Parser) parse_css_value_for_property(property_id PropertyID) ?StyleValue {
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_css_value_for_property_tokens(property_id, mut tokens)
}

pub fn (mut parser Parser) parse_css_value(property_id PropertyID) ?StyleValue {
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_css_value_tokens(property_id, mut tokens)
}

fn (mut parser Parser) parse_css_value_tokens(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	// CSS-wide keywords can be used as the entire value of any property.
	if value := parser.parse_css_wide_keyword_value(mut tokens) {
		if !tokens.has_more_tokens() {
			return value
		}
		return none
	}

	value := parser.parse_css_value_for_property_tokens(property_id, mut tokens) or { return none }
	tokens.consume_whitespace()
	if !tokens.is_empty() {
		return none
	}
	return value
}

fn (mut parser Parser) parse_css_value_for_property_tokens(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	// FIXME: This switch mirrors the translated C++ dispatch points that can be
	// represented with the currently translated PropertyID enum. The generated
	// property grammar tables are not available in this V port yet.
	match property_id {
		.accent_color, .caret_color {
			return parser.parse_auto_or_color_value(mut tokens)
		}
		.anchor_name {
			return parser.parse_anchor_name_value(mut tokens)
		}
		.anchor_scope {
			return parser.parse_anchor_scope_value(mut tokens)
		}
		.background_attachment {
			return parser.parse_background_attachment_value(mut tokens)
		}
		.background_blend_mode {
			return parser.parse_background_blend_mode_value(mut tokens)
		}
		.background_clip, .background_origin {
			return parser.parse_background_box_value(mut tokens)
		}
		.background_position_x, .background_position_y {
			return parser.parse_background_position_axis_list_value(property_id, mut tokens)
		}
		.background_repeat {
			return parser.parse_repeat_style_list_value(.background_repeat, mut tokens)
		}
		.background_size {
			return parser.parse_background_size_list_value(.background_size, mut tokens)
		}
		.animation_composition {
			return parser.parse_animation_composition_value(mut tokens)
		}
		.animation_delay {
			return parser.parse_animation_delay_value(mut tokens)
		}
		.animation_direction {
			return parser.parse_animation_direction_value(mut tokens)
		}
		.animation_duration {
			return parser.parse_animation_duration_value(mut tokens)
		}
		.animation_fill_mode {
			return parser.parse_animation_fill_mode_value(mut tokens)
		}
		.animation_iteration_count {
			return parser.parse_animation_iteration_count_value(mut tokens)
		}
		.animation_name {
			return parser.parse_animation_name_value(mut tokens)
		}
		.animation_play_state {
			return parser.parse_animation_play_state_value(mut tokens)
		}
		.border_block_end_width, .border_block_start_width, .border_bottom_width,
		.border_inline_end_width, .border_inline_start_width, .border_left_width,
		.border_right_width, .border_top_width, .outline_width {
			return parser.parse_border_or_outline_width_value(mut tokens)
		}
		.border_block_end_style, .border_block_start_style, .border_bottom_style,
		.border_inline_end_style, .border_inline_start_style, .border_left_style,
		.border_right_style, .border_top_style {
			return parser.parse_line_style_value(mut tokens)
		}
		.border_bottom_left_radius, .border_bottom_right_radius, .border_end_end_radius,
		.border_end_start_radius, .border_start_end_radius, .border_start_start_radius,
		.border_top_left_radius, .border_top_right_radius {
			return parser.parse_border_radius_value(mut tokens)
		}
		.border_image_outset {
			return parser.parse_border_image_outset_value(mut tokens)
		}
		.border_image_repeat {
			return parser.parse_border_image_repeat_value(mut tokens)
		}
		.border_image_slice {
			return parser.parse_border_image_slice_value(mut tokens)
		}
		.border_image_width {
			return parser.parse_border_image_width_value(mut tokens)
		}
		.block_size, .height, .inline_size, .min_block_size, .min_height, .min_inline_size,
		.min_width, .width, .max_block_size, .max_height, .max_inline_size, .max_width {
			return parser.parse_sizing_value(property_id, mut tokens)
		}
		.bottom, .inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start,
		.left, .right, .top {
			return parser.parse_inset_value(mut tokens)
		}
		.margin_block_end, .margin_block_start, .margin_bottom, .margin_inline_end,
		.margin_inline_start, .margin_left, .margin_right, .margin_top {
			return parser.parse_margin_value(mut tokens)
		}
		.padding_block_end, .padding_block_start, .padding_bottom, .padding_inline_end,
		.padding_inline_start, .padding_left, .padding_right, .padding_top {
			return parser.parse_padding_value(mut tokens)
		}
		.border_spacing {
			return parser.parse_border_spacing_value(mut tokens)
		}
		.border_collapse {
			return parser.parse_border_collapse_value(mut tokens)
		}
		.box_sizing {
			return parser.parse_box_sizing_value(mut tokens)
		}
		.outline_offset {
			return parser.parse_length_value(mut tokens)
		}
		.outline_style {
			return parser.parse_outline_style_value(mut tokens)
		}
		.object_position, .perspective_origin {
			return parser.parse_css_position_value(mut tokens, .normal)
		}
		.overflow_block, .overflow_inline, .overflow_x, .overflow_y {
			return parser.parse_overflow_value(mut tokens)
		}
		.overflow_clip_margin_block_end, .overflow_clip_margin_block_start,
		.overflow_clip_margin_bottom, .overflow_clip_margin_inline_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_left,
		.overflow_clip_margin_right, .overflow_clip_margin_top {
			return parser.parse_overflow_clip_margin_value(mut tokens)
		}
		.overflow_wrap {
			return parser.parse_overflow_wrap_value(mut tokens)
		}
		.paint_order {
			return parser.parse_paint_order_value(mut tokens)
		}
		.perspective {
			return parser.parse_perspective_value(mut tokens)
		}
		.pointer_events {
			return parser.parse_pointer_events_value(mut tokens)
		}
		.position {
			return parser.parse_position_value(mut tokens)
		}
		.position_anchor {
			return parser.parse_position_anchor_value(mut tokens)
		}
		.position_area {
			return parser.parse_position_area_value(mut tokens)
		}
		.position_try_fallbacks {
			return parser.parse_position_try_fallbacks_value(mut tokens)
		}
		.position_try_order {
			return parser.parse_position_try_order_value(mut tokens)
		}
		.position_visibility {
			return parser.parse_position_visibility_value(mut tokens)
		}
		.background_color, .border_block_end_color, .border_block_start_color,
		.border_bottom_color, .border_inline_end_color, .border_inline_start_color,
		.border_left_color, .border_right_color, .border_top_color, .color, .flood_color,
		.outline_color, .stop_color, .webkit_text_fill_color {
			return parser.parse_color_value(mut tokens)
		}
		.color_scheme {
			return parser.parse_color_scheme_value(mut tokens)
		}
		.content_visibility {
			return parser.parse_content_visibility_value(mut tokens)
		}
		.contain {
			return parser.parse_contain_value(mut tokens)
		}
		.container_type {
			return parser.parse_container_type_value(mut tokens)
		}
		.corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape,
		.corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape,
		.corner_top_left_shape, .corner_top_right_shape {
			return parser.parse_corner_shape_value(mut tokens)
		}
		.fill_opacity, .flood_opacity, .opacity, .shape_image_threshold, .stop_opacity,
		.stroke_opacity {
			return parser.parse_opacity_value(mut tokens)
		}
		.animation_timeline {
			return parser.parse_animation_timeline_value(mut tokens)
		}
		.animation_timing_function {
			return parser.parse_animation_timing_function_value(mut tokens)
		}
		.aspect_ratio {
			return parser.parse_aspect_ratio_value(mut tokens)
		}
		.align_content {
			return parser.parse_align_content_value(mut tokens)
		}
		.align_items {
			return parser.parse_align_items_value(mut tokens)
		}
		.align_self {
			return parser.parse_align_self_value(mut tokens)
		}
		.appearance {
			return parser.parse_appearance_value(mut tokens)
		}
		.background_image, .mask_image {
			return parser.parse_image_or_none_list_value(mut tokens)
		}
		.font_feature_settings {
			return parser.parse_font_feature_settings_value(mut tokens)
		}
		.font_kerning {
			return parser.parse_font_kerning_value(mut tokens)
		}
		.font_language_override {
			return parser.parse_font_language_override_value(mut tokens)
		}
		.font_optical_sizing {
			return parser.parse_font_optical_sizing_value(mut tokens)
		}
		.font_style {
			return parser.parse_font_style_value(mut tokens)
		}
		.font_variant_caps {
			return parser.parse_font_variant_caps_value(mut tokens)
		}
		.font_variant_emoji {
			return parser.parse_font_variant_emoji_value(mut tokens)
		}
		.font_variant_position {
			return parser.parse_font_variant_position_value(mut tokens)
		}
		.font_variation_settings {
			return parser.parse_font_variation_settings_value(mut tokens)
		}
		.font_weight {
			return parser.parse_font_weight_value(mut tokens)
		}
		.font_width {
			return parser.parse_font_width_value(mut tokens)
		}
		.flex_direction {
			return parser.parse_flex_direction_value(mut tokens)
		}
		.flex_wrap {
			return parser.parse_flex_wrap_value(mut tokens)
		}
		.column_span {
			return parser.parse_column_span_value(mut tokens)
		}
		.column_count {
			return parser.parse_auto_or_positive_integer_value(mut tokens)
		}
		.column_width, .column_height {
			return parser.parse_auto_or_nonnegative_length_value(mut tokens)
		}
		.column_gap, .row_gap {
			return parser.parse_gap_value(mut tokens)
		}
		.flex_grow, .flex_shrink {
			return parser.parse_nonnegative_number_value(mut tokens)
		}
		.image_rendering {
			return parser.parse_image_rendering_value(mut tokens)
		}
		.justify_content {
			return parser.parse_justify_content_value(mut tokens)
		}
		.justify_items {
			return parser.parse_justify_items_value(mut tokens)
		}
		.justify_self {
			return parser.parse_justify_self_value(mut tokens)
		}
		.isolation {
			return parser.parse_isolation_value(mut tokens)
		}
		.letter_spacing, .word_spacing {
			return parser.parse_letter_or_word_spacing_value(mut tokens)
		}
		.line_height {
			return parser.parse_line_height_value(mut tokens)
		}
		.list_style_position {
			return parser.parse_list_style_position_value(mut tokens)
		}
		.order {
			return parser.parse_integer_value(mut tokens)
		}
		.orphans, .widows {
			return parser.parse_positive_integer_value(mut tokens)
		}
		.border_image_source, .list_style_image {
			return parser.parse_image_or_none_value(mut tokens)
		}
		.caption_side {
			return parser.parse_caption_side_value(mut tokens)
		}
		.clear {
			return parser.parse_clear_value(mut tokens)
		}
		.clip_rule {
			return parser.parse_fill_rule_value(mut tokens)
		}
		.color_interpolation {
			return parser.parse_color_interpolation_value(mut tokens)
		}
		.direction {
			return parser.parse_direction_value(mut tokens)
		}
		.empty_cells {
			return parser.parse_empty_cells_value(mut tokens)
		}
		.fill_rule {
			return parser.parse_fill_rule_value(mut tokens)
		}
		.float_ {
			return parser.parse_float_value(mut tokens)
		}
		.dominant_baseline {
			return parser.parse_dominant_baseline_value(mut tokens)
		}
		.display {
			return parser.parse_display_value(mut tokens)
		}
		.flex_basis {
			return parser.parse_flex_basis_value(mut tokens)
		}
		.quotes {
			return parser.parse_quotes_value(mut tokens)
		}
		.box_shadow {
			return parser.parse_box_shadow_value(mut tokens)
		}
		.text_shadow {
			return parser.parse_text_shadow_value(mut tokens)
		}
		.math_depth {
			return parser.parse_math_depth_value(mut tokens)
		}
		.math_shift {
			return parser.parse_math_shift_value(mut tokens)
		}
		.math_style {
			return parser.parse_math_style_value(mut tokens)
		}
		.mask_type {
			return parser.parse_mask_type_value(mut tokens)
		}
		.mask_composite {
			return parser.parse_mask_composite_value(mut tokens)
		}
		.mask_clip {
			return parser.parse_mask_clip_value(mut tokens)
		}
		.mask_mode {
			return parser.parse_mask_mode_value(mut tokens)
		}
		.mask_origin {
			return parser.parse_mask_origin_value(mut tokens)
		}
		.mask_position {
			return parser.parse_position_list_value(mut tokens, .normal)
		}
		.mask_repeat {
			return parser.parse_repeat_style_list_value(.mask_repeat, mut tokens)
		}
		.mask_size {
			return parser.parse_background_size_list_value(.mask_size, mut tokens)
		}
		.mix_blend_mode {
			return parser.parse_mix_blend_mode_value(mut tokens)
		}
		.object_fit {
			return parser.parse_object_fit_value(mut tokens)
		}
		.rotate {
			return parser.parse_rotate_value(mut tokens)
		}
		.scale {
			return parser.parse_scale_value(mut tokens)
		}
		.scrollbar_color {
			return parser.parse_scrollbar_color_value(mut tokens)
		}
		.scrollbar_gutter {
			return parser.parse_scrollbar_gutter_value(mut tokens)
		}
		.scrollbar_width {
			return parser.parse_scrollbar_width_value(mut tokens)
		}
		.shape_rendering {
			return parser.parse_shape_rendering_value(mut tokens)
		}
		.shape_margin, .r {
			return parser.parse_nonnegative_length_percentage_value(mut tokens)
		}
		.cx, .cy, .x, .y {
			return parser.parse_length_percentage_value(mut tokens)
		}
		.rx, .ry {
			return parser.parse_auto_or_nonnegative_length_percentage_value(mut tokens)
		}
		.scroll_timeline_name {
			return parser.parse_timeline_name_value(mut tokens)
		}
		.scroll_timeline_axis, .view_timeline_axis {
			return parser.parse_timeline_axis_value(mut tokens)
		}
		.scroll_behavior {
			return parser.parse_scroll_behavior_value(mut tokens)
		}
		.stroke_linecap {
			return parser.parse_stroke_linecap_value(mut tokens)
		}
		.stroke_linejoin {
			return parser.parse_stroke_linejoin_value(mut tokens)
		}
		.stroke_miterlimit {
			return parser.parse_nonnegative_number_value(mut tokens)
		}
		.stroke_width, .stroke_dashoffset {
			return parser.parse_nonnegative_number_or_length_percentage_value(mut tokens)
		}
		.table_layout {
			return parser.parse_table_layout_value(mut tokens)
		}
		.tab_size {
			return parser.parse_tab_size_value(mut tokens)
		}
		.text_align {
			return parser.parse_text_align_value(mut tokens)
		}
		.text_anchor {
			return parser.parse_text_anchor_value(mut tokens)
		}
		.text_decoration_line {
			return parser.parse_text_decoration_line_value(mut tokens)
		}
		.text_decoration_style {
			return parser.parse_text_decoration_style_value(mut tokens)
		}
		.text_decoration_color {
			return parser.parse_color_value(mut tokens)
		}
		.text_decoration_thickness {
			return parser.parse_text_decoration_thickness_value(mut tokens)
		}
		.text_underline_offset {
			return parser.parse_auto_or_length_percentage_value(mut tokens)
		}
		.text_underline_position {
			return parser.parse_text_underline_position_value(mut tokens)
		}
		.text_indent {
			return parser.parse_text_indent_value(mut tokens)
		}
		.text_justify {
			return parser.parse_text_justify_value(mut tokens)
		}
		.text_overflow {
			return parser.parse_text_overflow_value(mut tokens)
		}
		.text_rendering {
			return parser.parse_text_rendering_value(mut tokens)
		}
		.text_transform {
			return parser.parse_text_transform_value(mut tokens)
		}
		.text_wrap_mode {
			return parser.parse_text_wrap_mode_value(mut tokens)
		}
		.text_wrap_style {
			return parser.parse_text_wrap_style_value(mut tokens)
		}
		.transform {
			return parser.parse_transform_value(mut tokens)
		}
		.transform_box {
			return parser.parse_transform_box_value(mut tokens)
		}
		.transform_origin {
			return parser.parse_transform_origin_value(mut tokens)
		}
		.transform_style {
			return parser.parse_transform_style_value(mut tokens)
		}
		.transition_behavior {
			return parser.parse_transition_behavior_value(mut tokens)
		}
		.transition_delay {
			return parser.parse_transition_time_list_value(mut tokens, false)
		}
		.transition_duration {
			return parser.parse_transition_time_list_value(mut tokens, true)
		}
		.transition_property {
			return parser.parse_transition_property_value(mut tokens)
		}
		.transition_timing_function {
			return parser.parse_transition_timing_function_value(mut tokens)
		}
		.translate {
			return parser.parse_translate_value(mut tokens)
		}
		.timeline_scope {
			return parser.parse_timeline_scope_value(mut tokens)
		}
		.touch_action {
			return parser.parse_touch_action_value(mut tokens)
		}
		.unicode_bidi {
			return parser.parse_unicode_bidi_value(mut tokens)
		}
		.user_select {
			return parser.parse_user_select_value(mut tokens)
		}
		.view_timeline_inset {
			return parser.parse_view_timeline_inset_list_value(mut tokens)
		}
		.view_timeline_name {
			return parser.parse_timeline_name_value(mut tokens)
		}
		.view_transition_name {
			return parser.parse_view_transition_name_value(mut tokens)
		}
		.visibility {
			return parser.parse_visibility_value(mut tokens)
		}
		.vertical_align {
			return parser.parse_vertical_align_value(mut tokens)
		}
		.will_change {
			return parser.parse_will_change_value(mut tokens)
		}
		.writing_mode {
			return parser.parse_writing_mode_value(mut tokens)
		}
		.white_space_collapse {
			return parser.parse_white_space_collapse_value(mut tokens)
		}
		.white_space_trim {
			return parser.parse_white_space_trim_value(mut tokens)
		}
		.word_break {
			return parser.parse_word_break_value(mut tokens)
		}
		.z_index {
			return parser.parse_z_index_value(mut tokens)
		}
		.resize {
			return parser.parse_resize_value(mut tokens)
		}
	}

	return none
}

fn (mut parser Parser) parse_css_wide_keyword_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	token := tokens.consume() or { return none }
	if !token.is(.ident) {
		return none
	}
	keyword := keyword_from_string(token.token().ident()) or { return none }
	if !keyword.is_css_wide_keyword() {
		return none
	}
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_builtin_value(mut tokens ComponentValueStream) ?StyleValue {
	if value := parser.parse_easing_value(mut tokens) {
		return value
	}
	if value := parser.parse_keyword_value(mut tokens) {
		return value
	}
	if value := parser.parse_number_percentage_value(mut tokens) {
		return value
	}
	if value := parser.parse_length_percentage_value(mut tokens) {
		return value
	}
	if value := parser.parse_color_value(mut tokens) {
		return value
	}
	if value := parser.parse_string_value(mut tokens) {
		return StyleValue(value)
	}
	if value := parser.parse_image_value(mut tokens) {
		return style_value_from_css_image_source_for_value_logic(value)
	}
	return none
}

// https://www.w3.org/TR/css-values-4/#typedefs
fn (mut parser Parser) parse_value(type_ ValueType, mut tokens ComponentValueStream) ?StyleValue {
	return match type_ {
		.angle {
			parser.parse_angle_value(mut tokens)
		}
		.color {
			parser.parse_color_value(mut tokens)
		}
		.corner_shape {
			parser.parse_corner_shape_value(mut tokens)
		}
		.custom_ident {
			if value := parser.parse_custom_ident_value(mut tokens, []) {
				StyleValue(value)
			} else {
				none
			}
		}
		.dashed_ident {
			mut transaction := tokens.clone()
			value := parser.parse_custom_ident_value(mut transaction, []) or { return none }
			if !value.custom_ident().starts_with('--') {
				return none
			}
			tokens = transaction
			StyleValue(value)
		}
		.easing_function {
			parser.parse_easing_value(mut tokens)
		}
		.flex {
			parser.parse_flex_value(mut tokens)
		}
		.font_style {
			parser.parse_font_style_value(mut tokens)
		}
		.frequency {
			parser.parse_frequency_value(mut tokens)
		}
		.image {
			parse_image_value_for_syntax(mut tokens)
		}
		.integer {
			parser.parse_integer_value(mut tokens)
		}
		.length {
			parser.parse_length_value(mut tokens)
		}
		.length_percentage {
			parser.parse_length_percentage_value(mut tokens)
		}
		.number {
			parser.parse_number_value(mut tokens)
		}
		.opacity {
			parser.parse_opacity_value(mut tokens)
		}
		.percentage {
			parser.parse_percentage_value(mut tokens)
		}
		.ratio {
			parser.parse_ratio_value(mut tokens)
		}
		.resolution {
			parser.parse_resolution_value(mut tokens)
		}
		.scroll_function {
			mut transaction := tokens.clone()
			transaction.consume_whitespace()
			component_value := transaction.consume() or { return none }
			value := parser.parse_scroll_function_value(component_value) or { return none }
			tokens = transaction
			StyleValue(value)
		}
		.string {
			if value := parser.parse_string_value(mut tokens) {
				StyleValue(value)
			} else {
				none
			}
		}
		.time {
			parser.parse_time_value(mut tokens)
		}
		.transform_function {
			parser.parse_transform_function_value(mut tokens)
		}
		.transform_list {
			parser.parse_transform_list_value(mut tokens)
		}
		.url {
			parse_url_value_for_syntax(mut tokens)
		}
		.view_function {
			mut transaction := tokens.clone()
			transaction.consume_whitespace()
			component_value := transaction.consume() or { return none }
			value := parser.parse_view_function_value(component_value) or { return none }
			tokens = transaction
			StyleValue(value)
		}
		.view_timeline_inset {
			parser.parse_view_timeline_inset_value(mut tokens)
		}
		else {
			none
		}
	}
}

fn (mut stream ComponentValueStream) consume_remaining_component_values() []ComponentValue {
	remaining_values := stream.values[stream.index..].clone()
	stream.index = stream.values.len
	return remaining_values
}

fn parse_animation_keyword_list_for_value_logic(mut tokens ComponentValueStream, allowed_keywords []string) ?StyleValue {
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut keywords := []StyleValue{}
	for value in values {
		mut keyword_tokens := ComponentValueStream.new(value)
		keyword_tokens.consume_whitespace()
		token := keyword_tokens.consume() or { return none }
		if !token.is(.ident) {
			return none
		}
		keyword_text := to_ascii_lowercase(token.token().ident())
		if keyword_text !in allowed_keywords {
			return none
		}
		keyword := keyword_from_string(keyword_text) or { return none }
		keyword_tokens.consume_whitespace()
		if keyword_tokens.has_more_tokens() {
			return none
		}
		keywords << StyleValue(KeywordStyleValue.create(keyword))
	}

	if keywords.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(keywords, .comma, .yes))
}

fn (mut parser Parser) parse_animation_composition_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-animations-2/#animation-composition
	// replace | add | accumulate
	return parse_animation_keyword_list_for_value_logic(mut tokens,
		['replace', 'add', 'accumulate'])
}

fn (mut parser Parser) parse_animation_delay_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_transition_time_list_value(mut tokens, false)
}

fn (mut parser Parser) parse_animation_direction_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-animations-1/#animation-direction
	// normal | reverse | alternate | alternate-reverse
	return parse_animation_keyword_list_for_value_logic(mut tokens, ['normal', 'reverse', 'alternate',
		'alternate-reverse'])
}

fn (mut parser Parser) parse_animation_duration_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-animations-2/#animation-duration
	// auto | <time [0s,∞]>
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut durations := []StyleValue{}
	for value in values {
		mut duration_tokens := ComponentValueStream.new(value)
		duration_tokens.consume_whitespace()
		if token := duration_tokens.peek() {
			if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'auto') {
				duration_tokens.consume()
				duration_tokens.consume_whitespace()
				if duration_tokens.has_more_tokens() {
					return none
				}
				durations << StyleValue(KeywordStyleValue.create(.auto))
				continue
			}
		}

		time_value := parser.parse_time_value(mut duration_tokens) or { return none }
		duration_tokens.consume_whitespace()
		if duration_tokens.has_more_tokens() {
			return none
		}
		if time_value is TimeStyleValue && time_value.time().to_seconds() < 0 {
			return none
		}
		durations << time_value
	}

	if durations.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(durations, .comma, .yes))
}

fn (mut parser Parser) parse_animation_fill_mode_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-animations-1/#animation-fill-mode
	// none | forwards | backwards | both
	return parse_animation_keyword_list_for_value_logic(mut tokens, ['none', 'forwards', 'backwards',
		'both'])
}

fn (mut parser Parser) parse_animation_iteration_count_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-animations-1/#animation-iteration-count
	// infinite | <number [0,∞]>
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut iteration_counts := []StyleValue{}
	for value in values {
		mut iteration_tokens := ComponentValueStream.new(value)
		iteration_tokens.consume_whitespace()
		if token := iteration_tokens.peek() {
			if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'infinite') {
				iteration_tokens.consume()
				iteration_tokens.consume_whitespace()
				if iteration_tokens.has_more_tokens() {
					return none
				}
				iteration_counts << StyleValue(KeywordStyleValue.create(.infinite))
				continue
			}
		}

		number_value := parser.parse_number_value(mut iteration_tokens) or { return none }
		iteration_tokens.consume_whitespace()
		if iteration_tokens.has_more_tokens() {
			return none
		}
		if number_value is NumberStyleValue && number_value.number() < 0 {
			return none
		}
		iteration_counts << number_value
	}

	if iteration_counts.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(iteration_counts, .comma, .yes))
}

fn (mut parser Parser) parse_animation_play_state_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-animations-1/#animation-play-state
	// running | paused
	return parse_animation_keyword_list_for_value_logic(mut tokens, ['running', 'paused'])
}

fn (mut parser Parser) parse_animation_timing_function_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_transition_timing_function_value(mut tokens)
}

fn parse_animation_name_entry_for_value_logic(values []ComponentValue) ?StyleValue {
	mut tokens := ComponentValueStream.new(values)
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	result := if component_value.is(.ident) {
		ident := component_value.token().ident()
		if equals_ignoring_ascii_case(ident, 'none') {
			StyleValue(KeywordStyleValue.create(.none_))
		} else {
			StyleValue(CustomIdentStyleValue.create(ident))
		}
	} else if component_value.is(.string) {
		StyleValue(StringStyleValue.create(component_value.token().string_value()))
	} else {
		return none
	}
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	return result
}

fn (mut parser Parser) parse_animation_name_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-animations-1/#animation-name
	// list, each item either a case-sensitive css identifier or the keyword none
	mut transaction := tokens.clone()
	name_values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())
	mut names := []StyleValue{}
	for values in name_values {
		names << (parse_animation_name_entry_for_value_logic(values) or { return none })
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(names, .comma, .yes))
}

fn (mut parser Parser) parse_aspect_ratio_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://www.w3.org/TR/css-sizing-4/#aspect-ratio
	// `auto || <ratio>`
	mut transaction := tokens.clone()
	mut auto_value := ?StyleValue(none)
	mut ratio_value := ?StyleValue(none)
	mut auto_value_set := false
	mut ratio_value_set := false

	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}

		mut value_transaction := transaction.clone()
		if value := parser.parse_ratio_value(mut value_transaction) {
			if ratio_value_set {
				return none
			}
			ratio_value = value
			ratio_value_set = true
			transaction = value_transaction
			continue
		}

		value_transaction = transaction.clone()
		if value := parser.parse_keyword_value(mut value_transaction) {
			if value.to_keyword() == .auto {
				if auto_value_set {
					return none
				}
				auto_value = value
				auto_value_set = true
				transaction = value_transaction
				continue
			}
		}

		return none
	}

	if resolved_auto := auto_value {
		if resolved_ratio := ratio_value {
			tokens = transaction
			return StyleValue(StyleValueList.create([resolved_auto, resolved_ratio], .space, .yes))
		}
		tokens = transaction
		return resolved_auto
	}

	if resolved_ratio := ratio_value {
		tokens = transaction
		return resolved_ratio
	}

	return none
}

fn parse_single_keyword_value_for_value_logic(mut tokens ComponentValueStream, keyword Keyword) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	token := transaction.consume() or { return none }
	if !token.is(.ident)
		|| !equals_ignoring_ascii_case(token.token().ident(), string_from_keyword(keyword)) {
		return none
	}
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}
	tokens = transaction
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_dashed_ident_value(mut tokens ComponentValueStream, blacklist []string) ?StyleValue {
	value := parser.parse_custom_ident_value(mut tokens, blacklist) or { return none }
	if !value.custom_ident().starts_with('--') {
		return none
	}
	return StyleValue(value)
}

fn (mut parser Parser) parse_dashed_ident_comma_list_value(mut tokens ComponentValueStream, blacklist []string) ?StyleValue {
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut idents := []StyleValue{}
	for value in values {
		mut item_tokens := ComponentValueStream.new(value)
		ident := parser.parse_dashed_ident_value(mut item_tokens, blacklist) or { return none }
		item_tokens.consume_whitespace()
		if item_tokens.has_more_tokens() {
			return none
		}
		idents << ident
	}

	if idents.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(idents, .comma, .yes))
}

fn (mut parser Parser) parse_anchor_name_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-anchor-position/#name
	// none | <dashed-ident>#
	if none_value := parse_single_keyword_value_for_value_logic(mut tokens, .none_) {
		return none_value
	}

	return parser.parse_dashed_ident_comma_list_value(mut tokens, ['none'])
}

fn (mut parser Parser) parse_anchor_scope_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-anchor-position/#anchor-scope
	// none | all | <dashed-ident>#
	if none_value := parse_single_keyword_value_for_value_logic(mut tokens, .none_) {
		return none_value
	}

	if all_value := parse_single_keyword_value_for_value_logic(mut tokens, .all) {
		return all_value
	}

	return parser.parse_dashed_ident_comma_list_value(mut tokens, ['none', 'all'])
}

fn (mut parser Parser) parse_position_anchor_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-anchor-position/#position-anchor
	// auto | <anchor-name>
	if auto_value := parse_single_keyword_value_for_value_logic(mut tokens, .auto) {
		return auto_value
	}

	// <anchor-name> = <dashed-ident>
	return parser.parse_dashed_ident_value(mut tokens, ['auto'])
}

fn (mut parser Parser) parse_timeline_name_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | <dashed-ident>#
	if none_value := parse_single_keyword_value_for_value_logic(mut tokens, .none_) {
		return none_value
	}

	return parser.parse_dashed_ident_comma_list_value(mut tokens, ['none'])
}

fn (mut parser Parser) parse_view_timeline_inset_list_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut insets := []StyleValue{}
	for value in values {
		mut item_tokens := ComponentValueStream.new(value)
		inset := parser.parse_view_timeline_inset_value(mut item_tokens) or { return none }
		item_tokens.consume_whitespace()
		if item_tokens.has_more_tokens() {
			return none
		}
		insets << inset
	}

	if insets.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(insets, .comma, .yes))
}

fn (mut parser Parser) parse_transition_property_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-transitions/#transition-property-property
	// none | <single-transition-property>#
	mut none_transaction := tokens.clone()
	none_transaction.consume_whitespace()
	if none_token := none_transaction.consume() {
		if none_token.is(.ident) && equals_ignoring_ascii_case(none_token.token().ident(), 'none') {
			none_transaction.consume_whitespace()
			if !none_transaction.has_more_tokens() {
				tokens = none_transaction
				return StyleValue(StyleValueList.create([
					StyleValue(KeywordStyleValue.create(.none_)),
				], .comma, .yes))
			}
		}
	}

	mut transaction := tokens.clone()
	transition_property_values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut transition_properties := []StyleValue{}
	for value in transition_property_values {
		mut transition_property_tokens := ComponentValueStream.new(value)
		custom_ident := parser.parse_custom_ident_value(mut transition_property_tokens, [
			'none',
		]) or { return none }
		transition_property_tokens.consume_whitespace()
		if transition_property_tokens.has_more_tokens() {
			return none
		}
		transition_properties << StyleValue(custom_ident)
	}

	if transition_properties.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(transition_properties, .comma, .yes))
}

fn (mut parser Parser) parse_transition_time_list_value(mut tokens ComponentValueStream, non_negative bool) ?StyleValue {
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut times := []StyleValue{}
	for value in values {
		mut time_tokens := ComponentValueStream.new(value)
		time_value := parser.parse_time_value(mut time_tokens) or { return none }
		time_tokens.consume_whitespace()
		if time_tokens.has_more_tokens() {
			return none
		}
		if non_negative && time_value is TimeStyleValue && time_value.time().to_seconds() < 0 {
			return none
		}
		times << time_value
	}

	if times.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(times, .comma, .yes))
}

fn parse_transition_timing_keyword(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	token := transaction.consume() or { return none }
	if !token.is(.ident) {
		return none
	}
	keyword := transition_timing_keyword_from_string(token.token().ident()) or { return none }

	tokens = transaction
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_transition_timing_function_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut timing_functions := []StyleValue{}
	for value in values {
		mut timing_tokens := ComponentValueStream.new(value)
		mut timing_function := ?StyleValue(none)
		if easing := parser.parse_easing_value(mut timing_tokens) {
			timing_function = easing
		} else if keyword := parse_transition_timing_keyword(mut timing_tokens) {
			timing_function = keyword
		} else {
			return none
		}
		timing_tokens.consume_whitespace()
		if timing_tokens.has_more_tokens() {
			return none
		}
		timing_functions << timing_function or { return none }
	}

	if timing_functions.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(timing_functions, .comma, .yes))
}

fn (mut parser Parser) parse_transition_behavior_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut behaviors := []StyleValue{}
	for value in values {
		mut behavior_tokens := ComponentValueStream.new(value)
		behavior_tokens.consume_whitespace()
		token := behavior_tokens.consume() or { return none }
		if !token.is(.ident) {
			return none
		}
		keyword := transition_behavior_keyword_from_string(token.token().ident()) or { return none }

		behavior_tokens.consume_whitespace()
		if behavior_tokens.has_more_tokens() {
			return none
		}
		behaviors << StyleValue(KeywordStyleValue.create(keyword))
	}

	if behaviors.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(behaviors, .comma, .yes))
}

fn transition_timing_keyword_from_string(value string) ?Keyword {
	return match to_ascii_lowercase(value) {
		'linear' { Keyword.linear }
		'ease' { Keyword.ease }
		'ease-in' { Keyword.ease_in }
		'ease-out' { Keyword.ease_out }
		'ease-in-out' { Keyword.ease_in_out }
		else { none }
	}
}

fn transition_behavior_keyword_from_string(value string) ?Keyword {
	return match to_ascii_lowercase(value) {
		'normal' { Keyword.normal }
		'allow-discrete' { Keyword.allow_discrete }
		else { none }
	}
}

fn parse_keyword_as_custom_ident_for_value_logic(mut tokens ComponentValueStream, allowed_keywords []string) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	ident := to_ascii_lowercase(component_value.token().ident())
	if ident !in allowed_keywords {
		return none
	}
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	return StyleValue(CustomIdentStyleValue.create(ident))
}

fn numeric_style_value_from_css_text_for_value_logic(text string) ?StyleValue {
	numeric_value := CSSNumericValue.parse(text) or { return none }
	return computed_interpolation_style_value_from_css_numeric_value(numeric_value)
}

fn (mut parser Parser) parse_border_or_outline_width_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parser.parse_length_value(mut transaction) {
		tokens = transaction
		return value
	}
	return parse_keyword_as_custom_ident_for_value_logic(mut tokens, ['thin', 'medium', 'thick'])
}

fn (mut parser Parser) parse_outline_style_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'none', 'dotted', 'dashed', 'solid',
		'double', 'groove', 'ridge', 'inset', 'outset'])
}

fn (mut parser Parser) parse_line_style_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['none', 'hidden', 'dotted', 'dashed', 'solid',
		'double', 'groove', 'ridge', 'inset', 'outset'])
}

fn (mut parser Parser) parse_overflow_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'clip', 'hidden', 'scroll', 'visible',
		'overlay'])
}

fn (mut parser Parser) parse_overflow_wrap_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['anywhere', 'break-word', 'normal'])
}

fn (mut parser Parser) parse_pointer_events_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'all', 'none'])
}

fn (mut parser Parser) parse_clear_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['none', 'left', 'right', 'both', 'inline-start',
		'inline-end'])
}

fn (mut parser Parser) parse_float_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['none', 'left', 'right', 'inline-start',
		'inline-end'])
}

fn (mut parser Parser) parse_dominant_baseline_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'text-bottom', 'alphabetic',
		'ideographic', 'middle', 'central', 'mathematical', 'hanging', 'text-top'])
}

fn (mut parser Parser) parse_box_shadow_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_shadow_value(mut tokens, .normal)
}

fn (mut parser Parser) parse_text_shadow_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_shadow_value(mut tokens, .text)
}

// https://drafts.csswg.org/css-backgrounds/#propdef-box-shadow
// https://drafts.csswg.org/css-text-decor/#propdef-text-shadow
fn (mut parser Parser) parse_shadow_value(mut tokens ComponentValueStream, shadow_type ShadowType) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())
	mut shadows := []StyleValue{}
	for value in values {
		mut shadow_tokens := ComponentValueStream.new(value)
		shadow := parser.parse_single_shadow_value(mut shadow_tokens, shadow_type) or { return none }
		shadows << shadow
	}
	if shadows.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(shadows, .comma, .yes))
}

fn (mut parser Parser) parse_single_shadow_value(mut tokens ComponentValueStream, shadow_type ShadowType) ?StyleValue {
	mut transaction := tokens.clone()

	mut color := ?StyleValue(none)
	mut offset_x := ?StyleValue(none)
	mut offset_y := ?StyleValue(none)
	mut blur_radius := ?StyleValue(none)
	mut spread_distance := ?StyleValue(none)
	mut placement := ?ShadowPlacement(none)

	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}

		if maybe_color := parser.parse_color_value(mut transaction) {
			if color != none {
				return none
			}
			color = maybe_color
			continue
		}

		if maybe_offset_x := parser.parse_length_value(mut transaction) {
			if offset_x != none {
				return none
			}
			offset_x = maybe_offset_x

			// Vertical offset is required.
			transaction.consume_whitespace()
			if !transaction.has_more_tokens() {
				return none
			}
			offset_y = parser.parse_length_value(mut transaction) or { return none }

			// Blur radius (optional).
			transaction.consume_whitespace()
			if !transaction.has_more_tokens() {
				break
			}
			maybe_blur := parser.parse_length_value(mut transaction) or { continue }
			if maybe_blur is LengthStyleValue && maybe_blur.raw_value() < 0 {
				return none
			}
			blur_radius = maybe_blur

			// Spread distance (optional, not allowed for text shadows).
			transaction.consume_whitespace()
			if !transaction.has_more_tokens() {
				break
			}
			maybe_spread := parser.parse_length_value(mut transaction) or { continue }
			if shadow_type == .text {
				return none
			}
			spread_distance = maybe_spread
			continue
		}

		token := transaction.peek() or { return none }
		if shadow_type == .normal && token.is(.ident)
			&& equals_ignoring_ascii_case(token.token().ident(), 'inset') {
			if placement != none {
				return none
			}
			placement = ShadowPlacement.inner
			transaction.consume()
			continue
		}

		if token.is(.comma) {
			break
		}

		return none
	}

	// x/y offsets are required.
	resolved_offset_x := offset_x or { return none }
	resolved_offset_y := offset_y or { return none }
	resolved_placement := placement or { ShadowPlacement.outer }

	tokens = transaction
	return StyleValue(ShadowStyleValue.create(shadow_type, color, resolved_offset_x, resolved_offset_y,
		blur_radius, spread_distance, resolved_placement))
}

// https://drafts.csswg.org/css-content/#propdef-quotes
fn (mut parser Parser) parse_quotes_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto', 'none']) {
		tokens = transaction
		return value
	}

	// [ <string> <string> ]+
	transaction = tokens.clone()
	mut strings := []StyleValue{}
	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
		string_value := parser.parse_string_value(mut transaction) or { return none }
		strings << StyleValue(string_value)
	}
	if strings.len == 0 || strings.len % 2 != 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(strings, .space, .no))
}

// https://drafts.csswg.org/css-flexbox-1/#propdef-flex-basis
fn (mut parser Parser) parse_flex_basis_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto', 'content']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parse_stub_keyword_from_set_for_value_logic(mut transaction, ['max-content',
		'min-content'])
	{
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parser.parse_fit_content_value(mut transaction) {
		tokens = transaction
		return value
	}

	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

// https://drafts.csswg.org/css-display/#the-display-properties
fn (mut parser Parser) parse_display_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	mut idents := []string{}
	for {
		transaction.consume_whitespace()
		component_value := transaction.consume() or { break }
		if !component_value.is(.ident) {
			return none
		}
		idents << to_ascii_lowercase(component_value.token().ident())
	}
	if idents.len == 0 {
		return none
	}

	display := if idents.len == 1 {
		display_from_single_keyword_string(idents[0]) or { return none }
	} else {
		display_from_multi_keyword_strings(idents) or { return none }
	}

	tokens = transaction
	return StyleValue(DisplayStyleValue.create(display))
}

fn (mut parser Parser) parse_position_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['absolute', 'fixed', 'relative', 'static',
		'sticky'])
}

fn (mut parser Parser) parse_caption_side_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['top', 'bottom'])
}

fn (mut parser Parser) parse_border_collapse_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['collapse', 'separate'])
}

fn (mut parser Parser) parse_box_sizing_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['border-box', 'content-box'])
}

fn (mut parser Parser) parse_fill_rule_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['nonzero', 'evenodd'])
}

fn (mut parser Parser) parse_color_interpolation_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'linearrgb', 'srgb'])
}

fn (mut parser Parser) parse_direction_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['ltr', 'rtl'])
}

fn (mut parser Parser) parse_empty_cells_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['show', 'hide'])
}

fn (mut parser Parser) parse_isolation_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'isolate'])
}

fn (mut parser Parser) parse_list_style_position_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['inside', 'outside'])
}

fn (mut parser Parser) parse_mask_type_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['luminance', 'alpha'])
}

fn (mut parser Parser) parse_shape_rendering_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'optimizespeed', 'crispedges',
		'geometricprecision'])
}

fn (mut parser Parser) parse_stroke_linecap_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['butt', 'round', 'square'])
}

fn (mut parser Parser) parse_stroke_linejoin_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['miter', 'round', 'bevel'])
}

fn (mut parser Parser) parse_table_layout_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'fixed'])
}

fn (mut parser Parser) parse_text_anchor_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['start', 'middle', 'end'])
}

fn (mut parser Parser) parse_text_align_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['center', 'justify', 'start', 'end', 'left',
		'right', 'match-parent', '-libweb-center', '-libweb-inherit-or-center', '-libweb-left',
		'-libweb-right'])
}

fn (mut parser Parser) parse_text_justify_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens,
		['auto', 'none', 'inter-word', 'inter-character'])
}

fn (mut parser Parser) parse_text_overflow_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['clip', 'ellipsis'])
}

fn (mut parser Parser) parse_text_rendering_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'optimizespeed', 'optimizelegibility',
		'geometricprecision'])
}

fn (mut parser Parser) parse_text_transform_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['capitalize', 'full-size-kana', 'full-width',
		'lowercase', 'math-auto', 'none', 'uppercase'])
}

fn (mut parser Parser) parse_text_wrap_mode_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['wrap', 'nowrap'])
}

fn (mut parser Parser) parse_text_wrap_style_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'balance', 'stable', 'pretty'])
}

fn (mut parser Parser) parse_transform_style_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['flat', 'preserve-3d'])
}

fn (mut parser Parser) parse_unicode_bidi_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['bidi-override', 'embed', 'isolate',
		'isolate-override', 'normal', 'plaintext'])
}

fn (mut parser Parser) parse_user_select_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['all', 'auto', 'contain', 'none', 'text'])
}

fn (mut parser Parser) parse_visibility_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['collapse', 'hidden', 'visible'])
}

fn (mut parser Parser) parse_white_space_collapse_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['collapse', 'discard', 'preserve',
		'preserve-breaks', 'preserve-spaces', 'break-spaces'])
}

fn (mut parser Parser) parse_white_space_trim_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	if value := parse_property_keyword_value(mut tokens, ['none']) {
		return value
	}

	mut transaction := tokens.clone()
	mut values := []StyleValue{}
	mut discard_before := false
	mut discard_after := false
	mut discard_inner := false

	for {
		transaction.consume_whitespace()
		component_value := transaction.consume() or { break }
		if !component_value.is(.ident) {
			return none
		}
		ident := to_ascii_lowercase(component_value.token().ident())
		keyword := match ident {
			'discard-before' {
				if discard_before {
					return none
				}
				discard_before = true
				Keyword.discard_before
			}
			'discard-after' {
				if discard_after {
					return none
				}
				discard_after = true
				Keyword.discard_after
			}
			'discard-inner' {
				if discard_inner {
					return none
				}
				discard_inner = true
				Keyword.discard_inner
			}
			else {
				return none
			}
		}

		values << StyleValue(KeywordStyleValue.create(keyword))
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
	}

	if values.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn (mut parser Parser) parse_word_break_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens,
		['normal', 'keep-all', 'break-all', 'break-word'])
}

fn (mut parser Parser) parse_z_index_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}

	return parser.parse_integer_value(mut tokens)
}

fn (mut parser Parser) parse_mix_blend_mode_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, [
		'normal',
		'multiply',
		'screen',
		'overlay',
		'darken',
		'lighten',
		'color-dodge',
		'color-burn',
		'hard-light',
		'soft-light',
		'difference',
		'exclusion',
		'hue',
		'saturation',
		'color',
		'luminosity',
		'plus-darker',
		'plus-lighter',
	])
}

fn (mut parser Parser) parse_object_fit_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens,
		['fill', 'contain', 'cover', 'none', 'scale-down'])
}

fn (mut parser Parser) parse_align_content_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['normal', 'start', 'flex-start', 'end',
		'flex-end', 'center', 'space-between', 'space-around', 'space-evenly', 'stretch'])
}

fn (mut parser Parser) parse_align_items_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['baseline', 'center', 'end', 'flex-end',
		'flex-start', 'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe'])
}

fn (mut parser Parser) parse_align_self_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'baseline', 'center', 'end', 'flex-end',
		'flex-start', 'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe'])
}

fn (mut parser Parser) parse_appearance_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'button', 'checkbox', 'listbox',
		'menulist', 'meter', 'menulist-button', 'none', 'push-button', 'progress-bar', 'radio',
		'searchfield', 'slider-horizontal', 'square-button', 'textarea', 'textfield'])
}

fn (mut parser Parser) parse_column_span_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['none', 'all'])
}

fn (mut parser Parser) parse_flex_direction_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens,
		['row', 'row-reverse', 'column', 'column-reverse'])
}

fn (mut parser Parser) parse_flex_wrap_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['nowrap', 'wrap', 'wrap-reverse'])
}

fn (mut parser Parser) parse_image_rendering_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'crisp-edges', 'high-quality',
		'pixelated', 'smooth', 'optimizespeed', 'optimizequality'])
}

fn (mut parser Parser) parse_justify_content_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['normal', 'start', 'end', 'flex-start',
		'flex-end', 'center', 'space-between', 'space-around', 'space-evenly', 'stretch', 'left',
		'right'])
}

fn (mut parser Parser) parse_justify_items_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['baseline', 'center', 'end', 'flex-end',
		'flex-start', 'legacy', 'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch',
		'unsafe', 'left', 'right'])
}

fn (mut parser Parser) parse_justify_self_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'baseline', 'center', 'end', 'flex-end',
		'flex-start', 'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe',
		'left', 'right'])
}

fn (mut parser Parser) parse_transform_box_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['content-box', 'border-box', 'fill-box',
		'stroke-box', 'view-box'])
}

fn (mut parser Parser) parse_writing_mode_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['horizontal-tb', 'vertical-rl', 'vertical-lr',
		'sideways-rl', 'sideways-lr'])
}

fn (mut parser Parser) parse_scrollbar_width_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'thin', 'none'])
}

fn (mut parser Parser) parse_scroll_behavior_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'smooth'])
}

fn (mut parser Parser) parse_resize_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['none', 'both', 'horizontal', 'vertical',
		'inline', 'block'])
}

// https://drafts.csswg.org/css-overflow-4/#overflow-clip-margin
fn (mut parser Parser) parse_overflow_clip_margin_value(mut tokens ComponentValueStream) ?StyleValue {
	// <visual-box> || <length [0,∞]>
	// FIXME: Implement the <visual-box> part of this.
	return parser.parse_nonnegative_length_value(mut tokens)
}

fn (mut parser Parser) parse_perspective_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none']) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_value(mut tokens)
}

fn (mut parser Parser) parse_tab_size_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parser.parse_nonnegative_length_value(mut transaction) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_number_value(mut tokens)
}

fn (mut parser Parser) parse_vertical_align_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, [
		'baseline',
		'sub',
		'super',
		'text-top',
		'text-bottom',
		'middle',
		'top',
		'bottom',
	])
	{
		tokens = transaction
		return value
	}
	return parser.parse_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_scrollbar_color_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}

	thumb_color := parser.parse_color_value(mut transaction) or { return none }
	track_color := parser.parse_color_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}
	tokens = transaction
	return StyleValue(ScrollbarColorStyleValue.create(thumb_color, track_color))
}

fn parse_scrollbar_gutter_ident_for_value_logic(mut tokens ComponentValueStream, ident string) bool {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return false }
	if !component_value.is(.ident)
		|| !equals_ignoring_ascii_case(component_value.token().ident(), ident) {
		return false
	}
	tokens = transaction
	return true
}

fn (mut parser Parser) parse_scrollbar_gutter_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// auto | stable && both-edges?
	mut transaction := tokens.clone()
	mut stable := ?bool(none)
	mut both_edges := ?bool(none)

	if parse_scrollbar_gutter_ident_for_value_logic(mut transaction, 'auto') {
		stable = false
	} else if parse_scrollbar_gutter_ident_for_value_logic(mut transaction, 'stable') {
		stable = true
		if parse_scrollbar_gutter_ident_for_value_logic(mut transaction, 'both-edges') {
			both_edges = true
		}
	} else if parse_scrollbar_gutter_ident_for_value_logic(mut transaction, 'both-edges') {
		both_edges = true
		if !parse_scrollbar_gutter_ident_for_value_logic(mut transaction, 'stable') {
			return none
		}
		stable = true
	}

	transaction.consume_whitespace()
	if stable == none || transaction.has_more_tokens() {
		return none
	}
	tokens = transaction
	if both_edges != none {
		return StyleValue(ScrollbarGutterStyleValue.create(.both_edges))
	}
	if stable or { false } {
		return StyleValue(ScrollbarGutterStyleValue.create(.stable))
	}
	return StyleValue(ScrollbarGutterStyleValue.create(.auto_))
}

// https://drafts.csswg.org/css-text-decor-4/#text-underline-position-property
fn (mut parser Parser) parse_text_underline_position_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// auto | [ from-font | under ] || [ left | right ]
	mut transaction := tokens.clone()
	if parse_scrollbar_gutter_ident_for_value_logic(mut transaction, 'auto') {
		transaction.consume_whitespace()
		if transaction.has_more_tokens() {
			return none
		}
		tokens = transaction
		return StyleValue(TextUnderlinePositionStyleValue.create(.auto_, .auto_))
	}

	transaction = tokens.clone()
	mut horizontal_value := TextUnderlinePositionHorizontal.auto_
	mut vertical_value := TextUnderlinePositionVertical.auto_
	mut has_horizontal := false
	mut has_vertical := false
	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		component_value := transaction.consume() or { return none }
		if !component_value.is(.ident) {
			return none
		}
		ident := to_ascii_lowercase(component_value.token().ident())
		match ident {
			'from-font' {
				if has_horizontal {
					return none
				}
				horizontal_value = .from_font
				has_horizontal = true
			}
			'under' {
				if has_horizontal {
					return none
				}
				horizontal_value = .under
				has_horizontal = true
			}
			'left' {
				if has_vertical {
					return none
				}
				vertical_value = .left
				has_vertical = true
			}
			'right' {
				if has_vertical {
					return none
				}
				vertical_value = .right
				has_vertical = true
			}
			else {
				return none
			}
		}

		transaction.consume_whitespace()
	}

	if !has_horizontal && !has_vertical {
		return none
	}
	tokens = transaction
	return StyleValue(TextUnderlinePositionStyleValue.create(horizontal_value, vertical_value))
}

fn parse_stub_keyword_list_for_value_logic(mut tokens ComponentValueStream, allowed []string) ?StyleValue {
	mut transaction := tokens.clone()
	mut values := []StyleValue{}
	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		value := parse_stub_keyword_from_set_for_value_logic(mut transaction, allowed) or {
			return none
		}
		values << value
		transaction.consume_whitespace()
	}
	if values.len == 0 {
		return none
	}
	tokens = transaction
	if values.len == 1 {
		return values[0]
	}
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn position_area_keywords_for_value_logic() []string {
	return [
		'left',
		'center',
		'right',
		'span-left',
		'span-right',
		'x-start',
		'x-end',
		'span-x-start',
		'span-x-end',
		'self-x-start',
		'self-x-end',
		'span-self-x-start',
		'span-self-x-end',
		'span-all',
		'top',
		'bottom',
		'span-top',
		'span-bottom',
		'y-start',
		'y-end',
		'span-y-start',
		'span-y-end',
		'self-y-start',
		'self-y-end',
		'span-self-y-start',
		'span-self-y-end',
		'block-start',
		'block-end',
		'span-block-start',
		'span-block-end',
		'inline-start',
		'inline-end',
		'span-inline-start',
		'span-inline-end',
		'self-block-start',
		'self-block-end',
		'span-self-block-start',
		'span-self-block-end',
		'self-inline-start',
		'self-inline-end',
		'span-self-inline-start',
		'span-self-inline-end',
		'start',
		'end',
		'span-start',
		'span-end',
		'self-start',
		'self-end',
		'span-self-start',
		'span-self-end',
	]
}

fn (mut parser Parser) parse_position_area(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// <position-area> = one or two position-area keywords, with axis-compatible
	// validation deferred until the full generated keyword table is translated.
	return parse_stub_keyword_list_for_value_logic(mut tokens,
		position_area_keywords_for_value_logic())
}

fn (mut parser Parser) parse_position_area_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | <position-area>
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none']) {
		tokens = transaction
		return value
	}
	return parser.parse_position_area(mut tokens)
}

fn (mut parser Parser) parse_try_tactic_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// <try-tactic> = flip-block || flip-inline || flip-start
	return parse_stub_keyword_list_for_value_logic(mut tokens, ['flip-block', 'flip-inline',
		'flip-start'])
}

fn (mut parser Parser) parse_single_position_try_fallbacks_value(mut tokens ComponentValueStream) ?StyleValue {
	// [<dashed-ident> || <try-tactic>] | <position-area>
	mut transaction := tokens.clone()
	if value := parser.parse_position_area(mut transaction) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	mut dashed_ident := ?StyleValue(none)
	mut try_tactic := ?StyleValue(none)
	mut has_dashed_ident := false
	mut has_try_tactic := false
	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		mut try_transaction := transaction.clone()
		if value := parser.parse_try_tactic_value(mut try_transaction) {
			if has_try_tactic {
				return none
			}
			try_tactic = value
			has_try_tactic = true
			transaction = try_transaction
			transaction.consume_whitespace()
			continue
		}
		mut dashed_transaction := transaction.clone()
		if value := parser.parse_dashed_ident_value(mut dashed_transaction, []) {
			if has_dashed_ident {
				return none
			}
			dashed_ident = value
			has_dashed_ident = true
			transaction = dashed_transaction
			transaction.consume_whitespace()
			continue
		}
		return none
	}

	mut values := []StyleValue{}
	if value := dashed_ident {
		values << value
	}
	if value := try_tactic {
		values << value
	}
	if values.len == 0 {
		return none
	}
	tokens = transaction
	if values.len == 1 {
		return values[0]
	}
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn (mut parser Parser) parse_position_try_fallbacks_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | [ [<dashed-ident> || <try-tactic>] | <position-area> ]#
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())
	mut fallbacks := []StyleValue{}
	for value in values {
		mut fallback_tokens := ComponentValueStream.new(value)
		fallback := parser.parse_single_position_try_fallbacks_value(mut fallback_tokens) or {
			return none
		}
		fallback_tokens.consume_whitespace()
		if fallback_tokens.has_more_tokens() {
			return none
		}
		fallbacks << fallback
	}
	if fallbacks.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(fallbacks, .comma, .yes))
}

fn (mut parser Parser) parse_position_try_order_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_stub_keyword_from_set_for_value_logic(mut tokens, [
		'normal',
		'most-width',
		'most-height',
		'most-block-size',
		'most-inline-size',
	])
}

fn (mut parser Parser) parse_timeline_scope_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none', 'all']) {
		tokens = transaction
		return value
	}
	return parser.parse_dashed_ident_comma_list_value(mut tokens, ['none', 'all'])
}

fn parse_will_change_feature_for_value_logic(mut parser Parser, values []ComponentValue) ?StyleValue {
	mut tokens := ComponentValueStream.new(values)
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	ident := to_ascii_lowercase(component_value.token().ident())
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	if ident in ['scroll-position', 'contents'] {
		return StyleValue(StubStyleValue.create(.keyword, ident))
	}
	if ident in ['all', 'auto', 'none', 'will-change'] || is_css_wide_keyword_string(ident) {
		return none
	}
	mut ident_tokens := ComponentValueStream.new(values)
	custom_ident := parser.parse_custom_ident_value(mut ident_tokens, [
		'all',
		'auto',
		'contents',
		'none',
		'scroll-position',
		'will-change',
	]) or { return none }
	ident_tokens.consume_whitespace()
	if ident_tokens.has_more_tokens() {
		return none
	}
	return StyleValue(custom_ident)
}

fn (mut parser Parser) parse_will_change_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())
	mut features := []StyleValue{}
	for value in values {
		feature := parse_will_change_feature_for_value_logic(mut parser, value) or { return none }
		features << feature
	}
	if features.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(features, .comma, .yes))
}

fn (mut parser Parser) parse_view_transition_name_value(mut tokens ComponentValueStream) ?StyleValue {
	if value := parse_property_keyword_value(mut tokens, ['none']) {
		return value
	}
	value := parser.parse_custom_ident_value(mut tokens, ['auto', 'none']) or { return none }
	return StyleValue(value)
}

fn parse_single_keyword_from_set_for_value_logic(mut tokens ComponentValueStream, allowed []string) ?Keyword {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	ident := to_ascii_lowercase(component_value.token().ident())
	if ident !in allowed {
		return none
	}
	keyword := keyword_from_string(ident) or { return none }
	tokens = transaction
	return keyword
}

fn parse_stub_keyword_from_set_for_value_logic(mut tokens ComponentValueStream, allowed []string) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	ident := to_ascii_lowercase(component_value.token().ident())
	if ident !in allowed {
		return none
	}
	tokens = transaction
	return StyleValue(StubStyleValue.create(.keyword, ident))
}

fn (mut parser Parser) parse_contain_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// none | strict | content | [ [size | inline-size] || layout || style || paint ]
	if value := parse_property_keyword_value(mut tokens, ['none', 'strict', 'content']) {
		return value
	}

	mut transaction := tokens.clone()
	mut size_value := ?StyleValue(none)
	mut layout_value := ?StyleValue(none)
	mut style_value := ?StyleValue(none)
	mut paint_value := ?StyleValue(none)
	mut size_value_set := false
	mut layout_value_set := false
	mut style_value_set := false
	mut paint_value_set := false

	for {
		keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
			'size',
			'inline-size',
			'layout',
			'style',
			'paint',
		]) or { break }
		match keyword {
			.size, .inline_size {
				if size_value_set {
					return none
				}
				size_value = StyleValue(KeywordStyleValue.create(keyword))
				size_value_set = true
			}
			.layout {
				if layout_value_set {
					return none
				}
				layout_value = StyleValue(KeywordStyleValue.create(keyword))
				layout_value_set = true
			}
			.style {
				if style_value_set {
					return none
				}
				style_value = StyleValue(KeywordStyleValue.create(keyword))
				style_value_set = true
			}
			.paint {
				if paint_value_set {
					return none
				}
				paint_value = StyleValue(KeywordStyleValue.create(keyword))
				paint_value_set = true
			}
			else {
				return none
			}
		}

		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}

	mut containment_values := []StyleValue{}
	if value := size_value {
		containment_values << value
	}
	if value := layout_value {
		containment_values << value
	}
	if value := style_value {
		containment_values << value
	}
	if value := paint_value {
		containment_values << value
	}
	if containment_values.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(containment_values, .space, .yes))
}

fn (mut parser Parser) parse_container_type_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// normal | [ [ size | inline-size ] || scroll-state ]
	if value := parse_property_keyword_value(mut tokens, ['normal']) {
		return value
	}

	mut transaction := tokens.clone()
	mut size_value := ?StyleValue(none)
	mut scroll_state_value := ?StyleValue(none)
	mut size_value_set := false
	mut scroll_state_value_set := false

	for {
		keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
			'size',
			'inline-size',
			'scroll-state',
		]) or { break }
		match keyword {
			.size, .inline_size {
				if size_value_set {
					return none
				}
				size_value = StyleValue(KeywordStyleValue.create(keyword))
				size_value_set = true
			}
			.scroll_state {
				if scroll_state_value_set {
					return none
				}
				scroll_state_value = StyleValue(KeywordStyleValue.create(keyword))
				scroll_state_value_set = true
			}
			else {
				return none
			}
		}

		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}

	mut containment_values := []StyleValue{}
	if value := size_value {
		containment_values << value
	}
	if value := scroll_state_value {
		containment_values << value
	}
	if containment_values.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(containment_values, .space, .yes))
}

struct PaintOrderParseState {
mut:
	has_fill    bool
	has_stroke  bool
	has_markers bool
}

fn parse_paint_order_keyword_for_value_logic(mut tokens ComponentValueStream, mut state PaintOrderParseState) ?StyleValue {
	keyword := parse_single_keyword_from_set_for_value_logic(mut tokens, [
		'fill',
		'markers',
		'stroke',
	]) or { return none }

	match keyword {
		.fill {
			if state.has_fill {
				return none
			}
			state.has_fill = true
		}
		.markers {
			if state.has_markers {
				return none
			}
			state.has_markers = true
		}
		.stroke {
			if state.has_stroke {
				return none
			}
			state.has_stroke = true
		}
		else {
			return none
		}
	}

	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_paint_order_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	if normal := parse_property_keyword_value(mut tokens, ['normal']) {
		return normal
	}

	mut transaction := tokens.clone()
	mut state := PaintOrderParseState{}

	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		return none
	}

	first_keyword_value := parse_paint_order_keyword_for_value_logic(mut transaction, mut state) or {
		return none
	}

	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return first_keyword_value
	}

	second_keyword_value := parse_paint_order_keyword_for_value_logic(mut transaction, mut state) or {
		return none
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		// The third keyword is parsed to ensure it is valid, but it doesn't get added to the list. This follows the
		// shortest-serialization principle, as the value can always be inferred.
		_ = parse_paint_order_keyword_for_value_logic(mut transaction, mut state) or { return none }
		transaction.consume_whitespace()
		if transaction.has_more_tokens() {
			return none
		}
	}

	tokens = transaction
	mut expected_second_keyword := Keyword.fill
	if first_keyword_value.to_keyword() == .fill {
		expected_second_keyword = .stroke
	}

	if expected_second_keyword == second_keyword_value.to_keyword() {
		return first_keyword_value
	}

	return StyleValue(StyleValueList.create([first_keyword_value, second_keyword_value], .space,
		.yes))
}

fn (mut parser Parser) parse_text_decoration_line_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	mut has_underline := false
	mut has_overline := false
	mut has_line_through := false
	mut has_blink := false
	mut has_spelling_error := false
	mut has_grammar_error := false
	mut style_values_count := 0
	mut includes_spelling_or_grammar_error_value := false

	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}

		keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
			'none',
			'underline',
			'overline',
			'line-through',
			'blink',
			'spelling-error',
			'grammar-error',
		]) or { break }

		match keyword {
			.none_ {
				if style_values_count != 0 {
					return none
				}
				tokens = transaction
				return StyleValue(KeywordStyleValue.create(keyword))
			}
			.underline {
				if has_underline {
					return none
				}
				has_underline = true
			}
			.overline {
				if has_overline {
					return none
				}
				has_overline = true
			}
			.line_through {
				if has_line_through {
					return none
				}
				has_line_through = true
			}
			.blink {
				if has_blink {
					return none
				}
				has_blink = true
			}
			.spelling_error {
				if has_spelling_error {
					return none
				}
				has_spelling_error = true
				includes_spelling_or_grammar_error_value = true
			}
			.grammar_error {
				if has_grammar_error {
					return none
				}
				has_grammar_error = true
				includes_spelling_or_grammar_error_value = true
			}
			else {
				return none
			}
		}

		style_values_count++
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() || style_values_count == 0 {
		return none
	}

	// These can only appear on their own.
	if style_values_count > 1 && includes_spelling_or_grammar_error_value {
		return none
	}

	mut style_values := []StyleValue{}
	if has_underline {
		style_values << StyleValue(KeywordStyleValue.create(.underline))
	}
	if has_overline {
		style_values << StyleValue(KeywordStyleValue.create(.overline))
	}
	if has_line_through {
		style_values << StyleValue(KeywordStyleValue.create(.line_through))
	}
	if has_blink {
		style_values << StyleValue(KeywordStyleValue.create(.blink))
	}
	if has_spelling_error {
		style_values << StyleValue(KeywordStyleValue.create(.spelling_error))
	}
	if has_grammar_error {
		style_values << StyleValue(KeywordStyleValue.create(.grammar_error))
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(style_values, .space, .yes))
}

fn (mut parser Parser) parse_text_decoration_style_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['dashed', 'dotted', 'double', 'solid', 'wavy'])
}

fn parse_property_keyword_value(mut tokens ComponentValueStream, allowed_keywords []string) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	ident := to_ascii_lowercase(component_value.token().ident())
	if ident !in allowed_keywords {
		return none
	}
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}
	// `overlay` is a legacy overflow alias whose generated metadata maps it to `auto`.
	keyword := if ident == 'overlay' { Keyword.auto } else { keyword_from_string(ident) or {
			return none} }
	tokens = transaction
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens ComponentValueStream, allowed_keywords []string) ?StyleValue {
	return parse_animation_keyword_list_for_value_logic(mut tokens, allowed_keywords)
}

fn (mut parser Parser) parse_background_attachment_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'fixed',
		'local',
		'scroll',
	])
}

fn (mut parser Parser) parse_background_blend_mode_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'normal',
		'multiply',
		'screen',
		'overlay',
		'darken',
		'lighten',
		'color-dodge',
		'color-burn',
		'hard-light',
		'soft-light',
		'difference',
		'exclusion',
		'hue',
		'saturation',
		'color',
		'luminosity',
		'plus-darker',
		'plus-lighter',
	])
}

fn (mut parser Parser) parse_background_box_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'border-box',
		'content-box',
		'padding-box',
		'text',
	])
}

enum PositionParsingMode {
	normal
	background_position
}

struct PositionAndLengthForValueLogic {
	position PositionEdge
	length   StyleValue
}

struct PositionAndMaybeLengthForValueLogic {
	position PositionEdge
	length   ?StyleValue
}

fn keyword_to_position_edge_for_value_logic(keyword Keyword) ?PositionEdge {
	return match keyword {
		.center { PositionEdge.center }
		.left { PositionEdge.left }
		.right { PositionEdge.right }
		.top { PositionEdge.top }
		.bottom { PositionEdge.bottom }
		else { none }
	}
}

fn parse_position_edge_for_value_logic(mut tokens ComponentValueStream) ?PositionEdge {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	keyword := keyword_from_string(component_value.token().ident()) or { return none }
	edge := keyword_to_position_edge_for_value_logic(keyword) or { return none }
	tokens = transaction
	return edge
}

fn position_edge_is_horizontal_for_value_logic(edge PositionEdge, accept_center bool) bool {
	return match edge {
		.left, .right { true }
		.center { accept_center }
		else { false }
	}
}

fn position_edge_is_vertical_for_value_logic(edge PositionEdge, accept_center bool) bool {
	return match edge {
		.top, .bottom { true }
		.center { accept_center }
		else { false }
	}
}

fn (mut parser Parser) parse_position_or_length_for_value_logic(mut tokens ComponentValueStream, as_horizontal bool) ?EdgeStyleValue {
	tokens.consume_whitespace()

	mut edge_transaction := tokens.clone()
	if position := parse_position_edge_for_value_logic(mut edge_transaction) {
		valid := if as_horizontal {
			position_edge_is_horizontal_for_value_logic(position, true)
		} else {
			position_edge_is_vertical_for_value_logic(position, true)
		}
		if !valid {
			return none
		}
		tokens = edge_transaction
		return EdgeStyleValue.create(position, none)
	}

	mut length_transaction := tokens.clone()
	maybe_length := parser.parse_length_percentage_value(mut length_transaction) or { return none }
	tokens = length_transaction
	return EdgeStyleValue.create(none, maybe_length)
}

fn (mut parser Parser) parse_position_and_length_for_value_logic(mut tokens ComponentValueStream) ?PositionAndLengthForValueLogic {
	tokens.consume_whitespace()
	position := parse_position_edge_for_value_logic(mut tokens) or { return none }
	tokens.consume_whitespace()
	length := parser.parse_length_percentage_value(mut tokens) or { return none }
	return PositionAndLengthForValueLogic{
		position: position
		length:   length
	}
}

fn (mut parser Parser) parse_position_and_maybe_length_for_value_logic(mut tokens ComponentValueStream) ?PositionAndMaybeLengthForValueLogic {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	position := parse_position_edge_for_value_logic(mut transaction) or { return none }
	transaction.consume_whitespace()
	mut length := ?StyleValue(none)
	if maybe_length := parser.parse_length_percentage_value(mut transaction) {
		// 'center' cannot be followed by a <length-percentage>
		if position == .center {
			return none
		}
		length = maybe_length
	}
	tokens = transaction
	return PositionAndMaybeLengthForValueLogic{
		position: position
		length:   length
	}
}

fn (mut parser Parser) parse_css_position_value(mut tokens ComponentValueStream, position_parsing_mode PositionParsingMode) ?StyleValue {
	// <position> = [
	//   [ left | center | right | top | bottom | <length-percentage> ]
	// |
	//   [ left | center | right ] && [ top | center | bottom ]
	// |
	//   [ left | center | right | <length-percentage> ]
	//   [ top | center | bottom | <length-percentage> ]
	// |
	//   [ [ left | right ] <length-percentage> ] &&
	//   [ [ top | bottom ] <length-percentage> ]
	// ]

	// [ [ left | right ] <length-percentage> ] &&
	// [ [ top | bottom ] <length-percentage> ]
	{
		mut transaction := tokens.clone()
		if group1 := parser.parse_position_and_length_for_value_logic(mut transaction) {
			if group2 := parser.parse_position_and_length_for_value_logic(mut transaction) {
				if position_edge_is_horizontal_for_value_logic(group1.position, false)
					&& position_edge_is_vertical_for_value_logic(group2.position, false) {
					tokens = transaction
					return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(group1.position,
						group1.length), EdgeStyleValue.create(group2.position, group2.length)))
				}
				if position_edge_is_vertical_for_value_logic(group1.position, false)
					&& position_edge_is_horizontal_for_value_logic(group2.position, false) {
					tokens = transaction
					return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(group2.position,
						group2.length), EdgeStyleValue.create(group1.position, group1.length)))
				}
			}
		}
	}

	// The extra 3-value syntax that's allowed for background-position:
	// [ center | [ left | right ] <length-percentage>? ] &&
	// [ center | [ top | bottom ] <length-percentage>? ]
	if position_parsing_mode == .background_position {
		mut transaction := tokens.clone()
		if group1_value := parser.parse_position_and_maybe_length_for_value_logic(mut transaction) {
			if group2_value := parser.parse_position_and_maybe_length_for_value_logic(mut transaction) {
				mut group1 := group1_value
				mut group2 := group2_value

				// 2-value or 4-value if both <length-percentage>s are present or missing.
				if !((group1.length != none && group2.length != none)
					|| (group1.length == none && group2.length == none)) {
					// If 'left' or 'right' is given, that position is X and the other is Y.
					// Conversely -
					// If 'top' or 'bottom' is given, that position is Y and the other is X.
					if position_edge_is_vertical_for_value_logic(group1.position, false)
						|| position_edge_is_horizontal_for_value_logic(group2.position, false) {
						tmp := group1
						group1 = group2
						group2 = tmp
					}

					// [ center | [ left | right ] ]
					if position_edge_is_horizontal_for_value_logic(group1.position, true)
						&& position_edge_is_vertical_for_value_logic(group2.position, true) {
						edge_x := if group1.position == .center {
							EdgeStyleValue.create(PositionEdge.center, none)
						} else {
							EdgeStyleValue.create(group1.position, group1.length)
						}
						edge_y := if group2.position == .center {
							EdgeStyleValue.create(PositionEdge.center, none)
						} else {
							EdgeStyleValue.create(group2.position, group2.length)
						}
						tokens = transaction
						return StyleValue(PositionStyleValue.create(edge_x, edge_y))
					}
				}
			}
		}
	}

	// [ left | center | right | <length-percentage> ]
	// [ top | center | bottom | <length-percentage> ]
	{
		mut transaction := tokens.clone()
		if horizontal_edge := parser.parse_position_or_length_for_value_logic(mut transaction, true) {
			if vertical_edge := parser.parse_position_or_length_for_value_logic(mut transaction,
				false)
			{
				tokens = transaction
				return StyleValue(PositionStyleValue.create(horizontal_edge, vertical_edge))
			}
		}
	}

	// [ left | center | right ] && [ top | center | bottom ]
	{
		mut transaction := tokens.clone()
		if first_edge_value := parse_position_edge_for_value_logic(mut transaction) {
			mut first_edge := first_edge_value
			transaction.consume_whitespace()
			if second_edge_value := parse_position_edge_for_value_logic(mut transaction) {
				mut second_edge := second_edge_value

				// If 'left' or 'right' is given, that position is X and the other is Y.
				// Conversely -
				// If 'top' or 'bottom' is given, that position is Y and the other is X.
				if position_edge_is_vertical_for_value_logic(first_edge, false)
					|| position_edge_is_horizontal_for_value_logic(second_edge, false) {
					tmp := first_edge
					first_edge = second_edge
					second_edge = tmp
				}
				if position_edge_is_horizontal_for_value_logic(first_edge, true)
					&& position_edge_is_vertical_for_value_logic(second_edge, true) {
					tokens = transaction
					return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(first_edge,
						none), EdgeStyleValue.create(second_edge, none)))
				}
			}
		}
	}

	// [ left | center | right | top | bottom | <length-percentage> ]
	{
		mut transaction := tokens.clone()
		if edge := parse_position_edge_for_value_logic(mut transaction) {
			tokens = transaction
			if position_edge_is_horizontal_for_value_logic(edge, false) {
				return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(edge, none), EdgeStyleValue.create(PositionEdge.center,
					none)))
			}
			if position_edge_is_vertical_for_value_logic(edge, false) {
				return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(PositionEdge.center,
					none), EdgeStyleValue.create(edge, none)))
			}
			return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(PositionEdge.center,
				none), EdgeStyleValue.create(PositionEdge.center, none)))
		}

		mut length_transaction := tokens.clone()
		if maybe_percentage := parser.parse_length_percentage_value(mut length_transaction) {
			tokens = length_transaction
			return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(none,
				maybe_percentage), EdgeStyleValue.create(PositionEdge.center, none)))
		}
	}

	return none
}

fn (mut parser Parser) parse_position_list_value(mut tokens ComponentValueStream, position_parsing_mode PositionParsingMode) ?StyleValue {
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut positions := []StyleValue{}
	for value in values {
		mut position_tokens := ComponentValueStream.new(value)
		position_value := parser.parse_css_position_value(mut position_tokens,
			position_parsing_mode) or { return none }
		position_tokens.consume_whitespace()
		if position_tokens.has_more_tokens() {
			return none
		}
		positions << position_value
	}

	if positions.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(positions, .comma, .yes))
}

fn (mut parser Parser) parse_single_background_position_x_or_y_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	mut relative_edge := ?PositionEdge(none)

	mut keyword_transaction := transaction.clone()
	if keyword := parse_single_keyword_from_set_for_value_logic(mut keyword_transaction, if property_id == .background_position_x {
		['center', 'left', 'right']
	} else {
		['center', 'bottom', 'top']
	})
	{
		if keyword == .center {
			tokens = keyword_transaction
			return StyleValue(EdgeStyleValue.create(PositionEdge.center, none))
		}
		relative_edge = keyword_to_position_edge_for_value_logic(keyword) or { return none }
		transaction = keyword_transaction
		if value := parser.parse_length_percentage_value(mut transaction) {
			tokens = transaction
			return StyleValue(EdgeStyleValue.create(relative_edge, value))
		}
		tokens = transaction
		return StyleValue(EdgeStyleValue.create(relative_edge, none))
	}

	value := parser.parse_length_percentage_value(mut transaction) or { return none }
	tokens = transaction
	return StyleValue(EdgeStyleValue.create(relative_edge, value))
}

fn (mut parser Parser) parse_background_position_axis_list_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut positions := []StyleValue{}
	for value in values {
		mut position_tokens := ComponentValueStream.new(value)
		position_value := parser.parse_single_background_position_x_or_y_value(property_id, mut
			position_tokens) or { return none }
		position_tokens.consume_whitespace()
		if position_tokens.has_more_tokens() {
			return none
		}
		positions << position_value
	}

	if positions.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(positions, .comma, .yes))
}

fn (mut parser Parser) parse_background_size_component_value(mut tokens ComponentValueStream, allow_cover_contain bool) ?StyleValue {
	mut transaction := tokens.clone()
	allowed_keywords := if allow_cover_contain {
		['auto', 'cover', 'contain']
	} else {
		['auto']
	}
	if value := parse_property_keyword_value(mut transaction, allowed_keywords) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_single_background_size_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	x_value := parser.parse_background_size_component_value(mut transaction, true) or {
		return none
	}
	if x_value.to_keyword() in [.cover, .contain] {
		tokens = transaction
		return x_value
	}

	y_value := parser.parse_background_size_component_value(mut transaction, false) or {
		tokens = transaction
		return StyleValue(BackgroundSizeStyleValue.create(x_value,
			StyleValue(KeywordStyleValue.create(.auto))))
	}
	tokens = transaction
	return StyleValue(BackgroundSizeStyleValue.create(x_value, y_value))
}

fn (mut parser Parser) parse_background_size_list_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	_ = property_id
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut sizes := []StyleValue{}
	for value in values {
		mut size_tokens := ComponentValueStream.new(value)
		size_value := parser.parse_single_background_size_value(mut size_tokens) or { return none }
		size_tokens.consume_whitespace()
		if size_tokens.has_more_tokens() {
			return none
		}
		sizes << size_value
	}

	if sizes.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(sizes, .comma, .yes))
}

fn parse_border_image_fill_for_value_logic(mut tokens ComponentValueStream) bool {
	mut transaction := tokens.clone()
	component_value := transaction.consume() or { return false }
	if !component_value.is(.ident) {
		return false
	}
	if !equals_ignoring_ascii_case(component_value.token().ident(), 'fill') {
		return false
	}
	tokens = transaction
	return true
}

// https://drafts.csswg.org/css-backgrounds/#border-image-slice
fn (mut parser Parser) parse_border_image_slice_value(mut tokens ComponentValueStream) ?StyleValue {
	// [<number [0,+infinity]> | <percentage [0,+infinity]>]{1,4} && fill?
	mut transaction := tokens.clone()
	mut fill := false

	transaction.consume_whitespace()
	if parse_border_image_fill_for_value_logic(mut transaction) {
		fill = true
	}
	transaction.consume_whitespace()

	mut number_percentages := []StyleValue{}
	for number_percentages.len <= 4 && transaction.has_more_tokens() {
		number_percentage := parser.parse_number_percentage_value(mut transaction) or { break }
		if style_value_numeric_component_is_negative_for_value_logic(number_percentage) {
			return none
		}
		number_percentages << number_percentage
		transaction.consume_whitespace()
	}

	mut expanded_values := []StyleValue{}
	match number_percentages.len {
		1 {
			expanded_values = [
				number_percentages[0],
				number_percentages[0],
				number_percentages[0],
				number_percentages[0],
			]
		}
		2 {
			expanded_values = [
				number_percentages[0],
				number_percentages[1],
				number_percentages[0],
				number_percentages[1],
			]
		}
		3 {
			expanded_values = [
				number_percentages[0],
				number_percentages[1],
				number_percentages[2],
				number_percentages[1],
			]
		}
		4 {
			expanded_values = number_percentages.clone()
		}
		else {
			return none
		}
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() && parse_border_image_fill_for_value_logic(mut transaction) {
		if fill {
			return none
		}
		fill = true
		transaction.consume_whitespace()
	}

	tokens = transaction
	return StyleValue(BorderImageSliceStyleValue.create(expanded_values[0], expanded_values[1],
		expanded_values[2], expanded_values[3], fill))
}

fn (mut parser Parser) parse_border_radius_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-borders-4/#typedef-border-radius
	// <border-radius> = <slash-separated-border-radius-syntax> | <legacy-border-radius-syntax>
	// <slash-separated-border-radius-syntax> = <length-percentage [0,+infinity]> [ / <length-percentage [0,+infinity]> ]?
	// <legacy-border-radius-syntax> = <length-percentage [0,+infinity]>{1,2}
	// NB: So, 1 or 2 `<length-percentage>`s, optionally separated with a `/`.
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	horizontal := parser.parse_nonnegative_length_percentage_value(mut transaction) or {
		return none
	}
	transaction.consume_whitespace()

	if next_token := transaction.peek() {
		if next_token.is_delim(u32(`/`)) {
			transaction.consume()
			transaction.consume_whitespace()
		}
	}

	if vertical := parser.parse_nonnegative_length_percentage_value(mut transaction) {
		tokens = transaction
		return StyleValue(BorderRadiusStyleValue.create(horizontal, vertical))
	}

	tokens = transaction
	return StyleValue(BorderRadiusStyleValue.create(horizontal, horizontal))
}

fn (mut parser Parser) parse_border_image_outset_component_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parser.parse_nonnegative_length_value(mut transaction) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_number_value(mut tokens)
}

fn (mut parser Parser) parse_border_image_width_component_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	if value := parser.parse_nonnegative_length_percentage_value(mut transaction) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_number_value(mut tokens)
}

fn (mut parser Parser) parse_border_image_outset_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	mut values := []StyleValue{}
	for values.len < 4 && transaction.has_more_tokens() {
		value := parser.parse_border_image_outset_component_value(mut transaction) or { break }
		values << value
		transaction.consume_whitespace()
	}
	if values.len == 0 {
		return none
	}
	tokens = transaction
	if values.len == 1 {
		return values[0]
	}
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn (mut parser Parser) parse_border_image_width_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	mut values := []StyleValue{}
	for values.len < 4 && transaction.has_more_tokens() {
		value := parser.parse_border_image_width_component_value(mut transaction) or { break }
		values << value
		transaction.consume_whitespace()
	}
	if values.len == 0 {
		return none
	}
	tokens = transaction
	if values.len == 1 {
		return values[0]
	}
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn (mut parser Parser) parse_anchor_function_stub_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function_named('anchor') {
		return none
	}
	tokens = transaction
	return StyleValue(StubStyleValue.create(.anchor, component_value.to_string()))
}

fn (mut parser Parser) parse_anchor_size_function_stub_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function_named('anchor-size') {
		return none
	}
	tokens = transaction
	return StyleValue(StubStyleValue.create(.anchor_size, component_value.to_string()))
}

fn (mut parser Parser) parse_fit_content_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if component_value.is(.ident)
		&& equals_ignoring_ascii_case(component_value.token().ident(), 'fit-content') {
		tokens = transaction
		return StyleValue(StubStyleValue.create(.fit_content, 'fit-content'))
	}
	if component_value.is_function_named('fit-content') {
		mut function_tokens := ComponentValueStream.new(component_value.function().value)
		_ = parser.parse_nonnegative_length_percentage_value(mut function_tokens) or { return none }
		function_tokens.consume_whitespace()
		if function_tokens.has_more_tokens() {
			return none
		}
		tokens = transaction
		return StyleValue(StubStyleValue.create(.fit_content, component_value.to_string()))
	}
	return none
}

fn property_is_max_size_for_value_logic(property_id PropertyID) bool {
	return property_id in [.max_block_size, .max_height, .max_inline_size, .max_width]
}

fn (mut parser Parser) parse_sizing_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	allowed_keywords := if property_is_max_size_for_value_logic(property_id) {
		['max-content', 'min-content', 'none']
	} else {
		['auto', 'max-content', 'min-content']
	}
	if value := parse_property_keyword_value(mut transaction, allowed_keywords) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parse_stub_keyword_from_set_for_value_logic(mut transaction, [
		'max-content',
		'min-content',
	])
	{
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parser.parse_fit_content_value(mut transaction) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parser.parse_anchor_size_function_stub_value(mut transaction) {
		tokens = transaction
		return value
	}

	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_inset_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parser.parse_anchor_function_stub_value(mut transaction) {
		tokens = transaction
		return value
	}

	return parser.parse_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_margin_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parser.parse_anchor_size_function_stub_value(mut transaction) {
		tokens = transaction
		return value
	}

	return parser.parse_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_padding_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_border_spacing_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	first_value := parser.parse_nonnegative_length_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return first_value
	}

	second_value := parser.parse_nonnegative_length_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create([first_value, second_value], .space, .yes))
}

fn (mut parser Parser) parse_border_image_repeat_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	first_keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
		'stretch',
		'repeat',
		'round',
		'space',
	]) or { return none }
	first_value := StyleValue(KeywordStyleValue.create(first_keyword))

	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return first_value
	}

	second_keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
		'stretch',
		'repeat',
		'round',
		'space',
	]) or { return none }
	second_value := StyleValue(KeywordStyleValue.create(second_keyword))

	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create([first_value, second_value], .space, .yes))
}

fn repetition_from_keyword_for_value_logic(keyword Keyword) ?Repetition {
	return match keyword {
		.no_repeat { Repetition.no_repeat }
		.repeat { Repetition.repeat }
		.round { Repetition.round }
		.space { Repetition.space }
		else { none }
	}
}

fn (mut parser Parser) parse_single_repeat_style_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	_ = property_id
	mut transaction := tokens.clone()

	x_keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
		'no-repeat',
		'repeat',
		'round',
		'space',
		'repeat-x',
		'repeat-y',
	]) or { return none }

	if x_keyword == .repeat_x {
		tokens = transaction
		return StyleValue(RepeatStyleStyleValue.create(.repeat, .no_repeat))
	}
	if x_keyword == .repeat_y {
		tokens = transaction
		return StyleValue(RepeatStyleStyleValue.create(.no_repeat, .repeat))
	}

	x_repeat := repetition_from_keyword_for_value_logic(x_keyword) or { return none }
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return StyleValue(RepeatStyleStyleValue.create(x_repeat, x_repeat))
	}

	y_keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
		'no-repeat',
		'repeat',
		'round',
		'space',
	]) or { return none }
	y_repeat := repetition_from_keyword_for_value_logic(y_keyword) or { return none }

	tokens = transaction
	return StyleValue(RepeatStyleStyleValue.create(x_repeat, y_repeat))
}

fn (mut parser Parser) parse_repeat_style_list_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut repeat_styles := []StyleValue{}
	for value in values {
		mut repeat_tokens := ComponentValueStream.new(value)
		repeat_value := parser.parse_single_repeat_style_value(property_id, mut repeat_tokens) or {
			return none
		}
		repeat_tokens.consume_whitespace()
		if repeat_tokens.has_more_tokens() {
			return none
		}
		repeat_styles << repeat_value
	}

	if repeat_styles.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(repeat_styles, .comma, .yes))
}

fn (mut parser Parser) parse_mask_clip_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'content-box',
		'padding-box',
		'border-box',
		'fill-box',
		'stroke-box',
		'view-box',
		'no-clip',
	])
}

fn (mut parser Parser) parse_mask_composite_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'add',
		'subtract',
		'intersect',
		'exclude',
	])
}

fn (mut parser Parser) parse_mask_mode_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'alpha',
		'luminance',
		'match-source',
	])
}

fn (mut parser Parser) parse_mask_origin_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'content-box',
		'padding-box',
		'border-box',
		'fill-box',
		'stroke-box',
		'view-box',
	])
}

fn (mut parser Parser) parse_timeline_axis_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'block',
		'inline',
		'x',
		'y',
	])
}

fn (mut parser Parser) parse_position_visibility_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// always | [ anchors-valid || anchors-visible || no-overflow ]
	if always := parse_property_keyword_value(mut tokens, ['always']) {
		return always
	}

	mut transaction := tokens.clone()
	mut anchors_valid_value := ?StyleValue(none)
	mut anchors_visible_value := ?StyleValue(none)
	mut no_overflow_value := ?StyleValue(none)
	mut has_anchors_valid := false
	mut has_anchors_visible := false
	mut has_no_overflow := false

	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
			'anchors-valid',
			'anchors-visible',
			'no-overflow',
		]) or { return none }

		match keyword {
			.anchors_valid {
				if has_anchors_valid {
					return none
				}
				anchors_valid_value = StyleValue(KeywordStyleValue.create(keyword))
				has_anchors_valid = true
			}
			.anchors_visible {
				if has_anchors_visible {
					return none
				}
				anchors_visible_value = StyleValue(KeywordStyleValue.create(keyword))
				has_anchors_visible = true
			}
			.no_overflow {
				if has_no_overflow {
					return none
				}
				no_overflow_value = StyleValue(KeywordStyleValue.create(keyword))
				has_no_overflow = true
			}
			else {
				return none
			}
		}

		transaction.consume_whitespace()
	}

	mut values := []StyleValue{}
	if value := anchors_valid_value {
		values << value
	}
	if value := anchors_visible_value {
		values << value
	}
	if value := no_overflow_value {
		values << value
	}
	if values.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn parse_touch_action_single_keyword_for_value_logic(mut tokens ComponentValueStream) ?Keyword {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	ident := to_ascii_lowercase(component_value.token().ident())
	if ident !in ['pan-x', 'pan-left', 'pan-right', 'pan-y', 'pan-up', 'pan-down'] {
		return none
	}
	keyword := keyword_from_string(ident) or { return none }
	tokens = transaction
	return keyword
}

fn (mut parser Parser) parse_touch_action_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://www.w3.org/TR/pointerevents/#the-touch-action-css-property
	// auto | none | [ [ pan-x | pan-left | pan-right ] || [ pan-y | pan-up | pan-down ] ] | manipulation
	if value := parse_property_keyword_value(mut tokens, ['auto', 'none', 'manipulation']) {
		return value
	}

	mut transaction := tokens.clone()
	mut parsed_values := []StyleValue{}
	mut has_horizontal := false
	mut has_vertical := false
	mut swap_order := false

	for {
		keyword := parse_touch_action_single_keyword_for_value_logic(mut transaction) or { break }
		match keyword {
			.pan_x, .pan_left, .pan_right {
				if has_horizontal {
					return none
				}
				if has_vertical {
					swap_order = true
				}
				has_horizontal = true
			}
			.pan_y, .pan_up, .pan_down {
				if has_vertical {
					return none
				}
				has_vertical = true
			}
			else {
				return none
			}
		}

		parsed_values << StyleValue(KeywordStyleValue.create(keyword))
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() || parsed_values.len == 0 {
		return none
	}
	if swap_order && parsed_values.len == 2 {
		first := parsed_values[0]
		parsed_values[0] = parsed_values[1]
		parsed_values[1] = first
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(parsed_values, .space, .yes))
}

// https://drafts.csswg.org/css-borders-4/#typedef-corner-shape-value
fn (mut parser Parser) parse_corner_shape_value(mut tokens ComponentValueStream) ?StyleValue {
	// <corner-shape-value> = round | scoop | bevel | notch | square | squircle | <superellipse()>
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if component_value.is(.ident) {
		ident := to_ascii_lowercase(component_value.token().ident())
		keyword := keyword_from_string(ident) or { return none }
		if keyword !in [.round, .scoop, .bevel, .notch, .square, .squircle] { return none }
		tokens = transaction
		return StyleValue(KeywordStyleValue.create(keyword))
	}

	if component_value.is_function_named('superellipse') {
		// superellipse() = superellipse(<number> | infinity | -infinity)
		mut function_tokens := ComponentValueStream.new(component_value.function().value)
		function_tokens.consume_whitespace()
		if token := function_tokens.consume() {
			if token.is(.ident) {
				ident := to_ascii_lowercase(token.token().ident())
				function_tokens.consume_whitespace()
				if function_tokens.has_more_tokens() {
					return none
				}
				keyword := keyword_from_string(ident) or { return none }
				if keyword == .negative_infinity {
					tokens = transaction
					return StyleValue(SuperellipseStyleValue.create(StyleValue(NumberStyleValue.create(math.inf(-1)))))
				}
				if keyword == .infinity {
					tokens = transaction
					return StyleValue(SuperellipseStyleValue.create(StyleValue(NumberStyleValue.create(math.inf(1)))))
				}
				return none
			}
			function_tokens.reconsume()
			number_value := parser.parse_number_value(mut function_tokens) or { return none }
			function_tokens.consume_whitespace()
			if function_tokens.has_more_tokens() {
				return none
			}
			tokens = transaction
			return StyleValue(SuperellipseStyleValue.create(number_value))
		}
	}

	return none
}

fn font_style_keyword_from_string(value string) ?FontStyleKeyword {
	return match to_ascii_lowercase(value) {
		'normal' { FontStyleKeyword.normal }
		'italic' { FontStyleKeyword.italic }
		'left' { FontStyleKeyword.left }
		'right' { FontStyleKeyword.right }
		'oblique' { FontStyleKeyword.oblique }
		else { none }
	}
}

fn (mut parser Parser) parse_font_kerning_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'normal', 'none'])
}

fn (mut parser Parser) parse_font_language_override_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['normal']) {
		tokens = transaction
		return value
	}
	if value := parser.parse_string_value(mut tokens) {
		return StyleValue(value)
	}
	return none
}

fn (mut parser Parser) parse_font_optical_sizing_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'none'])
}

fn (mut parser Parser) parse_font_variant_caps_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['normal', 'small-caps', 'all-small-caps',
		'petite-caps', 'all-petite-caps', 'unicase', 'titling-caps'])
}

fn (mut parser Parser) parse_font_variant_emoji_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['normal', 'text', 'emoji', 'unicode'])
}

fn (mut parser Parser) parse_font_variant_position_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['normal', 'sub', 'super'])
}

fn (mut parser Parser) parse_font_style_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-fonts/#font-style-prop
	// normal | italic | left | right | oblique <angle [-90deg,90deg]>?
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	font_style := font_style_keyword_from_string(component_value.token().ident()) or { return none }
	transaction.consume_whitespace()
	if transaction.has_more_tokens() && font_style == .oblique {
		angle_value := parser.parse_angle_value(mut transaction) or { return none }
		if angle_value is AngleStyleValue {
			angle_degrees := angle_value.angle().to_degrees()
			if angle_degrees < -90 || angle_degrees > 90 {
				return none
			}
		}
		tokens = transaction
		return StyleValue(FontStyleStyleValue.create(font_style, angle_value))
	}
	tokens = transaction
	return StyleValue(FontStyleStyleValue.create(font_style, none))
}

fn (mut parser Parser) parse_font_weight_value(mut tokens ComponentValueStream) ?StyleValue {
	mut keyword_transaction := tokens.clone()
	keyword_transaction.consume_whitespace()
	if component_value := keyword_transaction.consume() {
		if component_value.is(.ident) {
			ident := to_ascii_lowercase(component_value.token().ident())
			keyword := keyword_from_string(ident) or { return none }
			if keyword in [.normal, .bold, .bolder, .lighter] {
				tokens = keyword_transaction
				return StyleValue(KeywordStyleValue.create(keyword))
			}
		}
	}

	mut number_transaction := tokens.clone()
	if value := parser.parse_number_value(mut number_transaction) {
		if value is NumberStyleValue {
			number := value.number()
			if number < 1 || number > 1000 {
				return none
			}
		}
		tokens = number_transaction
		return value
	}

	mut numeric_transaction := tokens.clone()
	remaining_text :=
		serialize_a_series_of_component_values(numeric_transaction.consume_remaining_component_values())
	if value := numeric_style_value_from_css_text_for_value_logic(remaining_text) {
		if value is NumberStyleValue {
			number := value.number()
			if number < 1 || number > 1000 {
				return none
			}
			tokens = numeric_transaction
			return value
		}
	}
	return none
}

fn (mut parser Parser) parse_font_width_value(mut tokens ComponentValueStream) ?StyleValue {
	mut percentage_transaction := tokens.clone()
	if value := parser.parse_percentage_value(mut percentage_transaction) {
		tokens = percentage_transaction
		return value
	}
	mut transaction := tokens.clone()
	remaining_text :=
		serialize_a_series_of_component_values(transaction.consume_remaining_component_values())
	if value := numeric_style_value_from_css_text_for_value_logic(remaining_text) {
		if value is PercentageStyleValue {
			tokens = transaction
			return value
		}
	}
	return parse_keyword_as_custom_ident_for_value_logic(mut tokens, [
		'ultra-condensed',
		'extra-condensed',
		'condensed',
		'semi-condensed',
		'normal',
		'semi-expanded',
		'expanded',
		'extra-expanded',
		'ultra-expanded',
	])
}

fn (mut parser Parser) parse_line_height_value(mut tokens ComponentValueStream) ?StyleValue {
	mut normal_transaction := tokens.clone()
	normal_transaction.consume_whitespace()
	if token := normal_transaction.consume() {
		if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'normal') {
			normal_transaction.consume_whitespace()
			if !normal_transaction.has_more_tokens() {
				tokens = normal_transaction
				return StyleValue(KeywordStyleValue.create(.normal))
			}
		}
	}

	mut length_transaction := tokens.clone()
	if value := parser.parse_length_value(mut length_transaction) {
		tokens = length_transaction
		return value
	}
	mut number_transaction := tokens.clone()
	if value := parser.parse_number_value(mut number_transaction) {
		tokens = number_transaction
		return value
	}
	mut percentage_transaction := tokens.clone()
	if value := parser.parse_percentage_value(mut percentage_transaction) {
		tokens = percentage_transaction
		return value
	}

	mut transaction := tokens.clone()
	remaining_text :=
		serialize_a_series_of_component_values(transaction.consume_remaining_component_values())
	if value := numeric_style_value_from_css_text_for_value_logic(remaining_text) {
		match value {
			LengthStyleValue, NumberStyleValue, PercentageStyleValue {
				tokens = transaction
				return value
			}
			else {}
		}
	}
	return none
}

fn (mut parser Parser) parse_letter_or_word_spacing_value(mut tokens ComponentValueStream) ?StyleValue {
	mut normal_transaction := tokens.clone()
	normal_transaction.consume_whitespace()
	if token := normal_transaction.consume() {
		if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'normal') {
			normal_transaction.consume_whitespace()
			if !normal_transaction.has_more_tokens() {
				tokens = normal_transaction
				return StyleValue(KeywordStyleValue.create(.normal))
			}
		}
	}

	mut length_transaction := tokens.clone()
	if value := parser.parse_length_value(mut length_transaction) {
		tokens = length_transaction
		return value
	}
	mut percentage_transaction := tokens.clone()
	if value := parser.parse_percentage_value(mut percentage_transaction) {
		tokens = percentage_transaction
		return value
	}

	mut transaction := tokens.clone()
	remaining_text :=
		serialize_a_series_of_component_values(transaction.consume_remaining_component_values())
	if value := numeric_style_value_from_css_text_for_value_logic(remaining_text) {
		match value {
			LengthStyleValue, PercentageStyleValue {
				tokens = transaction
				return value
			}
			else {}
		}
	}
	return none
}

fn (mut parser Parser) parse_math_depth_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://w3c.github.io/mathml-core/#propdef-math-depth
	// auto-add | add(<integer>) | <integer>
	mut keyword_transaction := tokens.clone()
	keyword_transaction.consume_whitespace()
	if component_value := keyword_transaction.consume() {
		if component_value.is(.ident)
			&& equals_ignoring_ascii_case(component_value.token().ident(), 'auto-add') {
			keyword_transaction.consume_whitespace()
			if !keyword_transaction.has_more_tokens() {
				tokens = keyword_transaction
				return StyleValue(KeywordStyleValue.create(.auto_add))
			}
		}
	}

	mut add_transaction := tokens.clone()
	add_transaction.consume_whitespace()
	if component_value := add_transaction.consume() {
		if component_value.is_function_named('add') {
			mut add_tokens := ComponentValueStream.new(component_value.function().value)
			add_tokens.consume_whitespace()
			integer_value := parser.parse_integer_value(mut add_tokens) or { return none }
			add_tokens.consume_whitespace()
			if add_tokens.has_more_tokens() {
				return none
			}
			add_transaction.consume_whitespace()
			if add_transaction.has_more_tokens() {
				return none
			}
			tokens = add_transaction
			return StyleValue(AddFunctionStyleValue.create(integer_value))
		}
	}

	mut integer_transaction := tokens.clone()
	if integer_value := parser.parse_integer_value(mut integer_transaction) {
		tokens = integer_transaction
		return integer_value
	}
	return none
}

fn (mut parser Parser) parse_math_style_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	keyword := match to_ascii_lowercase(component_value.token().ident()) {
		'normal' { Keyword.normal }
		'compact' { Keyword.compact }
		else { return none }
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}
	tokens = transaction
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_math_shift_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['normal', 'compact'])
}

fn (mut parser Parser) parse_font_feature_settings_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-fonts/#propdef-font-feature-settings
	// normal | <feature-tag-value>#
	mut normal_transaction := tokens.clone()
	normal_transaction.consume_whitespace()
	if token := normal_transaction.consume() {
		if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'normal') {
			normal_transaction.consume_whitespace()
			if !normal_transaction.has_more_tokens() {
				tokens = normal_transaction
				return StyleValue(KeywordStyleValue.create(.normal))
			}
		}
	}

	mut transaction := tokens.clone()
	component_values := transaction.consume_remaining_component_values()
	tag_values := parse_a_comma_separated_list_of_component_values_for_value_logic(component_values)
	mut feature_tags := []StyleValue{}
	for values in tag_values {
		feature_tags << StyleValue(computed_interpolation_parse_font_feature_settings_entry(values) or {
			return none
		})
	}
	if feature_tags.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(feature_tags, .comma, .yes))
}

fn (mut parser Parser) parse_font_variation_settings_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-fonts/#propdef-font-variation-settings
	// normal | [ <opentype-tag> <number> ]#
	mut normal_transaction := tokens.clone()
	normal_transaction.consume_whitespace()
	if token := normal_transaction.consume() {
		if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'normal') {
			normal_transaction.consume_whitespace()
			if !normal_transaction.has_more_tokens() {
				tokens = normal_transaction
				return StyleValue(KeywordStyleValue.create(.normal))
			}
		}
	}

	mut transaction := tokens.clone()
	component_values := transaction.consume_remaining_component_values()
	tag_values := parse_a_comma_separated_list_of_component_values_for_value_logic(component_values)
	mut axis_tags := []StyleValue{}
	for values in tag_values {
		axis_tags << StyleValue(computed_interpolation_parse_font_variation_settings_entry(values) or {
			return none
		})
	}
	if axis_tags.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(axis_tags, .comma, .yes))
}

fn (mut parser Parser) parse_single_animation_timeline_value(mut tokens ComponentValueStream) ?StyleValue {
	// animation-timeline = auto | none | <dashed-ident> | scroll() | view()
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if component_value.is(.ident) {
		ident := component_value.token().ident()
		if equals_ignoring_ascii_case(ident, 'auto') {
			return StyleValue(KeywordStyleValue.create(.auto))
		}
		if equals_ignoring_ascii_case(ident, 'none') {
			return StyleValue(KeywordStyleValue.create(.none_))
		}
		if ident.starts_with('--') {
			return StyleValue(CustomIdentStyleValue.create(ident))
		}
		return none
	}
	if scroll_function := parser.parse_scroll_function_value(component_value) {
		return StyleValue(scroll_function)
	}
	if view_function := parser.parse_view_function_value(component_value) {
		return StyleValue(view_function)
	}
	return none
}

fn (mut parser Parser) parse_animation_timeline_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	component_values := transaction.consume_remaining_component_values()
	mut timelines := []StyleValue{}
	for values in parse_a_comma_separated_list_of_component_values_for_value_logic(component_values) {
		mut value_tokens := ComponentValueStream.new(values)
		value := parser.parse_single_animation_timeline_value(mut value_tokens) or { return none }
		value_tokens.consume_whitespace()
		if value_tokens.has_more_tokens() {
			return none
		}
		timelines << value
	}
	if timelines.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(timelines, .comma, .yes))
}

fn axis_from_identifier_for_value_logic(value string) ?Axis {
	return match to_ascii_lowercase(value) {
		'block' { Axis.block }
		'inline' { Axis.inline_ }
		'x' { Axis.x }
		'y' { Axis.y }
		else { none }
	}
}

fn scroller_from_identifier_for_value_logic(value string) ?Scroller {
	return match to_ascii_lowercase(value) {
		'root' { Scroller.root }
		'nearest' { Scroller.nearest }
		'self' { Scroller.self_ }
		else { none }
	}
}

fn (mut parser Parser) parse_scroll_function_value(component_value ComponentValue) ?ScrollFunctionStyleValue {
	// <scroll()> = scroll( [ <scroller> || <axis> ]? )
	if !component_value.is_function_named('scroll') {
		return none
	}
	mut argument_tokens := ComponentValueStream.new(component_value.function().value)
	mut scroller := ?Scroller(none)
	mut axis := ?Axis(none)
	for argument_tokens.has_more_tokens() {
		argument_tokens.consume_whitespace()
		token := argument_tokens.consume() or { break }
		if !token.is(.ident) {
			return none
		}
		ident := token.token().ident()
		if maybe_scroller := scroller_from_identifier_for_value_logic(ident) {
			if _ := scroller {
				return none
			}
			scroller = maybe_scroller
			continue
		}
		if maybe_axis := axis_from_identifier_for_value_logic(ident) {
			if _ := axis {
				return none
			}
			axis = maybe_axis
			continue
		}
		return none
	}

	resolved_scroller := scroller or { Scroller.nearest }
	resolved_axis := axis or { Axis.block }
	return ScrollFunctionStyleValue.create(resolved_scroller, resolved_axis)
}

fn (mut parser Parser) parse_view_timeline_inset_value(mut tokens ComponentValueStream) ?StyleValue {
	// [ [ auto | <length-percentage> ]{1,2} ]
	mut transaction := tokens.clone()
	mut inset_values := []StyleValue{}
	for transaction.has_more_tokens() && inset_values.len < 2 {
		transaction.consume_whitespace()
		if token := transaction.peek() {
			if token.is_ident('auto') {
				transaction.consume()
				inset_values << StyleValue(KeywordStyleValue.create(.auto))
				continue
			}
		}
		if length_percentage := parser.parse_length_percentage_value(mut transaction) {
			inset_values << length_percentage
			continue
		}
		break
	}
	if inset_values.len == 0 {
		return none
	}
	tokens = transaction
	if inset_values.len == 1 {
		inset_values << inset_values[0]
	}
	return StyleValue(StyleValueList.create(inset_values, .space, .yes))
}

fn (mut parser Parser) parse_view_function_value(component_value ComponentValue) ?ViewFunctionStyleValue {
	// <view()> = view( [ <axis> || <'view-timeline-inset'> ]? )
	if !component_value.is_function_named('view') {
		return none
	}
	mut argument_tokens := ComponentValueStream.new(component_value.function().value)
	mut axis := ?Axis(none)
	mut has_inset := false
	mut inset := StyleValue(StyleValueList.create([
		StyleValue(KeywordStyleValue.create(.auto)),
		StyleValue(KeywordStyleValue.create(.auto)),
	], .space, .yes))
	for argument_tokens.has_more_tokens() {
		if inset_value := parser.parse_view_timeline_inset_value(mut argument_tokens) {
			if has_inset {
				return none
			}
			inset = inset_value
			has_inset = true
			continue
		}

		argument_tokens.consume_whitespace()
		token := argument_tokens.consume() or { break }
		if !token.is(.ident) {
			return none
		}
		maybe_axis := axis_from_identifier_for_value_logic(token.token().ident()) or { return none }
		if _ := axis {
			return none
		}
		axis = maybe_axis
	}

	resolved_axis := axis or { Axis.block }
	resolved_inset := inset

	return ViewFunctionStyleValue.create(resolved_axis, resolved_inset)
}

fn (mut parser Parser) parse_keyword_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	keyword := keyword_from_string(component_value.token().ident()) or { return none }
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_auto_or_color_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if keyword := parser.parse_keyword_value(mut transaction) {
		if keyword.to_keyword() == .auto {
			tokens = transaction
			return keyword
		}
	}

	return parser.parse_color_value(mut tokens)
}

fn (mut parser Parser) parse_content_visibility_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	value := parser.parse_keyword_value(mut transaction) or { return none }
	if value is KeywordStyleValue {
		if value.keyword() in [.visible, .auto, .hidden] {
			tokens = transaction
			return value
		}
	}
	return none
}

fn (mut parser Parser) parse_integer_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.number) {
		return none
	}
	number := component_value.token().number()
	if !number.is_integer() {
		return none
	}
	return StyleValue(IntegerStyleValue.create(number.integer_value()))
}

fn (mut parser Parser) parse_number_value(mut tokens ComponentValueStream) ?StyleValue {
	number := parser.parse_number(mut tokens) or { return none }
	return StyleValue(NumberStyleValue.create(number.value()))
}

fn (mut parser Parser) parse_number(mut tokens ComponentValueStream) ?Number {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.number) {
		return none
	}
	return component_value.token().number()
}

fn (mut parser Parser) parse_easing_number_value(mut tokens ComponentValueStream) ?StyleValue {
	number := parser.parse_number(mut tokens) or { return none }
	return StyleValue(NumberStyleValue.create(number.value()))
}

fn (mut parser Parser) parse_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	percentage := parser.parse_percentage(mut tokens) or { return none }
	return StyleValue(PercentageStyleValue.create(percentage))
}

fn (mut parser Parser) parse_percentage(mut tokens ComponentValueStream) ?Percentage {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.percentage) {
		return none
	}
	return Percentage.new(component_value.token().percentage())
}

fn (mut parser Parser) parse_number_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	mut copy := tokens.clone()
	if value := parser.parse_number_value(mut copy) {
		tokens = copy
		return value
	}
	copy = tokens.clone()
	if value := parser.parse_percentage_value(mut copy) {
		tokens = copy
		return value
	}
	return none
}

fn style_value_numeric_component_is_negative_for_value_logic(value StyleValue) bool {
	return match value {
		LengthStyleValue { value.length().raw_value() < 0 }
		NumberStyleValue { value.number() < 0 }
		PercentageStyleValue { value.percentage().value() < 0 }
		else { false }
	}
}

fn (mut parser Parser) parse_nonnegative_number_value(mut tokens ComponentValueStream) ?StyleValue {
	value := parser.parse_number_value(mut tokens) or { return none }
	if style_value_numeric_component_is_negative_for_value_logic(value) {
		return none
	}
	return value
}

fn (mut parser Parser) parse_positive_integer_value(mut tokens ComponentValueStream) ?StyleValue {
	value := parser.parse_integer_value(mut tokens) or { return none }
	if value is IntegerStyleValue {
		if value.integer() < 1 {
			return none
		}
	}
	return value
}

fn (mut parser Parser) parse_auto_or_positive_integer_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	return parser.parse_positive_integer_value(mut tokens)
}

fn (mut parser Parser) parse_nonnegative_length_value(mut tokens ComponentValueStream) ?StyleValue {
	value := parser.parse_length_value(mut tokens) or { return none }
	if style_value_numeric_component_is_negative_for_value_logic(value) {
		return none
	}
	return value
}

fn (mut parser Parser) parse_auto_or_nonnegative_length_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_value(mut tokens)
}

fn (mut parser Parser) parse_nonnegative_length_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	value := parser.parse_length_percentage_value(mut tokens) or { return none }
	if style_value_numeric_component_is_negative_for_value_logic(value) {
		return none
	}
	return value
}

fn (mut parser Parser) parse_auto_or_nonnegative_length_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_auto_or_length_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	return parser.parse_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_nonnegative_number_or_length_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parser.parse_number_value(mut transaction) {
		if style_value_numeric_component_is_negative_for_value_logic(value) {
			return none
		}
		tokens = transaction
		return value
	}
	value := parser.parse_length_percentage_value(mut tokens) or { return none }
	if style_value_numeric_component_is_negative_for_value_logic(value) {
		return none
	}
	return value
}

fn (mut parser Parser) parse_gap_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['normal']) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_text_decoration_thickness_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto', 'from-font']) {
		tokens = transaction
		return value
	}
	return parser.parse_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_text_indent_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-text-3/#text-indent-property
	// [ <length-percentage> ] && hanging? && each-line?
	mut transaction := tokens.clone()
	mut length_percentage := ?StyleValue(none)
	mut has_hanging := false
	mut has_each_line := false

	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		if length_percentage == none {
			mut length_transaction := transaction.clone()
			if parsed := parser.parse_length_percentage_value(mut length_transaction) {
				length_percentage = parsed
				transaction = length_transaction
				transaction.consume_whitespace()
				continue
			}
		}

		component_value := transaction.consume() or { break }
		if !component_value.is(.ident) {
			return none
		}
		ident := to_ascii_lowercase(component_value.token().ident())
		match ident {
			'hanging' {
				if has_hanging {
					return none
				}
				has_hanging = true
			}
			'each-line' {
				if has_each_line {
					return none
				}
				has_each_line = true
			}
			else {
				return none
			}
		}

		transaction.consume_whitespace()
	}

	length_value := length_percentage or { return none }
	tokens = transaction
	return StyleValue(TextIndentStyleValue.create(length_value, if has_hanging {
		TextIndentHanging.yes
	} else {
		TextIndentHanging.no
	}, if has_each_line { TextIndentEachLine.yes } else { TextIndentEachLine.no }))
}

// https://drafts.csswg.org/css-color-4/#typedef-opacity-opacity-value
fn (mut parser Parser) parse_opacity_value(mut tokens ComponentValueStream) ?StyleValue {
	value := parser.parse_number_percentage_value(mut tokens) or { return none }

	// Percentages map to the range [0,1] for opacity values
	if value is PercentageStyleValue {
		return StyleValue(NumberStyleValue.create(value.percentage().as_fraction()))
	}

	return value
}

fn (mut parser Parser) parse_number_percentage_none_value(mut tokens ComponentValueStream) ?StyleValue {
	// Parses [<percentage> | <number> | none] (which is equivalent to [<alpha-value> | none])
	if value := parser.parse_number_value(mut tokens) {
		return value
	}
	if value := parser.parse_percentage_value(mut tokens) {
		return value
	}
	tokens.consume_whitespace()
	if value := tokens.peek() {
		if value.is(.ident) && equals_ignoring_ascii_case(value.token().ident(), 'none') {
			tokens.consume()
			return StyleValue(KeywordStyleValue.create(.none_))
		}
	}
	return none
}

fn (mut parser Parser) parse_angle_value(mut tokens ComponentValueStream) ?StyleValue {
	angle := parser.parse_angle(mut tokens) or { return none }
	return StyleValue(AngleStyleValue.create(angle))
}

fn (mut parser Parser) parse_angle(mut tokens ComponentValueStream) ?Angle {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if component_value.is(.number) && component_value.token().number_value() == 0 {
		return Angle.make_degrees(0)
	}
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_angle_unit(component_value.token().dimension_unit()) or { return none }
	return Angle.new(component_value.token().dimension_value(), unit)
}

fn (mut parser Parser) parse_length_value(mut tokens ComponentValueStream) ?StyleValue {
	length := parser.parse_length(mut tokens) or { return none }
	return StyleValue(LengthStyleValue.create(length))
}

fn (mut parser Parser) parse_length(mut tokens ComponentValueStream) ?Length {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if component_value.is(.number) && component_value.token().number_value() == 0 {
		return Length.make_px(0)
	}
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_length_unit(component_value.token().dimension_unit()) or { return none }
	return Length.new(component_value.token().dimension_value(), unit)
}

fn (mut parser Parser) parse_length_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	mut copy := tokens.clone()
	if value := parser.parse_length_value(mut copy) {
		tokens = copy
		return value
	}
	copy = tokens.clone()
	if value := parser.parse_percentage_value(mut copy) {
		tokens = copy
		return value
	}
	return none
}

fn (mut parser Parser) parse_flex_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_flex_unit(component_value.token().dimension_unit()) or { return none }
	return StyleValue(FlexStyleValue.create(Flex.new(component_value.token().dimension_value(),
		unit)))
}

fn (mut parser Parser) parse_frequency_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_frequency_unit(component_value.token().dimension_unit()) or { return none }
	return StyleValue(FrequencyStyleValue.create(Frequency.new(component_value.token().dimension_value(),
		unit)))
}

fn (mut parser Parser) parse_resolution_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_resolution_unit(component_value.token().dimension_unit()) or { return none }
	return StyleValue(ResolutionStyleValue.create(Resolution.new(component_value.token().dimension_value(),
		unit)))
}

fn (mut parser Parser) parse_time_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if component_value.is(.number) && component_value.token().number_value() == 0 {
		return StyleValue(TimeStyleValue.create(Time.new(0, .s)))
	}
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_time_unit(component_value.token().dimension_unit()) or { return none }
	return StyleValue(TimeStyleValue.create(Time.new(component_value.token().dimension_value(),
		unit)))
}

fn (mut parser Parser) parse_string_value(mut tokens ComponentValueStream) ?StringStyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.string) {
		return none
	}
	return StringStyleValue.create(component_value.token().string_value())
}

fn parse_a_comma_separated_list_of_component_values_for_value_logic(values []ComponentValue) [][]ComponentValue {
	mut lists := [][]ComponentValue{}
	mut current := []ComponentValue{}
	for value in values {
		if value.is(.comma) {
			lists << current
			current = []ComponentValue{}
			continue
		}
		current << value
	}
	lists << current
	return lists
}

fn remove_whitespace_from_component_values(values []ComponentValue) []ComponentValue {
	mut result := []ComponentValue{}
	for value in values {
		if value.is(.whitespace) {
			continue
		}
		result << value
	}
	return result
}

fn keyword_to_step_position_for_value_logic(name string) ?StepPosition {
	return match to_ascii_lowercase(name) {
		'jump-start' { StepPosition.jump_start }
		'jump-end' { StepPosition.jump_end }
		'jump-none' { StepPosition.jump_none }
		'jump-both' { StepPosition.jump_both }
		'start' { StepPosition.start }
		'end' { StepPosition.end }
		else { none }
	}
}

fn easing_integer_from_style_value(value StyleValue) ?i64 {
	return match value {
		IntegerStyleValue { value.integer() }
		else { none }
	}
}

fn easing_number_from_style_value(value StyleValue) ?f64 {
	return match value {
		NumberStyleValue { value.number() }
		else { none }
	}
}

fn style_value_resolves_to_percentage_for_value_logic(value StyleValue) bool {
	return value.is_percentage()
		|| (value.is_calculated() && value.as_calculated().resolves_to_percentage())
}

fn color_function_rectangular_color_space_from_string(value string) ?RectangularColorSpace {
	return match to_ascii_lowercase(value) {
		'srgb' { RectangularColorSpace.srgb }
		'srgb-linear' { RectangularColorSpace.srgb_linear }
		'display-p3' { RectangularColorSpace.display_p3 }
		'a98-rgb' { RectangularColorSpace.a98_rgb }
		'prophoto-rgb' { RectangularColorSpace.prophoto_rgb }
		'rec2020' { RectangularColorSpace.rec2020 }
		'lab' { RectangularColorSpace.lab }
		'oklab' { RectangularColorSpace.oklab }
		'xyz' { RectangularColorSpace.xyz_d65 }
		'xyz-d50' { RectangularColorSpace.xyz_d50 }
		'xyz-d65' { RectangularColorSpace.xyz_d65 }
		else { none }
	}
}

fn color_function_polar_color_space_from_string(value string) ?PolarColorSpace {
	return match to_ascii_lowercase(value) {
		'hsl' { PolarColorSpace.hsl }
		'hwb' { PolarColorSpace.hwb }
		'lch' { PolarColorSpace.lch }
		'oklch' { PolarColorSpace.oklch }
		else { none }
	}
}

fn color_function_hue_interpolation_method_from_string(value string) ?HueInterpolationMethod {
	return match to_ascii_lowercase(value) {
		'shorter' { HueInterpolationMethod.shorter }
		'longer' { HueInterpolationMethod.longer }
		'increasing' { HueInterpolationMethod.increasing }
		'decreasing' { HueInterpolationMethod.decreasing }
		else { none }
	}
}

fn color_function_supported_color_space(value string) bool {
	return to_ascii_lowercase(value) in ['srgb', 'srgb-linear', 'display-p3', 'a98-rgb',
		'prophoto-rgb', 'rec2020', 'xyz', 'xyz-d50', 'xyz-d65']
}

struct ParsedColorComponents {
	first  StyleValue
	second StyleValue
	third  StyleValue
	alpha  StyleValue
}

fn (mut parser Parser) parse_easing_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()

	transaction.consume_whitespace()

	part := transaction.consume() or { return none }

	if part.is(.ident) {
		name := part.token().ident()
		maybe_simple_easing := if equals_ignoring_ascii_case(name, 'step-start') {
			?EasingStyleValue(EasingStyleValue.create(EasingStyleValueFunction(EasingSteps{
				number_of_intervals: StyleValue(IntegerStyleValue.create(1))
				position:            .start
			})))
		} else if equals_ignoring_ascii_case(name, 'step-end') {
			?EasingStyleValue(EasingStyleValue.create(EasingStyleValueFunction(EasingSteps{
				number_of_intervals: StyleValue(IntegerStyleValue.create(1))
				position:            .end
			})))
		} else {
			?EasingStyleValue(none)
		}

		easing := maybe_simple_easing or { return none }

		tokens = transaction
		return StyleValue(easing)
	}

	if !part.is_function() {
		return none
	}

	mut comma_separated_arguments :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(part.function().value)

	// Remove whitespace
	for i in 0 .. comma_separated_arguments.len {
		comma_separated_arguments[i] =
			remove_whitespace_from_component_values(comma_separated_arguments[i])
	}

	name := part.function().name

	if equals_ignoring_ascii_case(name, 'linear') {
		// linear() = linear( [ <number> && <percentage>{0,2} ]# )
		mut stops := []EasingLinearStop{}
		for argument in comma_separated_arguments {
			mut argument_tokens := ComponentValueStream.new(argument)

			mut output := ?StyleValue(none)
			mut output_set := false
			mut first_input := ?StyleValue(none)
			mut second_input := ?StyleValue(none)

			if maybe_output := parser.parse_easing_number_value(mut argument_tokens) {
				output = maybe_output
				output_set = true
			}

			if maybe_first_input := parser.parse_percentage_value(mut argument_tokens) {
				first_input = maybe_first_input
				if maybe_second_input := parser.parse_percentage_value(mut argument_tokens) {
					second_input = maybe_second_input
				}
			}

			if maybe_output := parser.parse_easing_number_value(mut argument_tokens) {
				if output_set {
					return none
				}
				output = maybe_output
				output_set = true
			}

			resolved_output := output or { return none }
			if argument_tokens.has_more_tokens() {
				return none
			}

			stops << EasingLinearStop{
				output: resolved_output
				input:  first_input
			}
			if resolved_second_input := second_input {
				stops << EasingLinearStop{
					output: resolved_output
					input:  resolved_second_input
				}
			}
		}

		if stops.len == 0 {
			return none
		}

		tokens = transaction
		return StyleValue(EasingStyleValue.create(EasingStyleValueFunction(EasingLinear{
			stops: stops
		})))
	}

	if equals_ignoring_ascii_case(name, 'cubic-bezier') {
		if comma_separated_arguments.len != 4 {
			return none
		}

		for argument in comma_separated_arguments {
			if argument.len != 1 {
				return none
			}
		}

		mut argument_tokens_0 := ComponentValueStream.new(comma_separated_arguments[0])
		mut argument_tokens_1 := ComponentValueStream.new(comma_separated_arguments[1])
		mut argument_tokens_2 := ComponentValueStream.new(comma_separated_arguments[2])
		mut argument_tokens_3 := ComponentValueStream.new(comma_separated_arguments[3])
		x1 := parser.parse_easing_number_value(mut argument_tokens_0) or { return none }
		y1 := parser.parse_easing_number_value(mut argument_tokens_1) or { return none }
		x2 := parser.parse_easing_number_value(mut argument_tokens_2) or { return none }
		y2 := parser.parse_easing_number_value(mut argument_tokens_3) or { return none }
		x1_number := easing_number_from_style_value(x1) or { return none }
		x2_number := easing_number_from_style_value(x2) or { return none }
		if x1_number < 0.0 || x1_number > 1.0 {
			return none
		}
		if x2_number < 0.0 || x2_number > 1.0 {
			return none
		}

		bezier := EasingCubicBezier{
			x1: x1
			y1: y1
			x2: x2
			y2: y2
		}

		tokens = transaction
		return StyleValue(EasingStyleValue.create(EasingStyleValueFunction(bezier)))
	}

	if equals_ignoring_ascii_case(name, 'steps') {
		if comma_separated_arguments.len == 0 || comma_separated_arguments.len > 2 {
			return none
		}

		for argument in comma_separated_arguments {
			if argument.len != 1 {
				return none
			}
		}

		mut position := StepPosition.end

		if comma_separated_arguments.len == 2 {
			if comma_separated_arguments[1].len != 1 {
				return none
			}

			token := comma_separated_arguments[1][0]

			if !token.is(.ident) {
				return none
			}

			step_position := keyword_to_step_position_for_value_logic(token.token().ident()) or {
				return none
			}

			position = step_position
		}

		intervals_argument := comma_separated_arguments[0][0]
		mut intervals_token := ComponentValueStream.new([intervals_argument])
		intervals := parser.parse_integer_value(mut intervals_token) or { return none }

		// Perform extra validation
		// https://drafts.csswg.org/css-easing/#step-easing-functions
		// If the <step-position> is jump-none, the <integer> must be at least 2, or the function is invalid.
		// Otherwise, the <integer> must be at least 1, or the function is invalid.
		if integer := easing_integer_from_style_value(intervals) {
			if position == .jump_none {
				if integer <= 1 {
					return none
				}
			} else if integer <= 0 {
				return none
			}
		}

		tokens = transaction
		return StyleValue(EasingStyleValue.create(EasingStyleValueFunction(EasingSteps{
			number_of_intervals: intervals
			position:            position
		})))
	}

	return none
}

fn (mut parser Parser) parse_hue_none_value(mut tokens ComponentValueStream) ?StyleValue {
	// Parses [<hue> | none]
	//   <hue> = <number> | <angle>
	if angle := parser.parse_angle_value(mut tokens) {
		return angle
	}
	if number := parser.parse_number_value(mut tokens) {
		return number
	}
	tokens.consume_whitespace()
	if value := tokens.peek() {
		if value.is(.ident) && equals_ignoring_ascii_case(value.token().ident(), 'none') {
			tokens.consume()
			return StyleValue(KeywordStyleValue.create(.none_))
		}
	}
	return none
}

fn (mut parser Parser) parse_solidus_and_alpha_value(mut tokens ComponentValueStream) ?StyleValue {
	// [ / [<alpha-value> | none] ]?
	// <alpha-value> = <number> | <percentage>
	// Common to the modern-syntax color functions.
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	solidus := transaction.consume() or { return none }
	if !solidus.is_delim(u32(`/`)) {
		return none
	}
	transaction.consume_whitespace()
	alpha := parser.parse_number_percentage_none_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	tokens = transaction
	return alpha
}

fn (mut parser Parser) parse_rgb_color_value(component_value ComponentValue) ?StyleValue {
	// rgb() = [ <legacy-rgb-syntax> | <modern-rgb-syntax> ]
	// rgba() = [ <legacy-rgba-syntax> | <modern-rgba-syntax> ]
	// <legacy-rgb-syntax> = rgb( <percentage>#{3} , <alpha-value>? ) |
	//                       rgb( <number>#{3} , <alpha-value>? )
	// <legacy-rgba-syntax> = rgba( <percentage>#{3} , <alpha-value>? ) |
	//                        rgba( <number>#{3} , <alpha-value>? )
	// <modern-rgb-syntax> = rgb(
	//     [ <number> | <percentage> | none]{3}
	//     [ / [<alpha-value> | none] ]?  )
	// <modern-rgba-syntax> = rgba(
	//     [ <number> | <percentage> | none]{3}
	//     [ / [<alpha-value> | none] ]?  )
	if !component_value.is_function_named('rgb') && !component_value.is_function_named('rgba') {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	red := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }

	inner_tokens.consume_whitespace()
	legacy_syntax := if next := inner_tokens.peek() {
		next.is(.comma)
	} else {
		false
	}

	mut green := ?StyleValue(none)
	mut blue := ?StyleValue(none)
	mut alpha := ?StyleValue(none)

	if legacy_syntax {
		// Legacy syntax
		//   <percentage>#{3} , <alpha-value>?
		//   | <number>#{3} , <alpha-value>?
		// So, r/g/b can be numbers or percentages, as long as they're all the same type.
		//
		// We accepted the 'none' keyword when parsing the red value, but it's not allowed in the legacy syntax.
		if red.is_keyword() {
			return none
		}

		inner_tokens.consume()
		inner_tokens.consume_whitespace()
		green = parser.parse_number_percentage_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()

		comma := inner_tokens.consume() or { return none }
		if !comma.is(.comma) {
			return none
		}
		inner_tokens.consume_whitespace()
		blue = parser.parse_number_percentage_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()

		if inner_tokens.has_more_tokens() {
			alpha_comma := inner_tokens.consume() or { return none }
			if !alpha_comma.is(.comma) {
				return none
			}
			inner_tokens.consume_whitespace()
			alpha = parser.parse_number_percentage_value(mut inner_tokens) or { return none }
			inner_tokens.consume_whitespace()
			if inner_tokens.has_more_tokens() {
				return none
			}
		}

		// Verify we're all percentages or all numbers.
		green_value := green or { return none }
		blue_value := blue or { return none }
		red_is_percentage := style_value_resolves_to_percentage_for_value_logic(red)
		green_is_percentage := style_value_resolves_to_percentage_for_value_logic(green_value)
		blue_is_percentage := style_value_resolves_to_percentage_for_value_logic(blue_value)
		if red_is_percentage != green_is_percentage || red_is_percentage != blue_is_percentage {
			return none
		}
	} else {
		// Modern syntax
		//   [ <number> | <percentage> | none]{3}  [ / [<alpha-value> | none] ]?
		green = parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()
		blue = parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()

		if inner_tokens.has_more_tokens() {
			alpha = parser.parse_solidus_and_alpha_value(mut inner_tokens) or { return none }
			if inner_tokens.has_more_tokens() {
				return none
			}
		}
	}

	green_value := green or { return none }
	blue_value := blue or { return none }
	return StyleValue(RGBColorStyleValue.create(red, green_value, blue_value, alpha, if legacy_syntax {
		.legacy
	} else {
		.modern
	}, none))
}

fn (mut parser Parser) parse_hsl_color_value(component_value ComponentValue) ?StyleValue {
	// hsl() = [ <legacy-hsl-syntax> | <modern-hsl-syntax> ]
	// hsla() = [ <legacy-hsla-syntax> | <modern-hsla-syntax> ]
	if !component_value.is_function_named('hsl') && !component_value.is_function_named('hsla') {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	hue := parser.parse_hue_none_value(mut inner_tokens) or { return none }

	inner_tokens.consume_whitespace()
	legacy_syntax := if next := inner_tokens.peek() {
		next.is(.comma)
	} else {
		false
	}

	mut saturation := ?StyleValue(none)
	mut lightness := ?StyleValue(none)
	mut alpha := ?StyleValue(none)

	if legacy_syntax {
		// Legacy syntax
		//   <hue>, <percentage>, <percentage>, <alpha-value>?
		//
		// We accepted the 'none' keyword when parsing the h value, but it's not allowed in the legacy syntax.
		if hue.is_keyword() {
			return none
		}

		inner_tokens.consume()
		inner_tokens.consume_whitespace()
		saturation = parser.parse_percentage_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()

		comma := inner_tokens.consume() or { return none }
		if !comma.is(.comma) {
			return none
		}
		inner_tokens.consume_whitespace()
		lightness = parser.parse_percentage_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()

		if inner_tokens.has_more_tokens() {
			alpha_comma := inner_tokens.consume() or { return none }
			if !alpha_comma.is(.comma) {
				return none
			}
			inner_tokens.consume_whitespace()
			alpha = parser.parse_number_percentage_value(mut inner_tokens) or { return none }
			inner_tokens.consume_whitespace()
			if inner_tokens.has_more_tokens() {
				return none
			}
		}
	} else {
		// Modern syntax
		//   [<hue> | none]
		//   [<percentage> | <number> | none]
		//   [<percentage> | <number> | none]
		//   [ / [<alpha-value> | none] ]?
		saturation = parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()
		lightness = parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()

		if inner_tokens.has_more_tokens() {
			alpha = parser.parse_solidus_and_alpha_value(mut inner_tokens) or { return none }
			if inner_tokens.has_more_tokens() {
				return none
			}
		}
	}

	saturation_value := saturation or { return none }
	lightness_value := lightness or { return none }
	return StyleValue(HSLColorStyleValue.create(hue, saturation_value, lightness_value, alpha, if legacy_syntax {
		.legacy
	} else {
		.modern
	}))
}

fn (mut parser Parser) parse_hwb_color_value(component_value ComponentValue) ?StyleValue {
	// hwb() = hwb(
	//     [<hue> | none]
	//     [<percentage> | <number> | none]
	//     [<percentage> | <number> | none]
	//     [ / [<alpha-value> | none] ]? )
	if !component_value.is_function_named('hwb') {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	hue := parser.parse_hue_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	whiteness := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	blackness := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()

	mut alpha := ?StyleValue(none)
	if inner_tokens.has_more_tokens() {
		alpha = parser.parse_solidus_and_alpha_value(mut inner_tokens) or { return none }
		if inner_tokens.has_more_tokens() {
			return none
		}
	}

	return StyleValue(HWBColorStyleValue.create(hue, whiteness, blackness, alpha, .modern))
}

fn (mut parser Parser) parse_lab_like_color_value(component_value ComponentValue, function_name string) ?ParsedColorComponents {
	// This helper is designed to be compatible with lab and oklab and parses a function with a form like:
	// f() = f( [ <percentage> | <number> | none]
	//     [ <percentage> | <number> | none]
	//     [ <percentage> | <number> | none]
	//     [ / [<alpha-value> | none] ]? )
	if !component_value.is_function_named(function_name) {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	first := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	second := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	third := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()

	mut alpha := ?StyleValue(none)
	if inner_tokens.has_more_tokens() {
		alpha = parser.parse_solidus_and_alpha_value(mut inner_tokens) or { return none }
		if inner_tokens.has_more_tokens() {
			return none
		}
	}

	return ParsedColorComponents{
		first:  first
		second: second
		third:  third
		alpha:  alpha or { StyleValue(NumberStyleValue.create(1)) }
	}
}

fn (mut parser Parser) parse_lch_like_color_value(component_value ComponentValue, function_name string) ?ParsedColorComponents {
	// This helper is designed to be compatible with lch and oklch and parses a function with a form like:
	// f() = f( [<percentage> | <number> | none]
	//     [ <percentage> | <number> | none]
	//     [ <hue> | none]
	//     [ / [<alpha-value> | none] ]? )
	if !component_value.is_function_named(function_name) {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	first := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	second := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	third := parser.parse_hue_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()

	mut alpha := ?StyleValue(none)
	if inner_tokens.has_more_tokens() {
		alpha = parser.parse_solidus_and_alpha_value(mut inner_tokens) or { return none }
		if inner_tokens.has_more_tokens() {
			return none
		}
	}

	return ParsedColorComponents{
		first:  first
		second: second
		third:  third
		alpha:  alpha or { StyleValue(NumberStyleValue.create(1)) }
	}
}

fn (mut parser Parser) parse_color_function(component_value ComponentValue) ?StyleValue {
	// color() = color( <colorspace-params> [ / [ <alpha-value> | none ] ]? )
	//     <colorspace-params> = [ <predefined-rgb-params> | <xyz-params>]
	//     <predefined-rgb-params> = <predefined-rgb> [ <number> | <percentage> | none ]{3}
	//     <predefined-rgb> = srgb | srgb-linear | display-p3 | a98-rgb | prophoto-rgb | rec2020
	//     <xyz-params> = <xyz-space> [ <number> | <percentage> | none ]{3}
	//     <xyz-space> = xyz | xyz-d50 | xyz-d65
	if !component_value.is_function_named('color') {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	maybe_color_space := inner_tokens.consume() or { return none }
	if !maybe_color_space.is(.ident) {
		return none
	}
	color_space := to_ascii_lowercase(maybe_color_space.token().ident())
	if !color_function_supported_color_space(color_space) {
		return none
	}

	inner_tokens.consume_whitespace()
	c1 := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	c2 := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	c3 := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()

	mut alpha := ?StyleValue(none)
	if inner_tokens.has_more_tokens() {
		alpha = parser.parse_solidus_and_alpha_value(mut inner_tokens) or { return none }
		if inner_tokens.has_more_tokens() {
			return none
		}
	}

	return StyleValue(ColorFunctionStyleValue.create(color_space, c1, c2, c3, alpha))
}

fn (mut parser Parser) parse_color_interpolation_method_value(mut tokens ComponentValueStream) ?ColorInterpolationMethodStyleValue {
	// <rectangular-color-space> = srgb | srgb-linear | display-p3 | display-p3-linear | a98-rgb | prophoto-rgb | rec2020 | lab | oklab | <xyz-space>
	// <polar-color-space> = hsl | hwb | lch | oklch
	// <custom-color-space> = <dashed-ident>
	// <hue-interpolation-method> = [ shorter | longer | increasing | decreasing ] hue
	// <color-interpolation-method> = in [ <rectangular-color-space> | <polar-color-space> <hue-interpolation-method>? | <custom-color-space> ]
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	in_token := transaction.consume() or { return none }
	if !in_token.is(.ident) || !equals_ignoring_ascii_case(in_token.token().ident(), 'in') {
		return none
	}

	transaction.consume_whitespace()
	color_space_token := transaction.consume() or { return none }
	if !color_space_token.is(.ident) {
		return none
	}
	color_space_name := color_space_token.token().ident()

	if rectangular_color_space := color_function_rectangular_color_space_from_string(color_space_name) {
		tokens = transaction
		return ColorInterpolationMethodStyleValue.create(ColorInterpolationMethod(rectangular_color_space))
	}

	if polar_color_space := color_function_polar_color_space_from_string(color_space_name) {
		mut hue_interpolation_method := HueInterpolationMethod.shorter
		transaction.consume_whitespace()
		if maybe_hue_method_token := transaction.peek() {
			if maybe_hue_method_token.is(.ident) {
				if maybe_hue_method := color_function_hue_interpolation_method_from_string(maybe_hue_method_token.token().ident()) {
					transaction.consume()
					hue_interpolation_method = maybe_hue_method
					transaction.consume_whitespace()
					hue_token := transaction.consume() or { return none }
					if !hue_token.is(.ident)
						|| !equals_ignoring_ascii_case(hue_token.token().ident(), 'hue') {
						return none
					}
				}
			}
		}

		tokens = transaction
		return ColorInterpolationMethodStyleValue.create(ColorInterpolationMethod(PolarColorInterpolationMethod{
			color_space:              polar_color_space
			hue_interpolation_method: hue_interpolation_method
		}))
	}

	// TODO: Support <custom-color-space> once we support @color-profile rules.
	return none
}

fn (mut parser Parser) parse_color_mix_component(mut tokens ComponentValueStream) ?ColorMixComponent {
	tokens.consume_whitespace()
	mut percentage_style_value := ?StyleValue(none)
	if percentage := parser.parse_percentage_value(mut tokens) {
		percentage_style_value = percentage
	}
	tokens.consume_whitespace()

	color_style_value := parser.parse_color_value(mut tokens) or { return none }
	tokens.consume_whitespace()
	if percentage_style_value == none {
		if percentage := parser.parse_percentage_value(mut tokens) {
			percentage_style_value = percentage
			tokens.consume_whitespace()
		}
	}

	mut percentage_or_calculated := ?PercentageOrCalculated(none)
	if percentage_value := percentage_style_value {
		if !percentage_value.is_calculated() {
			percentage := percentage_value.as_percentage().percentage().value()
			if percentage < 0 || percentage > 100 {
				return none
			}
			percentage_or_calculated =
				PercentageOrCalculated.from_percentage(percentage_value.as_percentage().percentage())
		} else {
			percentage_or_calculated =
				PercentageOrCalculated.from_calculated(percentage_value.as_calculated())
		}
	}

	return ColorMixComponent{
		color:      color_style_value
		percentage: percentage_or_calculated
	}
}

fn (mut parser Parser) parse_color_mix_function(component_value ComponentValue) ?StyleValue {
	// color-mix() = color-mix( <color-interpolation-method>? , [ <color> && <percentage [0,100]>? ]#)
	// FIXME: Update color-mix to accept 1+ colors instead of exactly 2.
	if !component_value.is_function_named('color-mix') {
		return none
	}

	mut function_tokens := ComponentValueStream.new(component_value.function().value)
	mut color_interpolation_method := ?ColorInterpolationMethodStyleValue(none)
	if method := parser.parse_color_interpolation_method_value(mut function_tokens) {
		color_interpolation_method = method
		function_tokens.consume_whitespace()
		comma := function_tokens.consume() or { return none }
		if !comma.is(.comma) {
			return none
		}
	}

	first_component := parser.parse_color_mix_component(mut function_tokens) or { return none }
	function_tokens.consume_whitespace()
	comma := function_tokens.consume() or { return none }
	if !comma.is(.comma) {
		return none
	}
	second_component := parser.parse_color_mix_component(mut function_tokens) or { return none }

	if first_percentage := first_component.percentage {
		if second_percentage := second_component.percentage {
			if !first_percentage.is_calculated() && !second_percentage.is_calculated()
				&& first_percentage.value().value() == 0 && second_percentage.value().value() == 0 {
				return none
			}
		}
	}

	function_tokens.consume_whitespace()
	if function_tokens.has_more_tokens() {
		return none
	}

	return StyleValue(ColorMixStyleValue.create(color_interpolation_method, first_component,
		second_component))
}

fn (mut parser Parser) parse_light_dark_color_value(component_value ComponentValue) ?StyleValue {
	if !component_value.is_function_named('light-dark') {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	light := parser.parse_color_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	comma := inner_tokens.consume() or { return none }
	if !comma.is(.comma) {
		return none
	}
	inner_tokens.consume_whitespace()
	dark := parser.parse_color_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	if inner_tokens.has_more_tokens() {
		return none
	}
	return StyleValue(LightDarkStyleValue.create(light, dark))
}

fn (mut parser Parser) parse_color_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }

	// Keywords: <system-color> | <deprecated-color> | currentColor
	if component_value.is(.ident) {
		ident := component_value.token().ident()
		if keyword := keyword_from_string(ident) {
			if KeywordStyleValue.is_color(keyword) {
				return StyleValue(KeywordStyleValue.create(keyword))
			}
		}
		if color := named_css_color_for_value_logic(ident) {
			return StyleValue(ColorStyleValue.create_from_color(color, .legacy, ident))
		}
		return none
	}

	// Functions
	if color := parser.parse_color_function(component_value) {
		return color
	}
	if color := parser.parse_color_mix_function(component_value) {
		return color
	}
	if rgb := parser.parse_rgb_color_value(component_value) {
		return rgb
	}
	if hsl := parser.parse_hsl_color_value(component_value) {
		return hsl
	}
	if hwb := parser.parse_hwb_color_value(component_value) {
		return hwb
	}
	if lab_values := parser.parse_lab_like_color_value(component_value, 'lab') {
		return StyleValue(LabColorStyleValue.create(lab_values.first, lab_values.second,
			lab_values.third, lab_values.alpha))
	}
	if lch_values := parser.parse_lch_like_color_value(component_value, 'lch') {
		return StyleValue(LCHColorStyleValue.create(lch_values.first, lch_values.second,
			lch_values.third, lch_values.alpha))
	}
	if oklab_values := parser.parse_lab_like_color_value(component_value, 'oklab') {
		return StyleValue(OKLabColorStyleValue.create(oklab_values.first, oklab_values.second,
			oklab_values.third, oklab_values.alpha))
	}
	if oklch_values := parser.parse_lch_like_color_value(component_value, 'oklch') {
		return StyleValue(OKLCHColorStyleValue.create(oklch_values.first, oklch_values.second,
			oklch_values.third, oklch_values.alpha))
	}
	if light_dark := parser.parse_light_dark_color_value(component_value) {
		return light_dark
	}

	if component_value.is(.hash) {
		color := parse_hash_color_for_value_logic(component_value.token().hash_value()) or {
			return none
		}
		return StyleValue(ColorStyleValue.create_from_color(color, .legacy, none))
	}

	return none
}

fn parse_hash_color_for_value_logic(value string) ?Color {
	if value.len !in [3, 4, 6, 8] {
		return none
	}
	mut expanded := ''
	if value.len == 3 || value.len == 4 {
		for ch in value {
			expanded += '${rune(ch)}${rune(ch)}'
		}
	} else {
		expanded = value
	}
	r := strconv.parse_uint(expanded[0..2], 16, 8) or { return none }
	g := strconv.parse_uint(expanded[2..4], 16, 8) or { return none }
	b := strconv.parse_uint(expanded[4..6], 16, 8) or { return none }
	a := if expanded.len == 8 {
		strconv.parse_uint(expanded[6..8], 16, 8) or { return none }
	} else {
		u64(255)
	}
	return Color.rgba(u8(r), u8(g), u8(b), u8(a))
}

fn color_from_rgb_hex_for_value_logic(value int) Color {
	return Color.rgb(u8((value >> 16) & 0xff), u8((value >> 8) & 0xff), u8(value & 0xff))
}

fn named_css_color_for_value_logic(value string) ?Color {
	if equals_ignoring_ascii_case(value, 'transparent') {
		return Color.rgba(0, 0, 0, 0)
	}

	return match to_ascii_lowercase(value) {
		// CSS Level 1
		'black' { color_from_rgb_hex_for_value_logic(0x000000) }
		'silver' { color_from_rgb_hex_for_value_logic(0xc0c0c0) }
		'gray' { color_from_rgb_hex_for_value_logic(0x808080) }
		'white' { color_from_rgb_hex_for_value_logic(0xffffff) }
		'maroon' { color_from_rgb_hex_for_value_logic(0x800000) }
		'red' { color_from_rgb_hex_for_value_logic(0xff0000) }
		'purple' { color_from_rgb_hex_for_value_logic(0x800080) }
		'fuchsia' { color_from_rgb_hex_for_value_logic(0xff00ff) }
		'green' { color_from_rgb_hex_for_value_logic(0x008000) }
		'lime' { color_from_rgb_hex_for_value_logic(0x00ff00) }
		'olive' { color_from_rgb_hex_for_value_logic(0x808000) }
		'yellow' { color_from_rgb_hex_for_value_logic(0xffff00) }
		'navy' { color_from_rgb_hex_for_value_logic(0x000080) }
		'blue' { color_from_rgb_hex_for_value_logic(0x0000ff) }
		'teal' { color_from_rgb_hex_for_value_logic(0x008080) }
		'aqua' { color_from_rgb_hex_for_value_logic(0x00ffff) }
		// CSS Level 2 (Revision 1)
		'orange' { color_from_rgb_hex_for_value_logic(0xffa500) }
		// CSS Color Module Level 3
		'aliceblue' { color_from_rgb_hex_for_value_logic(0xf0f8ff) }
		'antiquewhite' { color_from_rgb_hex_for_value_logic(0xfaebd7) }
		'aquamarine' { color_from_rgb_hex_for_value_logic(0x7fffd4) }
		'azure' { color_from_rgb_hex_for_value_logic(0xf0ffff) }
		'beige' { color_from_rgb_hex_for_value_logic(0xf5f5dc) }
		'bisque' { color_from_rgb_hex_for_value_logic(0xffe4c4) }
		'blanchedalmond' { color_from_rgb_hex_for_value_logic(0xffebcd) }
		'blueviolet' { color_from_rgb_hex_for_value_logic(0x8a2be2) }
		'brown' { color_from_rgb_hex_for_value_logic(0xa52a2a) }
		'burlywood' { color_from_rgb_hex_for_value_logic(0xdeb887) }
		'cadetblue' { color_from_rgb_hex_for_value_logic(0x5f9ea0) }
		'chartreuse' { color_from_rgb_hex_for_value_logic(0x7fff00) }
		'chocolate' { color_from_rgb_hex_for_value_logic(0xd2691e) }
		'coral' { color_from_rgb_hex_for_value_logic(0xff7f50) }
		'cornflowerblue' { color_from_rgb_hex_for_value_logic(0x6495ed) }
		'cornsilk' { color_from_rgb_hex_for_value_logic(0xfff8dc) }
		'crimson' { color_from_rgb_hex_for_value_logic(0xdc143c) }
		'cyan' { color_from_rgb_hex_for_value_logic(0x00ffff) }
		'darkblue' { color_from_rgb_hex_for_value_logic(0x00008b) }
		'darkcyan' { color_from_rgb_hex_for_value_logic(0x008b8b) }
		'darkgoldenrod' { color_from_rgb_hex_for_value_logic(0xb8860b) }
		'darkgray' { color_from_rgb_hex_for_value_logic(0xa9a9a9) }
		'darkgreen' { color_from_rgb_hex_for_value_logic(0x006400) }
		'darkgrey' { color_from_rgb_hex_for_value_logic(0xa9a9a9) }
		'darkkhaki' { color_from_rgb_hex_for_value_logic(0xbdb76b) }
		'darkmagenta' { color_from_rgb_hex_for_value_logic(0x8b008b) }
		'darkolivegreen' { color_from_rgb_hex_for_value_logic(0x556b2f) }
		'darkorange' { color_from_rgb_hex_for_value_logic(0xff8c00) }
		'darkorchid' { color_from_rgb_hex_for_value_logic(0x9932cc) }
		'darkred' { color_from_rgb_hex_for_value_logic(0x8b0000) }
		'darksalmon' { color_from_rgb_hex_for_value_logic(0xe9967a) }
		'darkseagreen' { color_from_rgb_hex_for_value_logic(0x8fbc8f) }
		'darkslateblue' { color_from_rgb_hex_for_value_logic(0x483d8b) }
		'darkslategray' { color_from_rgb_hex_for_value_logic(0x2f4f4f) }
		'darkslategrey' { color_from_rgb_hex_for_value_logic(0x2f4f4f) }
		'darkturquoise' { color_from_rgb_hex_for_value_logic(0x00ced1) }
		'darkviolet' { color_from_rgb_hex_for_value_logic(0x9400d3) }
		'deeppink' { color_from_rgb_hex_for_value_logic(0xff1493) }
		'deepskyblue' { color_from_rgb_hex_for_value_logic(0x00bfff) }
		'dimgray' { color_from_rgb_hex_for_value_logic(0x696969) }
		'dimgrey' { color_from_rgb_hex_for_value_logic(0x696969) }
		'dodgerblue' { color_from_rgb_hex_for_value_logic(0x1e90ff) }
		'firebrick' { color_from_rgb_hex_for_value_logic(0xb22222) }
		'floralwhite' { color_from_rgb_hex_for_value_logic(0xfffaf0) }
		'forestgreen' { color_from_rgb_hex_for_value_logic(0x228b22) }
		'gainsboro' { color_from_rgb_hex_for_value_logic(0xdcdcdc) }
		'ghostwhite' { color_from_rgb_hex_for_value_logic(0xf8f8ff) }
		'gold' { color_from_rgb_hex_for_value_logic(0xffd700) }
		'goldenrod' { color_from_rgb_hex_for_value_logic(0xdaa520) }
		'greenyellow' { color_from_rgb_hex_for_value_logic(0xadff2f) }
		'grey' { color_from_rgb_hex_for_value_logic(0x808080) }
		'honeydew' { color_from_rgb_hex_for_value_logic(0xf0fff0) }
		'hotpink' { color_from_rgb_hex_for_value_logic(0xff69b4) }
		'indianred' { color_from_rgb_hex_for_value_logic(0xcd5c5c) }
		'indigo' { color_from_rgb_hex_for_value_logic(0x4b0082) }
		'ivory' { color_from_rgb_hex_for_value_logic(0xfffff0) }
		'khaki' { color_from_rgb_hex_for_value_logic(0xf0e68c) }
		'lavender' { color_from_rgb_hex_for_value_logic(0xe6e6fa) }
		'lavenderblush' { color_from_rgb_hex_for_value_logic(0xfff0f5) }
		'lawngreen' { color_from_rgb_hex_for_value_logic(0x7cfc00) }
		'lemonchiffon' { color_from_rgb_hex_for_value_logic(0xfffacd) }
		'lightblue' { color_from_rgb_hex_for_value_logic(0xadd8e6) }
		'lightcoral' { color_from_rgb_hex_for_value_logic(0xf08080) }
		'lightcyan' { color_from_rgb_hex_for_value_logic(0xe0ffff) }
		'lightgoldenrodyellow' { color_from_rgb_hex_for_value_logic(0xfafad2) }
		'lightgray' { color_from_rgb_hex_for_value_logic(0xd3d3d3) }
		'lightgreen' { color_from_rgb_hex_for_value_logic(0x90ee90) }
		'lightgrey' { color_from_rgb_hex_for_value_logic(0xd3d3d3) }
		'lightpink' { color_from_rgb_hex_for_value_logic(0xffb6c1) }
		'lightsalmon' { color_from_rgb_hex_for_value_logic(0xffa07a) }
		'lightseagreen' { color_from_rgb_hex_for_value_logic(0x20b2aa) }
		'lightskyblue' { color_from_rgb_hex_for_value_logic(0x87cefa) }
		'lightslategray' { color_from_rgb_hex_for_value_logic(0x778899) }
		'lightslategrey' { color_from_rgb_hex_for_value_logic(0x778899) }
		'lightsteelblue' { color_from_rgb_hex_for_value_logic(0xb0c4de) }
		'lightyellow' { color_from_rgb_hex_for_value_logic(0xffffe0) }
		'limegreen' { color_from_rgb_hex_for_value_logic(0x32cd32) }
		'linen' { color_from_rgb_hex_for_value_logic(0xfaf0e6) }
		'magenta' { color_from_rgb_hex_for_value_logic(0xff00ff) }
		'mediumaquamarine' { color_from_rgb_hex_for_value_logic(0x66cdaa) }
		'mediumblue' { color_from_rgb_hex_for_value_logic(0x0000cd) }
		'mediumorchid' { color_from_rgb_hex_for_value_logic(0xba55d3) }
		'mediumpurple' { color_from_rgb_hex_for_value_logic(0x9370db) }
		'mediumseagreen' { color_from_rgb_hex_for_value_logic(0x3cb371) }
		'mediumslateblue' { color_from_rgb_hex_for_value_logic(0x7b68ee) }
		'mediumspringgreen' { color_from_rgb_hex_for_value_logic(0x00fa9a) }
		'mediumturquoise' { color_from_rgb_hex_for_value_logic(0x48d1cc) }
		'mediumvioletred' { color_from_rgb_hex_for_value_logic(0xc71585) }
		'midnightblue' { color_from_rgb_hex_for_value_logic(0x191970) }
		'mintcream' { color_from_rgb_hex_for_value_logic(0xf5fffa) }
		'mistyrose' { color_from_rgb_hex_for_value_logic(0xffe4e1) }
		'moccasin' { color_from_rgb_hex_for_value_logic(0xffe4b5) }
		'navajowhite' { color_from_rgb_hex_for_value_logic(0xffdead) }
		'oldlace' { color_from_rgb_hex_for_value_logic(0xfdf5e6) }
		'olivedrab' { color_from_rgb_hex_for_value_logic(0x6b8e23) }
		'orangered' { color_from_rgb_hex_for_value_logic(0xff4500) }
		'orchid' { color_from_rgb_hex_for_value_logic(0xda70d6) }
		'palegoldenrod' { color_from_rgb_hex_for_value_logic(0xeee8aa) }
		'palegreen' { color_from_rgb_hex_for_value_logic(0x98fb98) }
		'paleturquoise' { color_from_rgb_hex_for_value_logic(0xafeeee) }
		'palevioletred' { color_from_rgb_hex_for_value_logic(0xdb7093) }
		'papayawhip' { color_from_rgb_hex_for_value_logic(0xffefd5) }
		'peachpuff' { color_from_rgb_hex_for_value_logic(0xffdab9) }
		'peru' { color_from_rgb_hex_for_value_logic(0xcd853f) }
		'pink' { color_from_rgb_hex_for_value_logic(0xffc0cb) }
		'plum' { color_from_rgb_hex_for_value_logic(0xdda0dd) }
		'powderblue' { color_from_rgb_hex_for_value_logic(0xb0e0e6) }
		'rosybrown' { color_from_rgb_hex_for_value_logic(0xbc8f8f) }
		'royalblue' { color_from_rgb_hex_for_value_logic(0x4169e1) }
		'saddlebrown' { color_from_rgb_hex_for_value_logic(0x8b4513) }
		'salmon' { color_from_rgb_hex_for_value_logic(0xfa8072) }
		'sandybrown' { color_from_rgb_hex_for_value_logic(0xf4a460) }
		'seagreen' { color_from_rgb_hex_for_value_logic(0x2e8b57) }
		'seashell' { color_from_rgb_hex_for_value_logic(0xfff5ee) }
		'sienna' { color_from_rgb_hex_for_value_logic(0xa0522d) }
		'skyblue' { color_from_rgb_hex_for_value_logic(0x87ceeb) }
		'slateblue' { color_from_rgb_hex_for_value_logic(0x6a5acd) }
		'slategray' { color_from_rgb_hex_for_value_logic(0x708090) }
		'slategrey' { color_from_rgb_hex_for_value_logic(0x708090) }
		'snow' { color_from_rgb_hex_for_value_logic(0xfffafa) }
		'springgreen' { color_from_rgb_hex_for_value_logic(0x00ff7f) }
		'steelblue' { color_from_rgb_hex_for_value_logic(0x4682b4) }
		'tan' { color_from_rgb_hex_for_value_logic(0xd2b48c) }
		'thistle' { color_from_rgb_hex_for_value_logic(0xd8bfd8) }
		'tomato' { color_from_rgb_hex_for_value_logic(0xff6347) }
		'turquoise' { color_from_rgb_hex_for_value_logic(0x40e0d0) }
		'violet' { color_from_rgb_hex_for_value_logic(0xee82ee) }
		'wheat' { color_from_rgb_hex_for_value_logic(0xf5deb3) }
		'whitesmoke' { color_from_rgb_hex_for_value_logic(0xf5f5f5) }
		'yellowgreen' { color_from_rgb_hex_for_value_logic(0x9acd32) }
		// CSS Color Module Level 4
		'rebeccapurple' { color_from_rgb_hex_for_value_logic(0x663399) }
		else { none }
	}
}

fn (mut parser Parser) parse_color_scheme_value(mut tokens ComponentValueStream) ?StyleValue {
	// normal | [ light | dark | <custom-ident> ]+ && only?

	// normal
	{
		mut transaction := tokens.clone()
		transaction.consume_whitespace()
		token := transaction.consume() or { return none }
		if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'normal') {
			if transaction.has_more_tokens() {
				return none
			}
			tokens = transaction
			return StyleValue(ColorSchemeStyleValue.normal())
		}
	}

	mut only := false
	mut schemes := []string{}

	// only? && (..)
	{
		mut transaction := tokens.clone()
		transaction.consume_whitespace()
		if token := transaction.consume() {
			if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'only') {
				only = true
				tokens = transaction
			}
		}
	}

	// [ light | dark | <custom-ident> ]+
	tokens.consume_whitespace()
	for tokens.has_more_tokens() {
		mut transaction := tokens.clone()

		// The 'normal', 'light', 'dark', and 'only' keywords are not valid <custom-ident>s in this property.
		// Note: only 'normal' is blacklisted here because 'light' and 'dark' aren't parsed differently and 'only' is checked for afterwards
		ident := parser.parse_custom_ident_value(mut transaction, ['normal']) or { return none }

		if ident.custom_ident() == 'only' {
			break
		}

		schemes << ident.custom_ident()
		transaction.consume_whitespace()
		tokens = transaction
	}

	// (..) && only?
	if !only {
		mut transaction := tokens.clone()
		transaction.consume_whitespace()
		if token := transaction.consume() {
			if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'only') {
				only = true
				tokens = transaction
			}
		}
	}

	tokens.consume_whitespace()
	if tokens.has_more_tokens() || schemes.len == 0 {
		return none
	}

	return StyleValue(ColorSchemeStyleValue.create(schemes, only))
}

pub fn (mut parser Parser) parse_descriptor_value(at_rule_id AtRuleID, descriptor_id DescriptorID) ?StyleValue {
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_descriptor_value_tokens(at_rule_id, descriptor_id, mut tokens)
}

fn (mut parser Parser) parse_descriptor_value_tokens(at_rule_id AtRuleID, descriptor_id DescriptorID, mut tokens ComponentValueStream) ?StyleValue {
	mut maybe_value := ?StyleValue(none)
	match at_rule_id {
		.page {
			maybe_value = match descriptor_id {
				.margin {
					parser.parse_page_margin_shorthand_descriptor_value(mut tokens)
				}
				.margin_top, .margin_right, .margin_bottom, .margin_left {
					parser.parse_page_margin_longhand_descriptor_value(mut tokens)
				}
				.bleed {
					parser.parse_page_bleed_descriptor_value(mut tokens)
				}
				.size {
					parser.parse_page_size_descriptor_value(mut tokens)
				}
				.page_orientation {
					parser.parse_page_orientation_descriptor_value(mut tokens)
				}
				.marks {
					parser.parse_page_marks_descriptor_value(mut tokens)
				}
				.unknown {
					?StyleValue(none)
				}
			}
		}
		.font_face, .counter_style {
			maybe_value = parser.parse_builtin_value(mut tokens)
		}
	}

	value := maybe_value or { return none }
	if value.is_css_wide_keyword() || value.type_() == .unresolved {
		return none
	}

	tokens.consume_whitespace()
	if !tokens.is_empty() {
		return none
	}
	return value
}

fn descriptor_ident_style_value(value string) StyleValue {
	return StyleValue(CustomIdentStyleValue.create(value))
}

// https://www.w3.org/TR/css-values-4/#custom-idents
fn (mut parser Parser) parse_custom_ident(mut tokens ComponentValueStream, blacklist []string) ?string {
	_ = parser
	mut transaction := tokens.clone()
	transaction.consume_whitespace()

	token := transaction.consume() or { return none }
	if !token.is(.ident) {
		return none
	}
	custom_ident := token.token().ident()

	// The CSS-wide keywords are not valid <custom-ident>s.
	if is_css_wide_keyword_string(custom_ident) {
		return none
	}

	// The default keyword is reserved and is also not a valid <custom-ident>.
	if equals_ignoring_ascii_case(custom_ident, 'default') {
		return none
	}

	// Specifications using <custom-ident> must specify clearly what other keywords are excluded from <custom-ident>,
	// if any-for example by saying that any pre-defined keywords in that property's value definition are excluded.
	// Excluded keywords are excluded in all ASCII case permutations.
	for value in blacklist {
		if equals_ignoring_ascii_case(custom_ident, value) {
			return none
		}
	}

	tokens = transaction
	return custom_ident
}

fn (mut parser Parser) parse_custom_ident_value(mut tokens ComponentValueStream, blacklist []string) ?CustomIdentStyleValue {
	custom_ident := parser.parse_custom_ident(mut tokens, blacklist) or { return none }
	return CustomIdentStyleValue.create(custom_ident)
}

fn descriptor_ident_list_style_value(values []string) StyleValue {
	mut style_values := []StyleValue{}
	for value in values {
		style_values << descriptor_ident_style_value(value)
	}
	return StyleValue(StyleValueList.create(style_values, .space, .yes))
}

fn consume_descriptor_ident(mut tokens ComponentValueStream) ?string {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	return component_value.token().ident().to_lower()
}

fn is_page_size_keyword(value string) bool {
	return value in ['a5', 'a4', 'a3', 'b5', 'b4', 'jis-b5', 'jis-b4', 'letter', 'legal', 'ledger']
}

fn is_page_size_orientation(value string) bool {
	return value == 'portrait' || value == 'landscape'
}

fn (mut parser Parser) parse_page_margin_component_value(mut tokens ComponentValueStream) ?StyleValue {
	mut copy := tokens.clone()
	if value := parser.parse_length_percentage_value(mut copy) {
		tokens = copy
		return value
	}

	copy = tokens.clone()
	if value := consume_descriptor_ident(mut copy) {
		if value == 'auto' {
			tokens = copy
			return StyleValue(KeywordStyleValue.create(.auto))
		}
	}
	return none
}

fn (mut parser Parser) parse_page_margin_longhand_descriptor_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_page_margin_component_value(mut tokens)
}

fn (mut parser Parser) parse_page_margin_shorthand_descriptor_value(mut tokens ComponentValueStream) ?StyleValue {
	mut values := []StyleValue{}
	for values.len < 4 {
		mut copy := tokens.clone()
		value := parser.parse_page_margin_component_value(mut copy) or { break }
		values << value
		tokens = copy
		if !tokens.has_more_tokens() {
			break
		}
	}
	if values.len == 0 {
		return none
	}
	if values.len == 1 {
		return values[0]
	}
	return StyleValue(StyleValueList.create(values, .space, .no))
}

fn (mut parser Parser) parse_page_bleed_descriptor_value(mut tokens ComponentValueStream) ?StyleValue {
	mut copy := tokens.clone()
	if value := consume_descriptor_ident(mut copy) {
		if value == 'auto' {
			tokens = copy
			return StyleValue(KeywordStyleValue.create(.auto))
		}
	}
	return parser.parse_length_value(mut tokens)
}

fn (mut parser Parser) parse_page_marks_descriptor_value(mut tokens ComponentValueStream) ?StyleValue {
	first := consume_descriptor_ident(mut tokens) or { return none }
	if first == 'none' {
		return descriptor_ident_style_value('none')
	}
	if first != 'crop' && first != 'cross' {
		return none
	}

	tokens.consume_whitespace()
	if !tokens.has_more_tokens() {
		return descriptor_ident_style_value(first)
	}

	second := consume_descriptor_ident(mut tokens) or { return none }
	if second != 'crop' && second != 'cross' {
		return none
	}
	if second == first {
		return none
	}

	return descriptor_ident_list_style_value(['crop', 'cross'])
}

fn (mut parser Parser) parse_page_orientation_descriptor_value(mut tokens ComponentValueStream) ?StyleValue {
	value := consume_descriptor_ident(mut tokens) or { return none }
	if value !in ['upright', 'rotate-left', 'rotate-right'] {
		return none
	}
	return descriptor_ident_style_value(value)
}

fn (mut parser Parser) parse_page_size_descriptor_value(mut tokens ComponentValueStream) ?StyleValue {
	mut copy := tokens.clone()
	if first_length := parser.parse_length_value(mut copy) {
		if first_length.is_length() && first_length.as_length().raw_value() < 0 {
			return none
		}

		copy.consume_whitespace()
		if second_length := parser.parse_length_value(mut copy) {
			if second_length.is_length() && second_length.as_length().raw_value() < 0 {
				return none
			}
			tokens = copy
			return StyleValue(StyleValueList.create([first_length, second_length], .space, .yes))
		}

		tokens = copy
		return first_length
	}

	first := consume_descriptor_ident(mut tokens) or { return none }
	if first == 'auto' {
		return StyleValue(KeywordStyleValue.create(.auto))
	}

	mut page_size := ''
	mut orientation := ''
	if is_page_size_orientation(first) {
		orientation = first
	} else if is_page_size_keyword(first) {
		page_size = first
	} else {
		return none
	}

	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		second := consume_descriptor_ident(mut tokens) or { return none }
		if orientation.len == 0 && is_page_size_orientation(second) {
			orientation = second
		} else if page_size.len == 0 && is_page_size_keyword(second) {
			page_size = second
		} else {
			return none
		}

		// Portrait is considered the default orientation, so don't include it.
		if orientation == 'portrait' {
			return descriptor_ident_style_value(page_size)
		}
		return descriptor_ident_list_style_value([page_size, orientation])
	}

	if page_size.len != 0 {
		return descriptor_ident_style_value(page_size)
	}
	return descriptor_ident_style_value(orientation)
}

pub fn parse_css_descriptor_value_logic(at_rule_id AtRuleID, descriptor_id DescriptorID, value string) ?StyleValue {
	mut parser := Parser.from_css_text(value)
	return parser.parse_descriptor_value(at_rule_id, descriptor_id)
}

pub fn parse_css_media_query_list_value_logic(text string) []&MediaQuery {
	mut parser := Parser.from_css_text(text)
	return parser.parse_as_media_query_list()
}

pub fn (mut parser Parser) parse_as_media_query_list() []&MediaQuery {
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_a_media_query_list(mut tokens)
}

fn (mut parser Parser) parse_a_media_query_list(mut tokens ComponentValueStream) []&MediaQuery {
	// Parse a comma-separated media query list. Invalid entries become "not all",
	// matching the C++ parser's error recovery shape.
	mut queries := []&MediaQuery{}
	for {
		query := parser.parse_media_query_tokens(mut tokens) or {
			&MediaQuery{
				text:    'not all'
				matches: false
			}
		}
		queries << query
		if !tokens.consume_a_comma() {
			break
		}
	}
	return queries
}

fn (mut parser Parser) parse_media_query_tokens(mut tokens ComponentValueStream) ?&MediaQuery {
	tokens.consume_whitespace()
	mut parts := []string{}
	for tokens.has_more_tokens() {
		value := tokens.consume() or { break }
		if value.is(.comma) {
			tokens.reconsume()
			break
		}
		parts << value.to_string()
	}
	text := parts.join('').trim_space()
	if text.len == 0 {
		return none
	}
	return parse_media_query_from_text(text)
}

fn (mut parser Parser) parse_media_type(mut tokens ComponentValueStream) ?MediaQueryKnownMediaType {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	return media_type_from_string(component_value.token().ident())
}

fn (mut parser Parser) parse_media_feature_value(media_feature string, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parser.parse_known_media_feature_value(media_feature, mut transaction) {
		transaction.consume_whitespace()

		// Only return the value if there are no trailing tokens.
		// Otherwise, the transaction gets reverted and we consume all the value tokens below.
		if !media_feature_stream_has_value_token(transaction) {
			tokens = transaction
			return value
		}
	}

	// Parsing failed somehow, so wrap all the tokens into an "unknown" MediaFeatureValue if possible.
	mut unknown_transaction := tokens.clone()
	unknown_transaction.consume_whitespace()
	mut unknown_tokens := []ComponentValue{}

	// Consume any tokens that could be part of a value.
	for unknown_transaction.has_more_tokens() {
		next := unknown_transaction.peek() or { break }
		if !is_media_feature_value_token(next) {
			break
		}
		unknown_tokens << unknown_transaction.consume() or { break }
	}

	if unknown_tokens.len != 0 {
		tokens = unknown_transaction
		return StyleValue(UnresolvedStyleValue.create(unknown_tokens))
	}

	return none
}

fn (mut parser Parser) parse_known_media_feature_value(media_feature string, mut tokens ComponentValueStream) ?StyleValue {
	feature_name := media_feature.to_lower()

	// One branch for each member of the MediaFeatureValueType enum:
	// Identifiers
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if token := transaction.peek() {
		if token.is(.ident) {
			ident := token.token().ident().to_lower()
			if media_feature_accepts_keyword_name(feature_name, ident) {
				transaction.consume()
				tokens = transaction
				if keyword := keyword_from_string(ident) {
					return StyleValue(KeywordStyleValue.create(keyword))
				}
				return StyleValue(CustomIdentStyleValue.create(ident))
			}
		}
	}

	// Boolean (<mq-boolean> in the spec: a 1 or 0)
	if media_feature_accepts_type_name(feature_name, .boolean) {
		transaction = tokens.clone()
		transaction.consume_whitespace()
		if value := parser.parse_integer_value(mut transaction) {
			integer := value.as_integer().integer()
			if integer == 0 || integer == 1 {
				tokens = transaction
				return value
			}
		}
	}

	// Integer
	if media_feature_accepts_type_name(feature_name, .integer) {
		transaction = tokens.clone()
		if value := parser.parse_integer_value(mut transaction) {
			tokens = transaction
			return value
		}
	}

	// Length
	if media_feature_accepts_type_name(feature_name, .length) {
		transaction = tokens.clone()
		transaction.consume_whitespace()
		if value := parser.parse_length_value(mut transaction) {
			tokens = transaction
			return value
		}
	}

	// Ratio
	if media_feature_accepts_type_name(feature_name, .ratio) {
		transaction = tokens.clone()
		transaction.consume_whitespace()
		if value := parser.parse_ratio_value(mut transaction) {
			tokens = transaction
			return value
		}
	}

	// Resolution
	if media_feature_accepts_type_name(feature_name, .resolution) {
		transaction = tokens.clone()
		transaction.consume_whitespace()
		if value := parser.parse_resolution_value(mut transaction) {
			tokens = transaction
			return value
		}
	}

	return none
}

fn media_feature_stream_has_value_token(stream ComponentValueStream) bool {
	mut copy := stream
	copy.consume_whitespace()
	next := copy.peek() or { return false }
	return is_media_feature_value_token(next)
}

fn (mut parser Parser) parse_ratio_value(mut tokens ComponentValueStream) ?StyleValue {
	ratio := parser.parse_ratio(mut tokens) or { return none }
	return StyleValue(RatioStyleValue.create(ratio))
}

fn (mut parser Parser) parse_ratio(mut tokens ComponentValueStream) ?Ratio {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()

	// FIXME: It seems like `calc(...) / calc(...)` is a valid <ratio>, but this case is neither mentioned in a spec,
	//        nor tested in WPT, as far as I can tell.
	//        Still, we should probably support it. That means not assuming we can resolve the calculation immediately.

	// Boundary: CalculatedStyleValue does not carry the CalculationNode tree yet, so the C++ parse_calculated_value()
	// branch in read_number_value is not representable here.

	// `<ratio> = <number [0,+inf]> [ / <number [0,+inf]> ]?`
	maybe_numerator := parser.read_ratio_number_value(transaction.consume() or { return none }) or {
		return none
	}
	if maybe_numerator < 0 {
		return none
	}
	numerator := maybe_numerator

	{
		mut two_value_transaction := transaction.clone()
		two_value_transaction.consume_whitespace()
		solidus := two_value_transaction.consume() or {
			tokens = transaction
			return Ratio.new_single(numerator)
		}
		two_value_transaction.consume_whitespace()
		maybe_denominator := parser.read_ratio_number_value(two_value_transaction.consume() or {
			tokens = transaction
			return Ratio.new_single(numerator)
		}) or {
			tokens = transaction
			return Ratio.new_single(numerator)
		}

		if solidus.is_delim(u32(`/`)) && maybe_denominator >= 0 {
			denominator := maybe_denominator
			// Two-value ratio
			tokens = two_value_transaction
			return Ratio.new(numerator, denominator)
		}
	}

	// Single-value ratio
	tokens = transaction
	return Ratio.new_single(numerator)
}

fn (mut parser Parser) read_ratio_number_value(component_value ComponentValue) ?f64 {
	_ = parser
	if component_value.is(.number) {
		return component_value.token().number_value()
	}
	return none
}

fn style_value_from_css_image_source_for_value_logic(value CSSImageSourceStyleValue) StyleValue {
	return match value {
		ConicGradientStyleValue { StyleValue(value) }
		ImageStyleValue { StyleValue(value) }
		LinearGradientStyleValue { StyleValue(value) }
		RadialGradientStyleValue { StyleValue(value) }
		StyleValue { value }
	}
}

fn (mut parser Parser) parse_image_or_none_value(mut tokens ComponentValueStream) ?StyleValue {
	if none_value := parse_single_keyword_value_for_value_logic(mut tokens, .none_) {
		return none_value
	}

	mut transaction := tokens.clone()
	image := parser.parse_image_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}

	tokens = transaction
	return style_value_from_css_image_source_for_value_logic(image)
}

fn (mut parser Parser) parse_image_or_none_list_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut images := []StyleValue{}
	for value in values {
		mut item_tokens := ComponentValueStream.new(value)
		image := parser.parse_image_or_none_value(mut item_tokens) or { return none }
		item_tokens.consume_whitespace()
		if item_tokens.has_more_tokens() {
			return none
		}
		images << image
	}

	if images.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(images, .comma, .yes))
}

fn (mut parser Parser) parse_image_value(mut tokens ComponentValueStream) ?CSSImageSourceStyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if component_value.is(.url) {
		return CSSImageSourceStyleValue(ImageStyleValue.create_from_url_string(component_value.token().url()))
	}
	if component_value.is_function_named('url') {
		return CSSImageSourceStyleValue(ImageStyleValue.create_from_url_string(component_value.function().value.map(it.to_string()).join('')))
	}
	if component_value.is_function_named('linear-gradient')
		|| component_value.is_function_named('repeating-linear-gradient')
		|| component_value.is_function_named('-webkit-linear-gradient')
		|| component_value.is_function_named('-webkit-repeating-linear-gradient') {
		mut inner := ComponentValueStream.new(component_value.function().value)
		gradient := parser.parse_linear_gradient_function(component_value.function().name, mut
			inner) or { return none }
		return CSSImageSourceStyleValue(gradient)
	}
	if component_value.is_function_named('radial-gradient')
		|| component_value.is_function_named('repeating-radial-gradient') {
		mut inner := ComponentValueStream.new(component_value.function().value)
		gradient := parser.parse_radial_gradient_function(component_value.function().name, mut
			inner) or { return none }
		return CSSImageSourceStyleValue(gradient)
	}
	if component_value.is_function_named('conic-gradient')
		|| component_value.is_function_named('repeating-conic-gradient') {
		mut inner := ComponentValueStream.new(component_value.function().value)
		gradient := parser.parse_conic_gradient_function(component_value.function().name, mut inner) or {
			return none
		}
		return CSSImageSourceStyleValue(gradient)
	}
	return none
}

fn (mut parser Parser) parse_transform_parameter_value(parameter TransformFunctionParameter, mut tokens ComponentValueStream) ?StyleValue {
	match parameter.type_ {
		.angle {
			// These are `<angle> | <zero>` in the spec, so we have to check for both kinds.
			if angle_value := parser.parse_angle_value(mut tokens) {
				return angle_value
			}
			if next := tokens.peek() {
				if next.is(.number) && next.token().number_value() == 0 {
					tokens.consume()
					return StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))
				}
			}
			return none
		}
		.length, .length_none {
			if length_value := parser.parse_length_value(mut tokens) {
				return length_value
			}
			if parameter.type_ == .length_none {
				if next := tokens.peek() {
					if next.is(.ident) && equals_ignoring_ascii_case(next.token().ident(), 'none') {
						tokens.consume()
						return StyleValue(KeywordStyleValue.create(.none_))
					}
				}
			}
			return none
		}
		.length_percentage {
			return parser.parse_length_percentage_value(mut tokens)
		}
		.number {
			return parser.parse_number_value(mut tokens)
		}
		.number_percentage {
			return parser.parse_number_percentage_value(mut tokens)
		}
	}
}

// https://drafts.csswg.org/css-transforms-1/#typedef-transform-function
fn (mut parser Parser) parse_transform_function_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	part := transaction.consume() or { return none }
	if !part.is_function() {
		return none
	}
	function := transform_function_from_string(part.function().name) or { return none }

	function_metadata := transform_function_metadata(function)
	mut arguments :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(part.function().value)

	if arguments.len > function_metadata.parameters.len {
		return none
	}

	if arguments.len < function_metadata.parameters.len
		&& function_metadata.parameters[arguments.len].required {
		return none
	}

	mut values := StyleValueVector{}
	for argument_index in 0 .. arguments.len {
		mut argument_tokens := ComponentValueStream.new(arguments[argument_index])
		argument_tokens.consume_whitespace()
		value := parser.parse_transform_parameter_value(function_metadata.parameters[argument_index], mut
			argument_tokens) or { return none }
		values << value
		if argument_tokens.has_more_tokens() {
			return none
		}
	}

	tokens = transaction
	return StyleValue(TransformationStyleValue.create(.transform, function, values))
}

// https://drafts.csswg.org/css-transforms-1/#typedef-transform-list
fn (mut parser Parser) parse_transform_list_value(mut tokens ComponentValueStream) ?StyleValue {
	// <transform-list> = <transform-function>+
	// https://www.w3.org/TR/css-transforms-1/#transform-property
	mut transaction := tokens.clone()
	mut transformations := StyleValueVector{}
	for transaction.has_more_tokens() {
		if maybe_function := parser.parse_transform_function_value(mut transaction) {
			transformations << maybe_function
			transaction.consume_whitespace()
			continue
		}
		break
	}
	if transformations.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(transformations, .space, .yes))
}

// https://www.w3.org/TR/css-transforms-1/#transform-property
fn (mut parser Parser) parse_transform_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | <transform-list>
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if component_value := transaction.peek() {
		if component_value.is(.ident)
			&& equals_ignoring_ascii_case(component_value.token().ident(), 'none') {
			transaction.consume()
			tokens = transaction
			return StyleValue(KeywordStyleValue.create(.none_))
		}
	}

	transaction = tokens.clone()
	value := parser.parse_transform_list_value(mut transaction) or { return none }
	tokens = transaction
	return value
}

enum TransformOriginAxisForValueLogic {
	none_
	x
	y
}

struct TransformOriginAxisOffsetForValueLogic {
mut:
	axis   TransformOriginAxisForValueLogic
	offset StyleValue
}

fn transform_origin_axis_offset_from_style_value_for_value_logic(value StyleValue) ?TransformOriginAxisOffsetForValueLogic {
	if value is PercentageStyleValue || value is LengthStyleValue {
		return TransformOriginAxisOffsetForValueLogic{
			axis:   .none_
			offset: value
		}
	}
	if value.is_keyword() {
		return match value.to_keyword() {
			.top {
				TransformOriginAxisOffsetForValueLogic{
					axis:   .y
					offset: value
				}
			}
			.left {
				TransformOriginAxisOffsetForValueLogic{
					axis:   .x
					offset: value
				}
			}
			.center {
				TransformOriginAxisOffsetForValueLogic{
					axis:   .none_
					offset: value
				}
			}
			.bottom {
				TransformOriginAxisOffsetForValueLogic{
					axis:   .y
					offset: value
				}
			}
			.right {
				TransformOriginAxisOffsetForValueLogic{
					axis:   .x
					offset: value
				}
			}
			else {
				none
			}
		}
	}
	if value is CalculatedStyleValue {
		return TransformOriginAxisOffsetForValueLogic{
			axis:   .none_
			offset: value
		}
	}
	return none
}

fn (mut parser Parser) parse_transform_origin_component_value_for_value_logic(mut tokens ComponentValueStream) ?StyleValue {
	if keyword := parse_single_keyword_from_set_for_value_logic(mut tokens, [
		'bottom',
		'center',
		'left',
		'right',
		'top',
	])
	{
		return StyleValue(KeywordStyleValue.create(keyword))
	}
	return parser.parse_length_percentage_value(mut tokens)
}

// https://www.w3.org/TR/css-transforms-1/#propdef-transform-origin
fn (mut parser Parser) parse_transform_origin_value(mut tokens ComponentValueStream) ?StyleValue {
	//   [ left | center | right | top | bottom | <length-percentage> ]
	// |
	//   [ left | center | right | <length-percentage> ]
	//   [ top | center | bottom | <length-percentage> ] <length>?
	// |
	//   [[ center | left | right ] && [ center | top | bottom ]] <length>?
	mut transaction := tokens.clone()
	transaction.consume_whitespace()

	zero_value := StyleValue(LengthStyleValue.create(Length.make_px(0)))
	first_component := parser.parse_transform_origin_component_value_for_value_logic(mut transaction) or {
		return none
	}
	first_value := transform_origin_axis_offset_from_style_value_for_value_logic(first_component) or {
		return none
	}
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return match first_value.axis {
			.none_, .x {
				StyleValue(StyleValueList.create([
					first_value.offset,
					StyleValue(KeywordStyleValue.create(.center)),
					zero_value,
				], .space, .yes))
			}
			.y {
				StyleValue(StyleValueList.create([
					StyleValue(KeywordStyleValue.create(.center)),
					first_value.offset,
					zero_value,
				], .space, .yes))
			}
		}
	}

	second_component := parser.parse_transform_origin_component_value_for_value_logic(mut transaction) or {
		return none
	}
	second_value := transform_origin_axis_offset_from_style_value_for_value_logic(second_component) or {
		return none
	}
	mut third_value := zero_value
	mut third_transaction := transaction.clone()
	if maybe_third := parser.parse_length_value(mut third_transaction) {
		third_value = maybe_third
		transaction = third_transaction
	}

	if (first_value.offset is LengthStyleValue || first_value.offset is PercentageStyleValue)
		&& second_value.axis == .x {
		return none
	}
	if (second_value.offset is LengthStyleValue || second_value.offset is PercentageStyleValue)
		&& first_value.axis == .y {
		return none
	}

	mut x_value := ?StyleValue(none)
	mut y_value := ?StyleValue(none)
	mut has_x_value := false
	mut has_y_value := false

	if first_value.axis == .x {
		x_value = first_value.offset
		has_x_value = true
	} else if first_value.axis == .y {
		y_value = first_value.offset
		has_y_value = true
	}

	if second_value.axis == .x {
		if has_x_value {
			return none
		}
		x_value = second_value.offset
		has_x_value = true
		// Put the other in Y since its axis can't have been X.
		y_value = first_value.offset
		has_y_value = true
	} else if second_value.axis == .y {
		if has_y_value {
			return none
		}
		y_value = second_value.offset
		has_y_value = true
		// Put the other in X since its axis can't have been Y.
		x_value = first_value.offset
		has_x_value = true
	} else {
		if has_x_value {
			y_value = second_value.offset
			has_y_value = true
		} else {
			x_value = second_value.offset
			has_x_value = true
		}
	}

	// If two or more values are defined and either no value is a keyword, or the only used keyword is center,
	// then the first value represents the horizontal position (or offset) and the second represents the vertical position (or offset).
	// A third value always represents the Z position (or offset) and must be of type <length>.
	if first_value.axis == .none_ && second_value.axis == .none_ {
		x_value = first_value.offset
		y_value = second_value.offset
		has_x_value = true
		has_y_value = true
	}

	if !has_x_value || !has_y_value {
		return none
	}
	x := x_value or { return none }
	y := y_value or { return none }
	tokens = transaction
	return StyleValue(StyleValueList.create([x, y, third_value], .space, .yes))
}

fn (mut parser Parser) parse_optional_angle_value_without_consuming_on_failure(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	value := parser.parse_angle_value(mut transaction) or { return none }
	tokens = transaction
	return value
}

// https://drafts.csswg.org/css-transforms-2/#propdef-rotate
fn (mut parser Parser) parse_rotate_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | <angle> | [ x | y | z ] && <angle> | <number>{3} && <angle>
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if component_value := transaction.peek() {
		if component_value.is(.ident)
			&& equals_ignoring_ascii_case(component_value.token().ident(), 'none') {
			transaction.consume()
			tokens = transaction
			return StyleValue(KeywordStyleValue.create(.none_))
		}
	}

	transaction = tokens.clone()
	mut angle := ?StyleValue(none)
	if angle_value := parser.parse_optional_angle_value_without_consuming_on_failure(mut transaction) {
		angle = angle_value
	}
	transaction.consume_whitespace()

	// <angle>
	if angle_value := angle {
		if !transaction.has_more_tokens() {
			tokens = transaction
			return StyleValue(TransformationStyleValue.create(.rotate, .rotate, [
				angle_value,
			]))
		}
	}

	parse_one_of_xyz := fn (mut input ComponentValueStream) ?string {
		mut axis_transaction := input.clone()
		axis_transaction.consume_whitespace()
		axis := axis_transaction.consume() or { return none }
		if axis.is(.ident) {
			ident := axis.token().ident()
			if equals_ignoring_ascii_case(ident, 'x') || equals_ignoring_ascii_case(ident, 'y')
				|| equals_ignoring_ascii_case(ident, 'z') {
				input = axis_transaction
				return to_ascii_lowercase(ident)
			}
		}
		return none
	}

	// [ x | y | z ] && <angle>
	if axis := parse_one_of_xyz(mut transaction) {
		transaction.consume_whitespace()
		if angle == none {
			angle = parser.parse_optional_angle_value_without_consuming_on_failure(mut transaction)
		}
		if angle_value := angle {
			tokens = transaction
			transform_function := match axis {
				'x' { TransformFunction.rotate_x }
				'y' { TransformFunction.rotate_y }
				else { TransformFunction.rotate_z }
			}

			return StyleValue(TransformationStyleValue.create(.rotate, transform_function, [
				angle_value,
			]))
		}
		return none
	}

	parse_three_numbers := fn [mut parser] (mut input ComponentValueStream) ?StyleValueVector {
		mut numbers_transaction := input.clone()
		mut numbers := StyleValueVector{}
		for _ in 0 .. 3 {
			number := parser.parse_number_value(mut numbers_transaction) or { return none }
			numbers << number
		}
		input = numbers_transaction
		return numbers
	}

	// <number>{3} && <angle>
	if mut numbers := parse_three_numbers(mut transaction) {
		transaction.consume_whitespace()
		if angle == none {
			angle = parser.parse_optional_angle_value_without_consuming_on_failure(mut transaction)
		}
		if angle_value := angle {
			numbers << angle_value
			tokens = transaction
			return StyleValue(TransformationStyleValue.create(.rotate, .rotate3d, numbers))
		}
	}

	return none
}

// https://drafts.csswg.org/css-transforms-2/#propdef-translate
fn (mut parser Parser) parse_translate_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | <length-percentage> [ <length-percentage> <length>? ]?
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if component_value := transaction.peek() {
		if component_value.is(.ident)
			&& equals_ignoring_ascii_case(component_value.token().ident(), 'none') {
			transaction.consume()
			tokens = transaction
			return StyleValue(KeywordStyleValue.create(.none_))
		}
	}

	transaction = tokens.clone()
	maybe_x := parser.parse_length_percentage_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return StyleValue(TransformationStyleValue.create(.translate, .translate, [
			maybe_x,
			StyleValue(LengthStyleValue.create(Length.make_px(0))),
		]))
	}

	maybe_y := parser.parse_length_percentage_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return StyleValue(TransformationStyleValue.create(.translate, .translate, [
			maybe_x,
			maybe_y,
		]))
	}

	maybe_z := parser.parse_length_value(mut transaction) or { return none }
	tokens = transaction
	return StyleValue(TransformationStyleValue.create(.translate, .translate3d, [
		maybe_x,
		maybe_y,
		maybe_z,
	]))
}

// https://drafts.csswg.org/css-transforms-2/#propdef-scale
fn (mut parser Parser) parse_scale_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | [ <number> | <percentage> ]{1,3}
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if component_value := transaction.peek() {
		if component_value.is(.ident)
			&& equals_ignoring_ascii_case(component_value.token().ident(), 'none') {
			transaction.consume()
			tokens = transaction
			return StyleValue(KeywordStyleValue.create(.none_))
		}
	}

	transaction = tokens.clone()
	maybe_x := parser.parse_number_percentage_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return StyleValue(TransformationStyleValue.create(.scale, .scale, [maybe_x, maybe_x]))
	}

	maybe_y := parser.parse_number_percentage_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return StyleValue(TransformationStyleValue.create(.scale, .scale, [
			maybe_x,
			maybe_y,
		]))
	}

	maybe_z := parser.parse_number_percentage_value(mut transaction) or { return none }
	tokens = transaction
	return StyleValue(TransformationStyleValue.create(.scale, .scale3d, [
		maybe_x,
		maybe_y,
		maybe_z,
	]))
}

fn (mut parser Parser) parse_linear_gradient_function(function_name string, mut tokens ComponentValueStream) ?LinearGradientStyleValue {
	repeating := if function_name.contains('repeating') {
		GradientRepeating.yes
	} else {
		GradientRepeating.no
	}
	gradient_type := if function_name.starts_with('-webkit-') {
		LinearGradientType.webkit
	} else {
		LinearGradientType.standard
	}
	mut direction := LinearGradientDirection(LinearGradientSideOrCorner.bottom)

	mut probe := tokens
	probe.consume_whitespace()
	if first := probe.consume() {
		if first.is(.ident) && equals_ignoring_ascii_case(first.token().ident(), 'to') {
			side := parser.parse_linear_gradient_side_or_corner(mut probe) or { return none }
			direction = LinearGradientDirection(side)
			if !probe.consume_a_comma() {
				return none
			}
			tokens = probe
		} else if first.is(.dimension) {
			probe.reconsume()
			angle_value := parser.parse_angle_value(mut probe) or { return none }
			direction = LinearGradientDirection(angle_value)
			if !probe.consume_a_comma() {
				return none
			}
			tokens = probe
		}
	}

	color_stops := parser.parse_linear_color_stop_list(mut tokens) or { return none }
	return LinearGradientStyleValue.create(direction, color_stops, gradient_type, repeating, none)
}

fn (mut parser Parser) parse_linear_gradient_side_or_corner(mut tokens ComponentValueStream) ?LinearGradientSideOrCorner {
	tokens.consume_whitespace()
	first := tokens.consume() or { return none }
	if !first.is(.ident) {
		return none
	}
	first_ident := first.token().ident().to_lower()
	mut second_ident := ''
	mut copy := tokens
	copy.consume_whitespace()
	if second := copy.consume() {
		if second.is(.ident) {
			second_ident = second.token().ident().to_lower()
			tokens = copy
		}
	}
	if second_ident.len == 0 {
		return match first_ident {
			'top' { LinearGradientSideOrCorner.top }
			'bottom' { LinearGradientSideOrCorner.bottom }
			'left' { LinearGradientSideOrCorner.left }
			'right' { LinearGradientSideOrCorner.right }
			else { none }
		}
	}
	return match '${first_ident} ${second_ident}' {
		'top left', 'left top' { LinearGradientSideOrCorner.top_left }
		'top right', 'right top' { LinearGradientSideOrCorner.top_right }
		'bottom left', 'left bottom' { LinearGradientSideOrCorner.bottom_left }
		'bottom right', 'right bottom' { LinearGradientSideOrCorner.bottom_right }
		else { none }
	}
}

fn (mut parser Parser) parse_linear_color_stop_list(mut tokens ComponentValueStream) ?[]ColorStopListElement {
	return parser.parse_color_stop_list(mut tokens, false)
}

fn (mut parser Parser) parse_angular_color_stop_list(mut tokens ComponentValueStream) ?[]ColorStopListElement {
	return parser.parse_color_stop_list(mut tokens, true)
}

fn (mut parser Parser) parse_color_stop_list(mut tokens ComponentValueStream, angular bool) ?[]ColorStopListElement {
	// <linear-color-stop>#{2,}. Transition hints are represented by a
	// ColorStopListElement with transition_hint populated, as in LibWeb.
	mut elements := []ColorStopListElement{}
	for {
		mut copy := tokens
		if hint := parser.parse_color_stop_position(mut copy, angular) {
			if copy.consume_a_comma() {
				elements << ColorStopListElement{
					transition_hint: hint
				}
				tokens = copy
				continue
			}
		}

		color := parser.parse_color_value(mut tokens) or { return none }
		position := parser.parse_color_stop_position(mut tokens, angular)
		second_position := parser.parse_color_stop_position(mut tokens, angular)
		elements << ColorStopListElement{
			color_stop: ColorStop{
				color:           color
				position:        position
				second_position: second_position
			}
		}
		if !tokens.consume_a_comma() {
			break
		}
	}
	if elements.len < 2 {
		return none
	}
	return elements
}

fn (mut parser Parser) parse_color_stop_position(mut tokens ComponentValueStream, angular bool) ?StyleValue {
	mut copy := tokens.clone()
	if angular {
		if value := parser.parse_angle_value(mut copy) {
			tokens = copy
			return value
		}
	} else {
		if value := parser.parse_length_percentage_value(mut copy) {
			tokens = copy
			return value
		}
	}
	copy = tokens.clone()
	if value := parser.parse_percentage_value(mut copy) {
		tokens = copy
		return value
	}
	return none
}

fn (mut parser Parser) parse_radial_gradient_function(function_name string, mut tokens ComponentValueStream) ?RadialGradientStyleValue {
	repeating := if function_name.contains('repeating') {
		GradientRepeating.yes
	} else {
		GradientRepeating.no
	}
	color_stops := parser.parse_linear_color_stop_list(mut tokens) or { return none }
	return RadialGradientStyleValue.create(.ellipse, StyleValue(KeywordStyleValue.create(.auto)),
		PositionStyleValue.create_center(), color_stops, repeating, none)
}

fn (mut parser Parser) parse_conic_gradient_function(function_name string, mut tokens ComponentValueStream) ?ConicGradientStyleValue {
	repeating := if function_name.contains('repeating') {
		GradientRepeating.yes
	} else {
		GradientRepeating.no
	}
	color_stops := parser.parse_angular_color_stop_list(mut tokens) or { return none }
	return ConicGradientStyleValue.create(none, PositionStyleValue.create_center(), color_stops,
		repeating, none)
}

pub fn parse_css_value_logic(property_id PropertyID, text string) ?StyleValue {
	mut parser := Parser.from_css_text(text)
	return parser.parse_css_value(property_id)
}

pub fn parse_css_image_value_logic(text string) ?CSSImageSourceStyleValue {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_image_value(mut tokens) or { return none }
	if tokens.has_more_tokens() {
		return none
	}
	return value
}

pub fn parse_css_media_feature_value_logic(media_feature string, text string) ?StyleValue {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_media_feature_value(media_feature, mut tokens) or { return none }
	if tokens.has_more_tokens() {
		return none
	}
	return value
}

fn value_logic_round_to_u8(value f64) u8 {
	return u8(int(math.max(0.0, math.min(255.0, math.round(value)))))
}

fn dom_style_value_from_value_logic(value StyleValue) &dom.StyleValue {
	return &dom.StyleValue{
		css_text: value.serialize(.normal)
	}
}
