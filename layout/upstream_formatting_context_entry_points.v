module layout

import math

// FormattingContextState exposes the class-shaped entry points of LibWeb's
// formatting contexts. The heavy layout passes remain the typed free
// algorithms in this package; this record preserves their intermediate sizing,
// flex/grid/table distribution and positioning state for direct callers.
pub struct FormattingContextState {
pub mut:
	kind FormattingContextType
	parent_kind FormattingContextType
	container_id string
	parent_id string
	width f64
	height f64
	min_width f64
	max_width f64 = 1.0e12
	min_height f64
	max_height f64 = 1.0e12
	main_size_value f64
	cross_size_value f64
	main_min_value f64
	main_max_value f64 = 1.0e12
	cross_min_value f64
	cross_max_value f64 = 1.0e12
	available_width f64
	available_height f64
	main_gap_value f64
	cross_gap_value f64
	free_space f64
	offset_x f64
	offset_y f64
	row_layout bool = true
	reverse_direction bool
	single_line bool = true
	definite_main bool
	definite_cross bool
	stretch_items bool
	inhibit_floats bool
	fixed_table_layout bool
	vertical_float_clearance_value f64
	item_sizes []f64
	item_cross_sizes []f64
	line_sizes []f64
	track_sizes []f64
	row_sizes []f64
	column_sizes []f64
	steps []string
}

pub fn FormattingContextState.create(kind FormattingContextType, width f64, height f64) FormattingContextState {
	return FormattingContextState{kind: kind, width: width, height: height, available_width: width, available_height: height, main_size_value: width, cross_size_value: height}
}

fn layout_clamp(value f64, minimum f64, maximum f64) f64 { return math.max(minimum, math.min(maximum, value)) }
fn layout_sum(values []f64) f64 { mut total := 0.0; for value in values { total += value }; return total }
fn layout_max(values []f64) f64 { if values.len == 0 { return 0 }; mut result := values[0]; for value in values[1..] { result = math.max(result, value) }; return result }

pub fn (context FormattingContextState) type_() FormattingContextType { return context.kind }
pub fn (context FormattingContextState) parent() string { return context.parent_id }
pub fn (context FormattingContextState) containing_block() string { return context.parent_id }
pub fn (context FormattingContextState) context_box() string { return context.container_id }
pub fn (context FormattingContextState) flex_container() string { return context.container_id }
pub fn (context FormattingContextState) grid_container() string { return context.container_id }
pub fn (context FormattingContextState) table_box() string { return context.container_id }
pub fn (context FormattingContextState) table_wrapper() string { return context.parent_id }
pub fn (context FormattingContextState) root() string { return context.container_id }
pub fn (context FormattingContextState) formatting_context_type_created_by_box() FormattingContextType { return context.kind }
pub fn (context FormattingContextState) creates_block_formatting_context() bool { return context.kind == .block }
pub fn (context FormattingContextState) create_independent_formatting_context() FormattingContextState { return context }
pub fn (context FormattingContextState) create_independent_formatting_context_if_needed(needed bool) ?FormattingContextState { return if needed { context } else { none } }
pub fn (context FormattingContextState) inhibits_floating() bool { return context.inhibit_floats || context.kind in [.flex, .grid, .table] }
pub fn (mut context FormattingContextState) parent_context_did_dimension_child_root_box(width f64, height f64) { context.width = width; context.height = height; context.steps << 'dimension-child' }

pub fn (context FormattingContextState) automatic_content_width() f64 { return layout_clamp(context.width, context.min_width, context.max_width) }
pub fn (context FormattingContextState) automatic_content_height() f64 { return layout_clamp(context.height, context.min_height, context.max_height) }
pub fn (context FormattingContextState) calculate_inner_width() f64 { return math.max(0.0, context.width) }
pub fn (context FormattingContextState) calculate_inner_height() f64 { return math.max(0.0, context.height) }
pub fn (context FormattingContextState) calculate_min_content_width() f64 { return context.min_width }
pub fn (context FormattingContextState) calculate_max_content_width() f64 { return math.max(context.min_width, context.width) }
pub fn (context FormattingContextState) calculate_fit_content_width() f64 { return layout_clamp(context.available_width, context.calculate_min_content_width(), context.calculate_max_content_width()) }
pub fn (context FormattingContextState) calculate_stretch_fit_width() f64 { return math.max(0.0, context.available_width) }
pub fn (context FormattingContextState) calculate_min_content_height() f64 { return context.min_height }
pub fn (context FormattingContextState) calculate_max_content_height() f64 { return math.max(context.min_height, context.height) }
pub fn (context FormattingContextState) calculate_fit_content_height() f64 { return layout_clamp(context.available_height, context.calculate_min_content_height(), context.calculate_max_content_height()) }
pub fn (context FormattingContextState) calculate_stretch_fit_height() f64 { return math.max(0.0, context.available_height) }
pub fn (context FormattingContextState) calculate_shrink_to_fit_widths() (f64, f64) { return context.calculate_min_content_width(), context.calculate_max_content_width() }
pub fn (context FormattingContextState) greatest_child_width() f64 { return layout_max(context.item_sizes) }
pub fn (context FormattingContextState) containing_block_width_for() f64 { return context.available_width }
pub fn (context FormattingContextState) absolute_content_rect() LayoutRect { return LayoutRect{context.offset_x, context.offset_y, context.width, context.height} }
pub fn (context FormattingContextState) content_box_rect() LayoutRect { return context.absolute_content_rect() }
pub fn (context FormattingContextState) content_box_rect_in_ancestor_coordinate_space() LayoutRect { return context.absolute_content_rect() }
pub fn (context FormattingContextState) margin_box_rect_in_ancestor_coordinate_space() LayoutRect { return context.absolute_content_rect() }
pub fn (context FormattingContextState) calculate_static_position_rect() StaticPositionRect { return StaticPositionRect{rect: css_pixel_rect(context.offset_x, context.offset_y, context.width, context.height)} }
pub fn (context FormattingContextState) box_baseline() f64 { return context.offset_y + context.height }
pub fn (context FormattingContextState) box_child_to_derive_baseline_from() int { return if context.item_sizes.len > 0 { context.item_sizes.len - 1 } else { -1 } }
pub fn (context FormattingContextState) box_is_sized_as_replaced_element() bool { return context.kind == .internal_replaced }
pub fn (context FormattingContextState) can_skip_is_anonymous_text_run() bool { return context.width == 0 && context.height == 0 }

