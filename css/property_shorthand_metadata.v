// Generated from Ladybird's generated LibWeb/CSS/PropertyID.cpp by
// tools/generate_css_shorthand_metadata.py. Do not edit by hand.
module css

pub fn generated_longhands_for_shorthand(property_id PropertyID) []PropertyID {
	return match property_id {
		.overscroll_behavior { [.overscroll_behavior_x,.overscroll_behavior_y] }
		.font {
			[.font_family, .font_size, .font_width, .font_style, .font_variant, .font_weight, .line_height, .font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing, .font_variation_settings, .font_size_adjust]
		}
		.position_try { [.position_try_order,.position_try_fallbacks] }
		.animation_range {
			[.animation_range_start, .animation_range_end]
		}
		.font_synthesis {
			[.font_synthesis_weight, .font_synthesis_style, .font_synthesis_small_caps, .font_synthesis_position]
		}
		.all {
			[.webkit_box_orient, .webkit_font_smoothing, .webkit_text_fill_color, .accent_color,
				.align_content, .align_items, .align_self, .anchor_name, .anchor_scope,
				.animation_composition, .animation_delay, .animation_direction, .animation_duration,
				.animation_fill_mode, .animation_iteration_count, .animation_name,
				.animation_play_state, .animation_range_end, .animation_range_start, .animation_timeline, .animation_timing_function, .appearance,
				.aspect_ratio, .backdrop_filter, .backface_visibility, .background_attachment,
				.background_blend_mode, .background_clip, .background_color, .background_image,
				.background_origin, .background_position_x, .background_position_y,
				.background_repeat, .background_size, .block_ellipsis, .block_size,
				.border_block_end_color, .border_block_end_style, .border_block_end_width,
				.border_block_start_color, .border_block_start_style, .border_block_start_width,
				.border_bottom_color, .border_bottom_left_radius, .border_bottom_right_radius,
				.border_bottom_style, .border_bottom_width, .border_collapse, .border_end_end_radius,
				.border_end_start_radius, .border_image_outset, .border_image_repeat,
				.border_image_slice, .border_image_source, .border_image_width,
				.border_inline_end_color, .border_inline_end_style, .border_inline_end_width,
				.border_inline_start_color, .border_inline_start_style, .border_inline_start_width,
				.border_left_color, .border_left_style, .border_left_width, .border_right_color,
				.border_right_style, .border_right_width, .border_spacing, .border_start_end_radius,
				.border_start_start_radius, .border_top_color, .border_top_left_radius,
				.border_top_right_radius, .border_top_style, .border_top_width, .bottom,
				.box_decoration_break, .box_shadow, .box_sizing, .break_after, .break_before,
				.break_inside, .caption_side, .caret_color, .clear, .clip, .clip_path, .clip_rule,
				.color, .color_interpolation, .color_interpolation_filters, .color_scheme,
				.column_count, .column_fill, .column_gap, .column_height, .column_rule_color,
				.column_rule_style, .column_rule_width, .column_span, .column_width, .contain,
				.contain_intrinsic_block_size, .contain_intrinsic_height,
				.contain_intrinsic_inline_size, .contain_intrinsic_width, .container_name,
				.container_type, .content, .continue_, .content_visibility, .corner_bottom_left_shape,
				.corner_bottom_right_shape, .corner_end_end_shape, .corner_end_start_shape,
				.corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape,
				.corner_top_right_shape, .counter_increment, .counter_reset, .counter_set, .cursor,
				.cx, .cy, .d, .display, .dominant_baseline, .empty_cells, .fill, .fill_opacity,
				.fill_rule, .field_sizing, .filter, .flex_basis, .flex_direction, .flex_grow, .flex_shrink,
				.flex_wrap, .float_, .flood_color, .flood_opacity, .font_family,
				.font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing,
				.font_size, .font_style,
				.font_synthesis_position, .font_synthesis_small_caps, .font_synthesis_style, .font_synthesis_weight, .font_variant_alternates, .font_variant_caps,
				.font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures,
				.font_variant_numeric, .font_variant_position, .font_variation_settings, .font_weight,
				.font_width, .grid_auto_columns, .grid_auto_flow, .grid_auto_rows, .grid_column_end,
				.grid_column_start, .grid_row_end, .grid_row_start, .grid_template_areas,
				.grid_template_columns, .grid_template_rows, .height, .hyphens, .image_rendering, .inline_size,
				.inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start,
				.isolation, .justify_content, .justify_items, .justify_self, .left, .letter_spacing,
				.line_height, .list_style_image, .list_style_position, .list_style_type,
				.margin_block_end, .margin_block_start, .margin_bottom, .margin_inline_end,
				.margin_inline_start, .margin_left, .margin_right, .margin_top, .mask_clip,
				.mask_composite, .mask_image, .mask_mode, .mask_origin, .mask_position, .mask_repeat,
				.mask_size, .mask_type, .math_depth, .math_shift, .math_style, .max_block_size,
				.max_height, .max_inline_size, .max_lines, .max_width, .min_block_size, .min_height,
				.min_inline_size, .min_width, .mix_blend_mode, .object_fit, .object_position,
				.opacity, .order, .orphans, .outline_color, .outline_offset, .outline_style,
				.outline_width, .overflow_block, .overflow_clip_margin_block_end,
				.overflow_clip_margin_block_start, .overflow_clip_margin_bottom,
				.overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start,
				.overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top,
				.overflow_inline, .overflow_wrap, .overflow_x, .overflow_y, .padding_block_end,
				.padding_block_start, .padding_bottom, .padding_inline_end, .padding_inline_start,
				.padding_left, .padding_right, .padding_top, .paint_order, .perspective,
				.perspective_origin, .pointer_events, .position, .position_anchor, .position_area,
				.position_try_fallbacks, .position_try_order, .position_visibility, .quotes, .r,
				.resize, .right, .rotate, .row_gap, .rx, .ry, .scale, .scroll_behavior,
				.scroll_margin_block_end, .scroll_margin_block_start, .scroll_margin_bottom,
				.scroll_margin_inline_end, .scroll_margin_inline_start, .scroll_margin_left,
				.scroll_margin_right, .scroll_margin_top, .scroll_padding_block_end,
				.scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline_end,
				.scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right,
				.scroll_padding_top, .scroll_snap_align, .scroll_snap_stop, .scroll_snap_type,
				.scroll_timeline_axis, .scroll_timeline_name, .scrollbar_color, .scrollbar_gutter,
				.scrollbar_width, .shape_image_threshold, .shape_margin, .shape_outside,
				.shape_rendering, .stop_color, .stop_opacity, .stroke, .stroke_dasharray,
				.stroke_dashoffset, .stroke_linecap, .stroke_linejoin, .stroke_miterlimit,
				.stroke_opacity, .stroke_width, .tab_size, .table_layout, .text_align, .text_align_last, .text_anchor,
				.text_decoration_color, .text_decoration_line, .text_decoration_skip_ink,
				.text_decoration_style, .text_decoration_thickness, .text_indent, .text_justify,
				.text_overflow, .text_rendering, .text_shadow, .text_transform,
				.text_underline_offset, .text_underline_position, .text_wrap_mode, .text_wrap_style,
				.timeline_scope, .top, .touch_action, .transform, .transform_box, .transform_origin,
				.transform_style, .transition_behavior, .transition_delay, .transition_duration,
				.transition_property, .transition_timing_function, .translate, .user_select,
				.vector_effect, .vertical_align, .view_timeline_axis, .view_timeline_inset,
				.view_timeline_name, .view_transition_name, .visibility, .white_space_collapse,
				.white_space_trim, .widows, .width, .will_change, .word_break, .word_spacing,
				.writing_mode, .x, .y, .z_index, .text_box_edge, .text_box_trim, .font_size_adjust, .font_palette, .forced_color_adjust, .text_orientation, .border_shape, .alignment_baseline, .baseline_shift, .baseline_source, .overscroll_behavior_x, .overscroll_behavior_y, .overscroll_behavior_inline, .overscroll_behavior_block, .grid_lanes_direction, .fit_tolerance, .grid_lanes_pack, .interpolate_size]
		}
		.animation {
			[.animation_duration, .animation_timing_function, .animation_delay,
				.animation_iteration_count, .animation_direction, .animation_fill_mode,
				.animation_play_state, .animation_name, .animation_timeline, .animation_range_start, .animation_range_end]
		}
		.background {
			[.background_attachment, .background_clip, .background_color, .background_image,
				.background_origin, .background_position, .background_repeat, .background_size]
		}
		.background_position {
			[.background_position_x, .background_position_y]
		}
		.border {
			[.border_width, .border_style, .border_color, .border_image]
		}
		.border_block {
			[.border_block_width, .border_block_style, .border_block_color]
		}
		.border_block_color {
			[.border_block_start_color, .border_block_end_color]
		}
		.border_block_end {
			[.border_block_end_width, .border_block_end_style, .border_block_end_color]
		}
		.border_block_start {
			[.border_block_start_width, .border_block_start_style, .border_block_start_color]
		}
		.border_block_style {
			[.border_block_start_style, .border_block_end_style]
		}
		.border_block_width {
			[.border_block_start_width, .border_block_end_width]
		}
		.border_bottom {
			[.border_bottom_width, .border_bottom_style, .border_bottom_color]
		}
		.border_color {
			[.border_top_color, .border_right_color, .border_bottom_color, .border_left_color]
		}
		.border_image {
			[.border_image_source, .border_image_slice, .border_image_width, .border_image_outset,
				.border_image_repeat]
		}
		.border_inline {
			[.border_inline_width, .border_inline_style, .border_inline_color]
		}
		.border_inline_color {
			[.border_inline_start_color, .border_inline_end_color]
		}
		.border_inline_end {
			[.border_inline_end_width, .border_inline_end_style, .border_inline_end_color]
		}
		.border_inline_start {
			[.border_inline_start_width, .border_inline_start_style, .border_inline_start_color]
		}
		.border_inline_style {
			[.border_inline_start_style, .border_inline_end_style]
		}
		.border_inline_width {
			[.border_inline_start_width, .border_inline_end_width]
		}
		.border_left {
			[.border_left_width, .border_left_style, .border_left_color]
		}
		.border_radius {
			[.border_top_left_radius, .border_top_right_radius, .border_bottom_left_radius,
				.border_bottom_right_radius]
		}
		.border_right {
			[.border_right_width, .border_right_style, .border_right_color]
		}
		.border_style {
			[.border_top_style, .border_right_style, .border_bottom_style, .border_left_style]
		}
		.border_top {
			[.border_top_width, .border_top_style, .border_top_color]
		}
		.border_width {
			[.border_top_width, .border_right_width, .border_bottom_width, .border_left_width]
		}
		.columns {
			[.column_width, .column_count, .column_height]
		}
		.column_rule {
			[.column_rule_width, .column_rule_style, .column_rule_color]
		}
		.contain_intrinsic_size {
			[.contain_intrinsic_width, .contain_intrinsic_height]
		}
		.container {
			[.container_name, .container_type]
		}
		.corner_block_end_shape {
			[.corner_end_start_shape, .corner_end_end_shape]
		}
		.corner_block_start_shape {
			[.corner_start_start_shape, .corner_start_end_shape]
		}
		.corner_bottom_shape {
			[.corner_bottom_left_shape, .corner_bottom_right_shape]
		}
		.corner_inline_end_shape {
			[.corner_start_end_shape, .corner_end_end_shape]
		}
		.corner_inline_start_shape {
			[.corner_start_start_shape, .corner_end_start_shape]
		}
		.corner_left_shape {
			[.corner_top_left_shape, .corner_bottom_left_shape]
		}
		.corner_right_shape {
			[.corner_top_right_shape, .corner_bottom_right_shape]
		}
		.corner_shape {
			[.corner_top_left_shape, .corner_top_right_shape, .corner_bottom_right_shape,
				.corner_bottom_left_shape]
		}
		.corner_top_shape {
			[.corner_top_left_shape, .corner_top_right_shape]
		}
		.flex {
			[.flex_grow, .flex_shrink, .flex_basis]
		}
		.flex_flow {
			[.flex_direction, .flex_wrap]
		}
		.font_variant {
			[.font_variant_alternates, .font_variant_caps, .font_variant_east_asian,
				.font_variant_emoji, .font_variant_ligatures, .font_variant_numeric,
				.font_variant_position]
		}
		.gap {
			[.row_gap, .column_gap]
		}
		.grid {
			[.grid_auto_flow, .grid_auto_rows, .grid_auto_columns, .grid_template_areas,
				.grid_template_rows, .grid_template_columns]
		}
		.grid_area {
			[.grid_column_end, .grid_column_start, .grid_row_end, .grid_row_start]
		}
		.grid_column {
			[.grid_column_end, .grid_column_start]
		}
		.grid_row {
			[.grid_row_end, .grid_row_start]
		}
		.grid_template {
			[.grid_template_areas, .grid_template_rows, .grid_template_columns]
		}
		.inset {
			[.top, .right, .bottom, .left]
		}
		.inset_block {
			[.inset_block_start, .inset_block_end]
		}
		.inset_inline {
			[.inset_inline_start, .inset_inline_end]
		}
		.list_style {
			[.list_style_position, .list_style_image, .list_style_type]
		}
		.line_clamp, .webkit_line_clamp {
			[.max_lines, .block_ellipsis, .continue_]
		}
		.margin {
			[.margin_top, .margin_right, .margin_bottom, .margin_left]
		}
		.margin_block {
			[.margin_block_start, .margin_block_end]
		}
		.margin_inline {
			[.margin_inline_start, .margin_inline_end]
		}
		.mask {
			[.mask_clip, .mask_composite, .mask_image, .mask_mode, .mask_origin, .mask_position,
				.mask_repeat, .mask_size]
		}
		.outline {
			[.outline_color, .outline_style, .outline_width]
		}
		.overflow {
			[.overflow_x, .overflow_y]
		}
		.overflow_clip_margin {
			[.overflow_clip_margin_top, .overflow_clip_margin_right, .overflow_clip_margin_bottom,
				.overflow_clip_margin_left]
		}
		.overflow_clip_margin_block {
			[.overflow_clip_margin_block_start, .overflow_clip_margin_block_end]
		}
		.overflow_clip_margin_inline {
			[.overflow_clip_margin_inline_start, .overflow_clip_margin_inline_end]
		}
		.padding {
			[.padding_top, .padding_right, .padding_bottom, .padding_left]
		}
		.padding_block {
			[.padding_block_start, .padding_block_end]
		}
		.padding_inline {
			[.padding_inline_start, .padding_inline_end]
		}
		.scroll_margin {
			[.scroll_margin_top, .scroll_margin_right, .scroll_margin_bottom, .scroll_margin_left]
		}
		.scroll_margin_block {
			[.scroll_margin_block_start, .scroll_margin_block_end]
		}
		.scroll_margin_inline {
			[.scroll_margin_inline_start, .scroll_margin_inline_end]
		}
		.scroll_padding {
			[.scroll_padding_top, .scroll_padding_right, .scroll_padding_bottom, .scroll_padding_left]
		}
		.scroll_padding_block {
			[.scroll_padding_block_start, .scroll_padding_block_end]
		}
		.scroll_padding_inline {
			[.scroll_padding_inline_start, .scroll_padding_inline_end]
		}
		.page_break_after {
			[.break_after]
		}
		.page_break_before {
			[.break_before]
		}
		.page_break_inside {
			[.break_inside]
		}
		.place_content {
			[.align_content, .justify_content]
		}
		.place_items {
			[.align_items, .justify_items]
		}
		.place_self {
			[.align_self, .justify_self]
		}
		.scroll_timeline {
			[.scroll_timeline_name, .scroll_timeline_axis]
		}
		.text_decoration {
			[.text_decoration_color, .text_decoration_line, .text_decoration_style,
				.text_decoration_thickness]
		}
		.text_wrap {
			[.text_wrap_mode, .text_wrap_style]
		}
		.transition {
			[.transition_property, .transition_duration, .transition_timing_function,
				.transition_delay, .transition_behavior]
		}
		.view_timeline {
			[.view_timeline_name, .view_timeline_axis, .view_timeline_inset]
		}
		.white_space {
			[.white_space_collapse, .text_wrap_mode, .white_space_trim]
		}
		else { []PropertyID{} }
	}
}

