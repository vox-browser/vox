module css

// Stateful entry points for the generated MutableComputedValues and
// ComputedValues interfaces. The upstream generated setters all have the same
// observable contract: replace one computed slot without disturbing the other
// slots. Strings retain the serialized value at this translation boundary;
// typed CSS algorithms continue to use ComputedProperties.
pub struct MutableComputedValuesFacade {
pub mut:
	values map[string]string
}

pub fn MutableComputedValuesFacade.new() MutableComputedValuesFacade {
	return MutableComputedValuesFacade{values: map[string]string{}}
}

fn (mut values MutableComputedValuesFacade) set_slot(name string, value string) {
	values.values[name] = value
}

pub fn (mut values MutableComputedValuesFacade) inherit_from(other MutableComputedValuesFacade) {
	for name, value in other.values {
		values.values[name] = value
	}
}

pub fn (values MutableComputedValuesFacade) border_left() string {
	return values.values['border-left']
}

pub fn (values MutableComputedValuesFacade) border_top() string {
	return values.values['border-top']
}

pub fn (values MutableComputedValuesFacade) border_right() string {
	return values.values['border-right']
}

pub fn (values MutableComputedValuesFacade) border_bottom() string {
	return values.values['border-bottom']
}

pub fn (mut values MutableComputedValuesFacade) set_accent_color(value string) {
	values.set_slot('accent-color', value)
}

pub fn (mut values MutableComputedValuesFacade) set_align_content(value string) {
	values.set_slot('align-content', value)
}

pub fn (mut values MutableComputedValuesFacade) set_align_items(value string) {
	values.set_slot('align-items', value)
}

pub fn (mut values MutableComputedValuesFacade) set_align_self(value string) {
	values.set_slot('align-self', value)
}

pub fn (mut values MutableComputedValuesFacade) set_appearance(value string) {
	values.set_slot('appearance', value)
}

pub fn (mut values MutableComputedValuesFacade) set_aspect_ratio(value string) {
	values.set_slot('aspect-ratio', value)
}

pub fn (mut values MutableComputedValuesFacade) set_backdrop_filter(value string) {
	values.set_slot('backdrop-filter', value)
}

pub fn (mut values MutableComputedValuesFacade) set_background_color(value string) {
	values.set_slot('background-color', value)
}

pub fn (mut values MutableComputedValuesFacade) set_background_color_clip(value string) {
	values.set_slot('background-color-clip', value)
}

pub fn (mut values MutableComputedValuesFacade) set_background_layers(value string) {
	values.set_slot('background-layers', value)
}

pub fn (mut values MutableComputedValuesFacade) set_border_bottom_left_radius(value string) {
	values.set_slot('border-bottom-left-radius', value)
}

pub fn (mut values MutableComputedValuesFacade) set_border_bottom_right_radius(value string) {
	values.set_slot('border-bottom-right-radius', value)
}

pub fn (mut values MutableComputedValuesFacade) set_border_collapse(value string) {
	values.set_slot('border-collapse', value)
}

pub fn (mut values MutableComputedValuesFacade) set_border_spacing_horizontal(value string) {
	values.set_slot('border-spacing-horizontal', value)
}

pub fn (mut values MutableComputedValuesFacade) set_border_spacing_vertical(value string) {
	values.set_slot('border-spacing-vertical', value)
}

pub fn (mut values MutableComputedValuesFacade) set_border_top_left_radius(value string) {
	values.set_slot('border-top-left-radius', value)
}

pub fn (mut values MutableComputedValuesFacade) set_border_top_right_radius(value string) {
	values.set_slot('border-top-right-radius', value)
}

pub fn (mut values MutableComputedValuesFacade) set_box_shadow(value string) {
	values.set_slot('box-shadow', value)
}

pub fn (mut values MutableComputedValuesFacade) set_box_sizing(value string) {
	values.set_slot('box-sizing', value)
}