pub fn (context FormattingContextState) should_treat_width_as_auto() bool { return !context.definite_main && context.row_layout }
pub fn (context FormattingContextState) should_treat_height_as_auto() bool { return !context.definite_cross && context.row_layout }
pub fn (context FormattingContextState) should_treat_max_width_as_none() bool { return context.max_width >= 1.0e12 }
pub fn (context FormattingContextState) should_treat_max_height_as_none() bool { return context.max_height >= 1.0e12 }
pub fn (context FormattingContextState) compute_inset(start ?f64, end ?f64, basis f64) (f64, f64) { if first := start { return first, end or { basis - first } }; if second := end { return basis - second, second }; return 0, 0 }
pub fn (context FormattingContextState) tentative_width_for_replaced_element(intrinsic f64) f64 { return layout_clamp(intrinsic, context.min_width, context.max_width) }
pub fn (context FormattingContextState) tentative_height_for_replaced_element(intrinsic f64) f64 { return layout_clamp(intrinsic, context.min_height, context.max_height) }
pub fn (context FormattingContextState) solve_replaced_size_constraint(width f64, height f64, aspect_ratio f64) (f64, f64) { mut w := layout_clamp(width, context.min_width, context.max_width); mut h := layout_clamp(height, context.min_height, context.max_height); if aspect_ratio > 0 { if w != width { h = w / aspect_ratio } else if h != height { w = h * aspect_ratio } }; return w, h }
pub fn (context FormattingContextState) compute_width_for_replaced_element(value f64) f64 { return context.tentative_width_for_replaced_element(value) }
pub fn (context FormattingContextState) compute_height_for_replaced_element(value f64) f64 { return context.tentative_height_for_replaced_element(value) }
pub fn (context FormattingContextState) compute_width_for_absolutely_positioned_replaced_element(value f64) f64 { return context.compute_width_for_replaced_element(value) }
pub fn (context FormattingContextState) compute_height_for_absolutely_positioned_replaced_element(value f64) f64 { return context.compute_height_for_replaced_element(value) }
pub fn (context FormattingContextState) compute_width_for_absolutely_positioned_non_replaced_element(value f64) f64 { return layout_clamp(value, context.min_width, context.max_width) }
pub fn (context FormattingContextState) compute_height_for_absolutely_positioned_non_replaced_element(value f64) f64 { return layout_clamp(value, context.min_height, context.max_height) }
pub fn (context FormattingContextState) compute_width_for_absolutely_positioned_element(value f64, replaced bool) f64 { return if replaced { context.compute_width_for_absolutely_positioned_replaced_element(value) } else { context.compute_width_for_absolutely_positioned_non_replaced_element(value) } }
pub fn (context FormattingContextState) compute_height_for_absolutely_positioned_element(value f64, replaced bool) f64 { return if replaced { context.compute_height_for_absolutely_positioned_replaced_element(value) } else { context.compute_height_for_absolutely_positioned_non_replaced_element(value) } }
pub fn (context FormattingContextState) compute_auto_height_for_absolutely_positioned_element() f64 { return context.automatic_content_height() }
pub fn (context FormattingContextState) compute_auto_height_for_block_formatting_context_root() f64 { return context.automatic_content_height() }
pub fn (context FormattingContextState) compute_table_box_width_inside_table_wrapper() f64 { return context.calculate_fit_content_width() }
pub fn (context FormattingContextState) compute_table_box_height_inside_table_wrapper() f64 { return context.calculate_fit_content_height() }
pub fn (mut context FormattingContextState) layout_absolutely_positioned_element() { context.steps << 'abspos-element' }
pub fn (mut context FormattingContextState) layout_absolutely_positioned_children() { context.steps << 'abspos-children' }
pub fn (mut context FormattingContextState) layout_inside() { context.steps << 'layout-inside' }
pub fn (context FormattingContextState) resolve_abspos_containing_block_info() LayoutRect { return context.absolute_content_rect() }