pub fn generated_expanded_longhands_for_shorthand(property_id PropertyID) []PropertyID {
	return match property_id {
		.overscroll_behavior { [.overscroll_behavior_x,.overscroll_behavior_y] }
		.font {
			[.font_family, .font_size, .font_width, .font_style, .font_variant_alternates, .font_variant_caps, .font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures, .font_variant_numeric, .font_variant_position, .font_weight, .line_height, .font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing, .font_variation_settings, .font_size_adjust]
		}
		.position_try { [.position_try_order,.position_try_fallbacks] }
		.animation_range {
			[.animation_range_start, .animation_range_end]
		}
		.font_synthesis {
			[.font_synthesis_weight, .font_synthesis_style, .font_synthesis_small_caps, .font_synthesis_position]
		}
		.all {
			[.webkit_box_orient, .webkit_font_smoothing, .webkit_text_fill_color, .accent_color,
				.align_content, .align_items, .align_self, .anchor_name, .anchor_scope,
				.animation_composition, .animation_delay, .animation_direction, .animation_duration,
				.animation_fill_mode, .animation_iteration_count, .animation_name,
				.animation_play_state, .animation_range_end, .animation_range_start, .animation_timeline, .animation_timing_function, .appearance,
				.aspect_ratio, .backdrop_filter, .backface_visibility, .background_attachment,
				.background_blend_mode, .background_clip, .background_color, .background_image,
				.background_origin, .background_position_x, .background_position_y,
				.background_repeat, .background_size, .block_ellipsis, .block_size,
				.border_block_end_color, .border_block_end_style, .border_block_end_width,
				.border_block_start_color, .border_block_start_style, .border_block_start_width,
				.border_bottom_color, .border_bottom_left_radius, .border_bottom_right_radius,
				.border_bottom_style, .border_bottom_width, .border_collapse, .border_end_end_radius,
				.border_end_start_radius, .border_image_outset, .border_image_repeat,
				.border_image_slice, .border_image_source, .border_image_width,
				.border_inline_end_color, .border_inline_end_style, .border_inline_end_width,
				.border_inline_start_color, .border_inline_start_style, .border_inline_start_width,
				.border_left_color, .border_left_style, .border_left_width, .border_right_color,
				.border_right_style, .border_right_width, .border_spacing, .border_start_end_radius,
				.border_start_start_radius, .border_top_color, .border_top_left_radius,
				.border_top_right_radius, .border_top_style, .border_top_width, .bottom,
				.box_decoration_break, .box_shadow, .box_sizing, .break_after, .break_before,
				.break_inside, .caption_side, .caret_color, .clear, .clip, .clip_path, .clip_rule,
				.color, .color_interpolation, .color_interpolation_filters, .color_scheme,
				.column_count, .column_fill, .column_gap, .column_height, .column_rule_color,
				.column_rule_style, .column_rule_width, .column_span, .column_width, .contain,
				.contain_intrinsic_block_size, .contain_intrinsic_height,
				.contain_intrinsic_inline_size, .contain_intrinsic_width, .container_name,
				.container_type, .content, .continue_, .content_visibility, .corner_bottom_left_shape,
				.corner_bottom_right_shape, .corner_end_end_shape, .corner_end_start_shape,
				.corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape,
				.corner_top_right_shape, .counter_increment, .counter_reset, .counter_set, .cursor,
				.cx, .cy, .d, .display, .dominant_baseline, .empty_cells, .fill, .fill_opacity,
				.fill_rule, .field_sizing, .filter, .flex_basis, .flex_direction, .flex_grow, .flex_shrink,
				.flex_wrap, .float_, .flood_color, .flood_opacity, .font_family,
				.font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing,
				.font_size, .font_style,
				.font_synthesis_position, .font_synthesis_small_caps, .font_synthesis_style, .font_synthesis_weight, .font_variant_alternates, .font_variant_caps,
				.font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures,
				.font_variant_numeric, .font_variant_position, .font_variation_settings, .font_weight,
				.font_width, .grid_auto_columns, .grid_auto_flow, .grid_auto_rows, .grid_column_end,
				.grid_column_start, .grid_row_end, .grid_row_start, .grid_template_areas,
				.grid_template_columns, .grid_template_rows, .height, .hyphens, .image_rendering, .inline_size,
				.inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start,
				.isolation, .justify_content, .justify_items, .justify_self, .left, .letter_spacing,
				.line_height, .list_style_image, .list_style_position, .list_style_type,
				.margin_block_end, .margin_block_start, .margin_bottom, .margin_inline_end,
				.margin_inline_start, .margin_left, .margin_right, .margin_top, .mask_clip,
				.mask_composite, .mask_image, .mask_mode, .mask_origin, .mask_position, .mask_repeat,
				.mask_size, .mask_type, .math_depth, .math_shift, .math_style, .max_block_size,
				.max_height, .max_inline_size, .max_lines, .max_width, .min_block_size, .min_height,
				.min_inline_size, .min_width, .mix_blend_mode, .object_fit, .object_position,
				.opacity, .order, .orphans, .outline_color, .outline_offset, .outline_style,
				.outline_width, .overflow_block, .overflow_clip_margin_block_end,
				.overflow_clip_margin_block_start, .overflow_clip_margin_bottom,
				.overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start,
				.overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top,
				.overflow_inline, .overflow_wrap, .overflow_x, .overflow_y, .padding_block_end,
				.padding_block_start, .padding_bottom, .padding_inline_end, .padding_inline_start,
				.padding_left, .padding_right, .padding_top, .paint_order, .perspective,
				.perspective_origin, .pointer_events, .position, .position_anchor, .position_area,
				.position_try_fallbacks, .position_try_order, .position_visibility, .quotes, .r,
				.resize, .right, .rotate, .row_gap, .rx, .ry, .scale, .scroll_behavior,
				.scroll_margin_block_end, .scroll_margin_block_start, .scroll_margin_bottom,
				.scroll_margin_inline_end, .scroll_margin_inline_start, .scroll_margin_left,
				.scroll_margin_right, .scroll_margin_top, .scroll_padding_block_end,
				.scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline_end,
				.scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right,
				.scroll_padding_top, .scroll_snap_align, .scroll_snap_stop, .scroll_snap_type,
				.scroll_timeline_axis, .scroll_timeline_name, .scrollbar_color, .scrollbar_gutter,
				.scrollbar_width, .shape_image_threshold, .shape_margin, .shape_outside,
				.shape_rendering, .stop_color, .stop_opacity, .stroke, .stroke_dasharray,
				.stroke_dashoffset, .stroke_linecap, .stroke_linejoin, .stroke_miterlimit,
				.stroke_opacity, .stroke_width, .tab_size, .table_layout, .text_align, .text_align_last, .text_anchor,
				.text_decoration_color, .text_decoration_line, .text_decoration_skip_ink,
				.text_decoration_style, .text_decoration_thickness, .text_indent, .text_justify,
				.text_overflow, .text_rendering, .text_shadow, .text_transform,
				.text_underline_offset, .text_underline_position, .text_wrap_mode, .text_wrap_style,
				.timeline_scope, .top, .touch_action, .transform, .transform_box, .transform_origin,
				.transform_style, .transition_behavior, .transition_delay, .transition_duration,
				.transition_property, .transition_timing_function, .translate, .user_select,
				.vector_effect, .vertical_align, .view_timeline_axis, .view_timeline_inset,
				.view_timeline_name, .view_transition_name, .visibility, .white_space_collapse,
				.white_space_trim, .widows, .width, .will_change, .word_break, .word_spacing,
				.writing_mode, .x, .y, .z_index, .text_box_edge, .text_box_trim, .font_size_adjust, .font_palette, .forced_color_adjust, .text_orientation, .border_shape, .alignment_baseline, .baseline_shift, .baseline_source, .overscroll_behavior_x, .overscroll_behavior_y, .overscroll_behavior_inline, .overscroll_behavior_block, .grid_lanes_direction, .fit_tolerance, .grid_lanes_pack, .interpolate_size]
		}
		.animation {
			[.animation_duration, .animation_timing_function, .animation_delay,
				.animation_iteration_count, .animation_direction, .animation_fill_mode,
				.animation_play_state, .animation_name, .animation_timeline, .animation_range_start, .animation_range_end]
		}
		.background {
			[.background_attachment, .background_clip, .background_color, .background_image,
				.background_origin, .background_position_x, .background_position_y,
				.background_repeat, .background_size]
		}
		.background_position {
			[.background_position_x, .background_position_y]
		}
		.border {
			[.border_top_width, .border_right_width, .border_bottom_width, .border_left_width,
				.border_top_style, .border_right_style, .border_bottom_style, .border_left_style,
				.border_top_color, .border_right_color, .border_bottom_color, .border_left_color,
				.border_image_source, .border_image_slice, .border_image_width, .border_image_outset,
				.border_image_repeat]
		}
		.border_block {
			[.border_block_start_width, .border_block_end_width, .border_block_start_style,
				.border_block_end_style, .border_block_start_color, .border_block_end_color]
		}
		.border_block_color {
			[.border_block_start_color, .border_block_end_color]
		}
		.border_block_end {
			[.border_block_end_width, .border_block_end_style, .border_block_end_color]
		}
		.border_block_start {
			[.border_block_start_width, .border_block_start_style, .border_block_start_color]
		}
		.border_block_style {
			[.border_block_start_style, .border_block_end_style]
		}
		.border_block_width {
			[.border_block_start_width, .border_block_end_width]
		}
		.border_bottom {
			[.border_bottom_width, .border_bottom_style, .border_bottom_color]
		}
		.border_color {
			[.border_top_color, .border_right_color, .border_bottom_color, .border_left_color]
		}
		.border_image {
			[.border_image_source, .border_image_slice, .border_image_width, .border_image_outset,
				.border_image_repeat]
		}
		.border_inline {
			[.border_inline_start_width, .border_inline_end_width, .border_inline_start_style,
				.border_inline_end_style, .border_inline_start_color, .border_inline_end_color]
		}
		.border_inline_color {
			[.border_inline_start_color, .border_inline_end_color]
		}
		.border_inline_end {
			[.border_inline_end_width, .border_inline_end_style, .border_inline_end_color]
		}
		.border_inline_start {
			[.border_inline_start_width, .border_inline_start_style, .border_inline_start_color]
		}
		.border_inline_style {
			[.border_inline_start_style, .border_inline_end_style]
		}
		.border_inline_width {
			[.border_inline_start_width, .border_inline_end_width]
		}
		.border_left {
			[.border_left_width, .border_left_style, .border_left_color]
		}
		.border_radius {
			[.border_top_left_radius, .border_top_right_radius, .border_bottom_left_radius,
				.border_bottom_right_radius]
		}
		.border_right {
			[.border_right_width, .border_right_style, .border_right_color]
		}
		.border_style {
			[.border_top_style, .border_right_style, .border_bottom_style, .border_left_style]
		}
		.border_top {
			[.border_top_width, .border_top_style, .border_top_color]
		}
		.border_width {
			[.border_top_width, .border_right_width, .border_bottom_width, .border_left_width]
		}
		.columns {
			[.column_width, .column_count, .column_height]
		}
		.column_rule {
			[.column_rule_width, .column_rule_style, .column_rule_color]
		}
		.contain_intrinsic_size {
			[.contain_intrinsic_width, .contain_intrinsic_height]
		}
		.container {
			[.container_name, .container_type]
		}
		.corner_block_end_shape {
			[.corner_end_start_shape, .corner_end_end_shape]
		}
		.corner_block_start_shape {
			[.corner_start_start_shape, .corner_start_end_shape]
		}
		.corner_bottom_shape {
			[.corner_bottom_left_shape, .corner_bottom_right_shape]
		}
		.corner_inline_end_shape {
			[.corner_start_end_shape, .corner_end_end_shape]
		}
		.corner_inline_start_shape {
			[.corner_start_start_shape, .corner_end_start_shape]
		}
		.corner_left_shape {
			[.corner_top_left_shape, .corner_bottom_left_shape]
		}
		.corner_right_shape {
			[.corner_top_right_shape, .corner_bottom_right_shape]
		}
		.corner_shape {
			[.corner_top_left_shape, .corner_top_right_shape, .corner_bottom_right_shape,
				.corner_bottom_left_shape]
		}
		.corner_top_shape {
			[.corner_top_left_shape, .corner_top_right_shape]
		}
		.flex {
			[.flex_grow, .flex_shrink, .flex_basis]
		}
		.flex_flow {
			[.flex_direction, .flex_wrap]
		}
		.font_variant {
			[.font_variant_alternates, .font_variant_caps, .font_variant_east_asian,
				.font_variant_emoji, .font_variant_ligatures, .font_variant_numeric,
				.font_variant_position]
		}
		.gap {
			[.row_gap, .column_gap]
		}
		.grid {
			[.grid_auto_flow, .grid_auto_rows, .grid_auto_columns, .grid_template_areas,
				.grid_template_rows, .grid_template_columns]
		}
		.grid_area {
			[.grid_column_end, .grid_column_start, .grid_row_end, .grid_row_start]
		}
		.grid_column {
			[.grid_column_end, .grid_column_start]
		}
		.grid_row {
			[.grid_row_end, .grid_row_start]
		}
		.grid_template {
			[.grid_template_areas, .grid_template_rows, .grid_template_columns]
		}
		.inset {
			[.top, .right, .bottom, .left]
		}
		.inset_block {
			[.inset_block_start, .inset_block_end]
		}
		.inset_inline {
			[.inset_inline_start, .inset_inline_end]
		}
		.list_style {
			[.list_style_position, .list_style_image, .list_style_type]
		}
		.line_clamp, .webkit_line_clamp {
			[.max_lines, .block_ellipsis, .continue_]
		}
		.margin {
			[.margin_top, .margin_right, .margin_bottom, .margin_left]
		}
		.margin_block {
			[.margin_block_start, .margin_block_end]
		}
		.margin_inline {
			[.margin_inline_start, .margin_inline_end]
		}
		.mask {
			[.mask_clip, .mask_composite, .mask_image, .mask_mode, .mask_origin, .mask_position,
				.mask_repeat, .mask_size]
		}
		.outline {
			[.outline_color, .outline_style, .outline_width]
		}
		.overflow {
			[.overflow_x, .overflow_y]
		}
		.overflow_clip_margin {
			[.overflow_clip_margin_top, .overflow_clip_margin_right, .overflow_clip_margin_bottom,
				.overflow_clip_margin_left]
		}
		.overflow_clip_margin_block {
			[.overflow_clip_margin_block_start, .overflow_clip_margin_block_end]
		}
		.overflow_clip_margin_inline {
			[.overflow_clip_margin_inline_start, .overflow_clip_margin_inline_end]
		}
		.padding {
			[.padding_top, .padding_right, .padding_bottom, .padding_left]
		}
		.padding_block {
			[.padding_block_start, .padding_block_end]
		}
		.padding_inline {
			[.padding_inline_start, .padding_inline_end]
		}
		.scroll_margin {
			[.scroll_margin_top, .scroll_margin_right, .scroll_margin_bottom, .scroll_margin_left]
		}
		.scroll_margin_block {
			[.scroll_margin_block_start, .scroll_margin_block_end]
		}
		.scroll_margin_inline {
			[.scroll_margin_inline_start, .scroll_margin_inline_end]
		}
		.scroll_padding {
			[.scroll_padding_top, .scroll_padding_right, .scroll_padding_bottom, .scroll_padding_left]
		}
		.scroll_padding_block {
			[.scroll_padding_block_start, .scroll_padding_block_end]
		}
		.scroll_padding_inline {
			[.scroll_padding_inline_start, .scroll_padding_inline_end]
		}
		.page_break_after {
			[.break_after]
		}
		.page_break_before {
			[.break_before]
		}
		.page_break_inside {
			[.break_inside]
		}
		.place_content {
			[.align_content, .justify_content]
		}
		.place_items {
			[.align_items, .justify_items]
		}
		.place_self {
			[.align_self, .justify_self]
		}
		.scroll_timeline {
			[.scroll_timeline_name, .scroll_timeline_axis]
		}
		.text_decoration {
			[.text_decoration_color, .text_decoration_line, .text_decoration_style,
				.text_decoration_thickness]
		}
		.text_wrap {
			[.text_wrap_mode, .text_wrap_style]
		}
		.transition {
			[.transition_property, .transition_duration, .transition_timing_function,
				.transition_delay, .transition_behavior]
		}
		.view_timeline {
			[.view_timeline_name, .view_timeline_axis, .view_timeline_inset]
		}
		.white_space {
			[.white_space_collapse, .text_wrap_mode, .white_space_trim]
		}
		else { []PropertyID{} }
	}
}