pub fn (mut values MutableComputedValuesFacade) set_caption_side(value string) {
	values.set_slot('caption-side', value)
}

pub fn (mut values MutableComputedValuesFacade) set_caret_color(value string) {
	values.set_slot('caret-color', value)
}

pub fn (mut values MutableComputedValuesFacade) set_clear(value string) {
	values.set_slot('clear', value)
}

pub fn (mut values MutableComputedValuesFacade) set_clip(value string) {
	values.set_slot('clip', value)
}

pub fn (mut values MutableComputedValuesFacade) set_clip_path(value string) {
	values.set_slot('clip-path', value)
}

pub fn (mut values MutableComputedValuesFacade) set_clip_rule(value string) {
	values.set_slot('clip-rule', value)
}

pub fn (mut values MutableComputedValuesFacade) set_color(value string) {
	values.set_slot('color', value)
}

pub fn (mut values MutableComputedValuesFacade) set_color_interpolation(value string) {
	values.set_slot('color-interpolation', value)
}

pub fn (mut values MutableComputedValuesFacade) set_color_scheme(value string) {
	values.set_slot('color-scheme', value)
}

pub fn (mut values MutableComputedValuesFacade) set_column_count(value string) {
	values.set_slot('column-count', value)
}

pub fn (mut values MutableComputedValuesFacade) set_column_gap(value string) {
	values.set_slot('column-gap', value)
}

pub fn (mut values MutableComputedValuesFacade) set_column_height(value string) {
	values.set_slot('column-height', value)
}

pub fn (mut values MutableComputedValuesFacade) set_column_span(value string) {
	values.set_slot('column-span', value)
}

pub fn (mut values MutableComputedValuesFacade) set_column_width(value string) {
	values.set_slot('column-width', value)
}

pub fn (mut values MutableComputedValuesFacade) set_contain(value string) {
	values.set_slot('contain', value)
}

pub fn (mut values MutableComputedValuesFacade) set_container_type(value string) {
	values.set_slot('container-type', value)
}

pub fn (mut values MutableComputedValuesFacade) set_content(value string) {
	values.set_slot('content', value)
}

pub fn (mut values MutableComputedValuesFacade) set_content_visibility(value string) {
	values.set_slot('content-visibility', value)
}

pub fn (mut values MutableComputedValuesFacade) set_counter_increment(value string) {
	values.set_slot('counter-increment', value)
}

pub fn (mut values MutableComputedValuesFacade) set_counter_reset(value string) {
	values.set_slot('counter-reset', value)
}

pub fn (mut values MutableComputedValuesFacade) set_counter_set(value string) {
	values.set_slot('counter-set', value)
}

pub fn (mut values MutableComputedValuesFacade) set_cursor(value string) {
	values.set_slot('cursor', value)
}

pub fn (mut values MutableComputedValuesFacade) set_cx(value string) {
	values.set_slot('cx', value)
}

pub fn (mut values MutableComputedValuesFacade) set_cy(value string) {
	values.set_slot('cy', value)
}

pub fn (mut values MutableComputedValuesFacade) set_direction(value string) {
	values.set_slot('direction', value)
}

pub fn (mut values MutableComputedValuesFacade) set_display(value string) {
	values.set_slot('display', value)
}

pub fn (mut values MutableComputedValuesFacade) set_display_before_box_type_transformation(value string) {
	values.set_slot('display-before-box-type-transformation', value)
}

pub fn (mut values MutableComputedValuesFacade) set_dominant_baseline(value string) {
	values.set_slot('dominant-baseline', value)
}

pub fn (mut values MutableComputedValuesFacade) set_empty_cells(value string) {
	values.set_slot('empty-cells', value)
}

pub fn (mut values MutableComputedValuesFacade) set_fill(value string) {
	values.set_slot('fill', value)
}

pub fn (mut values MutableComputedValuesFacade) set_fill_opacity(value string) {
	values.set_slot('fill-opacity', value)
}