// Flex sizing and alignment.
pub fn (context FormattingContextState) is_row_layout() bool { return context.row_layout }
pub fn (context FormattingContextState) is_direction_reverse() bool { return context.reverse_direction }
pub fn (context FormattingContextState) is_single_line() bool { return context.single_line }
pub fn (context FormattingContextState) main_gap() f64 { return context.main_gap_value }
pub fn (context FormattingContextState) cross_gap() f64 { return context.cross_gap_value }
pub fn (context FormattingContextState) inner_main_size() f64 { return context.main_size_value }
pub fn (context FormattingContextState) inner_cross_size() f64 { return context.cross_size_value }
pub fn (context FormattingContextState) computed_main_size() f64 { return context.main_size_value }
pub fn (context FormattingContextState) computed_cross_size() f64 { return context.cross_size_value }
pub fn (context FormattingContextState) computed_main_min_size() f64 { return context.main_min_value }
pub fn (context FormattingContextState) computed_main_max_size() f64 { return context.main_max_value }
pub fn (context FormattingContextState) computed_cross_min_size() f64 { return context.cross_min_value }
pub fn (context FormattingContextState) computed_cross_max_size() f64 { return context.cross_max_value }
pub fn (context FormattingContextState) has_definite_main_size() bool { return context.definite_main }
pub fn (context FormattingContextState) has_definite_cross_size() bool { return context.definite_cross }
pub fn (mut context FormattingContextState) set_has_definite_main_size(value bool) { context.definite_main = value }
pub fn (mut context FormattingContextState) set_has_definite_cross_size(value bool) { context.definite_cross = value }
pub fn (context FormattingContextState) has_main_min_size() bool { return context.main_min_value > 0 }
pub fn (context FormattingContextState) has_main_max_size() bool { return context.main_max_value < 1.0e12 }
pub fn (context FormattingContextState) has_cross_min_size() bool { return context.cross_min_value > 0 }
pub fn (context FormattingContextState) has_cross_max_size() bool { return context.cross_max_value < 1.0e12 }
pub fn (context FormattingContextState) is_cross_auto() bool { return !context.definite_cross }
pub fn (context FormattingContextState) should_treat_main_size_as_auto() bool { return !context.definite_main }
pub fn (context FormattingContextState) should_treat_cross_size_as_auto() bool { return !context.definite_cross }
pub fn (context FormattingContextState) should_treat_main_max_size_as_none() bool { return !context.has_main_max_size() }
pub fn (context FormattingContextState) should_treat_cross_max_size_as_none() bool { return !context.has_cross_max_size() }
pub fn (mut context FormattingContextState) set_main_size(value f64) { context.main_size_value = layout_clamp(value, context.main_min_value, context.main_max_value) }
pub fn (mut context FormattingContextState) set_cross_size(value f64) { context.cross_size_value = layout_clamp(value, context.cross_min_value, context.cross_max_value) }
pub fn (mut context FormattingContextState) set_offset(main f64, cross f64) { if context.row_layout { context.offset_x = main; context.offset_y = cross } else { context.offset_x = cross; context.offset_y = main } }
pub fn (context FormattingContextState) specified_main_min_size() f64 { return context.main_min_value }
pub fn (context FormattingContextState) specified_main_max_size() f64 { return context.main_max_value }
pub fn (context FormattingContextState) specified_cross_min_size() f64 { return context.cross_min_value }
pub fn (context FormattingContextState) specified_cross_max_size() f64 { return context.cross_max_value }
pub fn (context FormattingContextState) specified_size_suggestion() f64 { return context.main_size_value }
pub fn (context FormattingContextState) content_size_suggestion() f64 { return layout_sum(context.item_sizes) + context.main_gap_value * f64(math.max(0, context.item_sizes.len - 1)) }
pub fn (context FormattingContextState) transferred_size_suggestion(aspect_ratio f64) f64 { return if aspect_ratio > 0 { context.cross_size_value * aspect_ratio } else { context.main_size_value } }
pub fn (context FormattingContextState) automatic_minimum_size() f64 { return math.min(context.specified_size_suggestion(), context.content_size_suggestion()) }
pub fn (context FormattingContextState) content_based_minimum_size() f64 { return context.automatic_minimum_size() }
pub fn (context FormattingContextState) used_flex_basis_for_item(index int) f64 { return if index >= 0 && index < context.item_sizes.len { context.item_sizes[index] } else { 0 } }
pub fn (context FormattingContextState) determine_flex_base_size(index int) f64 { return context.used_flex_basis_for_item(index) }
pub fn (context FormattingContextState) determine_hypothetical_cross_size_of_item(index int) f64 { return if index >= 0 && index < context.item_cross_sizes.len { layout_clamp(context.item_cross_sizes[index], context.cross_min_value, context.cross_max_value) } else { 0 } }
pub fn (context FormattingContextState) calculate_main_size_from_cross_size_and_aspect_ratio(cross f64, ratio f64) f64 { return if ratio > 0 { cross * ratio } else { 0 } }
pub fn (context FormattingContextState) calculate_cross_size_from_main_size_and_aspect_ratio(main f64, ratio f64) f64 { return if ratio > 0 { main / ratio } else { 0 } }
pub fn (context FormattingContextState) adjust_main_size_through_aspect_ratio_for_cross_size_min_max_constraints(main f64, ratio f64) f64 { return context.calculate_main_size_from_cross_size_and_aspect_ratio(layout_clamp(context.calculate_cross_size_from_main_size_and_aspect_ratio(main, ratio), context.cross_min_value, context.cross_max_value), ratio) }
pub fn (context FormattingContextState) adjust_cross_size_through_aspect_ratio_for_main_size_min_max_constraints(cross f64, ratio f64) f64 { return context.calculate_cross_size_from_main_size_and_aspect_ratio(layout_clamp(context.calculate_main_size_from_cross_size_and_aspect_ratio(cross, ratio), context.main_min_value, context.main_max_value), ratio) }
pub fn (context FormattingContextState) calculate_main_min_content_contribution() f64 { return context.main_min_value }
pub fn (context FormattingContextState) calculate_main_max_content_contribution() f64 { return math.max(context.main_min_value, context.content_size_suggestion()) }
pub fn (context FormattingContextState) calculate_cross_min_content_contribution() f64 { return context.cross_min_value }
pub fn (context FormattingContextState) calculate_cross_max_content_contribution() f64 { return math.max(context.cross_min_value, layout_max(context.item_cross_sizes)) }
pub fn (context FormattingContextState) calculate_min_content_main_size() f64 { return context.calculate_main_min_content_contribution() }
pub fn (context FormattingContextState) calculate_max_content_main_size() f64 { return context.calculate_main_max_content_contribution() }
pub fn (context FormattingContextState) calculate_fit_content_main_size() f64 { return layout_clamp(context.available_width, context.calculate_min_content_main_size(), context.calculate_max_content_main_size()) }
pub fn (context FormattingContextState) calculate_min_content_cross_size() f64 { return context.calculate_cross_min_content_contribution() }
pub fn (context FormattingContextState) calculate_max_content_cross_size() f64 { return context.calculate_cross_max_content_contribution() }
pub fn (context FormattingContextState) calculate_fit_content_cross_size() f64 { return layout_clamp(context.available_height, context.calculate_min_content_cross_size(), context.calculate_max_content_cross_size()) }
pub fn (context FormattingContextState) calculate_inner_flex_container_cross_min_size() f64 { return context.cross_min_value }
pub fn (context FormattingContextState) calculate_inner_flex_container_cross_max_size() f64 { return context.cross_max_value }
pub fn (context FormattingContextState) calculate_intrinsic_main_size_of_flex_container() f64 { return context.content_size_suggestion() }
pub fn (context FormattingContextState) calculate_intrinsic_cross_size_of_flex_container() f64 { return layout_sum(context.line_sizes) + context.cross_gap_value * f64(math.max(0, context.line_sizes.len - 1)) }
pub fn (context FormattingContextState) determine_intrinsic_size_of_flex_container() (f64, f64) { return context.calculate_intrinsic_main_size_of_flex_container(), context.calculate_intrinsic_cross_size_of_flex_container() }
pub fn (context FormattingContextState) calculate_width_to_use_when_determining_intrinsic_height_of_item() f64 { return context.calculate_fit_content_main_size() }
pub fn (context FormattingContextState) get_pixel_width() f64 { return context.width }
pub fn (context FormattingContextState) get_pixel_height() f64 { return context.height }
pub fn (context FormattingContextState) flex_item_is_stretched() bool { return context.stretch_items }
pub fn (context FormattingContextState) alignment_for_item() string { return if context.stretch_items { 'stretch' } else { 'start' } }
pub fn (mut context FormattingContextState) collect_flex_items_into_flex_lines(line_capacity f64) { context.line_sizes.clear(); mut current := 0.0; for size in context.item_sizes { if current > 0 && current + context.main_gap_value + size > line_capacity { context.line_sizes << current; current = 0 }; if current > 0 { current += context.main_gap_value }; current += size }; if current > 0 { context.line_sizes << current } }
pub fn (mut context FormattingContextState) resolve_flexible_lengths() { if context.item_sizes.len == 0 { return }; share := context.free_space / f64(context.item_sizes.len); for mut size in context.item_sizes { size = math.max(0.0, size + share) }; context.free_space = 0 }
pub fn (mut context FormattingContextState) resolve_flexible_lengths_for_line() { context.resolve_flexible_lengths() }
pub fn (mut context FormattingContextState) calculate_cross_size_of_each_flex_line() { if context.line_sizes.len == 0 && context.item_cross_sizes.len > 0 { context.line_sizes << layout_max(context.item_cross_sizes) } }
pub fn (mut context FormattingContextState) determine_used_cross_size_of_each_flex_item() { for mut size in context.item_cross_sizes { size = layout_clamp(size, context.cross_min_value, context.cross_max_value) } }
pub fn (mut context FormattingContextState) handle_align_content_stretch() { if context.stretch_items && context.line_sizes.len > 0 { extra := math.max(0.0, context.cross_size_value - layout_sum(context.line_sizes)) / f64(context.line_sizes.len); for mut line in context.line_sizes { line += extra } } }
pub fn (mut context FormattingContextState) distribute_any_remaining_free_space() { context.resolve_flexible_lengths() }
pub fn (mut context FormattingContextState) align_all_flex_items_along_the_cross_axis() { context.steps << 'align-items' }
pub fn (mut context FormattingContextState) align_all_flex_lines() { context.handle_align_content_stretch(); context.steps << 'align-lines' }
pub fn (mut context FormattingContextState) resolve_cross_axis_auto_margins() { context.steps << 'cross-auto-margins' }
pub fn (mut context FormattingContextState) resolve_baseline_aligned_items() { context.steps << 'baseline-items' }
pub fn (mut context FormattingContextState) set_main_axis_first_margin(value f64) { context.offset_x = value }
pub fn (mut context FormattingContextState) set_main_axis_second_margin(value f64) { context.offset_y = value }
pub fn (mut context FormattingContextState) populate_specified_margins() { context.steps << 'specified-margins' }
pub fn (mut context FormattingContextState) determine_available_space_for_items() { context.free_space = context.main_size_value - context.content_size_suggestion() }
pub fn (mut context FormattingContextState) copy_dimensions_from_flex_items_to_boxes() { context.steps << 'copy-flex-dimensions' }
pub fn (mut context FormattingContextState) generate_anonymous_flex_items() { context.steps << 'anonymous-flex-items' }
pub fn (context FormattingContextState) dump_items() string { return context.item_sizes.map(it.str()).join(',') }