pub fn generated_shorthands_for_longhand(property_id PropertyID) []PropertyID {
	return match property_id {
		.grid_lanes_direction, .fit_tolerance, .grid_lanes_pack, .interpolate_size { [.all] }
		.overscroll_behavior_x, .overscroll_behavior_y { [.overscroll_behavior,.all] }
		.overscroll_behavior_inline, .overscroll_behavior_block { [.all] }
		.alignment_baseline, .baseline_shift, .baseline_source { [.all] }
		.border_shape {
			[.all]
		}
		.text_orientation {
			[.all]
		}
		.forced_color_adjust {
			[.all]
		}
		.font_palette {
			[.all]
		}
		.font_size_adjust {
			[.font, .all]
		}
		.animation_range_start {
			[.animation, .animation_range, .all]
		}
		.animation_range_end {
			[.animation, .animation_range, .all]
		}
		.text_box_trim {
			[.all]
		}
		.text_box_edge {
			[.all]
		}
		.font_synthesis_weight {
			[.font_synthesis, .all]
		}
		.font_synthesis_style {
			[.font_synthesis, .all]
		}
		.font_synthesis_small_caps {
			[.font_synthesis, .all]
		}
		.font_synthesis_position {
			[.font_synthesis, .all]
		}
		.hyphens { [.all] }
		.field_sizing { [.all] }
		.text_align_last { [.all] }
		.scroll_snap_align, .scroll_snap_stop, .scroll_snap_type {
			[.all]
		}
		.color_interpolation_filters {
			[.all]
		}
		.backface_visibility {
			[.all]
		}
		.scroll_padding_top, .scroll_padding_right, .scroll_padding_bottom, .scroll_padding_left {
			[.all, .scroll_padding]
		}
		.scroll_padding_block_start, .scroll_padding_block_end {
			[.all, .scroll_padding_block]
		}
		.scroll_padding_inline_start, .scroll_padding_inline_end {
			[.all, .scroll_padding_inline]
		}
		.scroll_margin_top, .scroll_margin_right, .scroll_margin_bottom, .scroll_margin_left {
			[.all, .scroll_margin]
		}
		.scroll_margin_block_start, .scroll_margin_block_end {
			[.all, .scroll_margin_block]
		}
		.scroll_margin_inline_start, .scroll_margin_inline_end {
			[.all, .scroll_margin_inline]
		}
		.block_ellipsis, .continue_, .max_lines {
			[.all, .line_clamp, .webkit_line_clamp]
		}
		.webkit_box_orient {
			[.all]
		}
		.box_decoration_break, .column_fill {
			[.all]
		}
		.break_after, .break_before, .break_inside {
			[.all]
		}
		.column_rule_color, .column_rule_style, .column_rule_width {
			[.all, .column_rule]
		}
		.contain_intrinsic_block_size, .contain_intrinsic_inline_size {
			[.all]
		}
		.contain_intrinsic_width, .contain_intrinsic_height {
			[.all, .contain_intrinsic_size]
		}
		.vector_effect {
			[.all]
		}
		.d {
			[.all]
		}
		.grid_column_start {
			[.all, .grid_area, .grid_column]
		}
		.word_spacing {
			[.all]
		}
		.position_area {
			[.all]
		}
		.border_inline_width {
			[.border_inline]
		}
		.table_layout {
			[.all]
		}
		.fill_opacity {
			[.all]
		}
		.border_left_color {
			[.all, .border, .border_color, .border_left]
		}
		.overflow_x {
			[.all, .overflow]
		}
		.transform_origin {
			[.all]
		}
		.orphans {
			[.all]
		}
		.font_language_override {
			[.all, .font]
		}
		.anchor_name {
			[.all]
		}
		.font_variant_ligatures {
			[.all, .font, .font_variant]
		}
		.overflow_wrap {
			[.all]
		}
		.background_position_y {
			[.all, .background, .background_position]
		}
		.border_block_start_color {
			[.all, .border_block, .border_block_start, .border_block_color]
		}
		.padding_right {
			[.all, .padding]
		}
		.max_height {
			[.all]
		}
		.isolation {
			[.all]
		}
		.background_blend_mode {
			[.all]
		}
		.font_variant_emoji {
			[.all, .font, .font_variant]
		}
		.cy {
			[.all]
		}
		.shape_rendering {
			[.all]
		}
		.border_start_start_radius {
			[.all]
		}
		.mask_position {
			[.all, .mask]
		}
		.rotate {
			[.all]
		}
		.text_decoration_line {
			[.all, .text_decoration]
		}
		.text_decoration_skip_ink {
			[.all]
		}
		.column_gap {
			[.all, .gap]
		}
		.flex_wrap {
			[.all, .flex_flow]
		}
		.padding_left {
			[.all, .padding]
		}
		.border_inline_color {
			[.border_inline]
		}
		.border_collapse {
			[.all]
		}
		.overflow_block {
			[.all]
		}
		.border_color {
			[.border]
		}
		.cursor {
			[.all]
		}
		.word_break {
			[.all]
		}
		.background_size {
			[.all, .background]
		}
		.float_ {
			[.all]
		}
		.scroll_behavior {
			[.all]
		}
		.background_color {
			[.all, .background]
		}
		.margin_inline_end {
			[.all, .margin_inline]
		}
		.background_origin {
			[.all, .background]
		}
		.border_start_end_radius {
			[.all]
		}
		.border_right_style {
			[.all, .border, .border_style, .border_right]
		}
		.scrollbar_color {
			[.all]
		}
		.view_timeline_inset {
			[.all, .view_timeline]
		}
		.left {
			[.all, .inset]
		}
		.touch_action {
			[.all]
		}
		.border_block_start_style {
			[.all, .border_block, .border_block_start, .border_block_style]
		}
		.display {
			[.all]
		}
		.order {
			[.all]
		}
		.animation_duration {
			[.all, .animation]
		}
		.image_rendering {
			[.all]
		}
		.inset_block_start {
			[.all, .inset_block]
		}
		.mix_blend_mode {
			[.all]
		}
		.text_overflow {
			[.all]
		}
		.mask_type {
			[.all]
		}
		.font_variant_alternates {
			[.all, .font, .font_variant]
		}
		.border_image {
			[.border]
		}
		.animation_timing_function {
			[.all, .animation]
		}
		.transition_delay {
			[.all, .transition]
		}
		.column_width {
			[.all, .columns]
		}
		.border_bottom_style {
			[.all, .border, .border_style, .border_bottom]
		}
		.animation_fill_mode {
			[.all, .animation]
		}
		.clip_rule {
			[.all]
		}
		.margin_top {
			[.all, .margin]
		}
		.accent_color {
			[.all]
		}
		.corner_top_right_shape {
			[.all, .corner_shape, .corner_right_shape, .corner_top_shape]
		}
		.corner_top_left_shape {
			[.all, .corner_shape, .corner_left_shape, .corner_top_shape]
		}
		.background_position_x {
			[.all, .background, .background_position]
		}
		.ry {
			[.all]
		}
		.transition_property {
			[.all, .transition]
		}
		.animation_timeline {
			[.all, .animation]
		}
		.max_width {
			[.all]
		}
		.column_span {
			[.all]
		}
		.pointer_events {
			[.all]
		}
		.empty_cells {
			[.all]
		}
		.transition_behavior {
			[.all, .transition]
		}
		.font_size {
			[.all, .font]
		}
		.border_spacing {
			[.all]
		}
		.view_timeline_name {
			[.all, .view_timeline]
		}
		.border_bottom_color {
			[.all, .border, .border_color, .border_bottom]
		}
		.counter_reset {
			[.all]
		}
		.mask_composite {
			[.all, .mask]
		}
		.flex_grow {
			[.all, .flex]
		}
		.list_style_image {
			[.all, .list_style]
		}
		.content {
			[.all]
		}
		.border_bottom_width {
			[.all, .border, .border_width, .border_bottom]
		}
		.stroke_linejoin {
			[.all]
		}
		.row_gap {
			[.all, .gap]
		}
		.cx {
			[.all]
		}
		.border_image_outset {
			[.all, .border, .border_image]
		}
		.border_inline_end_width {
			[.all, .border_inline, .border_inline_end, .border_inline_width]
		}
		.grid_auto_rows {
			[.all, .grid]
		}
		.max_inline_size {
			[.all]
		}
		.counter_increment {
			[.all]
		}
		.stroke_miterlimit {
			[.all]
		}
		.mask_origin {
			[.all, .mask]
		}
		.min_width {
			[.all]
		}
		.shape_margin {
			[.all]
		}
		.math_style {
			[.all]
		}
		.border_left_width {
			[.all, .border, .border_width, .border_left]
		}
		.top {
			[.all, .inset]
		}
		.transition_duration {
			[.all, .transition]
		}
		.border_top_width {
			[.all, .border, .border_width, .border_top]
		}
		.min_height {
			[.all]
		}
		.position_try_fallbacks {
			[.position_try,.all]
		}
		.width {
			[.all]
		}
		.text_shadow {
			[.all]
		}
		.outline_style {
			[.all, .outline]
		}
		.border_width {
			[.border]
		}
		.border_inline_start_width {
			[.all, .border_inline, .border_inline_start, .border_inline_width]
		}
		.animation_composition {
			[.all]
		}
		.text_align {
			[.all]
		}
		.list_style_position {
			[.all, .list_style]
		}
		.margin_bottom {
			[.all, .margin]
		}
		.font_weight {
			[.all, .font]
		}
		.stroke_opacity {
			[.all]
		}
		.view_timeline_axis {
			[.all, .view_timeline]
		}
		.bottom {
			[.all, .inset]
		}
		.text_transform {
			[.all]
		}
		.border_left_style {
			[.all, .border, .border_style, .border_left]
		}
		.font_feature_settings {
			[.all, .font]
		}
		.stop_color {
			[.all]
		}
		.animation_play_state {
			[.all, .animation]
		}
		.inline_size {
			[.all]
		}
		.border_style {
			[.border]
		}
		.animation_delay {
			[.all, .animation]
		}
		.background_attachment {
			[.all, .background]
		}
		.user_select {
			[.all]
		}
		.writing_mode {
			[.all]
		}
		.box_sizing {
			[.all]
		}
		.line_height {
			[.all, .font]
		}
		.position_visibility {
			[.all]
		}
		.border_bottom_right_radius {
			[.all, .border_radius]
		}
		.background_position {
			[.background]
		}
		.scale {
			[.all]
		}
		.background_image {
			[.all, .background]
		}
		.align_items {
			[.all, .place_items]
		}
		.animation_iteration_count {
			[.all, .animation]
		}
		.border_block_style {
			[.border_block]
		}
		.corner_start_end_shape {
			[.all, .corner_block_start_shape, .corner_inline_end_shape]
		}
		.align_content {
			[.all, .place_content]
		}
		.overflow_clip_margin_inline_start {
			[.all, .overflow_clip_margin_inline]
		}
		.border_right_color {
			[.all, .border, .border_color, .border_right]
		}
		.font_kerning {
			[.all, .font]
		}
		.margin_left {
			[.all, .margin]
		}
		.object_fit {
			[.all]
		}
		.white_space_trim {
			[.all, .white_space]
		}
		.margin_block_start {
			[.all, .margin_block]
		}
		.backdrop_filter {
			[.all]
		}
		.mask_mode {
			[.all, .mask]
		}
		.rx {
			[.all]
		}
		.text_decoration_style {
			[.all, .text_decoration]
		}
		.border_bottom_left_radius {
			[.all, .border_radius]
		}
		.scroll_timeline_axis {
			[.all, .scroll_timeline]
		}
		.letter_spacing {
			[.all]
		}
		.grid_template_rows {
			[.all, .grid, .grid_template]
		}
		.grid_auto_flow {
			[.all, .grid]
		}
		.text_underline_position {
			[.all]
		}
		.timeline_scope {
			[.all]
		}
		.font_variant {
			[.font]
		}
		.caret_color {
			[.all]
		}
		.z_index {
			[.all]
		}
		.overflow_clip_margin_block_end {
			[.all, .overflow_clip_margin_block]
		}
		.grid_auto_columns {
			[.all, .grid]
		}
		.scroll_timeline_name {
			[.all, .scroll_timeline]
		}
		.perspective_origin {
			[.all]
		}
		.padding_inline_end {
			[.all, .padding_inline]
		}
		.visibility {
			[.all]
		}
		.transform_box {
			[.all]
		}
		.y {
			[.all]
		}
		.overflow_clip_margin_left {
			[.all, .overflow_clip_margin]
		}
		.text_decoration_color {
			[.all, .text_decoration]
		}
		.column_count {
			[.all, .columns]
		}
		.white_space_collapse {
			[.all, .white_space]
		}
		.min_block_size {
			[.all]
		}
		.transform_style {
			[.all]
		}
		.caption_side {
			[.all]
		}
		.will_change {
			[.all]
		}
		.border_inline_end_style {
			[.all, .border_inline, .border_inline_end, .border_inline_style]
		}
		.counter_set {
			[.all]
		}
		.align_self {
			[.all, .place_self]
		}
		.animation_name {
			[.all, .animation]
		}
		.translate {
			[.all]
		}
		.border_inline_start_color {
			[.all, .border_inline, .border_inline_start, .border_inline_color]
		}
		.outline_color {
			[.all, .outline]
		}
		.overflow_clip_margin_inline_end {
			[.all, .overflow_clip_margin_inline]
		}
		.position_anchor {
			[.all]
		}
		.content_visibility {
			[.all]
		}
		.opacity {
			[.all]
		}
		.color {
			[.all]
		}
		.clip {
			[.all]
		}
		.font_variant_numeric {
			[.all, .font, .font_variant]
		}
		.mask_size {
			[.all, .mask]
		}
		.transform {
			[.all]
		}
		.color_interpolation {
			[.all]
		}
		.padding_block_start {
			[.all, .padding_block]
		}
		.padding_inline_start {
			[.all, .padding_inline]
		}
		.border_inline_start_style {
			[.all, .border_inline, .border_inline_start, .border_inline_style]
		}
		.height {
			[.all]
		}
		.corner_bottom_right_shape {
			[.all, .corner_shape, .corner_bottom_shape, .corner_right_shape]
		}
		.font_variant_caps {
			[.all, .font, .font_variant]
		}
		.right {
			[.all, .inset]
		}
		.widows {
			[.all]
		}
		.flood_opacity {
			[.all]
		}
		.list_style_type {
			[.all, .list_style]
		}
		.dominant_baseline {
			[.all]
		}
		.grid_template_columns {
			[.all, .grid, .grid_template]
		}
		.overflow_clip_margin_top {
			[.all, .overflow_clip_margin]
		}
		.border_image_slice {
			[.all, .border, .border_image]
		}
		.outline_width {
			[.all, .outline]
		}
		.border_block_start_width {
			[.all, .border_block, .border_block_start, .border_block_width]
		}
		.border_right_width {
			[.all, .border, .border_width, .border_right]
		}
		.border_top_style {
			[.all, .border, .border_style, .border_top]
		}
		.text_justify {
			[.all]
		}
		.padding_block_end {
			[.all, .padding_block]
		}
		.contain {
			[.all]
		}
		.stroke_dashoffset {
			[.all]
		}
		.view_transition_name {
			[.all]
		}
		.text_wrap_mode {
			[.all, .white_space, .text_wrap]
		}
		.webkit_text_fill_color {
			[.all]
		}
		.webkit_font_smoothing {
			[.all]
		}
		.block_size {
			[.all]
		}
		.corner_end_start_shape {
			[.all, .corner_block_end_shape, .corner_inline_start_shape]
		}
		.border_block_end_style {
			[.all, .border_block, .border_block_end, .border_block_style]
		}
		.anchor_scope {
			[.all]
		}
		.border_top_left_radius {
			[.all, .border_radius]
		}
		.position {
			[.all]
		}
		.fill {
			[.all]
		}
		.inset_inline_end {
			[.all, .inset_inline]
		}
		.corner_end_end_shape {
			[.all, .corner_block_end_shape, .corner_inline_end_shape]
		}
		.border_inline_style {
			[.border_inline]
		}
		.corner_bottom_left_shape {
			[.all, .corner_shape, .corner_bottom_shape, .corner_left_shape]
		}
		.math_shift {
			[.all]
		}
		.quotes {
			[.all]
		}
		.border_block_color {
			[.border_block]
		}
		.object_position {
			[.all]
		}
		.justify_items {
			[.all, .place_items]
		}
		.stroke_dasharray {
			[.all]
		}
		.clip_path {
			[.all]
		}
		.transition_timing_function {
			[.all, .transition]
		}
		.border_image_repeat {
			[.all, .border, .border_image]
		}
		.border_end_end_radius {
			[.all]
		}
		.container_type {
			[.all, .container]
		}
		.container_name {
			[.all, .container]
		}
		.justify_self {
			[.all, .place_self]
		}
		.font_width {
			[.all, .font]
		}
		.inset_block_end {
			[.all, .inset_block]
		}
		.background_repeat {
			[.all, .background]
		}
		.border_block_end_color {
			[.all, .border_block, .border_block_end, .border_block_color]
		}
		.box_shadow {
			[.all]
		}
		.clear {
			[.all]
		}
		.column_height {
			[.all, .columns]
		}
		.border_top_right_radius {
			[.all, .border_radius]
		}
		.flex_shrink {
			[.all, .flex]
		}
		.text_underline_offset {
			[.all]
		}
		.text_wrap_style {
			[.all, .text_wrap]
		}
		.stroke_linecap {
			[.all]
		}
		.border_block_width {
			[.border_block]
		}
		.border_top_color {
			[.all, .border, .border_color, .border_top]
		}
		.scrollbar_gutter {
			[.all]
		}
		.outline_offset {
			[.all]
		}
		.paint_order {
			[.all]
		}
		.font_variant_position {
			[.all, .font, .font_variant]
		}
		.text_indent {
			[.all]
		}
		.corner_start_start_shape {
			[.all, .corner_block_start_shape, .corner_inline_start_shape]
		}
		.max_block_size {
			[.all]
		}
		.aspect_ratio {
			[.all]
		}
		.fill_rule {
			[.all]
		}
		.overflow_clip_margin_bottom {
			[.all, .overflow_clip_margin]
		}
		.overflow_inline {
			[.all]
		}
		.overflow_y {
			[.all, .overflow]
		}
		.animation_direction {
			[.all, .animation]
		}
		.border_block_end_width {
			[.all, .border_block, .border_block_end, .border_block_width]
		}
		.color_scheme {
			[.all]
		}
		.text_rendering {
			[.all]
		}
		.inset_inline_start {
			[.all, .inset_inline]
		}
		.flood_color {
			[.all]
		}
		.font_optical_sizing {
			[.all, .font]
		}
		.filter {
			[.all]
		}
		.grid_column_end {
			[.all, .grid_area, .grid_column]
		}
		.tab_size {
			[.all]
		}
		.grid_row_start {
			[.all, .grid_area, .grid_row]
		}
		.font_style {
			[.all, .font]
		}
		.padding_bottom {
			[.all, .padding]
		}
		.overflow_clip_margin_right {
			[.all, .overflow_clip_margin]
		}
		.padding_top {
			[.all, .padding]
		}
		.perspective {
			[.all]
		}
		.math_depth {
			[.all]
		}
		.border_inline_end_color {
			[.all, .border_inline, .border_inline_end, .border_inline_color]
		}
		.justify_content {
			[.all, .place_content]
		}
		.border_end_start_radius {
			[.all]
		}
		.border_image_source {
			[.all, .border, .border_image]
		}
		.grid_template_areas {
			[.all, .grid, .grid_template]
		}
		.mask_image {
			[.all, .mask]
		}
		.mask_clip {
			[.all, .mask]
		}
		.mask_repeat {
			[.all, .mask]
		}
		.resize {
			[.all]
		}
		.grid_row_end {
			[.all, .grid_area, .grid_row]
		}
		.flex_direction {
			[.all, .flex_flow]
		}
		.font_variation_settings {
			[.all, .font]
		}
		.r {
			[.all]
		}
		.scrollbar_width {
			[.all]
		}
		.font_family {
			[.all, .font]
		}
		.font_variant_east_asian {
			[.all, .font, .font_variant]
		}
		.shape_image_threshold {
			[.all]
		}
		.x {
			[.all]
		}
		.min_inline_size {
			[.all]
		}
		.appearance {
			[.all]
		}
		.text_anchor {
			[.all]
		}
		.position_try_order {
			[.position_try,.all]
		}
		.margin_block_end {
			[.all, .margin_block]
		}
		.stroke_width {
			[.all]
		}
		.shape_outside {
			[.all]
		}
		.overflow_clip_margin_block_start {
			[.all, .overflow_clip_margin_block]
		}
		.stop_opacity {
			[.all]
		}
		.stroke {
			[.all]
		}
		.background_clip {
			[.all, .background]
		}
		.margin_inline_start {
			[.all, .margin_inline]
		}
		.vertical_align {
			[.all]
		}
		.text_decoration_thickness {
			[.all, .text_decoration]
		}
		.border_image_width {
			[.all, .border, .border_image]
		}
		.flex_basis {
			[.all, .flex]
		}
		.margin_right {
			[.all, .margin]
		}
		else { []PropertyID{} }
	}
}