pub fn (mut values MutableComputedValuesFacade) set_fill_rule(value string) {
	values.set_slot('fill-rule', value)
}

pub fn (mut values MutableComputedValuesFacade) set_filter(value string) {
	values.set_slot('filter', value)
}

pub fn (mut values MutableComputedValuesFacade) set_flex_basis(value string) {
	values.set_slot('flex-basis', value)
}

pub fn (mut values MutableComputedValuesFacade) set_flex_direction(value string) {
	values.set_slot('flex-direction', value)
}

pub fn (mut values MutableComputedValuesFacade) set_flex_grow(value string) {
	values.set_slot('flex-grow', value)
}

pub fn (mut values MutableComputedValuesFacade) set_flex_shrink(value string) {
	values.set_slot('flex-shrink', value)
}

pub fn (mut values MutableComputedValuesFacade) set_flex_wrap(value string) {
	values.set_slot('flex-wrap', value)
}

pub fn (mut values MutableComputedValuesFacade) set_float(value string) {
	values.set_slot('float', value)
}

pub fn (mut values MutableComputedValuesFacade) set_flood_color(value string) {
	values.set_slot('flood-color', value)
}

pub fn (mut values MutableComputedValuesFacade) set_flood_opacity(value string) {
	values.set_slot('flood-opacity', value)
}

pub fn (mut values MutableComputedValuesFacade) set_font_language_override(value string) {
	values.set_slot('font-language-override', value)
}

pub fn (mut values MutableComputedValuesFacade) set_font_list(value string) {
	values.set_slot('font-list', value)
}

pub fn (mut values MutableComputedValuesFacade) set_font_size(value string) {
	values.set_slot('font-size', value)
}

pub fn (mut values MutableComputedValuesFacade) set_font_variation_settings(value string) {
	values.set_slot('font-variation-settings', value)
}

pub fn (mut values MutableComputedValuesFacade) set_font_weight(value string) {
	values.set_slot('font-weight', value)
}

pub fn (mut values MutableComputedValuesFacade) set_grid_auto_columns(value string) {
	values.set_slot('grid-auto-columns', value)
}

pub fn (mut values MutableComputedValuesFacade) set_grid_auto_flow(value string) {
	values.set_slot('grid-auto-flow', value)
}

pub fn (mut values MutableComputedValuesFacade) set_grid_auto_rows(value string) {
	values.set_slot('grid-auto-rows', value)
}

pub fn (mut values MutableComputedValuesFacade) set_grid_column_end(value string) {
	values.set_slot('grid-column-end', value)
}

pub fn (mut values MutableComputedValuesFacade) set_grid_column_start(value string) {
	values.set_slot('grid-column-start', value)
}

pub fn (mut values MutableComputedValuesFacade) set_grid_row_end(value string) {
	values.set_slot('grid-row-end', value)
}

pub fn (mut values MutableComputedValuesFacade) set_grid_row_start(value string) {
	values.set_slot('grid-row-start', value)
}

pub fn (mut values MutableComputedValuesFacade) set_grid_template_areas(value string) {
	values.set_slot('grid-template-areas', value)
}

pub fn (mut values MutableComputedValuesFacade) set_grid_template_columns(value string) {
	values.set_slot('grid-template-columns', value)
}

pub fn (mut values MutableComputedValuesFacade) set_grid_template_rows(value string) {
	values.set_slot('grid-template-rows', value)
}

pub fn (mut values MutableComputedValuesFacade) set_height(value string) {
	values.set_slot('height', value)
}

pub fn (mut values MutableComputedValuesFacade) set_image_rendering(value string) {
	values.set_slot('image-rendering', value)
}

pub fn (mut values MutableComputedValuesFacade) set_inset(value string) {
	values.set_slot('inset', value)
}

pub fn (mut values MutableComputedValuesFacade) set_isolation(value string) {
	values.set_slot('isolation', value)
}

pub fn (mut values MutableComputedValuesFacade) set_justify_content(value string) {
	values.set_slot('justify-content', value)
}