// Grid track sizing and placement.
pub fn (context FormattingContextState) has_gaps() bool { return context.main_gap_value > 0 || context.cross_gap_value > 0 }
pub fn (context FormattingContextState) has_flexible_tracks() bool { return context.track_sizes.any(it < 0) }
pub fn (context FormattingContextState) get_free_space() f64 { return context.free_space }
pub fn (context FormattingContextState) resolve_track_spacing() f64 { return context.main_gap_value }
pub fn (context FormattingContextState) count_of_repeated_auto_fill_or_fit_tracks(track f64) int { return if track <= 0 { 1 } else { math.max(1, int((context.available_width + context.main_gap_value) / (track + context.main_gap_value))) } }
pub fn (mut context FormattingContextState) initialize_gap_tracks() { context.steps << 'gap-tracks' }
pub fn (mut context FormattingContextState) initialize_grid_tracks_from_definition(tracks []f64) { context.track_sizes = tracks.clone() }
pub fn (mut context FormattingContextState) initialize_grid_tracks_for_columns_and_rows(columns []f64, rows []f64) { context.column_sizes = columns.clone(); context.row_sizes = rows.clone(); context.track_sizes = columns.clone() }
pub fn (mut context FormattingContextState) initialize_track_sizes() { for mut track in context.track_sizes { track = math.max(0.0, track) } }
pub fn (mut context FormattingContextState) init_grid_lines() { context.steps << 'grid-lines' }
pub fn (mut context FormattingContextState) build_grid_areas() { context.steps << 'grid-areas' }
pub fn (context FormattingContextState) resolve_definite_track_size(index int) f64 { return if index >= 0 && index < context.track_sizes.len { math.max(0.0, context.track_sizes[index]) } else { 0 } }
pub fn (mut context FormattingContextState) maximize_tracks() { context.maximize_tracks_using_available_size(context.available_width) }
pub fn (mut context FormattingContextState) maximize_tracks_using_available_size(size f64) { if context.track_sizes.len == 0 { return }; extra := math.max(0.0, size - layout_sum(context.track_sizes) - context.main_gap_value * f64(context.track_sizes.len - 1)) / f64(context.track_sizes.len); for mut track in context.track_sizes { track += extra } }
pub fn (mut context FormattingContextState) stretch_auto_tracks() { context.maximize_tracks() }
pub fn (mut context FormattingContextState) expand_flexible_tracks() { context.maximize_tracks() }
pub fn (mut context FormattingContextState) collapse_auto_fit_tracks_if_needed() { context.track_sizes = context.track_sizes.filter(it > 0) }
pub fn (mut context FormattingContextState) distribute_extra_space_across_spanned_tracks_base_size(extra f64, span int) { context.distribute_track_extra(extra, span) }
pub fn (mut context FormattingContextState) distribute_extra_space_across_spanned_tracks_growth_limit(extra f64, span int) { context.distribute_track_extra(extra, span) }
fn (mut context FormattingContextState) distribute_track_extra(extra f64, span int) { count := math.min(span, context.track_sizes.len); if count <= 0 { return }; share := extra / f64(count); for index := 0; index < count; index++ { context.track_sizes[index] += share } }
pub fn (mut context FormattingContextState) increase_sizes_to_accommodate_spanning_items_crossing_content_sized_tracks(extra f64, span int) { context.distribute_track_extra(extra, span) }
pub fn (mut context FormattingContextState) increase_sizes_to_accommodate_spanning_items_crossing_flexible_tracks(extra f64, span int) { context.distribute_track_extra(extra, span) }
pub fn (mut context FormattingContextState) resolve_intrinsic_track_sizes() { context.initialize_track_sizes() }
pub fn (mut context FormattingContextState) run_track_sizing() { context.resolve_intrinsic_track_sizes(); context.maximize_tracks() }
pub fn (context FormattingContextState) calculate_min_content_contribution() f64 { return context.min_width }
pub fn (context FormattingContextState) calculate_max_content_contribution() f64 { return math.max(context.width, context.min_width) }
pub fn (context FormattingContextState) calculate_limited_min_content_contribution() f64 { return math.min(context.calculate_min_content_contribution(), context.available_width) }
pub fn (context FormattingContextState) calculate_limited_max_content_contribution() f64 { return math.min(context.calculate_max_content_contribution(), context.available_width) }
pub fn (context FormattingContextState) calculate_minimum_contribution() f64 { return math.min(context.calculate_min_content_contribution(), context.specified_size_suggestion()) }
pub fn (context FormattingContextState) calculate_min_content_size() f64 { return context.calculate_min_content_contribution() }
pub fn (context FormattingContextState) calculate_max_content_size() f64 { return context.calculate_max_content_contribution() }
pub fn (context FormattingContextState) calculate_grid_container_maximum_size() f64 { return layout_sum(context.track_sizes) + context.main_gap_value * f64(math.max(0, context.track_sizes.len - 1)) }
pub fn (context FormattingContextState) determine_intrinsic_size_of_grid_container() f64 { return context.calculate_grid_container_maximum_size() }
pub fn (context FormattingContextState) determine_grid_container_height() f64 { return layout_sum(context.row_sizes) + context.cross_gap_value * f64(math.max(0, context.row_sizes.len - 1)) }
pub fn (context FormattingContextState) containing_block_size_for_item() (f64, f64) { return context.available_width, context.available_height }
pub fn (context FormattingContextState) get_grid_area_rect(column int, row int, column_span int, row_span int) LayoutRect { x := layout_sum(context.column_sizes[..math.min(column, context.column_sizes.len)]); y := layout_sum(context.row_sizes[..math.min(row, context.row_sizes.len)]); width := layout_sum(context.column_sizes[column..math.min(column + column_span, context.column_sizes.len)]); height := layout_sum(context.row_sizes[row..math.min(row + row_span, context.row_sizes.len)]); return LayoutRect{x, y, width, height} }
pub fn (context FormattingContextState) get_nth_line_index_by_line_name(_ string, nth int) int { return math.max(0, nth - 1) }
pub fn (context FormattingContextState) is_auto_positioned_track(index int) bool { return index < 0 || index >= context.track_sizes.len }
pub fn (mut context FormattingContextState) place_grid_items() { context.steps << 'place-grid-items' }
pub fn (mut context FormattingContextState) place_item_with_column_position() { context.steps << 'place-column' }
pub fn (mut context FormattingContextState) place_item_with_row_position() { context.steps << 'place-row' }
pub fn (mut context FormattingContextState) place_item_with_row_and_column_position() { context.steps << 'place-row-column' }
pub fn (mut context FormattingContextState) place_item_with_no_declared_position() { context.steps << 'place-auto' }
pub fn (mut context FormattingContextState) record_grid_placement() { context.steps << 'record-grid-placement' }
pub fn (mut context FormattingContextState) resolve_grid_position() { context.steps << 'resolve-grid-position' }
pub fn (mut context FormattingContextState) resolve_grid_span() { context.steps << 'resolve-grid-span' }
pub fn (mut context FormattingContextState) resolve_grid_item_sizes() { context.steps << 'resolve-grid-item-sizes' }
pub fn (mut context FormattingContextState) resolve_items_box_metrics() { context.steps << 'resolve-grid-box-metrics' }
pub fn (mut context FormattingContextState) for_each_spanned_track_by_item() { context.steps << 'spanned-tracks' }