// Legacy shorthands keep their own parsing and serialization behavior, but are
// deliberately absent from generated_shorthands_for_longhand().
pub fn property_is_legacy_shorthand(property_id PropertyID) bool {
	return property_id in [.page_break_after, .page_break_before, .page_break_inside]
}

pub fn generated_property_needs_layout_for_getcomputedstyle(property_id PropertyID) bool {
	return match property_id {
		.block_size, .border, .border_block, .border_block_end, .border_block_end_width, .border_block_start, .border_block_start_width, .border_block_width, .border_bottom, .border_bottom_width, .border_image_slice, .border_image_width, .border_inline, .border_inline_end, .bottom, .grid_template, .grid_template_columns, .grid_template_rows, .height, .inline_size, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .left, .line_height, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .padding, .padding_block, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .right, .top, .width {
			true
		}
		else { false }
	}
}

pub fn generated_property_needs_layout_node_for_resolved_value(property_id PropertyID) bool {
	return match property_id {
		.webkit_text_fill_color, .animation_duration, .backdrop_filter, .background_color, .border_block_end_color, .border_block_end_width, .border_block_start_color, .border_block_start_width, .border_bottom_color, .border_bottom_width, .border_inline_end_color, .border_inline_end_width, .border_inline_start_color, .border_inline_start_width, .border_left_color, .border_left_width, .border_right_color, .border_right_width, .border_top_color, .border_top_width, .box_shadow, .caret_color, .color, .column_rule_color, .contain, .filter, .font_weight, .font_width, .letter_spacing, .line_height, .math_depth, .outline_color, .text_decoration_color, .text_shadow, .transform, .transform_origin, .z_index {
			true
		}
		else { false }
	}
}