pub fn (mut values MutableComputedValuesFacade) set_justify_items(value string) {
	values.set_slot('justify-items', value)
}

pub fn (mut values MutableComputedValuesFacade) set_justify_self(value string) {
	values.set_slot('justify-self', value)
}

pub fn (mut values MutableComputedValuesFacade) set_letter_spacing(value string) {
	values.set_slot('letter-spacing', value)
}

pub fn (mut values MutableComputedValuesFacade) set_line_height(value string) {
	values.set_slot('line-height', value)
}

pub fn (mut values MutableComputedValuesFacade) set_list_style_position(value string) {
	values.set_slot('list-style-position', value)
}

pub fn (mut values MutableComputedValuesFacade) set_list_style_type(value string) {
	values.set_slot('list-style-type', value)
}

pub fn (mut values MutableComputedValuesFacade) set_margin(value string) {
	values.set_slot('margin', value)
}

pub fn (mut values MutableComputedValuesFacade) set_mask(value string) {
	values.set_slot('mask', value)
}

pub fn (mut values MutableComputedValuesFacade) set_mask_image(value string) {
	values.set_slot('mask-image', value)
}

pub fn (mut values MutableComputedValuesFacade) set_mask_type(value string) {
	values.set_slot('mask-type', value)
}

pub fn (mut values MutableComputedValuesFacade) set_math_depth(value string) {
	values.set_slot('math-depth', value)
}

pub fn (mut values MutableComputedValuesFacade) set_math_shift(value string) {
	values.set_slot('math-shift', value)
}

pub fn (mut values MutableComputedValuesFacade) set_math_style(value string) {
	values.set_slot('math-style', value)
}

pub fn (mut values MutableComputedValuesFacade) set_max_height(value string) {
	values.set_slot('max-height', value)
}

pub fn (mut values MutableComputedValuesFacade) set_max_width(value string) {
	values.set_slot('max-width', value)
}

pub fn (mut values MutableComputedValuesFacade) set_min_height(value string) {
	values.set_slot('min-height', value)
}

pub fn (mut values MutableComputedValuesFacade) set_min_width(value string) {
	values.set_slot('min-width', value)
}

pub fn (mut values MutableComputedValuesFacade) set_mix_blend_mode(value string) {
	values.set_slot('mix-blend-mode', value)
}

pub fn (mut values MutableComputedValuesFacade) set_object_fit(value string) {
	values.set_slot('object-fit', value)
}

pub fn (mut values MutableComputedValuesFacade) set_object_position(value string) {
	values.set_slot('object-position', value)
}

pub fn (mut values MutableComputedValuesFacade) set_opacity(value string) {
	values.set_slot('opacity', value)
}

pub fn (mut values MutableComputedValuesFacade) set_order(value string) {
	values.set_slot('order', value)
}

pub fn (mut values MutableComputedValuesFacade) set_outline_color(value string) {
	values.set_slot('outline-color', value)
}

pub fn (mut values MutableComputedValuesFacade) set_outline_offset(value string) {
	values.set_slot('outline-offset', value)
}

pub fn (mut values MutableComputedValuesFacade) set_outline_style(value string) {
	values.set_slot('outline-style', value)
}

pub fn (mut values MutableComputedValuesFacade) set_outline_width(value string) {
	values.set_slot('outline-width', value)
}

pub fn (mut values MutableComputedValuesFacade) set_overflow_clip_margin(value string) {
	values.set_slot('overflow-clip-margin', value)
}

pub fn (mut values MutableComputedValuesFacade) set_overflow_x(value string) {
	values.set_slot('overflow-x', value)
}

pub fn (mut values MutableComputedValuesFacade) set_overflow_y(value string) {
	values.set_slot('overflow-y', value)
}

pub fn (mut values MutableComputedValuesFacade) set_padding(value string) {
	values.set_slot('padding', value)
}