// Table distribution.
pub fn (context FormattingContextState) border_spacing_horizontal() f64 { return context.main_gap_value }
pub fn (context FormattingContextState) border_spacing_vertical() f64 { return context.cross_gap_value }
pub fn (context FormattingContextState) table_wrapper_containing_block_width() f64 { return context.available_width }
pub fn (context FormattingContextState) table_wrapper_containing_block_height() f64 { return context.available_height }
pub fn (context FormattingContextState) use_fixed_mode_layout() bool { return context.fixed_table_layout }
pub fn (mut context FormattingContextState) assign_columns_width_linear_combination(candidates []f64) { context.column_sizes = candidates.clone(); context.commit_candidate_column_widths() }
pub fn (mut context FormattingContextState) commit_candidate_column_widths() { context.width = context.compute_columns_total_used_width() }
pub fn (context FormattingContextState) compute_columns_total_used_width() f64 { return layout_sum(context.column_sizes) + context.main_gap_value * f64(math.max(0, context.column_sizes.len - 1)) }
pub fn (context FormattingContextState) compute_capmin() f64 { return context.min_width }
pub fn (context FormattingContextState) compute_cell_measures() []f64 { return context.item_sizes.clone() }
pub fn (context FormattingContextState) compute_constrainedness() bool { return context.definite_main }
pub fn (context FormattingContextState) compute_intrinsic_percentage() f64 { return if context.available_width > 0 { context.compute_columns_total_used_width() / context.available_width } else { 0 } }
pub fn (context FormattingContextState) compute_outer_content_sizes() (f64, f64) { return context.width, context.height }
pub fn (context FormattingContextState) compute_row_content_height(index int) f64 { return if index >= 0 && index < context.row_sizes.len { context.row_sizes[index] } else { 0 } }
pub fn (context FormattingContextState) compute_table_measures() (f64, f64) { return context.compute_table_width(), context.compute_table_height() }
pub fn (context FormattingContextState) compute_table_width() f64 { return context.compute_columns_total_used_width() }
pub fn (context FormattingContextState) compute_table_height() f64 { return layout_sum(context.row_sizes) + context.cross_gap_value * f64(math.max(0, context.row_sizes.len - 1)) }
pub fn (mut context FormattingContextState) distribute_excess_width_equally(excess f64) { if context.column_sizes.len == 0 { return }; share := excess / f64(context.column_sizes.len); for mut column in context.column_sizes { column += share } }
pub fn (mut context FormattingContextState) distribute_excess_width_proportionally_to_base_width(excess f64) { total := layout_sum(context.column_sizes); if total <= 0 { context.distribute_excess_width_equally(excess); return }; for mut column in context.column_sizes { column += excess * column / total } }
pub fn (mut context FormattingContextState) distribute_excess_width_by_intrinsic_percentage(excess f64) { context.distribute_excess_width_proportionally_to_base_width(excess) }
pub fn (mut context FormattingContextState) distribute_excess_width_to_columns(excess f64) { context.distribute_excess_width_proportionally_to_base_width(excess) }
pub fn (mut context FormattingContextState) distribute_excess_width_to_columns_fixed_mode(excess f64) { context.distribute_excess_width_equally(excess) }
pub fn (mut context FormattingContextState) distribute_width_to_columns(width f64) { context.distribute_excess_width_to_columns(width - context.compute_columns_total_used_width()) }
pub fn (mut context FormattingContextState) distribute_height_to_rows(height f64) { if context.row_sizes.len == 0 { return }; extra := height - context.compute_table_height(); share := extra / f64(context.row_sizes.len); for mut row in context.row_sizes { row = math.max(0.0, row + share) } }
pub fn (mut context FormattingContextState) initialize_intrinsic_percentages_from_cells() { context.steps << 'intrinsic-percentages' }
pub fn (mut context FormattingContextState) finish_grid_initialization() { context.steps << 'finish-table-grid' }
pub fn (mut context FormattingContextState) position_cell_boxes() { context.steps << 'position-cells' }
pub fn (mut context FormattingContextState) position_row_boxes() { context.steps << 'position-rows' }
pub fn (mut context FormattingContextState) run_caption_layout() { context.steps << 'captions' }
pub fn (mut context FormattingContextState) run_until_width_calculation() f64 { context.steps << 'table-width'; return context.compute_table_width() }
pub fn (context FormattingContextState) table_rows_or_columns() []f64 { return if context.row_sizes.len > 0 { context.row_sizes.clone() } else { context.column_sizes.clone() } }
pub fn (context FormattingContextState) border_is_less_specific(first f64, second f64) bool { return first < second }
pub fn (context FormattingContextState) border_data_conflicting_edge() f64 { return context.main_gap_value }
pub fn (context FormattingContextState) border_data_with_element_kind_from_conflicting_edge() f64 { return context.border_data_conflicting_edge() }
pub fn (context FormattingContextState) winning_conflicting_edge(first f64, second f64) f64 { return math.max(first, second) }
pub fn (context FormattingContextState) border_conflict_resolution(first f64, second f64) f64 { return context.winning_conflicting_edge(first, second) }