pub fn (mut values MutableComputedValuesFacade) set_paint_order(value string) {
	values.set_slot('paint-order', value)
}

pub fn (mut values MutableComputedValuesFacade) set_perspective(value string) {
	values.set_slot('perspective', value)
}

pub fn (mut values MutableComputedValuesFacade) set_perspective_origin(value string) {
	values.set_slot('perspective-origin', value)
}

pub fn (mut values MutableComputedValuesFacade) set_pointer_events(value string) {
	values.set_slot('pointer-events', value)
}

pub fn (mut values MutableComputedValuesFacade) set_position(value string) {
	values.set_slot('position', value)
}

pub fn (mut values MutableComputedValuesFacade) set_quotes(value string) {
	values.set_slot('quotes', value)
}

pub fn (mut values MutableComputedValuesFacade) set_r(value string) {
	values.set_slot('r', value)
}

pub fn (mut values MutableComputedValuesFacade) set_resize(value string) {
	values.set_slot('resize', value)
}

pub fn (mut values MutableComputedValuesFacade) set_rotate(value string) {
	values.set_slot('rotate', value)
}

pub fn (mut values MutableComputedValuesFacade) set_row_gap(value string) {
	values.set_slot('row-gap', value)
}

pub fn (mut values MutableComputedValuesFacade) set_rx(value string) {
	values.set_slot('rx', value)
}

pub fn (mut values MutableComputedValuesFacade) set_ry(value string) {
	values.set_slot('ry', value)
}

pub fn (mut values MutableComputedValuesFacade) set_scale(value string) {
	values.set_slot('scale', value)
}

pub fn (mut values MutableComputedValuesFacade) set_scrollbar_color(value string) {
	values.set_slot('scrollbar-color', value)
}

pub fn (mut values MutableComputedValuesFacade) set_scrollbar_width(value string) {
	values.set_slot('scrollbar-width', value)
}

pub fn (mut values MutableComputedValuesFacade) set_shape_rendering(value string) {
	values.set_slot('shape-rendering', value)
}

pub fn (mut values MutableComputedValuesFacade) set_stop_color(value string) {
	values.set_slot('stop-color', value)
}

pub fn (mut values MutableComputedValuesFacade) set_stop_opacity(value string) {
	values.set_slot('stop-opacity', value)
}

pub fn (mut values MutableComputedValuesFacade) set_stroke(value string) {
	values.set_slot('stroke', value)
}

pub fn (mut values MutableComputedValuesFacade) set_stroke_dasharray(value string) {
	values.set_slot('stroke-dasharray', value)
}

pub fn (mut values MutableComputedValuesFacade) set_stroke_dashoffset(value string) {
	values.set_slot('stroke-dashoffset', value)
}

pub fn (mut values MutableComputedValuesFacade) set_stroke_linecap(value string) {
	values.set_slot('stroke-linecap', value)
}

pub fn (mut values MutableComputedValuesFacade) set_stroke_linejoin(value string) {
	values.set_slot('stroke-linejoin', value)
}

pub fn (mut values MutableComputedValuesFacade) set_stroke_miterlimit(value string) {
	values.set_slot('stroke-miterlimit', value)
}

pub fn (mut values MutableComputedValuesFacade) set_stroke_opacity(value string) {
	values.set_slot('stroke-opacity', value)
}

pub fn (mut values MutableComputedValuesFacade) set_stroke_width(value string) {
	values.set_slot('stroke-width', value)
}

pub fn (mut values MutableComputedValuesFacade) set_tab_size(value string) {
	values.set_slot('tab-size', value)
}