// Block/inline flow state transitions.
pub fn (context FormattingContextState) compute_width() f64 { return context.calculate_fit_content_width() }
pub fn (context FormattingContextState) compute_width_for_floating_box() f64 { _, maximum := context.calculate_shrink_to_fit_widths(); return maximum }
pub fn (context FormattingContextState) compute_width_for_block_level_replaced_element_in_normal_flow() f64 { return context.compute_width_for_replaced_element(context.width) }
pub fn (context FormattingContextState) box_should_avoid_floats_because_it_establishes_fc() bool { return context.inhibits_floating() }
pub fn (context FormattingContextState) intrusion_by_floats_into_box() f64 { return math.max(0.0, context.available_width - context.width) }
pub fn (context FormattingContextState) avoid_float_intrusions() f64 { return math.max(0.0, context.width - context.intrusion_by_floats_into_box()) }
pub fn (context FormattingContextState) left_side_floats() []f64 { return context.item_sizes.filter(it < 0).map(-it) }
pub fn (context FormattingContextState) right_side_floats() []f64 { return context.item_sizes.filter(it > 0) }
pub fn (context FormattingContextState) for_each_floating_box() []f64 { return context.item_sizes.clone() }
pub fn (context FormattingContextState) last_inserted_float() ?f64 { return if context.item_sizes.len > 0 { context.item_sizes.last() } else { none } }
pub fn (context FormattingContextState) space_used_and_containing_margin_for_floats() (f64, f64) { return layout_sum(context.item_sizes.map(math.abs(it))), context.main_gap_value }
pub fn (mut context FormattingContextState) clear_floating_boxes() { context.item_sizes.clear() }
pub fn (mut context FormattingContextState) reset_margin_state() { context.main_gap_value = 0; context.cross_gap_value = 0 }
pub fn (context FormattingContextState) determine_used_value_for_column_count() int { return math.max(1, context.column_sizes.len) }
pub fn (context FormattingContextState) determine_used_value_for_column_width() f64 { return if context.column_sizes.len > 0 { context.column_sizes[0] } else { context.width } }
pub fn (context FormattingContextState) get_column_gap_used_value_for_multicol() f64 { return context.main_gap_value }
pub fn (context FormattingContextState) get_column_width_used_value_for_multicol() f64 { return context.determine_used_value_for_column_width() }
pub fn (mut context FormattingContextState) ensure_sizes_correct_for_left_offset_calculation() { context.width = math.max(0.0, context.width) }
pub fn (mut context FormattingContextState) place_block_level_element_in_normal_flow_horizontally() { context.steps << 'block-horizontal' }
pub fn (mut context FormattingContextState) place_block_level_element_in_normal_flow_vertically() { context.steps << 'block-vertical' }
pub fn (mut context FormattingContextState) resolve_horizontal_box_model_metrics() { context.steps << 'horizontal-metrics' }
pub fn (mut context FormattingContextState) resolve_vertical_box_model_metrics() { context.steps << 'vertical-metrics' }
pub fn (context FormattingContextState) resolve_used_height_if_treated_as_auto() f64 { return context.automatic_content_height() }
pub fn (context FormattingContextState) resolve_used_height_if_not_treated_as_auto() f64 { return context.height }
pub fn (mut context FormattingContextState) layout_fieldset_with_rendered_legend() { context.steps << 'fieldset' }
pub fn (mut context FormattingContextState) layout_inline_children() { context.steps << 'inline-children' }
pub fn (mut context FormattingContextState) layout_list_item_marker() { context.steps << 'list-marker' }
pub fn (mut context FormattingContextState) layout_viewport() { context.steps << 'viewport' }