pub fn (mut values MutableComputedValuesFacade) set_table_layout(value string) {
	values.set_slot('table-layout', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_align(value string) {
	values.set_slot('text-align', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_anchor(value string) {
	values.set_slot('text-anchor', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_decoration_color(value string) {
	values.set_slot('text-decoration-color', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_decoration_line(value string) {
	values.set_slot('text-decoration-line', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_decoration_style(value string) {
	values.set_slot('text-decoration-style', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_decoration_thickness(value string) {
	values.set_slot('text-decoration-thickness', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_indent(value string) {
	values.set_slot('text-indent', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_justify(value string) {
	values.set_slot('text-justify', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_overflow(value string) {
	values.set_slot('text-overflow', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_shadow(value string) {
	values.set_slot('text-shadow', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_transform(value string) {
	values.set_slot('text-transform', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_underline_offset(value string) {
	values.set_slot('text-underline-offset', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_underline_position(value string) {
	values.set_slot('text-underline-position', value)
}

pub fn (mut values MutableComputedValuesFacade) set_text_wrap_mode(value string) {
	values.set_slot('text-wrap-mode', value)
}

pub fn (mut values MutableComputedValuesFacade) set_touch_action(value string) {
	values.set_slot('touch-action', value)
}

pub fn (mut values MutableComputedValuesFacade) set_transform_box(value string) {
	values.set_slot('transform-box', value)
}

pub fn (mut values MutableComputedValuesFacade) set_transform_origin(value string) {
	values.set_slot('transform-origin', value)
}

pub fn (mut values MutableComputedValuesFacade) set_transform_style(value string) {
	values.set_slot('transform-style', value)
}

pub fn (mut values MutableComputedValuesFacade) set_transformations(value string) {
	values.set_slot('transformations', value)
}

pub fn (mut values MutableComputedValuesFacade) set_transition_delay(value string) {
	values.set_slot('transition-delay', value)
}

pub fn (mut values MutableComputedValuesFacade) set_translate(value string) {
	values.set_slot('translate', value)
}

pub fn (mut values MutableComputedValuesFacade) set_unicode_bidi(value string) {
	values.set_slot('unicode-bidi', value)
}

pub fn (mut values MutableComputedValuesFacade) set_user_select(value string) {
	values.set_slot('user-select', value)
}

pub fn (mut values MutableComputedValuesFacade) set_vertical_align(value string) {
	values.set_slot('vertical-align', value)
}

pub fn (mut values MutableComputedValuesFacade) set_view_transition_name(value string) {
	values.set_slot('view-transition-name', value)
}

pub fn (mut values MutableComputedValuesFacade) set_visibility(value string) {
	values.set_slot('visibility', value)
}

pub fn (mut values MutableComputedValuesFacade) set_webkit_text_fill_color(value string) {
	values.set_slot('webkit-text-fill-color', value)
}

pub fn (mut values MutableComputedValuesFacade) set_white_space_collapse(value string) {
	values.set_slot('white-space-collapse', value)
}

pub fn (mut values MutableComputedValuesFacade) set_white_space_trim(value string) {
	values.set_slot('white-space-trim', value)
}

pub fn (mut values MutableComputedValuesFacade) set_width(value string) {
	values.set_slot('width', value)
}

pub fn (mut values MutableComputedValuesFacade) set_will_change(value string) {
	values.set_slot('will-change', value)
}

pub fn (mut values MutableComputedValuesFacade) set_word_break(value string) {
	values.set_slot('word-break', value)
}

pub fn (mut values MutableComputedValuesFacade) set_word_spacing(value string) {
	values.set_slot('word-spacing', value)
}

pub fn (mut values MutableComputedValuesFacade) set_writing_mode(value string) {
	values.set_slot('writing-mode', value)
}

pub fn (mut values MutableComputedValuesFacade) set_x(value string) {
	values.set_slot('x', value)
}

pub fn (mut values MutableComputedValuesFacade) set_y(value string) {
	values.set_slot('y', value)
}

pub fn (mut values MutableComputedValuesFacade) set_z_index(value string) {
	values.set_slot('z-index', value)
}

pub struct CSSComputedValuesFacade {
pub mut:
	values map[string]string
}

pub fn CSSComputedValuesFacade.new() CSSComputedValuesFacade {
	return CSSComputedValuesFacade{values: map[string]string{}}
}

pub fn (values CSSComputedValuesFacade) clone_inherited_values() CSSComputedValuesFacade {
	return CSSComputedValuesFacade{values: values.values.clone()}
}

pub fn (values CSSComputedValuesFacade) has_noninitial_border_radii() bool {
	for name in ['border-bottom-left-radius', 'border-bottom-right-radius', 'border-top-left-radius', 'border-top-right-radius'] {
		if value := values.values[name] {
			if value != '' && value != '0' && value != '0px' {
				return true
			}
		}
	}
	return false
}

pub fn (values CSSComputedValuesFacade) background_color() string {
	return values.values['background-color']
}

pub fn (values CSSComputedValuesFacade) border_bottom() string {
	return values.values['border-bottom']
}

pub fn (values CSSComputedValuesFacade) border_bottom_left_radius() string {
	return values.values['border-bottom-left-radius']
}

pub fn (values CSSComputedValuesFacade) border_bottom_right_radius() string {
	return values.values['border-bottom-right-radius']
}

pub fn (values CSSComputedValuesFacade) border_left() string {
	return values.values['border-left']
}

pub fn (values CSSComputedValuesFacade) border_right() string {
	return values.values['border-right']
}

pub fn (values CSSComputedValuesFacade) border_top() string {
	return values.values['border-top']
}

pub fn (values CSSComputedValuesFacade) border_top_left_radius() string {
	return values.values['border-top-left-radius']
}

pub fn (values CSSComputedValuesFacade) border_top_right_radius() string {
	return values.values['border-top-right-radius']
}

pub fn (values CSSComputedValuesFacade) clip_path() string {
	return values.values['clip-path']
}

pub fn (values CSSComputedValuesFacade) column_count() string {
	return values.values['column-count']
}

pub fn (values CSSComputedValuesFacade) column_gap() string {
	return values.values['column-gap']
}

pub fn (values CSSComputedValuesFacade) column_height() string {
	return values.values['column-height']
}

pub fn (values CSSComputedValuesFacade) column_width() string {
	return values.values['column-width']
}

pub fn (values CSSComputedValuesFacade) cx() string {
	return values.values['cx']
}

pub fn (values CSSComputedValuesFacade) cy() string {
	return values.values['cy']
}

pub fn (values CSSComputedValuesFacade) fill() string {
	return values.values['fill']
}

pub fn (values CSSComputedValuesFacade) flood_color() string {
	return values.values['flood-color']
}

pub fn (values CSSComputedValuesFacade) inset() string {
	return values.values['inset']
}

pub fn (values CSSComputedValuesFacade) margin() string {
	return values.values['margin']
}

pub fn (values CSSComputedValuesFacade) mask() string {
	return values.values['mask']
}

pub fn (values CSSComputedValuesFacade) mask_image() string {
	return values.values['mask-image']
}

pub fn (values CSSComputedValuesFacade) max_height() string {
	return values.values['max-height']
}

pub fn (values CSSComputedValuesFacade) max_width() string {
	return values.values['max-width']
}

pub fn (values CSSComputedValuesFacade) min_height() string {
	return values.values['min-height']
}

pub fn (values CSSComputedValuesFacade) min_width() string {
	return values.values['min-width']
}

pub fn (values CSSComputedValuesFacade) outline_color() string {
	return values.values['outline-color']
}

pub fn (values CSSComputedValuesFacade) outline_width() string {
	return values.values['outline-width']
}

pub fn (values CSSComputedValuesFacade) overflow_clip_margin() string {
	return values.values['overflow-clip-margin']
}

pub fn (values CSSComputedValuesFacade) padding() string {
	return values.values['padding']
}

pub fn (values CSSComputedValuesFacade) r() string {
	return values.values['r']
}

pub fn (values CSSComputedValuesFacade) row_gap() string {
	return values.values['row-gap']
}

pub fn (values CSSComputedValuesFacade) rx() string {
	return values.values['rx']
}

pub fn (values CSSComputedValuesFacade) ry() string {
	return values.values['ry']
}

pub fn (values CSSComputedValuesFacade) stop_color() string {
	return values.values['stop-color']
}

pub fn (values CSSComputedValuesFacade) stroke() string {
	return values.values['stroke']
}

pub fn (values CSSComputedValuesFacade) stroke_dashoffset() string {
	return values.values['stroke-dashoffset']
}

pub fn (values CSSComputedValuesFacade) stroke_width() string {
	return values.values['stroke-width']
}

pub fn (values CSSComputedValuesFacade) text_decoration_color() string {
	return values.values['text-decoration-color']
}

pub fn (values CSSComputedValuesFacade) transition_delay() string {
	return values.values['transition-delay']
}

pub fn (values CSSComputedValuesFacade) webkit_text_fill_color() string {
	return values.values['webkit-text-fill-color']
}

pub struct CSSInitialValuesFacade {
	values map[string]string
}

pub fn CSSInitialValuesFacade.new(values map[string]string) CSSInitialValuesFacade {
	return CSSInitialValuesFacade{values: values.clone()}
}

pub fn (values CSSInitialValuesFacade) background_color() string {
	return values.values['background-color']
}

pub fn (values CSSInitialValuesFacade) border_radius() string {
	return values.values['border-radius']
}

pub fn (values CSSInitialValuesFacade) border_spacing() string {
	return values.values['border-spacing']
}

pub fn (values CSSInitialValuesFacade) column_count() string {
	return values.values['column-count']
}

pub fn (values CSSInitialValuesFacade) column_gap() string {
	return values.values['column-gap']
}

pub fn (values CSSInitialValuesFacade) column_height() string {
	return values.values['column-height']
}

pub fn (values CSSInitialValuesFacade) column_width() string {
	return values.values['column-width']
}

pub fn (values CSSInitialValuesFacade) cx() string {
	return values.values['cx']
}

pub fn (values CSSInitialValuesFacade) cy() string {
	return values.values['cy']
}

pub fn (values CSSInitialValuesFacade) flood_color() string {
	return values.values['flood-color']
}

pub fn (values CSSInitialValuesFacade) inset() string {
	return values.values['inset']
}

pub fn (values CSSInitialValuesFacade) margin() string {
	return values.values['margin']
}

pub fn (values CSSInitialValuesFacade) max_height() string {
	return values.values['max-height']
}

pub fn (values CSSInitialValuesFacade) max_width() string {
	return values.values['max-width']
}

pub fn (values CSSInitialValuesFacade) min_height() string {
	return values.values['min-height']
}

pub fn (values CSSInitialValuesFacade) min_width() string {
	return values.values['min-width']
}

pub fn (values CSSInitialValuesFacade) outline_color() string {
	return values.values['outline-color']
}

pub fn (values CSSInitialValuesFacade) outline_width() string {
	return values.values['outline-width']
}

pub fn (values CSSInitialValuesFacade) overflow_clip_margin() string {
	return values.values['overflow-clip-margin']
}

pub fn (values CSSInitialValuesFacade) padding() string {
	return values.values['padding']
}

pub fn (values CSSInitialValuesFacade) r() string {
	return values.values['r']
}

pub fn (values CSSInitialValuesFacade) row_gap() string {
	return values.values['row-gap']
}

pub fn (values CSSInitialValuesFacade) rx() string {
	return values.values['rx']
}

pub fn (values CSSInitialValuesFacade) ry() string {
	return values.values['ry']
}

pub fn (values CSSInitialValuesFacade) stop_color() string {
	return values.values['stop-color']
}

pub fn (values CSSInitialValuesFacade) stroke_dashoffset() string {
	return values.values['stroke-dashoffset']
}

pub fn (values CSSInitialValuesFacade) stroke_width() string {
	return values.values['stroke-width']
}

pub fn (values CSSInitialValuesFacade) transition_delay() string {
	return values.values['transition-delay']
}