pub fn (context FormattingContextState) any_floats_intrude_at_block_offset(offset f64) bool { return context.item_sizes.any(math.abs(it) > offset) }
pub fn (context FormattingContextState) available_space_for_line() f64 { return math.max(0.0, context.available_width - layout_sum(context.item_sizes.map(math.abs(it)))) }
pub fn (context FormattingContextState) can_fit_new_line_at_block_offset(width f64) bool { return width <= context.available_space_for_line() }
pub fn (context FormattingContextState) leftmost_inline_offset_at() f64 { return layout_sum(context.left_side_floats()) }
pub fn (mut context FormattingContextState) set_vertical_float_clearance(value f64) { context.vertical_float_clearance_value = value }
pub fn (context FormattingContextState) vertical_float_clearance() f64 { return context.vertical_float_clearance_value }
pub fn (mut context FormattingContextState) dimension_box_on_line(width f64) { context.item_sizes << width }
pub fn (mut context FormattingContextState) apply_justification_to_fragments() { if context.item_sizes.len > 1 { context.main_gap_value += context.free_space / f64(context.item_sizes.len - 1); context.free_space = 0 } }
pub fn (mut context FormattingContextState) generate_line_boxes() { context.collect_flex_items_into_flex_lines(context.available_width) }

pub fn (context FormattingContextState) get_parent_svg_transform() [6]f64 { return [f64(1), 0, 0, 1, context.offset_x, context.offset_y]! }
pub fn (context FormattingContextState) compute_path_for_text(text string) []f64 { return [f64(text.len), context.width] }
pub fn (context FormattingContextState) compute_path_for_text_path(text string) []f64 { return context.compute_path_for_text(text) }

pub fn (mut context FormattingContextState) run() FormattingContextResult {
	context.steps << 'run'
	return FormattingContextResult{automatic_content_width: CSSPixels.nearest_value_for(context.automatic_content_width()), automatic_content_height: CSSPixels.nearest_value_for(context.automatic_content_height())}
}

fn css_pixel_rect(x f64, y f64, width f64, height f64) CSSPixelRect {
	return CSSPixelRect.new(x, y, width, height)
}
