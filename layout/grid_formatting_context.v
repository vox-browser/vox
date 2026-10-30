// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css

struct GridTrack {
mut:
	// An empty auto-fit track collapsed after placement; its gutters collapse.
	collapsed             bool
	base_size             CSSPixels
	flex                  f64
	flexible              bool
	intrinsic             bool
	minimum_intrinsic     bool
	auto_fit              bool
	auto_min              bool
	min_content_min       bool
	max_content_min       bool
	auto_max              bool
	growth_limit          CSSPixels
	has_growth_limit      bool
	min_content_max       bool
	max_content_max       bool
	fit_content_max       bool
	fit_content_limit     CSSPixels
	has_fit_content_limit bool
	fixed_max             bool
	fixed_max_size        CSSPixels
	base_size_frozen      bool
	growth_limit_frozen   bool
	infinitely_growable   bool
}

enum GridBaseSizeDistributionPhase {
	minimum_contribution
	min_content_contribution
	max_content_contribution
}

enum GridGrowthLimitDistributionPhase {
	intrinsic_maximum
	max_content_maximum
}

enum GridFlexibleMinimumPhase {
	intrinsic
	min_content
	limited_max_content
	max_content
}

fn grid_flexible_minimum_phase_dominates(track GridTrack, phase GridFlexibleMinimumPhase, columns bool, available_size AvailableSize) bool {
	return match phase {
		.intrinsic {
			available_size.is_max_content() || (!columns && available_size.is_min_content())
				|| track.minimum_intrinsic
		}
		.min_content { track.min_content_min || track.max_content_min }
		.limited_max_content { track.auto_min || track.max_content_min }
		.max_content { track.max_content_min }
	}
}

struct GridItemPlacement {
	item &Node = unsafe { nil }
mut:
	row                int
	column             int
	row_span           int = 1
	column_span        int = 1
	inline_start_extra CSSPixels
	inline_end_extra   CSSPixels
	block_start_extra  CSSPixels
	block_end_extra    CSSPixels
}

fn (placement GridItemPlacement) sizing_extra(columns bool) CSSPixels {
	return if columns {
		placement.inline_start_extra.plus(placement.inline_end_extra)
	} else {
		placement.block_start_extra.plus(placement.block_end_extra)
	}
}

struct GridAxisPlacement {
mut:
	start int
	end   int
	span  int = 1
}

struct GridPlacementResult {
	placements              []GridItemPlacement
	implicit_columns_before int
	implicit_rows_before    int
}

enum GridItemAlignment {
	normal
	start
	end
	center
	stretch
	baseline
}

fn grid_inline_alignment(container &Node, item &Node) GridItemAlignment {
	self_alignment := item.computed_values().justify_self()
	if self_alignment == .auto_ {
		return match container.computed_values().justify_items() {
			.center { .center }
			.end_, .flex_end, .self_end, .right { .end }
			.start, .flex_start, .self_start, .left, .safe, .unsafe_ { .start }
			.stretch { .stretch }
			.baseline { .baseline }
			.normal, .legacy { .normal }
		}
	}
	return match self_alignment {
		.center { .center }
		.end_, .flex_end, .self_end, .right { .end }
		.start, .flex_start, .self_start, .left, .safe, .unsafe_ { .start }
		.stretch { .stretch }
		.baseline { .baseline }
		.normal, .auto_ { .normal }
	}
}

fn grid_block_alignment(container &Node, item &Node) GridItemAlignment {
	self_alignment := item.computed_values().align_self()
	if self_alignment == .auto_ {
		return match container.computed_values().align_items() {
			.center { .center }
			.end_, .flex_end, .self_end { .end }
			.start, .flex_start, .self_start, .safe, .unsafe_ { .start }
			.stretch { .stretch }
			.baseline { .baseline }
			.normal { .normal }
		}
	}
	return match self_alignment {
		.center { .center }
		.end_, .flex_end, .self_end { .end }
		.start, .flex_start, .self_start, .safe, .unsafe_ { .start }
		.stretch { .stretch }
		.baseline { .baseline }
		.normal, .auto_ { .normal }
	}
}

fn static_position_alignment_for_grid_item(alignment GridItemAlignment) StaticPositionAlignment {
	return match alignment {
		.center { .center }
		.end { .end }
		.normal, .start, .stretch, .baseline { .start }
	}
}

fn grid_container_is_abspos_containing_block(container &Node, child &Node) bool {
	containing_block := child.containing_block() or { return false }
	return voidptr(containing_block) == voidptr(container)
}

fn set_grid_abspos_containing_rect(mut state LayoutState, container &Node, child &Node, rect css.CSSPixelRect) {
	if !grid_container_is_abspos_containing_block(container, child) {
		return
	}
	styled := child.as_node_with_style() or { return }
	mut child_state := state.get_mutable(styled)
	child_state.set_abspos_containing_block_rect(rect)
	is_direct_grid_child := if parent := child.parent() {
		voidptr(parent) == voidptr(container)
	} else {
		false
	}
	if !is_direct_grid_child {
		existing_static_position := child_state.static_position()
		child_state.set_static_position_rect(StaticPositionRect{
			rect: css.CSSPixelRect.new(rect.x.plus(existing_static_position.x()).to_double(), rect.y.plus(existing_static_position.y()).to_double(), 0, 0)
		})
		return
	}
	child_state.set_static_position_rect(StaticPositionRect{
		rect: rect
		horizontal_alignment: static_position_alignment_for_grid_item(grid_inline_alignment(container, child))
		vertical_alignment: static_position_alignment_for_grid_item(grid_block_alignment(container, child))
	})
}

fn set_grid_abspos_descendant_rects(mut state LayoutState, container &Node, ancestor &Node, rect css.CSSPixelRect) {
	for descendant in ancestor.children() {
		if descendant.is_absolutely_positioned() {
			set_grid_abspos_containing_rect(mut state, container, descendant, rect)
		}
		set_grid_abspos_descendant_rects(mut state, container, descendant, rect)
	}
}

fn resolve_grid_table_wrapper_width(mut state LayoutState, wrapper &Node, mut wrapper_state UsedValues, grid_area_width CSSPixels, alignment GridItemAlignment) CSSPixels {
	mut wrapper_width := compute_table_wrapper_content_width(mut state, wrapper, mut wrapper_state,
		grid_area_width)
	mut table := ?&Node(none)
	for child in wrapper.children() {
		if child.display().is_table_inside() {
			table = child
			break
		}
	}
	table_node := table or { return wrapper_width }
	table_style := table_node.computed_values()
	if !table_style.size_value(.width).is_auto() || alignment !in [.normal, .stretch]
		|| property_is_auto(wrapper.computed_values(), .margin_left)
		|| property_is_auto(wrapper.computed_values(), .margin_right) {
		return wrapper_width
	}
	mut stretched := css_pixels_max(CSSPixels.new(0),
		grid_area_width.minus(flex_or_grid_item_outer_inline_edges(wrapper_state)))
	maximum := table_style.size_value(.max_width)
	if !maximum.is_none() {
		if maximum.is_intrinsic_sizing_constraint() {
			stretched = css_pixels_min(stretched, wrapper_width)
		} else if maximum_width := resolve_layout_size(table_node, maximum, grid_area_width) {
			table_styled := table_node.as_node_with_style() or { return wrapper_width }
			table_state := state.get(table_styled)
			maximum_border_box_width := if table_style.box_sizing() == .border_box {
				maximum_width
			} else {
				maximum_width.plus(table_state.border_left).plus(table_state.padding_left).plus(table_state.padding_right).plus(table_state.border_right)
			}
			stretched = css_pixels_min(stretched, maximum_border_box_width)
		}
	}
	return css_pixels_max(wrapper_width, stretched)
}

fn grid_track_from_size(node &Node, size css.GridSize, basis CSSPixels, available_is_definite bool, auto_fit bool) GridTrack {
	if size.is_flexible_length() {
		return GridTrack{
			flex: size.flex_factor()
			flexible: true
			// A bare <flex> track has an automatic minimum.
			intrinsic: true
			minimum_intrinsic: true
			auto_fit: auto_fit
			auto_min: true
		}
	}
	css_size := size.css_size()
	available_size := if available_is_definite {
		AvailableSize.make_definite(basis)
	} else {
		AvailableSize.make_indefinite()
	}
	if size.is_fixed(available_size) {
		value := resolve_layout_size(node, css_size, basis) or { CSSPixels.new(0) }
		return GridTrack{
			base_size: value
			auto_fit: auto_fit
			fixed_max: true
			fixed_max_size: value
		}
	}
	mut track := GridTrack{
		intrinsic: size.is_intrinsic(available_size)
		minimum_intrinsic: size.is_intrinsic(available_size)
		auto_fit: auto_fit
		auto_min: size.is_auto(available_size) || size.is_fit_content()
		min_content_min: css_size.is_min_content()
		max_content_min: css_size.is_max_content()
		auto_max: size.is_auto(available_size)
		min_content_max: css_size.is_min_content()
		max_content_max: css_size.is_max_content()
		fit_content_max: size.is_fit_content()
	}
	if size.is_fit_content() {
		if fit_content_space := css_size.fit_content_available_space() {
			fit_content_size := css.Size.make_length_percentage(fit_content_space)
			if available_is_definite || !fit_content_size.contains_percentage() {
				if limit := resolve_layout_size(node, fit_content_size, basis) {
					track.fit_content_limit = limit
					track.has_fit_content_limit = true
				}
			}
		}
	}
	return track
}

fn definite_grid_track_size(node &Node, track css.ExplicitGridTrack, basis CSSPixels) ?CSSPixels {
	if track.is_repeat() {
		return none
	}
	if track.is_minmax() {
		minmax := track.minmax()
		maximum := minmax.max_grid_size()
		minimum := minmax.min_grid_size()
		if maximum.is_definite() {
			mut size := resolve_layout_size(node, maximum.css_size(), basis) or { return none }
			if minimum.is_definite() {
				if minimum_size := resolve_layout_size(node, minimum.css_size(), basis) {
					size = css_pixels_max(size, minimum_size)
				}
			}
			return size
		}
		if minimum.is_definite() {
			return resolve_layout_size(node, minimum.css_size(), basis)
		}
		return none
	}
	size := track.grid_size()
	if !size.is_definite() {
		return none
	}
	return resolve_layout_size(node, size.css_size(), basis)
}

// A track's size for estimating automatic repetitions: its max track sizing
// function if definite, floored by a definite min, else its definite min.
fn auto_repeat_estimate_track_size(node &Node, track css.ExplicitGridTrack, basis CSSPixels) ?CSSPixels {
	return definite_grid_track_size(node, track, basis)
}

// The definite size and track count of `template` outside its automatic
// repetition. Fixed repeat(N, ...) entries expand fully; tracks without a
// definite size contribute nothing to the size.
fn auto_repeat_template_rest(node &Node, list css.GridTrackSizeList, basis CSSPixels) (CSSPixels, int) {
	mut size := CSSPixels.new(0)
	mut count := 0
	for track in list.track_list() {
		if track.is_repeat() {
			repeat := track.repeat()
			if !repeat.is_fixed() {
				continue
			}
			inner_size, inner_count := auto_repeat_template_rest(node, repeat.grid_track_size_list(),
				basis)
			size = size.plus(inner_size.scaled(f64(repeat.repeat_count())))
			count += inner_count * int(repeat.repeat_count())
			continue
		}
		if track_size := auto_repeat_estimate_track_size(node, track, basis) {
			size = size.plus(track_size)
		}
		count++
	}
	return size, count
}

// GridFormattingContext::count_of_repeated_auto_fill_or_fit_tracks(). On a
// standalone axis with a definite size, auto-fill repeats the largest positive
// number of times that does not overflow the content box once the template's
// other definite tracks and the gaps are accounted for; otherwise once.
fn auto_repeat_count(node &Node, repeat css.GridRepeat, template css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, available_is_definite bool) int {
	list := repeat.grid_track_size_list()
	mut repeated_tracks_size := CSSPixels.new(0)
	mut repeated_track_count := 0
	for track in list.track_list() {
		// If neither sizing function is definite, the number of repetitions is one.
		size := auto_repeat_estimate_track_size(node, track, basis) or { return 1 }
		// Floor each track to 1px to avoid division by zero.
		repeated_tracks_size = repeated_tracks_size.plus(css_pixels_max(size, CSSPixels.new(1)))
		repeated_track_count++
	}
	denominator := repeated_tracks_size.plus(gap.scaled(f64(repeated_track_count)))
	if available_is_definite && denominator.raw_value() > 0 {
		rest_size, rest_count := auto_repeat_template_rest(node, template, basis)
		// The gap is added to the free space because the last track has none.
		leftover := basis.plus(gap).minus(rest_size).minus(gap.scaled(f64(rest_count)))
		count := int(leftover.raw_value() / denominator.raw_value())
		return if count > 1 { count } else { 1 }
	}
	return 1
}

fn append_explicit_grid_track(node &Node, track css.ExplicitGridTrack, template css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, available_is_definite bool, inherited_auto_fit bool, mut tracks []GridTrack) {
	if track.is_repeat() {
		repeat := track.repeat()
		repeat_count := if repeat.is_fixed() {
			int(repeat.repeat_count())
		} else {
			auto_repeat_count(node, repeat, template, basis, gap, available_is_definite)
		}
		repeated_track_is_auto_fit := inherited_auto_fit || repeat.is_auto_fit()
		for _ in 0 .. repeat_count {
			append_grid_track_list_in_template(node, repeat.grid_track_size_list(), template, basis, gap, available_is_definite, repeated_track_is_auto_fit, mut tracks)
		}
		return
	}
	if track.is_minmax() {
		minmax := track.minmax()
		mut resolved := grid_track_from_size(node, minmax.max_grid_size(), basis, available_is_definite, inherited_auto_fit)
		minimum := grid_track_from_size(node, minmax.min_grid_size(), basis, available_is_definite, inherited_auto_fit)
		maximum_available_size := if available_is_definite {
			AvailableSize.make_definite(basis)
		} else {
			AvailableSize.make_indefinite()
		}
		if minmax.max_grid_size().is_fixed(maximum_available_size) {
			resolved.fixed_max = true
			resolved.fixed_max_size = resolved.base_size
		}
		resolved.auto_min = minimum.auto_min
		resolved.minimum_intrinsic = minimum.minimum_intrinsic
		resolved.min_content_min = minimum.min_content_min
		resolved.max_content_min = minimum.max_content_min
		if minmax.max_grid_size().is_flexible_length() {
			resolved.base_size = minimum.base_size
			resolved.intrinsic = minimum.intrinsic
			resolved.auto_max = false
			tracks << resolved
			return
		}
		if !resolved.intrinsic && !minimum.intrinsic {
			resolved.growth_limit = resolved.base_size
			resolved.has_growth_limit = true
			resolved.base_size = minimum.base_size
			tracks << resolved
			return
		}
		if resolved.intrinsic {
			if !minimum.intrinsic {
				resolved.base_size = minimum.base_size
			}
		} else if minimum.intrinsic {
			// A definite max track sizing function is a growth limit, not the
			// initial base size for minmax(auto, <length>). Its automatic minimum
			// still participates in intrinsic track sizing, clamped by that limit.
			resolved.growth_limit = resolved.base_size
			resolved.has_growth_limit = true
			resolved.base_size = CSSPixels.new(0)
			resolved.intrinsic = true
		}
		tracks << resolved
		return
	}
	tracks << grid_track_from_size(node, track.grid_size(), basis, available_is_definite, inherited_auto_fit)
}

fn append_grid_track_list(node &Node, list css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, available_is_definite bool, inherited_auto_fit bool, mut tracks []GridTrack) {
	append_grid_track_list_in_template(node, list, list, basis, gap, available_is_definite, inherited_auto_fit, mut tracks)
}

fn append_grid_track_list_in_template(node &Node, list css.GridTrackSizeList, template css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, available_is_definite bool, inherited_auto_fit bool, mut tracks []GridTrack) {
	for track in list.track_list() {
		append_explicit_grid_track(node, track, template, basis, gap, available_is_definite, inherited_auto_fit, mut tracks)
	}
}

fn expanded_explicit_grid_track_count_in_template(node &Node, list css.GridTrackSizeList, template css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, available_is_definite bool) int {
	mut count := 0
	for track in list.track_list() {
		if track.is_repeat() {
			repeat := track.repeat()
			repeat_count := if repeat.is_fixed() {
				int(repeat.repeat_count())
			} else {
				auto_repeat_count(node, repeat, template, basis, gap, available_is_definite)
			}
			count += repeat_count * expanded_explicit_grid_track_count_in_template(node, repeat.grid_track_size_list(), template, basis, gap, available_is_definite)
			continue
		}
		count++
	}
	return count
}

fn expand_grid_lines(node &Node, definition css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, available_is_definite bool, mut lines [][]css.GridLineName, mut pending_names []css.GridLineName) {
	expand_grid_lines_in_template(node, definition, definition, basis, gap, available_is_definite, mut
		lines, mut pending_names)
}

fn expand_grid_lines_in_template(node &Node, definition css.GridTrackSizeList, template css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, available_is_definite bool, mut lines [][]css.GridLineName, mut pending_names []css.GridLineName) {
	for item in definition.list() {
		match item {
			css.GridLineNames {
				for line_name in item.names() {
					pending_names << line_name
				}
			}
			css.ExplicitGridTrack {
				if item.is_repeat() {
					repeat := item.repeat()
					repeat_count := if repeat.is_fixed() {
						int(repeat.repeat_count())
					} else {
						auto_repeat_count(node, repeat, template, basis, gap, available_is_definite)
					}
					for _ in 0 .. repeat_count {
						expand_grid_lines_in_template(node, repeat.grid_track_size_list(), template, basis, gap, available_is_definite, mut lines, mut pending_names)
					}
				} else {
					lines << pending_names.clone()
					pending_names.clear()
				}
			}
		}
	}
}

// GridFormattingContext::init_grid_lines() plus build_grid_areas(). Explicit
// line names and the four implicit <area>-start/end names share one line map.
fn grid_lines_for_definition(node &Node, definition css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, available_is_definite bool, areas css.GridTemplateAreas, columns bool) [][]css.GridLineName {
	mut lines := [][]css.GridLineName{}
	mut pending_names := []css.GridLineName{}
	expand_grid_lines(node, definition, basis, gap, available_is_definite, mut lines, mut pending_names)
	lines << pending_names.clone()
	required_line_count := int(if columns { areas.column_count } else { areas.row_count }) + 1
	for lines.len < required_line_count {
		lines << []css.GridLineName{}
	}
	for name, area in areas.areas {
		start := int(if columns { area.column_start } else { area.row_start })
		end := int(if columns { area.column_end } else { area.row_end })
		lines[start] << css.GridLineName{
			name: '${name}-start'
			implicit: true
		}
		lines[end] << css.GridLineName{
			name: '${name}-end'
			implicit: true
		}
	}
	return lines
}

fn count_subgrid_line_name_lists_from_index(list css.GridTrackSizeList, start_index int) int {
	mut count := 0
	items := list.list()
	for item_index in start_index .. items.len {
		item := items[item_index]
		match item {
			css.GridLineNames {
				count++
			}
			css.ExplicitGridTrack {
				if !item.is_repeat() {
					continue
				}
				repeat := item.repeat()
				repeated_count := count_subgrid_line_name_lists_from_index(repeat.grid_track_size_list(),
					0)
				count += if repeat.is_fixed() {
					repeated_count * int(repeat.repeat_count())
				} else {
					repeated_count
				}
			}
		}
	}
	return count
}

fn explicit_track_count_from_subgrid_line_name_list(list css.GridTrackSizeList) int {
	count := count_subgrid_line_name_lists_from_index(list, 0)
	return if count > 1 { count - 1 } else { 0 }
}

fn expand_subgrid_line_names(list css.GridTrackSizeList, mut lines [][]css.GridLineName, initial_line_index int) int {
	mut line_index := initial_line_index
	items := list.list()
	for item_index, item in items {
		match item {
			css.GridLineNames {
				if line_index < lines.len {
					for name in item.names() {
						lines[line_index] << name
					}
				}
				line_index++
			}
			css.ExplicitGridTrack {
				if !item.is_repeat() {
					continue
				}
				repeat := item.repeat()
				mut repeat_count := 0
				if repeat.is_fixed() {
					repeat_count = int(repeat.repeat_count())
				} else if repeat.is_auto_fill() {
					line_names_per_repeat := count_subgrid_line_name_lists_from_index(repeat.grid_track_size_list(),
						0)
					remaining := count_subgrid_line_name_lists_from_index(list, item_index + 1)
					if line_names_per_repeat > 0 && line_index < lines.len
						&& lines.len - line_index > remaining {
						repeat_count = (lines.len - line_index - remaining) / line_names_per_repeat
					}
				}
				for _ in 0 .. repeat_count {
					line_index = expand_subgrid_line_names(repeat.grid_track_size_list(), mut lines,
						line_index)
				}
			}
		}
	}
	return line_index
}

fn subgrid_lines_for_definition(definition css.GridTrackSizeList, inherited [][]css.GridLineName, track_count int) [][]css.GridLineName {
	mut lines := [][]css.GridLineName{len: track_count + 1}
	for index in 0 .. lines.len {
		if index < inherited.len {
			lines[index] = inherited[index].clone()
		}
	}
	expand_subgrid_line_names(definition, mut lines, 0)
	return lines
}

struct GridAreaLineName {
	area_name string
	is_start bool
}

struct ParentGridArea {
mut:
	row_start    ?int
	row_end      ?int
	column_start ?int
	column_end   ?int
}

fn parse_implicit_grid_area_line_name(line_name css.GridLineName) ?GridAreaLineName {
	if !line_name.implicit {
		return none
	}
	if line_name.name.ends_with('-start') {
		return GridAreaLineName{
			area_name: line_name.name[..line_name.name.len - '-start'.len]
			is_start: true
		}
	}
	if line_name.name.ends_with('-end') {
		return GridAreaLineName{
			area_name: line_name.name[..line_name.name.len - '-end'.len]
		}
	}
	return none
}

fn collect_parent_grid_areas(lines [][]css.GridLineName, columns bool, mut areas map[string]ParentGridArea) {
	for line_index, line_names in lines {
		for line_name in line_names {
			area_line_name := parse_implicit_grid_area_line_name(line_name) or { continue }
			mut area := areas[area_line_name.area_name] or { ParentGridArea{} }
			if columns {
				if area_line_name.is_start {
					if old_index := area.column_start {
						area.column_start = if line_index < old_index { line_index } else { old_index }
					} else {
						area.column_start = line_index
					}
				} else if old_index := area.column_end {
					area.column_end = if line_index > old_index { line_index } else { old_index }
				} else {
					area.column_end = line_index
				}
			} else if area_line_name.is_start {
				if old_index := area.row_start {
					area.row_start = if line_index < old_index { line_index } else { old_index }
				} else {
					area.row_start = line_index
				}
			} else if old_index := area.row_end {
				area.row_end = if line_index > old_index { line_index } else { old_index }
			} else {
				area.row_end = line_index
			}
			areas[area_line_name.area_name] = area
		}
	}
}

fn grid_ranges_overlap(first_start int, first_end int, second_start int, second_end int) bool {
	maximum_start := if first_start > second_start { first_start } else { second_start }
	minimum_end := if first_end < second_end { first_end } else { second_end }
	return maximum_start < minimum_end
}

// CSS Grid 2 subgrid area inheritance clips an overlapping parent named area
// to the child's two-dimensional span. Only explicitly assigned line names are
// copied directly; implicit area names are reconstructed at the clipped edges.
fn inherited_subgrid_line_names(parent_column_lines [][]css.GridLineName, parent_row_lines [][]css.GridLineName, placement GridItemPlacement, columns bool) [][]css.GridLineName {
	start := if columns { placement.column } else { placement.row }
	span := if columns { placement.column_span } else { placement.row_span }
	parent_lines := if columns { parent_column_lines } else { parent_row_lines }
	mut lines := [][]css.GridLineName{len: span + 1}
	for index in 0 .. lines.len {
		parent_line_index := start + index
		if parent_line_index < 0 || parent_line_index >= parent_lines.len {
			continue
		}
		for parent_line_name in parent_lines[parent_line_index] {
			if !parent_line_name.implicit {
				lines[index] << css.GridLineName{
					name: parent_line_name.name
				}
			}
		}
	}

	mut parent_areas := map[string]ParentGridArea{}
	collect_parent_grid_areas(parent_column_lines, true, mut parent_areas)
	collect_parent_grid_areas(parent_row_lines, false, mut parent_areas)
	for area_name, area in parent_areas {
		row_start := area.row_start or { continue }
		row_end := area.row_end or { continue }
		column_start := area.column_start or { continue }
		column_end := area.column_end or { continue }
		if !grid_ranges_overlap(row_start, row_end, placement.row,
			placement.row + placement.row_span)
			|| !grid_ranges_overlap(column_start, column_end, placement.column,
				placement.column + placement.column_span) {
			continue
		}
		area_start := if columns { column_start } else { row_start }
		area_end := if columns { column_end } else { row_end }
		subgrid_end := start + span
		start_line_index := (if area_start > start { area_start } else { start }) - start
		end_line_index := (if area_end < subgrid_end { area_end } else { subgrid_end }) - start
		if start_line_index >= 0 && start_line_index < lines.len {
			lines[start_line_index] << css.GridLineName{
				name: '${area_name}-start'
				implicit: true
			}
		}
		if end_line_index >= 0 && end_line_index < lines.len {
			lines[end_line_index] << css.GridLineName{
				name: '${area_name}-end'
				implicit: true
			}
		}
	}
	return lines
}

fn grid_line_name_strings(lines [][]css.GridLineName) [][]string {
	mut result := [][]string{len: lines.len}
	for index, names in lines {
		for name in names {
			result[index] << name.name
		}
	}
	return result
}

fn clamp_grid_axis_placement_to_subgrid(mut placement GridAxisPlacement, track_count int) {
	if track_count <= 0 {
		return
	}
	mut end := placement.start + placement.span
	if end <= 0 {
		placement.start = 0
		end = 1
	} else if placement.start >= track_count {
		placement.start = track_count - 1
		end = track_count
	} else {
		if placement.start < 0 {
			placement.start = 0
		}
		if end > track_count {
			end = track_count
		}
	}
	placement.span = end - placement.start
	placement.end = end
}

fn resolve_grid_axis_position_for_context(start css.GridTrackPlacement, end css.GridTrackPlacement, explicit_line_count int, lines [][]css.GridLineName, is_subgridded bool) GridAxisPlacement {
	mut placement := resolve_grid_axis_position(start, end, explicit_line_count, lines)
	if is_subgridded {
		clamp_grid_axis_placement_to_subgrid(mut placement, if lines.len > 0 {
			lines.len - 1
		} else {
			0
		})
	}
	return placement
}

fn resolve_grid_item_axis_position(item &Node, columns bool, start css.GridTrackPlacement, end css.GridTrackPlacement, explicit_line_count int, lines [][]css.GridLineName, is_subgridded bool) GridAxisPlacement {
	mut placement := resolve_grid_axis_position(start, end, explicit_line_count, lines)
	if grid_span_value(start) == none && grid_span_value(end) == none
		&& !(start.is_positioned() && end.is_positioned()) && item.display().is_grid_inside() {
		template := if columns {
			item.computed_values().grid_template_columns()
		} else {
			item.computed_values().grid_template_rows()
		}
		if template.is_subgrid() {
			placement.span = if explicit_track_count_from_subgrid_line_name_list(template) > 1 {
				explicit_track_count_from_subgrid_line_name_list(template)
			} else {
				1
			}
			placement.end = placement.start + placement.span
		}
	}
	if is_subgridded {
		clamp_grid_axis_placement_to_subgrid(mut placement, if lines.len > 0 {
			lines.len - 1
		} else {
			0
		})
	}
	return placement
}

fn resolve_grid_tracks(container &Node, list css.GridTrackSizeList, implicit_list css.GridTrackSizeList, available CSSPixels, gap CSSPixels, available_is_definite bool, implicit_before_count int, required_count int) []GridTrack {
	mut tracks := []GridTrack{}
	implicit_tracks := implicit_list.track_list()
	for index in 0 .. implicit_before_count {
		if implicit_tracks.len > 0 {
			implicit_index := (implicit_before_count - index - 1) % implicit_tracks.len
			append_explicit_grid_track(container, implicit_tracks[implicit_index], css.GridTrackSizeList{}, available, gap, available_is_definite, false, mut tracks)
		} else {
			tracks << GridTrack{
				intrinsic: true
				minimum_intrinsic: true
				auto_min: true
				auto_max: true
			}
		}
	}
	append_grid_track_list(container, list, available, gap, available_is_definite, false, mut tracks)
	mut implicit_index := 0
	for tracks.len < required_count {
		if implicit_tracks.len > 0 {
			append_explicit_grid_track(container, implicit_tracks[implicit_index % implicit_tracks.len], css.GridTrackSizeList{}, available, gap, available_is_definite, false, mut tracks)
			implicit_index++
		} else {
			tracks << GridTrack{
				intrinsic: true
				minimum_intrinsic: true
				auto_min: true
				auto_max: true
			}
		}
	}
	if tracks.len == 0 {
		tracks << GridTrack{
			flex: 1
			intrinsic: true
			minimum_intrinsic: true
			auto_min: true
		}
	}
	return tracks
}

fn resolved_grid_line_number(placement css.GridTrackPlacement, explicit_line_count int) ?int {
	if !placement.has_line_number() {
		return none
	}
	resolved := css.int_from_style_value(placement.line_number())
	if resolved == 0 {
		return none
	}
	value := int(resolved)
	return if value > 0 { value - 1 } else { explicit_line_count + value }
}

fn grid_axis_is_auto(start css.GridTrackPlacement, end css.GridTrackPlacement) bool {
	return start.is_auto_positioned() && end.is_auto_positioned()
}

fn get_nth_grid_line_index(lines [][]css.GridLineName, name string, nth_line int) ?int {
	if nth_line == 0 {
		return none
	}
	mut remaining := if nth_line < 0 { lines.len + nth_line } else { nth_line - 1 }
	for index, names in lines {
		for candidate in names {
			if candidate.name != name {
				continue
			}
			if remaining == 0 {
				return index
			}
			remaining--
		}
	}
	return none
}

fn grid_span_value(placement css.GridTrackPlacement) ?int {
	if !placement.is_span() {
		return none
	}
	resolved := css.int_from_style_value(placement.span())
	if resolved <= 0 {
		return none
	}
	return int(resolved)
}

// GridFormattingContext::resolve_grid_position(). Line indexes are zero-based;
// negative authored indexes are resolved from the end of the explicit grid.
fn resolve_grid_axis_position(start css.GridTrackPlacement, end css.GridTrackPlacement, explicit_line_count int, lines [][]css.GridLineName) GridAxisPlacement {
	mut result := GridAxisPlacement{}
	start_line_number := if start.has_line_number() {
		int(css.int_from_style_value(start.line_number()))
	} else {
		1
	}
	end_line_number := if end.has_line_number() {
		int(css.int_from_style_value(end.line_number()))
	} else {
		1
	}
	if line := resolved_grid_line_number(start, explicit_line_count) {
		result.start = line
	}
	if line := resolved_grid_line_number(end, explicit_line_count) {
		result.end = line
	}
	if span := grid_span_value(end) {
		result.span = span
	}
	if span := grid_span_value(start) {
		result.span = span
		result.start = result.end - result.span
	}
	if end.has_identifier() {
		identifier := end.identifier()
		if area_line := get_nth_grid_line_index(lines, '${identifier}-end', end_line_number) {
			result.end = area_line
		} else if named_line := get_nth_grid_line_index(lines, identifier, end_line_number) {
			result.end = named_line
		} else {
			result.end = explicit_line_count
		}
		if !start.has_line_number() {
			result.start = result.end - 1
		}
	}
	if start.has_identifier() {
		identifier := start.identifier()
		if area_line := get_nth_grid_line_index(lines, '${identifier}-start', start_line_number) {
			result.start = area_line
		} else if named_line := get_nth_grid_line_index(lines, identifier, start_line_number) {
			result.start = named_line
		} else {
			result.start = explicit_line_count
		}
	}
	if !start.is_positioned() && end.is_positioned() && !end.is_span() {
		result.start = result.end - result.span
	}
	if start.is_positioned() && end.is_positioned() {
		if result.start > result.end {
			temporary := result.start
			result.start = result.end
			result.end = temporary
		}
		if result.start != result.end {
			result.span = result.end - result.start
		} else {
			result.span = 1
			result.end = result.start + result.span
		}
	}
	if start.is_span() && end.is_span() {
		result.span = grid_span_value(start) or { 1 }
	}
	return result
}

fn ordered_grid_items(container &Node) []&Node {
	// GridFormattingContext::place_grid_items() buckets items by `order`, then
	// sorts only the distinct order keys. Keep equal-order items in document
	// order without the former O(n²) insertion into one growing array.
	mut order_item_buckets := [][]&Node{}
	mut bucket_indices := map[int]int{}
	mut keys := []int{}
	mut item_count := 0
	for child in container.children() {
		if !child.is_box() || child.is_absolutely_positioned() || can_skip_anonymous_text_run(child) {
			continue
		}
		mut mutable_child := unsafe { &Node(child) }
		mutable_child.set_grid_item(true)
		order := child.computed_values().order()
		bucket_number := bucket_indices[order] or {
			order_item_buckets << []&Node{}
			keys << order
			bucket_indices[order] = order_item_buckets.len
			order_item_buckets.len
		}
		order_item_buckets[bucket_number - 1] << child
		item_count++
	}
	keys.sort()
	mut items := []&Node{cap: item_count}
	for key in keys {
		bucket_number := bucket_indices[key] or { continue }
		for item in order_item_buckets[bucket_number - 1] {
			items << item
		}
	}
	return items
}

fn grid_cell_key(row int, column int) u64 {
	// OccupationGrid hashes a typed pair of signed coordinates. Preserve the
	// two's-complement bit patterns in separate halves so implicit negative
	// lines cannot collide, without formatting and allocating a string for
	// every placement probe.
	return (u64(u32(row)) << 32) | u64(u32(column))
}

fn grid_area_is_free(occupied map[u64]bool, row int, column int, row_span int, column_span int) bool {
	for y in row .. row + row_span {
		for x in column .. column + column_span {
			if occupied[grid_cell_key(y, x)] {
				return false
			}
		}
	}
	return true
}

fn occupy_grid_area(mut occupied map[u64]bool, placement GridItemPlacement) {
	for y in placement.row .. placement.row + placement.row_span {
		for x in placement.column .. placement.column + placement.column_span {
			occupied[grid_cell_key(y, x)] = true
		}
	}
}

fn clamp_grid_item_placement_to_subgrid(mut placement GridItemPlacement, column_track_count int, row_track_count int, subgridded_columns bool, subgridded_rows bool) {
	if subgridded_columns {
		mut column := GridAxisPlacement{
			start: placement.column
			span: placement.column_span
		}
		clamp_grid_axis_placement_to_subgrid(mut column, column_track_count)
		placement.column = column.start
		placement.column_span = column.span
	}
	if subgridded_rows {
		mut row := GridAxisPlacement{
			start: placement.row
			span: placement.row_span
		}
		clamp_grid_axis_placement_to_subgrid(mut row, row_track_count)
		placement.row = row.start
		placement.row_span = row.span
	}
}

fn place_grid_items(container &Node, column_lines [][]css.GridLineName, row_lines [][]css.GridLineName, subgridded_columns bool, subgridded_rows bool) GridPlacementResult {
	mut placements := []GridItemPlacement{}
	mut occupied := map[u64]bool{}
	items := ordered_grid_items(container)
	explicit_column_count := if column_lines.len > 0 { column_lines.len - 1 } else { 0 }
	explicit_row_count := if row_lines.len > 0 { row_lines.len - 1 } else { 0 }
	mut column_count := if explicit_column_count > 0 { explicit_column_count } else { 1 }
	mut row_count := if explicit_row_count > 0 { explicit_row_count } else { 1 }
	mut implicit_minimum_column := 0
	mut implicit_minimum_row := 0
	// CSS Grid auto-placement step 3 determines the width of the implicit grid
	// before advancing the cursor. Definite column positions can extend either
	// edge, and an auto-positioned item must always fit its largest column span.
	for item in items {
		computed := item.computed_values()
		column_axis_is_auto := grid_axis_is_auto(computed.grid_column_start(), computed.grid_column_end())
		row_axis_is_auto := grid_axis_is_auto(computed.grid_row_start(), computed.grid_row_end())
		column_position := resolve_grid_item_axis_position(item, true, computed.grid_column_start(),
			computed.grid_column_end(), column_lines.len, column_lines, subgridded_columns)
		row_position := resolve_grid_item_axis_position(item, false, computed.grid_row_start(),
			computed.grid_row_end(), row_lines.len, row_lines, subgridded_rows)
		column_span := column_position.span
		row_span := row_position.span
		column := if column_axis_is_auto { -1 } else { column_position.start }
		row := if row_axis_is_auto { -1 } else { row_position.start }
		if column >= 0 {
			end := column + column_span
			if end > column_count {
				column_count = end
			}
		} else if !column_axis_is_auto {
			if column < implicit_minimum_column {
				implicit_minimum_column = column
			}
		} else if column_span > column_count {
			column_count = column_span
		}
		if row >= 0 {
			end := row + row_span
			if end > row_count {
				row_count = end
			}
		} else if !row_axis_is_auto {
			if row < implicit_minimum_row {
				implicit_minimum_row = row
			}
		} else if row_span > row_count {
			row_count = row_span
		}
	}

	// Step 1: position items with definite positions in both axes.
	for item in items {
		computed := item.computed_values()
		if grid_axis_is_auto(computed.grid_row_start(), computed.grid_row_end())
			|| grid_axis_is_auto(computed.grid_column_start(), computed.grid_column_end()) {
			continue
		}
		column_position := resolve_grid_item_axis_position(item, true, computed.grid_column_start(),
			computed.grid_column_end(), column_lines.len, column_lines, subgridded_columns)
		row_position := resolve_grid_item_axis_position(item, false, computed.grid_row_start(),
			computed.grid_row_end(), row_lines.len, row_lines, subgridded_rows)
		column_span := column_position.span
		row_span := row_position.span
		mut placement := GridItemPlacement{
			item: item
			row: row_position.start
			column: column_position.start
			row_span: row_span
			column_span: column_span
		}
		clamp_grid_item_placement_to_subgrid(mut placement, explicit_column_count,
			explicit_row_count, subgridded_columns, subgridded_rows)
		placements << placement
		occupy_grid_area(mut occupied, placement)
	}

	// Step 2: position items locked to a definite row in the first free column.
	for item in items {
		computed := item.computed_values()
		if grid_axis_is_auto(computed.grid_row_start(), computed.grid_row_end())
			|| !grid_axis_is_auto(computed.grid_column_start(), computed.grid_column_end()) {
			continue
		}
		column_position := resolve_grid_item_axis_position(item, true, computed.grid_column_start(),
			computed.grid_column_end(), column_lines.len, column_lines, subgridded_columns)
		row_position := resolve_grid_item_axis_position(item, false, computed.grid_row_start(),
			computed.grid_row_end(), row_lines.len, row_lines, subgridded_rows)
		column_span := column_position.span
		row_span := row_position.span
		row := row_position.start
		mut column := 0
		for column < column_count
			&& !grid_area_is_free(occupied, row, column, row_span, column_span) {
			column++
		}
		if column + column_span > column_count {
			column_count = column + column_span
		}
		mut placement := GridItemPlacement{
			item: item
			row: row
			column: column
			row_span: row_span
			column_span: column_span
		}
		clamp_grid_item_placement_to_subgrid(mut placement, explicit_column_count,
			explicit_row_count, subgridded_columns, subgridded_rows)
		placements << placement
		occupy_grid_area(mut occupied, placement)
	}

	// Step 4: place every item whose row is still auto-positioned. Row flow
	// advances columns inside rows; column flow performs the transposed search.
	auto_flow := container.computed_values().grid_auto_flow()
	mut cursor_row := implicit_minimum_row
	mut cursor_column := implicit_minimum_column
	for item in items {
		computed := item.computed_values()
		if !grid_axis_is_auto(computed.grid_row_start(), computed.grid_row_end()) {
			continue
		}
		column_position := resolve_grid_item_axis_position(item, true, computed.grid_column_start(),
			computed.grid_column_end(), column_lines.len, column_lines, subgridded_columns)
		row_position := resolve_grid_item_axis_position(item, false, computed.grid_row_start(),
			computed.grid_row_end(), row_lines.len, row_lines, subgridded_rows)
		column_span := column_position.span
		row_span := row_position.span
		column_is_auto := grid_axis_is_auto(computed.grid_column_start(), computed.grid_column_end())
		if auto_flow.dense {
			cursor_column = implicit_minimum_column
			cursor_row = implicit_minimum_row
		}
		mut column := if column_is_auto {
			cursor_column
		} else {
			column_position.start
		}
		mut row := cursor_row
		if !column_is_auto {
			if !auto_flow.dense && column < cursor_column {
				row++
			}
			cursor_column = column
			for !grid_area_is_free(occupied, row, column, row_span, column_span) {
				row++
			}
			cursor_row = row
		} else if auto_flow.row {
			for column + column_span > column_count
				|| !grid_area_is_free(occupied, row, column, row_span, column_span) {
				column++
				if column >= column_count {
					column = implicit_minimum_column
					row++
				}
			}
		} else {
			for row + row_span > row_count
				|| !grid_area_is_free(occupied, row, column, row_span, column_span) {
				row++
				if row >= row_count {
					row = implicit_minimum_row
					column++
				}
			}
		}
		mut placement := GridItemPlacement{
			item: item
			row: row
			column: column
			row_span: row_span
			column_span: column_span
		}
		clamp_grid_item_placement_to_subgrid(mut placement, explicit_column_count,
			explicit_row_count, subgridded_columns, subgridded_rows)
		placements << placement
		occupy_grid_area(mut occupied, placement)
		// place_item_with_no_declared_position(): the cursor's major-axis
		// position stays at the item's start line so subsequent items keep
		// packing into the same row (or column); only the minor-axis position
		// advances past the item.
		if !column_is_auto {
			cursor_column = column
			cursor_row = row
		} else if auto_flow.row {
			cursor_column = column + column_span
			cursor_row = row
		} else {
			cursor_column = column
			cursor_row = row + row_span
		}
	}
	mut minimum_column := 0
	mut minimum_row := 0
	for placement in placements {
		if placement.column < minimum_column {
			minimum_column = placement.column
		}
		if placement.row < minimum_row {
			minimum_row = placement.row
		}
	}
	columns_before := -minimum_column
	rows_before := -minimum_row
	if columns_before > 0 || rows_before > 0 {
		for index in 0 .. placements.len {
			placements[index].column += columns_before
			placements[index].row += rows_before
		}
	}
	return GridPlacementResult{
		placements: placements
		implicit_columns_before: columns_before
		implicit_rows_before: rows_before
	}
}

fn collect_grid_track_sizing_placements(mut state LayoutState, _ &Node, placements []GridItemPlacement, column_lines [][]css.GridLineName, row_lines [][]css.GridLineName, columns bool, parent_gap CSSPixels, axis_offset int, mut result []GridItemPlacement) {
	for placement in placements {
		item := placement.item
		template := if columns {
			item.computed_values().grid_template_columns()
		} else {
			item.computed_values().grid_template_rows()
		}
		if !item.display().is_grid_inside() || !template.is_subgrid() {
			mut projected := placement
			if columns {
				projected.column += axis_offset
			} else {
				projected.row += axis_offset
			}
			result << projected
			continue
		}

		child_columns_template := item.computed_values().grid_template_columns()
		child_rows_template := item.computed_values().grid_template_rows()
		child_areas := item.computed_values().grid_template_areas()
		child_columns_subgridded := child_columns_template.is_subgrid()
		child_rows_subgridded := child_rows_template.is_subgrid()
		child_column_lines := if child_columns_subgridded {
			inherited := inherited_subgrid_line_names(column_lines, row_lines, placement, true)
			subgrid_lines_for_definition(child_columns_template, inherited, placement.column_span)
		} else {
			grid_lines_for_definition(item, child_columns_template, CSSPixels.new(0), CSSPixels.new(0),
				false, child_areas, true)
		}
		child_row_lines := if child_rows_subgridded {
			inherited := inherited_subgrid_line_names(column_lines, row_lines, placement, false)
			subgrid_lines_for_definition(child_rows_template, inherited, placement.row_span)
		} else {
			grid_lines_for_definition(item, child_rows_template, CSSPixels.new(0), CSSPixels.new(0),
				false, child_areas, false)
		}
		child_result := place_grid_items(item, child_column_lines, child_row_lines,
			child_columns_subgridded, child_rows_subgridded)
		mut child_placements := child_result.placements.clone()
		mut edge_start := if columns { placement.inline_start_extra } else { placement.block_start_extra }
		mut edge_end := if columns { placement.inline_end_extra } else { placement.block_end_extra }
		if styled := item.as_node_with_style() {
			mut item_state := state.get_mutable(styled)
			resolve_box_model_edges(styled.computed_values(), mut item_state, CSSPixels.new(0).to_double())
			edge_start = edge_start.plus(if columns {
				item_state.margin_box_left()
			} else {
				item_state.margin_box_top()
			})
			edge_end = edge_end.plus(if columns {
				item_state.margin_box_right()
			} else {
				item_state.margin_box_bottom()
			})
		}
		gap_property := if columns { css.PropertyID.column_gap } else { .row_gap }
		computed_gap := if item.computed_values().gap_value(gap_property).is_normal {
			parent_gap
		} else {
			resolve_layout_gap(item, gap_property, CSSPixels.new(0))
		}
		gap_extra := computed_gap.minus(parent_gap).divided_by_float(2)
		track_count := if columns { placement.column_span } else { placement.row_span }
		for index in 0 .. child_placements.len {
			child_start := if columns { child_placements[index].column } else { child_placements[index].row }
			child_span := if columns {
				child_placements[index].column_span
			} else {
				child_placements[index].row_span
			}
			if columns {
				if child_start == 0 {
					child_placements[index].inline_start_extra = edge_start
				} else {
					child_placements[index].inline_start_extra = gap_extra
				}
				if child_start + child_span == track_count {
					child_placements[index].inline_end_extra = edge_end
				} else {
					child_placements[index].inline_end_extra = gap_extra
				}
			} else {
				if child_start == 0 {
					child_placements[index].block_start_extra = edge_start
				} else {
					child_placements[index].block_start_extra = gap_extra
				}
				if child_start + child_span == track_count {
					child_placements[index].block_end_extra = edge_end
				} else {
					child_placements[index].block_end_extra = gap_extra
				}
			}
		}
		collect_grid_track_sizing_placements(mut state, item, child_placements, child_column_lines,
			child_row_lines, columns, parent_gap, axis_offset + if columns {
				placement.column
			} else {
				placement.row
			}, mut result)
	}
}

fn grid_track_sizing_placements(mut state LayoutState, container &Node, placements []GridItemPlacement, column_lines [][]css.GridLineName, row_lines [][]css.GridLineName, columns bool, parent_gap CSSPixels) []GridItemPlacement {
	mut result := []GridItemPlacement{}
	collect_grid_track_sizing_placements(mut state, container, placements, column_lines, row_lines,
		columns, parent_gap, 0, mut result)
	return result
}

// GridFormattingContext::initialize_gap_tracks(): the gutters on either side of
// a collapsed track collapse. Keep the gutter directly preceding each
// non-collapsed track except the first such track.
fn grid_gutter_after_track_collapses(tracks []GridTrack, index int) bool {
	if index + 1 >= tracks.len || tracks[index + 1].collapsed {
		return true
	}
	for track_index in 0 .. index + 1 {
		if !tracks[track_index].collapsed {
			return false
		}
	}
	return true
}

// The number of uncollapsed gutters after tracks first .. last-1.
fn grid_gutter_count(tracks []GridTrack, first int, last int) int {
	mut any_collapsed := false
	for track in tracks {
		if track.collapsed {
			any_collapsed = true
			break
		}
	}
	if !any_collapsed {
		return if last > first { last - first } else { 0 }
	}
	mut count := 0
	start := if first > 0 { first } else { 0 }
	end := if last < tracks.len - 1 { last } else { tracks.len - 1 }
	for index in start .. end {
		if !grid_gutter_after_track_collapses(tracks, index) {
			count++
		}
	}
	return count
}

fn grid_track_range_size(tracks []GridTrack, start int, span int, gap CSSPixels) CSSPixels {
	mut size := gap.scaled(f64(if span > 0 { grid_gutter_count(tracks, start, start + span - 1) } else { 0 }))
	for index in start .. start + span {
		if index >= 0 && index < tracks.len {
			size = size.plus(tracks[index].base_size)
		}
	}
	return size
}

fn grid_track_offset(tracks []GridTrack, index int, gap CSSPixels) CSSPixels {
	gap_count := if index <= 0 || tracks.len <= 1 {
		0
	} else if index < tracks.len {
		index
	} else {
		tracks.len - 1
	}
	mut offset := gap.scaled(f64(grid_gutter_count(tracks, 0, gap_count)))
	for track_index in 0 .. index {
		if track_index < tracks.len {
			offset = offset.plus(tracks[track_index].base_size)
		}
	}
	return offset
}

fn subgrid_axis_data_for_item(tracks []GridTrack, line_names [][]css.GridLineName, start int, span int, gap CSSPixels) GridSubgridAxisData {
	mut inherited_tracks := []GridTrack{cap: span}
	for index in 0 .. span {
		track_index := start + index
		if track_index >= 0 && track_index < tracks.len {
			inherited_tracks << tracks[track_index]
		} else {
			inherited_tracks << GridTrack{
				intrinsic: true
				minimum_intrinsic: true
				auto_min: true
				auto_max: true
			}
		}
	}
	return GridSubgridAxisData{
		tracks: inherited_tracks
		line_names: line_names
		gap: gap
	}
}

fn install_grid_item_subgrid_data(mut state LayoutState, item &Node, columns []GridTrack, rows []GridTrack, column_lines [][]css.GridLineName, row_lines [][]css.GridLineName, placement GridItemPlacement, column_gap CSSPixels, row_gap CSSPixels) {
	if !item.display().is_grid_inside() {
		return
	}
	styled := item.as_node_with_style() or { return }
	if item.computed_values().grid_template_columns().is_subgrid() {
		inherited_lines := inherited_subgrid_line_names(column_lines, row_lines, placement, true)
		state.set_subgrid_axis_data(styled, true, subgrid_axis_data_for_item(columns, inherited_lines,
			placement.column, placement.column_span, column_gap))
	}
	if item.computed_values().grid_template_rows().is_subgrid() {
		inherited_lines := inherited_subgrid_line_names(column_lines, row_lines, placement, false)
		state.set_subgrid_axis_data(styled, false, subgrid_axis_data_for_item(rows, inherited_lines,
			placement.row, placement.row_span, row_gap))
	}
}

fn apply_subgrid_gap_extra_margins(container &Node, mut item_state UsedValues, placement GridItemPlacement, columns bool, track_count int, parent_gap CSSPixels, percentage_basis CSSPixels) {
	gap_property := if columns { css.PropertyID.column_gap } else { .row_gap }
	computed_gap := if container.computed_values().gap_value(gap_property).is_normal {
		parent_gap
	} else {
		resolve_layout_gap(container, gap_property, percentage_basis)
	}
	extra := computed_gap.minus(parent_gap).divided_by_float(2)
	if extra.raw_value() == 0 {
		return
	}
	start := if columns { placement.column } else { placement.row }
	span := if columns { placement.column_span } else { placement.row_span }
	if start > 0 {
		if columns {
			item_state.margin_left = item_state.margin_left.plus(extra)
		} else {
			item_state.margin_top = item_state.margin_top.plus(extra)
		}
	}
	if start + span < track_count {
		if columns {
			item_state.margin_right = item_state.margin_right.plus(extra)
		} else {
			item_state.margin_bottom = item_state.margin_bottom.plus(extra)
		}
	}
}

fn grid_inline_content_geometry(container &Node, container_width CSSPixels, tracks []GridTrack, computed_gap CSSPixels) (CSSPixels, CSSPixels) {
	mut tracks_size := CSSPixels.new(0)
	for track in tracks {
		tracks_size = tracks_size.plus(track.base_size)
	}
	gap_count := grid_gutter_count(tracks, 0, tracks.len - 1)
	mut effective_gap := computed_gap
	if gap_count > 0 {
		total_gap_space := css_pixels_max(container_width.minus(tracks_size), CSSPixels.new(0))
		distributed_gap := match container.computed_values().justify_content() {
			.space_between { CSSPixels.from_raw(total_gap_space.raw_value() / gap_count) }
			.space_around { CSSPixels.from_raw(total_gap_space.raw_value() / (gap_count + 1)) }
			.space_evenly { CSSPixels.from_raw(total_gap_space.raw_value() / (gap_count + 2)) }
			else { CSSPixels.new(0) }
		}
		effective_gap = css_pixels_max(effective_gap, distributed_gap)
	}
	used_size := tracks_size.plus(effective_gap.scaled(f64(gap_count)))
	free_space := css_pixels_max(container_width.minus(used_size), CSSPixels.new(0))
	mut leading := match container.computed_values().justify_content() {
		.end_, .flex_end, .right {
			free_space
		}
		.center, .space_around, .space_evenly {
			CSSPixels.from_raw(free_space.raw_value() / 2)
		}
		else {
			CSSPixels.new(0)
		}
	}
	if container.computed_values().direction() == .rtl {
		match container.computed_values().justify_content() {
			.left {
				leading = free_space
			}
			.right {
				leading = CSSPixels.new(0)
			}
			else {}
		}
	}
	return leading, effective_gap
}

fn grid_block_content_geometry(container &Node, container_height CSSPixels, tracks []GridTrack, computed_gap CSSPixels) (CSSPixels, CSSPixels) {
	mut tracks_size := CSSPixels.new(0)
	for track in tracks {
		tracks_size = tracks_size.plus(track.base_size)
	}
	gap_count := grid_gutter_count(tracks, 0, tracks.len - 1)
	mut effective_gap := computed_gap
	if gap_count > 0 {
		total_gap_space := css_pixels_max(container_height.minus(tracks_size), CSSPixels.new(0))
		distributed_gap := match container.computed_values().align_content() {
			.space_between { CSSPixels.from_raw(total_gap_space.raw_value() / gap_count) }
			.space_around { CSSPixels.from_raw(total_gap_space.raw_value() / (gap_count + 1)) }
			.space_evenly { CSSPixels.from_raw(total_gap_space.raw_value() / (gap_count + 2)) }
			else { CSSPixels.new(0) }
		}
		effective_gap = css_pixels_max(effective_gap, distributed_gap)
	}
	used_size := tracks_size.plus(effective_gap.scaled(f64(gap_count)))
	free_space := css_pixels_max(container_height.minus(used_size), CSSPixels.new(0))
	leading := match container.computed_values().align_content() {
		.end_, .flex_end {
			free_space
		}
		.center, .space_around, .space_evenly {
			CSSPixels.from_raw(free_space.raw_value() / 2)
		}
		else {
			CSSPixels.new(0)
		}
	}
	return leading, effective_gap
}

fn grid_physical_column_offset(container &Node, container_width CSSPixels, tracks []GridTrack, start int, span int, gap CSSPixels, leading CSSPixels) CSSPixels {
	logical_offset := leading.plus(grid_track_offset(tracks, start, gap))
	if container.computed_values().direction() != .rtl {
		return logical_offset
	}
	area_width := grid_track_range_size(tracks, start, span, gap)
	return container_width.minus(logical_offset).minus(area_width)
}

fn distribute_grid_item_contribution_across_intrinsic_track_bases(mut tracks []GridTrack, start int, span int, gap CSSPixels, contribution CSSPixels, phase GridBaseSizeDistributionPhase) {
	current := grid_track_range_size(tracks, start, span, gap)
	mut affected_tracks := []int{}
	for index in start .. start + span {
		if index < 0 || index >= tracks.len || tracks[index].flexible
			|| tracks[index].flex > 0 {
			continue
		}
		track := tracks[index]
		affected := match phase {
			.minimum_contribution { track.minimum_intrinsic }
			.min_content_contribution { track.min_content_min || track.max_content_min }
			.max_content_contribution { track.auto_min || track.max_content_min }
		}
		if affected {
			affected_tracks << index
		}
	}
	if affected_tracks.len == 0 {
		return
	}
	mut remaining := contribution.minus(current)
	if remaining.raw_value() <= 0 {
		return
	}
	mut item_incurred_increase := []CSSPixels{len: tracks.len}
	for remaining.raw_value() > 0 {
		mut all_frozen := true
		for index in affected_tracks {
			if !tracks[index].base_size_frozen {
				all_frozen = false
				break
			}
		}
		if all_frozen {
			break
		}
		increase_per_track := CSSPixels.from_raw(if remaining.raw_value() / affected_tracks.len > 0 {
			remaining.raw_value() / affected_tracks.len
		} else {
			1
		})
		for index in affected_tracks {
			if tracks[index].base_size_frozen {
				continue
			}
			mut increase := css_pixels_min(increase_per_track, remaining)
			if tracks[index].has_growth_limit {
				maximum_increase := tracks[index].growth_limit.minus(tracks[index].base_size)
				if item_incurred_increase[index].plus(increase).raw_value() >= maximum_increase.raw_value() {
					tracks[index].base_size_frozen = true
					increase = css_pixels_max(maximum_increase.minus(item_incurred_increase[index]), CSSPixels.new(0))
				}
			}
			item_incurred_increase[index] = item_incurred_increase[index].plus(increase)
			remaining = remaining.minus(increase)
			if remaining.raw_value() <= 0 {
				break
			}
		}
	}
	if remaining.raw_value() > 0 {
		mut tracks_to_grow_beyond_limits := []int{}
		for index in affected_tracks {
			track := tracks[index]
			if (phase in [.minimum_contribution, .min_content_contribution]
				&& (track.auto_max || track.min_content_max || track.max_content_max
					|| track.fit_content_max))
				|| (phase == .max_content_contribution && track.max_content_max) {
				tracks_to_grow_beyond_limits << index
			}
		}
		if tracks_to_grow_beyond_limits.len == 0 {
			tracks_to_grow_beyond_limits = affected_tracks.clone()
		}
		increase_per_track := CSSPixels.from_raw(remaining.raw_value() / tracks_to_grow_beyond_limits.len)
		for index in tracks_to_grow_beyond_limits {
			increase := css_pixels_min(increase_per_track, remaining)
			item_incurred_increase[index] = item_incurred_increase[index].plus(increase)
			remaining = remaining.minus(increase)
		}
	}
	for index in affected_tracks {
		tracks[index].base_size = tracks[index].base_size.plus(item_incurred_increase[index])
		if tracks[index].has_growth_limit
			&& tracks[index].growth_limit.raw_value() < tracks[index].base_size.raw_value() {
			tracks[index].growth_limit = tracks[index].base_size
		}
	}
}

// GridFormattingContext::distribute_extra_space_across_spanned_tracks_growth_limit().
// The frozen and infinitely-growable bits deliberately live on GridTrack: the
// C++ algorithm carries them from the intrinsic-maximum phase into the later
// max-content phase and across items of increasing span.
fn distribute_grid_item_contribution_across_intrinsic_track_growth_limits(mut tracks []GridTrack, start int, span int, gap CSSPixels, contribution CSSPixels, phase GridGrowthLimitDistributionPhase) {
	first := if start > 0 { start } else { 0 }
	last := if start + span < tracks.len { start + span } else { tracks.len }
	if first >= last {
		return
	}
	mut affected_tracks := []int{}
	for index in first .. last {
		track := tracks[index]
		affected := match phase {
			.intrinsic_maximum {
				track.auto_max || track.min_content_max || track.max_content_max
					|| track.fit_content_max
			}
			.max_content_maximum {
				track.auto_max || track.max_content_max || track.fit_content_max
			}
		}
		if affected {
			affected_tracks << index
		}
	}
	mut item_incurred_increase := []CSSPixels{len: tracks.len}
	if affected_tracks.len > 0 {
		mut current := gap.scaled(f64(grid_gutter_count(tracks, first, last - 1)))
		for index in first .. last {
			current = current.plus(if tracks[index].has_growth_limit {
				tracks[index].growth_limit
			} else {
				tracks[index].base_size
			})
		}
		mut remaining := css_pixels_max(contribution.minus(current), CSSPixels.new(0))
		for remaining.raw_value() > 0 {
			mut all_frozen := true
			for index in affected_tracks {
				if !tracks[index].growth_limit_frozen {
					all_frozen = false
					break
				}
			}
			if all_frozen {
				break
			}
			increase_per_track := CSSPixels.from_raw(if remaining.raw_value() / affected_tracks.len > 0 {
				remaining.raw_value() / affected_tracks.len
			} else {
				1
			})
			for index in affected_tracks {
				if tracks[index].growth_limit_frozen {
					continue
				}
				mut increase := css_pixels_min(increase_per_track, remaining)
				if !tracks[index].infinitely_growable && tracks[index].has_growth_limit {
					maximum_increase := tracks[index].growth_limit.minus(tracks[index].base_size)
					if item_incurred_increase[index].plus(increase).raw_value() >= maximum_increase.raw_value() {
						tracks[index].growth_limit_frozen = true
						increase = css_pixels_max(maximum_increase.minus(item_incurred_increase[index]), CSSPixels.new(0))
					}
				}
				item_incurred_increase[index] = item_incurred_increase[index].plus(increase)
				remaining = remaining.minus(increase)
				if remaining.raw_value() <= 0 {
					break
				}
			}
		}
	}
	for index in first .. last {
		increase := item_incurred_increase[index]
		match phase {
			.intrinsic_maximum {
				if tracks[index].has_growth_limit {
					tracks[index].growth_limit = tracks[index].growth_limit.plus(increase)
				} else {
					tracks[index].growth_limit = tracks[index].base_size.plus(increase)
					tracks[index].has_growth_limit = true
					tracks[index].infinitely_growable = true
				}
			}
			.max_content_maximum {
				if tracks[index].has_growth_limit {
					tracks[index].growth_limit = tracks[index].growth_limit.plus(increase)
				} else {
					tracks[index].growth_limit = tracks[index].base_size.plus(increase)
					tracks[index].has_growth_limit = true
				}
				if tracks[index].fit_content_max && tracks[index].has_fit_content_limit {
					tracks[index].growth_limit = css_pixels_max(tracks[index].base_size, css_pixels_min(tracks[index].growth_limit, tracks[index].fit_content_limit))
				}
			}
		}
	}
}

fn grid_track_range_crosses_flexible_track(tracks []GridTrack, start int, span int) bool {
	first := if start > 0 { start } else { 0 }
	last := if start + span < tracks.len { start + span } else { tracks.len }
	for index in first .. last {
		if tracks[index].flexible || tracks[index].flex > 0 {
			return true
		}
	}
	return false
}

fn grid_track_range_crosses_intrinsic_sizing_track(tracks []GridTrack, start int, span int) bool {
	first := if start > 0 { start } else { 0 }
	last := if start + span < tracks.len { start + span } else { tracks.len }
	for index in first .. last {
		track := tracks[index]
		if track.minimum_intrinsic || track.auto_max || track.min_content_max
			|| track.max_content_max || track.fit_content_max {
			return true
		}
	}
	return false
}

fn grid_content_based_minimum_from_outer_contribution(item &Node, item_state &UsedValues, tracks []GridTrack, start int, span int, gap CSSPixels, outer_contribution CSSPixels, columns bool) CSSPixels {
	edges := if columns {
		flex_or_grid_item_outer_inline_edges(item_state)
	} else {
		flex_or_grid_item_outer_block_edges(item_state)
	}
	mut content_minimum := css_pixels_max(outer_contribution.minus(edges), CSSPixels.new(0))
	preferred := item.computed_values().size_value(if columns {
		css.PropertyID.width
	} else {
		.height
	})
	has_definite_preferred_size := if columns {
		item_state.has_definite_width()
	} else {
		item_state.has_definite_height()
	}
	if has_definite_preferred_size {
		if specified := resolve_layout_size(item, preferred, grid_track_range_size(tracks, start, span, gap)) {
			content_minimum = specified
		}
	} else if box := item.as_box() {
		if box.has_preferred_aspect_ratio() {
			opposite := item.computed_values().size_value(if columns {
				css.PropertyID.height
			} else {
				.width
			})
			if opposite.is_length() {
				if opposite_size := resolve_layout_size(item, opposite, CSSPixels.new(0)) {
					content_minimum = if columns {
						intrinsic_content_width_from_aspect_ratio(box, item_state, opposite_size)
					} else {
						intrinsic_content_height_from_aspect_ratio(box, item_state, opposite_size)
					}
				}
			}
		}
	}
	first := if start > 0 { start } else { 0 }
	last := if start + span < tracks.len { start + span } else { tracks.len }
	mut all_maximums_are_fixed := first < last
	mut fixed_maximum_sum := CSSPixels.new(0)
	for index in first .. last {
		if !tracks[index].fixed_max {
			all_maximums_are_fixed = false
			break
		}
		fixed_maximum_sum = fixed_maximum_sum.plus(tracks[index].fixed_max_size)
	}
	if all_maximums_are_fixed {
		content_minimum = css_pixels_min(content_minimum, fixed_maximum_sum)
	}
	maximum := item.computed_values().size_value(if columns {
		css.PropertyID.max_width
	} else {
		.max_height
	})
	if !maximum.contains_percentage() {
		if maximum_size := resolve_layout_size(item, maximum, CSSPixels.new(0)) {
			content_minimum = css_pixels_min(content_minimum, maximum_size)
		}
	}
	if item.is_replaced_box()
		&& (preferred.contains_percentage() || maximum.contains_percentage()) {
		content_minimum = CSSPixels.new(0)
	}
	return content_minimum.plus(edges)
}

fn finalize_grid_track_growth_limits(mut tracks []GridTrack) {
	for index in 0 .. tracks.len {
		if !tracks[index].has_growth_limit {
			tracks[index].growth_limit = tracks[index].base_size
			tracks[index].has_growth_limit = true
		}
	}
}

// GridFormattingContext::calculate_minimum_contribution(), column dimension.
// In particular, an auto-sized item spanning a flexible track has the usual
// zero automatic minimum unless it spans exactly one auto-minimum track.
fn grid_item_minimum_outer_inline_contribution(mut state LayoutState, item &Node, tracks []GridTrack, start int, span int, gap CSSPixels) CSSPixels {
	preferred := item.computed_values().size_value(.width)
	if !preferred.is_auto() && !preferred.contains_percentage() && !preferred.is_fit_content() {
		return grid_intrinsic_outer_width_contribution(mut state, item, .min_content)
	}
	minimum := item.computed_values().size_value(.min_width)
	if minimum.is_min_content() {
		return grid_intrinsic_outer_width_contribution(mut state, item, .min_content)
	}
	if minimum.is_max_content() {
		return grid_intrinsic_outer_width_contribution(mut state, item, .max_content)
	}
	styled := item.as_node_with_style() or {
		return grid_intrinsic_outer_width_contribution(mut state, item, .min_content)
	}
	mut item_state := state.get_mutable(styled)
	containing_width := if containing := item_state.containing_block_used_values() {
		containing.content_width()
	} else {
		CSSPixels.new(0)
	}
	// Track sizing can reach an item's definite minimum before any intrinsic
	// contribution has resolved its box model. Include the complete outer size
	// even on that first pass.
	resolve_box_model_edges(styled.computed_values(), mut item_state, containing_width.to_double())
	edges := flex_or_grid_item_outer_inline_edges(item_state)
	if minimum.is_auto() {
		first := if start > 0 { start } else { 0 }
		last := if start + span < tracks.len { start + span } else { tracks.len }
		mut spans_auto_track := false
		mut spans_flexible_track := false
		for index in first .. last {
			spans_auto_track = spans_auto_track || tracks[index].auto_min
			spans_flexible_track = spans_flexible_track || tracks[index].flexible
				|| tracks[index].flex > 0
		}
		if spans_auto_track && !flex_item_is_scroll_container(item)
			&& (span == 1 || !spans_flexible_track) {
			min_content_contribution := grid_intrinsic_outer_width_contribution(mut state, item, .min_content)
			return grid_content_based_minimum_from_outer_contribution(item, item_state, tracks, start, span, gap, min_content_contribution, true)
		}
		return edges
	}
	// Track sizing has no definite grid-area width yet. Resolve a cyclic
	// percentage minimum through the item's intrinsic available space (zero),
	// not through the already definite grid container width. The completed area
	// becomes the percentage basis when the item is laid out below.
	if resolved := resolve_layout_content_size(item, minimum, CSSPixels.new(0), item_state,
		true) {
		return resolved.plus(edges)
	}
	return grid_intrinsic_outer_width_contribution(mut state, item, .min_content)
}

// GridFormattingContext::increase_sizes_to_accommodate_spanning_items_crossing_flexible_tracks().
// Accumulate the largest item contribution for each affected flexible track,
// after removing space already supplied by fixed tracks and gutters. C++ does
// this for all items together so overlapping items do not cumulatively grow a
// track; only the largest contribution assigned to that track is applied.
fn increase_grid_flexible_tracks_for_spanning_items(mut state LayoutState, container &Node, container_state &UsedValues, mut tracks []GridTrack, placements []GridItemPlacement, columns bool, available_size AvailableSize, gap CSSPixels, percentage_basis CSSPixels, available_height_is_definite bool) {
	for phase in [GridFlexibleMinimumPhase.intrinsic, .min_content, .limited_max_content,
		.max_content] {
		if phase == .limited_max_content && !available_size.is_max_content() {
			continue
		}
		mut track_contributions := []CSSPixels{len: tracks.len}
		for placement in placements {
			start := if columns { placement.column } else { placement.row }
			span := if columns { placement.column_span } else { placement.row_span }
			first := if start > 0 { start } else { 0 }
			last := if start + span < tracks.len { start + span } else { tracks.len }
			if first >= last {
				continue
			}
			mut total_flex := 0.0
			mut affected_track_count := 0
			mut non_flexible_space := gap.scaled(f64(grid_gutter_count(tracks, first, last - 1)))
			for index in first .. last {
				track := tracks[index]
				dominated := grid_flexible_minimum_phase_dominates(track, phase, columns, available_size)
				if (track.flexible || track.flex > 0) && dominated {
					total_flex += track.flex
					affected_track_count++
				} else {
					non_flexible_space = non_flexible_space.plus(track.base_size)
				}
			}
			if affected_track_count == 0 {
				continue
			}
			// Intrinsic probes can lay out an entire nested grid. Only measure the
			// contributions consumed by this phase; computing all three eagerly
			// repeats that work even when the result cannot affect any track.
			needs_minimum := phase in [.intrinsic, .limited_max_content]
			needs_min_content := phase == .min_content || (phase == .intrinsic
				&& (available_size.is_max_content() || (!columns && available_size.is_min_content())))
			needs_max_content := phase == .max_content || (phase == .limited_max_content
				&& !(total_flex == 0 && flex_item_is_scroll_container(placement.item)))
			minimum_contribution := (if !needs_minimum {
				CSSPixels.new(0)
			} else if columns {
				grid_item_minimum_outer_inline_contribution(mut state, placement.item, tracks, start, span, gap)
			} else {
				styled := placement.item.as_node_with_style() or { continue }
				item_state := state.get(styled)
				grid_item_minimum_outer_block_contribution(mut state, placement.item, item_state, tracks, start, span, available_height_is_definite, percentage_basis, gap)
			}).plus(placement.sizing_extra(columns))
			spanned_track_size := grid_track_range_size(tracks, start, span, gap)
			min_content_contribution := (if !needs_min_content {
				CSSPixels.new(0)
			} else if columns {
				grid_intrinsic_outer_width_contribution(mut state, placement.item, .min_content)
			} else {
				styled := placement.item.as_node_with_style() or { continue }
				item_state := state.get(styled)
				grid_item_outer_block_content_contribution(mut state, placement.item, item_state, .min_content, available_height_is_definite, percentage_basis, spanned_track_size)
			}).plus(placement.sizing_extra(columns))
			max_content_contribution := (if !needs_max_content {
				CSSPixels.new(0)
			} else if columns {
				grid_intrinsic_outer_width_contribution(mut state, placement.item, .max_content)
			} else {
				styled := placement.item.as_node_with_style() or { continue }
				item_state := state.get(styled)
				grid_item_outer_block_content_contribution(mut state, placement.item, item_state, .max_content, available_height_is_definite, percentage_basis, spanned_track_size)
			}).plus(placement.sizing_extra(columns))
			mut item_contribution := match phase {
				.intrinsic {
					if available_size.is_max_content()
						|| (!columns && available_size.is_min_content()) {
						grid_limited_content_contribution(state, container, container_state, available_size, columns, tracks, start, span, min_content_contribution, minimum_contribution)
					} else {
						minimum_contribution
					}
				}
				.min_content { min_content_contribution }
				.limited_max_content {
					if total_flex == 0 && flex_item_is_scroll_container(placement.item) {
						minimum_contribution
					} else {
						grid_limited_content_contribution(state, container, container_state, available_size, columns, tracks, start, span, max_content_contribution, minimum_contribution)
					}
				}
				.max_content { max_content_contribution }
			}
			item_contribution = css_pixels_max(item_contribution.minus(non_flexible_space), CSSPixels.new(0))
			for index in first .. last {
				track := tracks[index]
				dominated := grid_flexible_minimum_phase_dominates(track, phase, columns, available_size)
				if !(track.flexible || track.flex > 0) || !dominated {
					continue
				}
				contribution := if total_flex > 0 {
					CSSPixels.nearest_value_for(item_contribution.to_double() * (track.flex / total_flex))
				} else {
					CSSPixels.from_raw(item_contribution.raw_value() / affected_track_count)
				}
				track_contributions[index] = css_pixels_max(track_contributions[index], contribution)
			}
		}
		for index in 0 .. tracks.len {
			if track_contributions[index].raw_value() > tracks[index].base_size.raw_value() {
				tracks[index].base_size = track_contributions[index]
			}
			if tracks[index].has_growth_limit
				&& tracks[index].growth_limit.raw_value() < tracks[index].base_size.raw_value() {
				tracks[index].growth_limit = tracks[index].base_size
			}
		}
	}
}

// collapse_auto_fit_tracks_if_needed(). C++ asks the occupation grid whether the track's
// *first* cell is taken - is_occupied(track_index, 0) for a column, is_occupied(0,
// track_index) for a row - rather than scanning the whole track for an item. An item further
// along the track therefore does not keep it alive: the only item in column 1 sitting at
// `grid-row: 2` still leaves that column collapsed.
fn collapse_empty_auto_fit_tracks(mut tracks []GridTrack, placements []GridItemPlacement, columns bool) {
	for track_index in 0 .. tracks.len {
		if !tracks[track_index].auto_fit {
			continue
		}
		mut occupied := false
		for placement in placements {
			start := if columns { placement.column } else { placement.row }
			span := if columns { placement.column_span } else { placement.row_span }
			cross_start := if columns { placement.row } else { placement.column }
			cross_span := if columns { placement.row_span } else { placement.column_span }
			if track_index >= start && track_index < start + span && cross_start <= 0
				&& cross_start + cross_span > 0 {
				occupied = true
				break
			}
		}
		if !occupied {
			tracks[track_index].collapsed = true
			tracks[track_index].base_size = CSSPixels.new(0)
			tracks[track_index].flex = 0
			tracks[track_index].intrinsic = false
			tracks[track_index].minimum_intrinsic = false
			tracks[track_index].auto_min = false
			tracks[track_index].min_content_min = false
			tracks[track_index].max_content_min = false
			tracks[track_index].auto_max = false
			tracks[track_index].min_content_max = false
		}
	}
}

fn stretch_auto_grid_tracks(mut tracks []GridTrack, free_space CSSPixels) {
	if free_space.raw_value() <= 0 {
		return
	}
	mut count := 0
	for track in tracks {
		if track.auto_max {
			count++
		}
	}
	if count == 0 {
		return
	}
	addition := CSSPixels.from_raw(free_space.raw_value() / count)
	for index in 0 .. tracks.len {
		if tracks[index].auto_max {
			tracks[index].base_size = tracks[index].base_size.plus(addition)
		}
	}
}

fn grow_grid_tracks_to_limits(mut tracks []GridTrack, free_space CSSPixels) {
	mut remaining := free_space
	for remaining.raw_value() > 0 {
		mut growable_count := 0
		for track in tracks {
			if !track.base_size_frozen && track.has_growth_limit
				&& track.base_size.raw_value() < track.growth_limit.raw_value() {
				growable_count++
			}
		}
		if growable_count == 0 {
			return
		}
		share := CSSPixels.from_raw(remaining.raw_value() / growable_count)
		if share.raw_value() == 0 {
			return
		}
		mut distributed := CSSPixels.new(0)
		for index in 0 .. tracks.len {
			if tracks[index].base_size_frozen || !tracks[index].has_growth_limit
				|| tracks[index].base_size.raw_value() >= tracks[index].growth_limit.raw_value() {
				continue
			}
			growth := css_pixels_min(share, tracks[index].growth_limit.minus(tracks[index].base_size))
			tracks[index].base_size = tracks[index].base_size.plus(growth)
			distributed = distributed.plus(growth)
		}
		if distributed.raw_value() <= 0 {
			return
		}
		remaining = remaining.minus(distributed)
	}
}

fn grid_track_base_size_sum(tracks []GridTrack, gap CSSPixels) CSSPixels {
	mut total := gap.scaled(f64(grid_gutter_count(tracks, 0, tracks.len - 1)))
	for track in tracks {
		total = total.plus(track.base_size)
	}
	return total
}

// GridFormattingContext::maximize_tracks_using_available_size() and
// maximize_tracks(). Max- and indefinite-content space is infinite for this
// step, while min-content space is zero. If maximization would exceed a
// definite grid-container maximum, LibWeb restores the pre-maximization bases
// and repeats using that maximum as the available grid space.
fn maximize_grid_tracks(mut tracks []GridTrack, available_size AvailableSize, gap CSSPixels, maximum_size ?CSSPixels) {
	mut saved_base_sizes := []CSSPixels{cap: tracks.len}
	for track in tracks {
		saved_base_sizes << track.base_size
	}
	free_space := if available_size.is_max_content() || available_size.is_indefinite() {
		CSSPixels.max()
	} else if available_size.is_min_content() {
		CSSPixels.new(0)
	} else {
		available_size.to_px_or_zero().minus(grid_track_base_size_sum(tracks, gap))
	}
	grow_grid_tracks_to_limits(mut tracks, free_space)

	if maximum := maximum_size {
		// Match LibWeb: this comparison sums real tracks only; gutters enter the
		// repeated free-space calculation below.
		mut maximized_inner_size := CSSPixels.new(0)
		for track in tracks {
			maximized_inner_size = maximized_inner_size.plus(track.base_size)
		}
		if maximized_inner_size.raw_value() > maximum.raw_value() {
			for index in 0 .. tracks.len {
				tracks[index].base_size = saved_base_sizes[index]
			}
			grow_grid_tracks_to_limits(mut tracks, maximum.minus(grid_track_base_size_sum(tracks, gap)))
		}
	}
}

// GridFormattingContext::expand_flexible_tracks(), definite-space branch.
// Find the largest fr size that fits without shrinking any flexible track
// below the base size established by intrinsic track sizing.
fn expand_flexible_grid_tracks(mut tracks []GridTrack, available_size CSSPixels, gap CSSPixels) {
	mut has_flexible_track := false
	for track in tracks {
		if track.flex > 0 {
			has_flexible_track = true
			break
		}
	}
	if !has_flexible_track {
		return
	}
	mut treated_as_inflexible := []bool{len: tracks.len}
	for {
		mut leftover_space := available_size.minus(gap.scaled(f64(grid_gutter_count(tracks, 0,
			tracks.len - 1))))
		// C++ keeps the hypothetical fr size as an exact CSSPixelFraction and only lands on
		// a pixel value when it is multiplied by a track's flex factor, where the fixed-point
		// division truncates. Computing it in f64 and rounding to the nearest 1/64 instead
		// puts `1fr 2fr` in 300px with a 10px gap one subpixel out.
		mut flex_factor_sum := CSSPixels.new(0)
		for index, track in tracks {
			if treated_as_inflexible[index] || track.flex <= 0 {
				leftover_space = leftover_space.minus(track.base_size)
			} else {
				flex_factor_sum = flex_factor_sum.plus(CSSPixels.nearest_value_for(track.flex))
			}
		}
		if flex_factor_sum.raw_value() < CSSPixels.new(1).raw_value() {
			flex_factor_sum = CSSPixels.new(1)
		}
		flex_fraction := leftover_space.divided_by(flex_factor_sum)
		mut need_to_restart := false
		for index, track in tracks {
			if treated_as_inflexible[index] || track.flex <= 0 {
				continue
			}
			scaled_fraction := CSSPixels.nearest_value_for(track.flex).times_fraction(flex_fraction)
			if scaled_fraction.raw_value() < track.base_size.raw_value() {
				treated_as_inflexible[index] = true
				need_to_restart = true
			}
		}
		if need_to_restart {
			continue
		}
		for index in 0 .. tracks.len {
			if tracks[index].flex <= 0 {
				continue
			}
			scaled_fraction := CSSPixels.nearest_value_for(tracks[index].flex).times_fraction(flex_fraction)
			if scaled_fraction.raw_value() > tracks[index].base_size.raw_value() {
				tracks[index].base_size = scaled_fraction
			}
		}
		return
	}
}

// GridFormattingContext::expand_flexible_tracks(), indefinite-space branch:
// "find the size of an fr" for a track range crossed by an item's
// max-content contribution. Fixed tracks and gutters consume space first;
// flexible tracks whose base size is larger than their tentative share are
// treated as inflexible and the calculation is restarted.
fn grid_flex_fraction_for_range(tracks []GridTrack, start int, span int, space_to_fill CSSPixels, gap CSSPixels) CSSPixelFraction {
	first := if start > 0 { start } else { 0 }
	last := if start + span < tracks.len { start + span } else { tracks.len }
	if first >= last {
		return CSSPixels.new(0).divided_by(CSSPixels.new(1))
	}
	mut treated_as_inflexible := []bool{len: tracks.len}
	for {
		mut leftover_space := space_to_fill.minus(gap.scaled(f64(grid_gutter_count(tracks, first,
			last - 1))))
		mut flex_factor_sum := CSSPixels.new(0)
		for index in first .. last {
			track := tracks[index]
			if treated_as_inflexible[index] || track.flex <= 0 {
				leftover_space = leftover_space.minus(track.base_size)
			} else {
				flex_factor_sum = flex_factor_sum.plus(CSSPixels.nearest_value_for(track.flex))
			}
		}
		if flex_factor_sum.raw_value() < CSSPixels.new(1).raw_value() {
			flex_factor_sum = CSSPixels.new(1)
		}
		flex_fraction := leftover_space.divided_by(flex_factor_sum)
		mut need_to_restart := false
		for index in first .. last {
			track := tracks[index]
			if treated_as_inflexible[index] || track.flex <= 0 {
				continue
			}
			if CSSPixels.nearest_value_for(track.flex).times_fraction(flex_fraction).raw_value() < track.base_size.raw_value() {
				treated_as_inflexible[index] = true
				need_to_restart = true
			}
		}
		if !need_to_restart {
			return flex_fraction
		}
	}
	return CSSPixels.new(0).divided_by(CSSPixels.new(1))
}

fn grid_item_preferred_block_size_behaves_as_auto(item &Node, item_state &UsedValues, available_height_is_definite bool) bool {
	preferred := item.computed_values().size_value(.height)
	if preferred.is_auto() {
		if box := item.as_box() {
			if _ := box.preferred_aspect_ratio() {
				return !item_state.has_definite_width()
			}
		}
		return true
	}
	// During track sizing a non-replaced item's percentage preferred block
	// size is cyclic in this axis, even when the grid container itself has a
	// definite height. It contributes as the property's initial auto value;
	// the percentage is resolved against the finished grid area only later.
	if preferred.contains_percentage() && (!item.is_replaced_box()
		|| !available_height_is_definite) {
		return true
	}
	return false
}

// GridFormattingContext::calculate_min_content_contribution() and
// calculate_max_content_contribution(), row dimension. Row contributions are
// measured from the item's laid-out inline size; using its previous margin-box
// height for every phase loses preferred-size, fit-content, and automatic-size
// distinctions made by the C++ track sizing algorithm.
fn grid_item_outer_block_content_contribution(mut state LayoutState, item &Node, item_state &UsedValues, constraint SizeConstraint, available_height_is_definite bool, percentage_basis CSSPixels, spanned_track_size CSSPixels) CSSPixels {
	box := item.as_box() or { return CSSPixels.new(0) }
	edges := flex_or_grid_item_outer_block_edges(item_state)
	preferred := item.computed_values().size_value(.height)
	preferred_behaves_as_auto := grid_item_preferred_block_size_behaves_as_auto(item, item_state, available_height_is_definite)
	mut inner := CSSPixels.new(0)
	if preferred_behaves_as_auto || (constraint == .max_content && preferred.is_fit_content()) {
		inner = if constraint == .min_content {
			calculate_min_content_height(mut state, box, item_state.content_width())
		} else {
			calculate_fit_content_height(mut state, box, item_state.content_width(), if available_height_is_definite {
				AvailableSize.make_definite(percentage_basis)
			} else {
				AvailableSize.make_indefinite()
			})
		}
	} else if preferred.is_min_content() {
		inner = calculate_min_content_height(mut state, box, item_state.content_width())
	} else if preferred.is_max_content() {
		inner = calculate_max_content_height(mut state, box, item_state.content_width())
	} else if preferred.is_fit_content() {
		inner = calculate_fit_content_height(mut state, box, item_state.content_width(), if available_height_is_definite {
			AvailableSize.make_definite(percentage_basis)
		} else {
			AvailableSize.make_indefinite()
		})
	} else if preferred.is_auto() {
		if box.has_preferred_aspect_ratio() {
			inner = intrinsic_content_height_from_aspect_ratio(box, item_state,
				item_state.content_width())
		} else {
			inner = item_state.content_height()
		}
	} else {
		basis := if constraint == .max_content { spanned_track_size } else { percentage_basis }
		inner = resolve_layout_content_size(item, preferred, basis, item_state, false) or {
			item_state.content_height()
		}
	}
	mut contribution := inner.plus(edges)
	maximum := item.computed_values().size_value(.max_height)
	if !maximum.is_none() && !(maximum.contains_percentage() && !available_height_is_definite) {
		if maximum_size := resolve_layout_size(item, maximum, percentage_basis) {
			contribution = css_pixels_min(contribution, maximum_size)
		}
	}
	return contribution
}

fn grid_item_minimum_outer_block_contribution(mut state LayoutState, item &Node, item_state &UsedValues, tracks []GridTrack, start int, span int, available_height_is_definite bool, percentage_basis CSSPixels, gap CSSPixels) CSSPixels {
	spanned_track_size := grid_track_range_size(tracks, start, span, gap)
	if !grid_item_preferred_block_size_behaves_as_auto(item, item_state, available_height_is_definite) {
		return grid_item_outer_block_content_contribution(mut state, item, item_state, .min_content, available_height_is_definite, percentage_basis, spanned_track_size)
	}
	minimum := item.computed_values().size_value(.min_height)
	if minimum.is_min_content() {
		return grid_item_outer_block_content_contribution(mut state, item, item_state, .min_content, available_height_is_definite, percentage_basis, spanned_track_size)
	}
	if minimum.is_max_content() {
		return grid_item_outer_block_content_contribution(mut state, item, item_state, .max_content, available_height_is_definite, percentage_basis, spanned_track_size)
	}
	edges := flex_or_grid_item_outer_block_edges(item_state)
	if minimum.is_auto() {
		first := if start > 0 { start } else { 0 }
		last := if start + span < tracks.len { start + span } else { tracks.len }
		mut spans_auto_track := false
		mut spans_flexible_track := false
		for index in first .. last {
			spans_auto_track = spans_auto_track || tracks[index].auto_min
			spans_flexible_track = spans_flexible_track || tracks[index].flexible
				|| tracks[index].flex > 0
		}
		if spans_auto_track && !flex_item_is_scroll_container(item)
			&& (span == 1 || !spans_flexible_track) {
			min_content_contribution := grid_item_outer_block_content_contribution(mut state, item, item_state, .min_content, available_height_is_definite, percentage_basis, spanned_track_size)
			return grid_content_based_minimum_from_outer_contribution(item, item_state, tracks, start, span, gap, min_content_contribution, false)
		}
		return edges
	}
	if resolved := resolve_layout_content_size(item, minimum, percentage_basis, item_state, false) {
		return resolved.plus(edges)
	}
	return grid_item_outer_block_content_contribution(mut state, item, item_state, .min_content, available_height_is_definite, percentage_basis, spanned_track_size)
}

fn grid_should_treat_max_height_as_none(state &LayoutState, container &Node, available_height AvailableSize) bool {
	maximum := container.computed_values().size_value(.max_height)
	if maximum.is_none() {
		return true
	}
	if maximum.contains_percentage() {
		if available_height.is_min_content() {
			return false
		}
		containing := container.containing_block() or { return true }
		containing_styled := unsafe { &Node(containing) }.as_node_with_style() or { return true }
		containing_values := state.try_get(containing_styled) or { return true }
		if !containing_values.has_definite_height() {
			return true
		}
	}
	if maximum.is_fit_content() && available_height.is_intrinsic_sizing_constraint() {
		return true
	}
	if maximum.is_max_content() && available_height.is_max_content() {
		return true
	}
	if maximum.is_min_content() && available_height.is_min_content() {
		return true
	}
	return false
}

// GridFormattingContext::calculate_fixed_max_track_size_limit(). Fixed and
// resolvable fit-content() maxima limit intrinsic contributions only when every
// spanned track supplies such a limit.
fn grid_fixed_max_track_size_limit(tracks []GridTrack, start int, span int) ?CSSPixels {
	first := if start > 0 { start } else { 0 }
	last := if start + span < tracks.len { start + span } else { tracks.len }
	if first >= last || last - first != span {
		return none
	}
	mut result := CSSPixels.new(0)
	for index in first .. last {
		track := tracks[index]
		if track.fixed_max {
			result = result.plus(track.fixed_max_size)
		} else if track.fit_content_max && track.has_fit_content_limit {
			result = result.plus(track.fit_content_limit)
		} else {
			return none
		}
	}
	return result
}

// GridFormattingContext::calculate_limited_{min,max}_content_contribution().
fn grid_limited_content_contribution(state &LayoutState, container &Node, container_state &UsedValues, available_size AvailableSize, columns bool, tracks []GridTrack, start int, span int, contribution CSSPixels, minimum_contribution CSSPixels) CSSPixels {
	if contribution.raw_value() < minimum_contribution.raw_value() {
		return minimum_contribution
	}
	if fixed_maximum := grid_fixed_max_track_size_limit(tracks, start, span) {
		return css_pixels_max(css_pixels_min(contribution, fixed_maximum), minimum_contribution)
	}
	maximum_is_none := if columns {
		should_treat_max_width_as_none(state, container, available_size)
	} else {
		grid_should_treat_max_height_as_none(state, container, available_size)
	}
	if maximum_is_none {
		return contribution
	}
	maximum := container.computed_values().size_value(if columns {
		css.PropertyID.max_width
	} else {
		.max_height
	})
	if maximum_size := resolve_layout_content_size(container, maximum, available_size.to_px_or_zero(), container_state, columns) {
		return css_pixels_min(contribution, maximum_size)
	}
	return contribution
}

// GridFormattingContext::calculate_min_content_contribution(). A scroll
// container whose preferred inline size behaves as auto contributes zero
// content in the column dimension; its box-model edges still participate.
// This is intentionally column-only: upstream retains the content height of
// scroll containers for row min-content sizing.
fn grid_intrinsic_outer_width_contribution(mut state LayoutState, item &Node, constraint SizeConstraint) CSSPixels {
	box := item.as_box() or { return CSSPixels.new(0) }
	preferred := item.computed_values().size_value(.width)
	preferred_behaves_as_auto := preferred.is_auto() || preferred.contains_percentage()
	styled := item.as_node_with_style() or { return CSSPixels.new(0) }
	mut item_state := state.get_mutable(styled)
	containing_width := if containing := item_state.containing_block_used_values() {
		containing.content_width()
	} else {
		CSSPixels.new(0)
	}
	resolve_box_model_edges(styled.computed_values(), mut item_state, containing_width.to_double())
	edges := flex_or_grid_item_outer_inline_edges(item_state)

	// Grid's min-/max-content contributions are the item's outer size when it is
	// sized under that intrinsic constraint. The item's minimum size is handled
	// separately by calculate_minimum_contribution(); baking min-width into this
	// measurement applies it twice, and cyclic percentage minimums can then grow
	// an intrinsic track from the grid container's already-resolved width.
	mut inner := CSSPixels.new(0)
	if constraint == .min_content && preferred_behaves_as_auto
		&& flex_item_is_scroll_container(item) {
		// Scroll containers contribute no content to a column min-content size.
	} else if preferred_behaves_as_auto {
		inner = if constraint == .min_content {
			calculate_min_content_width(mut state, box)
		} else {
			calculate_max_content_width(mut state, box)
		}
	} else if preferred.is_fit_content() {
		inner = calculate_fit_content_width(mut state, box,
			AvailableSize.make_definite(containing_width))
	} else if preferred.is_min_content() {
		inner = calculate_min_content_width(mut state, box)
	} else if preferred.is_max_content() {
		inner = calculate_max_content_width(mut state, box)
	} else {
		inner = resolve_layout_content_size(item, preferred, containing_width, item_state,
			true) or {
				if constraint == .min_content {
					calculate_min_content_width(mut state, box)
				} else {
					calculate_max_content_width(mut state, box)
				}
			}
	}

	// A cyclic percentage maximum behaves as none for an intrinsic contribution.
	maximum := item.computed_values().size_value(.max_width)
	if !maximum.contains_percentage() && !should_treat_max_width_as_none(state, item,
		if constraint == .min_content { AvailableSize.make_min_content() } else { AvailableSize.make_max_content() }) {
		if maximum_size := resolve_layout_content_size(item, maximum, CSSPixels.new(0),
			item_state, true) {
			inner = css_pixels_min(inner, maximum_size)
		}
	}
	return inner.plus(edges)
}

fn run_grid_formatting_context(mut state LayoutState, container &Node, mut container_state UsedValues, layout_mode LayoutMode, available_space AvailableSpace) FormattingContextResult {
	// A resolved block size can be reused during intrinsic measurement. An
	// indefinite one still needs row sizing: a nested grid's auto height is
	// part of its block parent's contribution to an ancestor grid row.
	if layout_mode == .intrinsic_sizing
		&& !available_space.width.is_intrinsic_sizing_constraint()
		&& available_space.height.is_definite() {
		return FormattingContextResult{
			automatic_content_width: container_state.content_width()
			automatic_content_height: container_state.content_height()
		}
	}
	width_is_intrinsic := available_space.width.is_intrinsic_sizing_constraint()
	container_width := if width_is_intrinsic {
		CSSPixels.new(0)
	} else {
		container_state.content_width()
	}
	// A parent may rerun an auto-height grid with a definite available block
	// size after min-height clamps its used size. That constraint participates
	// in align-content/auto-track stretching without making percentage row
	// sizes definite (the container's computed height is still auto).
	grid_alignment_height := if container_state.has_definite_height() {
		?CSSPixels(container_state.content_height())
	} else if available_space.height.is_definite() {
		?CSSPixels(available_space.height.to_px_or_zero())
	} else {
		?CSSPixels(none)
	}
	template_columns := container.computed_values().grid_template_columns()
	template_rows := container.computed_values().grid_template_rows()
	container_styled := container.as_node_with_style() or { panic('grid container has no style') }
	inherited_columns := state.subgrid_axis_data(container_styled, true)
	inherited_rows := state.subgrid_axis_data(container_styled, false)
	subgridded_columns := template_columns.is_subgrid() && inherited_columns != none
	subgridded_rows := template_rows.is_subgrid() && inherited_rows != none
	// Subgridded axes use their parent's gutter. Standalone axes resolve each
	// percentage gutter against the available size in its own dimension.
	column_gap := if data := inherited_columns {
		if subgridded_columns { data.gap } else { resolve_layout_gap(container, .column_gap,
			available_space.width.to_px_or_zero()) }
	} else {
		resolve_layout_gap(container, .column_gap, available_space.width.to_px_or_zero())
	}
	row_gap := if data := inherited_rows {
		if subgridded_rows { data.gap } else { resolve_layout_gap(container, .row_gap,
			available_space.height.to_px_or_zero()) }
	} else {
		resolve_layout_gap(container, .row_gap, available_space.height.to_px_or_zero())
	}
	row_basis := if container_state.has_definite_height() {
		container_state.content_height()
	} else {
		CSSPixels.new(0)
	}
	areas := container.computed_values().grid_template_areas()
	column_lines := if data := inherited_columns {
		if subgridded_columns {
			subgrid_lines_for_definition(template_columns, data.line_names, data.tracks.len)
		} else {
			grid_lines_for_definition(container, template_columns, container_width, column_gap,
				true, areas, true)
		}
	} else {
		if template_columns.is_subgrid() {
			[][]css.GridLineName{len: 1}
		} else {
			grid_lines_for_definition(container, template_columns, container_width, column_gap,
				true, areas, true)
		}
	}
	row_lines := if data := inherited_rows {
		if subgridded_rows {
			subgrid_lines_for_definition(template_rows, data.line_names, data.tracks.len)
		} else {
			grid_lines_for_definition(container, template_rows, row_basis, row_gap,
				container_state.has_definite_height(), areas, false)
		}
	} else {
		if template_rows.is_subgrid() {
			[][]css.GridLineName{len: 1}
		} else {
			grid_lines_for_definition(container, template_rows, row_basis, row_gap,
				container_state.has_definite_height(), areas, false)
		}
	}
	explicit_column_count := if column_lines.len > 0 { column_lines.len - 1 } else { 0 }
	explicit_row_count := if row_lines.len > 0 { row_lines.len - 1 } else { 0 }
	placement_result := place_grid_items(container, column_lines, row_lines, subgridded_columns,
		subgridded_rows)
	placements := placement_result.placements
	column_sizing_placements := grid_track_sizing_placements(mut state, container, placements,
		column_lines, row_lines, true, column_gap)
	row_sizing_placements := grid_track_sizing_placements(mut state, container, placements,
		column_lines, row_lines, false, row_gap)
	mut required_columns := if explicit_column_count + placement_result.implicit_columns_before > 0 {
		explicit_column_count + placement_result.implicit_columns_before
	} else {
		1
	}
	mut required_rows := explicit_row_count + placement_result.implicit_rows_before
	for placement in placements {
		if placement.column + placement.column_span > required_columns {
			required_columns = placement.column + placement.column_span
		}
		if placement.row + placement.row_span > required_rows {
			required_rows = placement.row + placement.row_span
		}
	}
	mut columns := if data := inherited_columns {
		if subgridded_columns {
			data.tracks.clone()
		} else {
			resolve_grid_tracks(container, template_columns, container.computed_values().grid_auto_columns(),
				container_width, column_gap, !width_is_intrinsic,
				placement_result.implicit_columns_before, required_columns)
		}
	} else {
		resolve_grid_tracks(container, template_columns, container.computed_values().grid_auto_columns(),
			container_width, column_gap, !width_is_intrinsic,
			placement_result.implicit_columns_before, required_columns)
	}
	collapse_empty_auto_fit_tracks(mut columns, placements, true)

	// Resolve non-spanning items first, then items of increasing span, through
	// the same six intrinsic track-sizing phases used by C++.
	mut maximum_column_span := 1
	for placement in column_sizing_placements {
		if placement.column_span > maximum_column_span {
			maximum_column_span = placement.column_span
		}
	}
	for index in 0 .. columns.len {
		if columns[index].has_growth_limit {
			columns[index].growth_limit = css_pixels_max(columns[index].growth_limit, columns[index].base_size)
		}
	}
	for span in 1 .. maximum_column_span + 1 {
		for placement in column_sizing_placements {
			if placement.column_span != span
				|| grid_track_range_crosses_flexible_track(columns, placement.column, placement.column_span)
				|| !grid_track_range_crosses_intrinsic_sizing_track(columns, placement.column, placement.column_span) {
				continue
			}
			minimum_contribution := grid_item_minimum_outer_inline_contribution(mut state, placement.item,
				columns, placement.column, placement.column_span, column_gap).plus(placement.sizing_extra(true))
			min_content_contribution := grid_intrinsic_outer_width_contribution(mut state,
				placement.item, .min_content).plus(placement.sizing_extra(true))
			phase_one_contribution := if width_is_intrinsic {
				grid_limited_content_contribution(state, container, container_state, available_space.width, true, columns, placement.column, placement.column_span, min_content_contribution, minimum_contribution)
			} else {
				minimum_contribution
			}
			distribute_grid_item_contribution_across_intrinsic_track_bases(mut columns, placement.column, placement.column_span, column_gap, phase_one_contribution, .minimum_contribution)
			distribute_grid_item_contribution_across_intrinsic_track_bases(mut columns, placement.column, placement.column_span, column_gap, min_content_contribution, .min_content_contribution)
			if available_space.width.is_max_content() {
				max_content_contribution := grid_intrinsic_outer_width_contribution(mut state,
					placement.item, .max_content).plus(placement.sizing_extra(true))
				limited_max_content_contribution := grid_limited_content_contribution(state, container, container_state, available_space.width, true, columns, placement.column, placement.column_span, max_content_contribution, minimum_contribution)
				distribute_grid_item_contribution_across_intrinsic_track_bases(mut columns, placement.column, placement.column_span, column_gap, limited_max_content_contribution, .max_content_contribution)
			}
			for index in 0 .. columns.len {
				if columns[index].has_growth_limit
					&& columns[index].growth_limit.raw_value() < columns[index].base_size.raw_value() {
					columns[index].growth_limit = columns[index].base_size
				}
			}
			distribute_grid_item_contribution_across_intrinsic_track_growth_limits(mut columns, placement.column, placement.column_span, column_gap, min_content_contribution, .intrinsic_maximum)
			max_content_contribution := grid_intrinsic_outer_width_contribution(mut state,
				placement.item, .max_content).plus(placement.sizing_extra(true))
			distribute_grid_item_contribution_across_intrinsic_track_growth_limits(mut columns, placement.column, placement.column_span, column_gap, max_content_contribution, .max_content_maximum)
		}
	}
	increase_grid_flexible_tracks_for_spanning_items(mut state, container, container_state, mut columns,
		column_sizing_placements, true, available_space.width, column_gap, container_width, false)
	finalize_grid_track_growth_limits(mut columns)
	if width_is_intrinsic && available_space.width.is_max_content() {
		// GridFormattingContext::expand_flexible_tracks() derives the used flex
		// fraction both from flexible tracks' base sizes and from every item
		// crossing a flexible track. The latter is important for mixed fixed/fr
		// spans: a 200px item over `50px 1fr` needs a 150px flexible track.
		mut intrinsic_flex_fraction := CSSPixels.new(0).divided_by(CSSPixels.new(1))
		for track in columns {
			if track.flex <= 0 {
				continue
			}
			candidate := if track.flex > 1 {
				track.base_size.divided_by(CSSPixels.nearest_value_for(track.flex))
			} else {
				track.base_size.divided_by(CSSPixels.new(1))
			}
			if candidate.compare(intrinsic_flex_fraction) > 0 {
				intrinsic_flex_fraction = candidate
			}
		}
		for placement in column_sizing_placements {
			last_column := if placement.column + placement.column_span < columns.len {
				placement.column + placement.column_span
			} else {
				columns.len
			}
			mut crosses_flexible_track := false
			for index in placement.column .. last_column {
				if columns[index].flex > 0 {
					crosses_flexible_track = true
					break
				}
			}
			if !crosses_flexible_track {
				continue
			}
			contribution := grid_intrinsic_outer_width_contribution(mut state, placement.item,
				.max_content).plus(placement.sizing_extra(true))
			candidate := grid_flex_fraction_for_range(columns, placement.column, placement.column_span, contribution, column_gap)
			if candidate.compare(intrinsic_flex_fraction) > 0 {
				intrinsic_flex_fraction = candidate
			}
		}
		for index in 0 .. columns.len {
			if columns[index].flex > 0 {
				columns[index].base_size = css_pixels_max(columns[index].base_size, CSSPixels.nearest_value_for(columns[index].flex).times_fraction(intrinsic_flex_fraction))
			}
		}
	}
	mut column_maximum_size := ?CSSPixels(none)
	if !should_treat_max_width_as_none(state, container, available_space.width) {
		maximum := container.computed_values().size_value(.max_width)
		if resolved := resolve_layout_content_size(container, maximum, available_space.width.to_px_or_zero(), container_state, true) {
			column_maximum_size = resolved
		}
	}
	maximize_grid_tracks(mut columns, available_space.width, column_gap, column_maximum_size)
	if !width_is_intrinsic {
		if container.document().font_rendering_policy() == .chromium {
			chromium_expand_flexible_grid_tracks(mut columns, container_width, column_gap)
		} else {
			expand_flexible_grid_tracks(mut columns, container_width, column_gap)
		}
	}
	mut columns_before_alignment := column_gap.scaled(f64(grid_gutter_count(columns, 0,
		columns.len - 1)))
	for column in columns {
		columns_before_alignment = columns_before_alignment.plus(column.base_size)
	}
	if container.computed_values().justify_content() in [.normal, .stretch] {
		stretch_auto_grid_tracks(mut columns, container_width.minus(columns_before_alignment))
	}
	column_leading_space, effective_column_gap := grid_inline_content_geometry(container, container_width, columns, column_gap)
	mut intrinsic_container_width := effective_column_gap.scaled(f64(grid_gutter_count(columns, 0,
		columns.len - 1)))
	for column in columns {
		intrinsic_container_width = intrinsic_container_width.plus(column.base_size)
	}
	if width_is_intrinsic {
		container_state.set_content_width(intrinsic_container_width)
	}

	mut rows := if data := inherited_rows {
		if subgridded_rows {
			data.tracks.clone()
		} else {
			resolve_grid_tracks(container, template_rows, container.computed_values().grid_auto_rows(),
				row_basis, row_gap, container_state.has_definite_height(),
				placement_result.implicit_rows_before, if required_rows > 0 { required_rows } else { 1 })
		}
	} else {
		resolve_grid_tracks(container, template_rows, container.computed_values().grid_auto_rows(),
			row_basis, row_gap, container_state.has_definite_height(),
			placement_result.implicit_rows_before, if required_rows > 0 { required_rows } else { 1 })
	}
	collapse_empty_auto_fit_tracks(mut rows, placements, false)
	for placement in placements {
		area_width := grid_track_range_size(columns, placement.column, placement.column_span, effective_column_gap)
		styled := placement.item.as_node_with_style() or { continue }
		mut item_state := state.get_mutable(styled)
		install_grid_item_subgrid_data(mut state, placement.item, columns, rows, column_lines,
			row_lines, placement, effective_column_gap, row_gap)
		item_state.set_containing_block_used_values(container_state)
		resolve_box_model_edges(styled.computed_values(), mut item_state, area_width.to_double())
		if subgridded_columns {
			apply_subgrid_gap_extra_margins(container, mut item_state, placement, true, columns.len,
				column_gap, container_width)
		}
		if subgridded_rows {
			apply_subgrid_gap_extra_margins(container, mut item_state, placement, false, rows.len,
				row_gap, row_basis)
		}
		inline_alignment := grid_inline_alignment(container, placement.item)
		width_is_auto := placement.item.computed_values().size_value(.width).is_auto()
		has_auto_inline_margin := property_is_auto(placement.item.computed_values(), .margin_left)
			|| property_is_auto(placement.item.computed_values(), .margin_right)
		mut forced_width := if placement.item.is_table_wrapper() {
			?CSSPixels(resolve_grid_table_wrapper_width(mut state, placement.item, mut item_state,
				area_width, inline_alignment))
		} else if inline_alignment in [.normal, .stretch] && width_is_auto
			&& !placement.item.is_replaced_box()
			&& !has_auto_inline_margin {
			?CSSPixels(area_width.minus(flex_or_grid_item_outer_inline_edges(item_state)))
		} else if width_is_auto && !placement.item.is_replaced_box() {
			if box := placement.item.as_box() {
				?CSSPixels(calculate_fit_content_width(mut state, box, AvailableSize.make_definite(area_width)))
			} else {
				?CSSPixels(none)
			}
		} else {
			resolve_layout_content_size(placement.item, placement.item.computed_values().size_value(.width), area_width, item_state, true)
		}
		if width := forced_width {
			forced_width =
				clamp_layout_content_size(placement.item, width, area_width, item_state, true)
		}
		item_state = layout_independent_child(mut state, placement.item, mut container_state, area_width, if container_state.has_definite_height() {
			container_state.content_height()
		} else {
			none
		}, forced_width, none)
	}
	mut maximum_row_span := 1
	for placement in row_sizing_placements {
		if placement.row_span > maximum_row_span {
			maximum_row_span = placement.row_span
		}
	}
	for span in 1 .. maximum_row_span + 1 {
		for placement in row_sizing_placements {
			if placement.row_span != span
				|| grid_track_range_crosses_flexible_track(rows, placement.row, placement.row_span)
				|| !grid_track_range_crosses_intrinsic_sizing_track(rows, placement.row, placement.row_span) {
				continue
			}
			styled := placement.item.as_node_with_style() or { continue }
			item_state := state.get(styled)
			spanned_track_size := grid_track_range_size(rows, placement.row, placement.row_span, row_gap)
			minimum_contribution := grid_item_minimum_outer_block_contribution(mut state,
				placement.item, item_state, rows, placement.row, placement.row_span,
				container_state.has_definite_height(), row_basis, row_gap).plus(placement.sizing_extra(false))
			min_content_contribution := grid_item_outer_block_content_contribution(mut state,
				placement.item, item_state, .min_content, container_state.has_definite_height(),
				row_basis, spanned_track_size).plus(placement.sizing_extra(false))
			phase_one_contribution := if available_space.height.is_intrinsic_sizing_constraint() {
				grid_limited_content_contribution(state, container, container_state, available_space.height, false, rows, placement.row, placement.row_span, min_content_contribution, minimum_contribution)
			} else {
				minimum_contribution
			}
			distribute_grid_item_contribution_across_intrinsic_track_bases(mut rows, placement.row, placement.row_span, row_gap, phase_one_contribution, .minimum_contribution)
			distribute_grid_item_contribution_across_intrinsic_track_bases(mut rows, placement.row, placement.row_span, row_gap, min_content_contribution, .min_content_contribution)
			if available_space.height.is_max_content() {
				max_content_contribution := grid_item_outer_block_content_contribution(mut state,
					placement.item, item_state, .max_content, container_state.has_definite_height(),
					row_basis, spanned_track_size).plus(placement.sizing_extra(false))
				limited_max_content_contribution := grid_limited_content_contribution(state, container, container_state, available_space.height, false, rows, placement.row, placement.row_span, max_content_contribution, minimum_contribution)
				distribute_grid_item_contribution_across_intrinsic_track_bases(mut rows, placement.row, placement.row_span, row_gap, limited_max_content_contribution, .max_content_contribution)
			}
			for index in 0 .. rows.len {
				if rows[index].has_growth_limit
					&& rows[index].growth_limit.raw_value() < rows[index].base_size.raw_value() {
					rows[index].growth_limit = rows[index].base_size
				}
			}
			distribute_grid_item_contribution_across_intrinsic_track_growth_limits(mut rows, placement.row, placement.row_span, row_gap, min_content_contribution, .intrinsic_maximum)
			max_content_contribution := grid_item_outer_block_content_contribution(mut state,
				placement.item, item_state, .max_content, container_state.has_definite_height(),
				row_basis, spanned_track_size).plus(placement.sizing_extra(false))
			distribute_grid_item_contribution_across_intrinsic_track_growth_limits(mut rows, placement.row, placement.row_span, row_gap, max_content_contribution, .max_content_maximum)
		}
	}
	increase_grid_flexible_tracks_for_spanning_items(mut state, container, container_state, mut rows,
		row_sizing_placements, false, available_space.height, row_gap, row_basis,
		container_state.has_definite_height())
	finalize_grid_track_growth_limits(mut rows)
	// Like LibWeb, maximize and choose the flexible-track branch from the
	// available grid space, not from whether the computed height was definite.
	// This is observable when an auto-height grid is rerun with a definite
	// block-size constraint after min/max clamping.
	maximize_grid_tracks(mut rows, available_space.height, row_gap, none)
	if available_space.height.is_definite() {
		if container.document().font_rendering_policy() == .chromium {
			chromium_expand_flexible_grid_tracks(mut rows, available_space.height.to_px_or_zero(), row_gap)
		} else {
			expand_flexible_grid_tracks(mut rows, available_space.height.to_px_or_zero(), row_gap)
		}
	} else {
		// GridFormattingContext::expand_flexible_tracks(), indefinite-space
		// branch. Include every item crossing a flexible row, rather than only
		// the flexible rows' existing base sizes.
		mut flex_fraction := CSSPixels.new(0).divided_by(CSSPixels.new(1))
		for row in rows {
			if row.flex <= 0 {
				continue
			}
			candidate := if row.flex > 1 {
				row.base_size.divided_by(CSSPixels.nearest_value_for(row.flex))
			} else {
				row.base_size.divided_by(CSSPixels.new(1))
			}
			if candidate.compare(flex_fraction) > 0 {
				flex_fraction = candidate
			}
		}
		for placement in row_sizing_placements {
			last_row := if placement.row + placement.row_span < rows.len {
				placement.row + placement.row_span
			} else {
				rows.len
			}
			mut crosses_flexible_track := false
			for index in placement.row .. last_row {
				if rows[index].flex > 0 {
					crosses_flexible_track = true
					break
				}
			}
			if !crosses_flexible_track {
				continue
			}
			styled := placement.item.as_node_with_style() or { continue }
			item_state := state.get(styled)
			contribution := grid_item_outer_block_content_contribution(mut state, placement.item,
				item_state, .max_content, container_state.has_definite_height(), row_basis,
				grid_track_range_size(rows, placement.row, placement.row_span, row_gap)).plus(placement.sizing_extra(false))
			candidate := grid_flex_fraction_for_range(rows, placement.row, placement.row_span, contribution, row_gap)
			if candidate.compare(flex_fraction) > 0 {
				flex_fraction = candidate
			}
		}
		if flex_fraction.numerator().raw_value() > 0 {
			for index in 0 .. rows.len {
				if rows[index].flex > 0 {
					rows[index].base_size = css_pixels_max(rows[index].base_size, CSSPixels.nearest_value_for(rows[index].flex).times_fraction(flex_fraction))
				}
			}
		}
	}
	if alignment_height := grid_alignment_height {
		if container.computed_values().align_content() in [.normal, .stretch] {
			mut rows_before_alignment := row_gap.scaled(f64(grid_gutter_count(rows, 0,
				rows.len - 1)))
			for row in rows {
				rows_before_alignment = rows_before_alignment.plus(row.base_size)
			}
			stretch_auto_grid_tracks(mut rows, alignment_height.minus(rows_before_alignment))
		}
	}

	mut row_leading_space := CSSPixels.new(0)
	mut effective_row_gap := row_gap
	if alignment_height := grid_alignment_height {
		row_leading_space, effective_row_gap = grid_block_content_geometry(container, alignment_height, rows, row_gap)
	}
	mut automatic_height := effective_row_gap.scaled(f64(grid_gutter_count(rows, 0, rows.len - 1)))
	for row in rows {
		automatic_height = automatic_height.plus(row.base_size)
	}
	if layout_mode == .intrinsic_sizing {
		if available_space.height.is_intrinsic_sizing_constraint() {
			container_state.set_content_height(automatic_height)
		}
		return FormattingContextResult{
			automatic_content_width: if width_is_intrinsic {
				intrinsic_container_width
			} else {
				container_width
			}
			automatic_content_height: automatic_height
		}
	}
	// getComputedStyle() needs to return the resolved values of
	// grid-template-columns and grid-template-rows, so they are saved in the
	// state here and handed to the layout node when it is committed.
	mut used_columns := []CSSPixels{cap: columns.len}
	for column in columns {
		used_columns << column.base_size
	}
	mut used_rows := []CSSPixels{cap: rows.len}
	for row in rows {
		used_rows << row.base_size
	}
	container_state.set_grid_template_columns(used_columns)
	container_state.set_grid_template_rows(used_rows)
	container_state.set_grid_subgridded_axes(subgridded_columns, subgridded_rows)
	// Only *explicit* line names are serialized, so recompute the line map
	// without the `<area>-start`/`-end` names that grid-template-areas adds.
	empty_areas := css.GridTemplateAreas{}
	used_column_line_names := if subgridded_columns {
		grid_line_name_strings(subgrid_lines_for_definition(template_columns,
			[][]css.GridLineName{}, columns.len))
	} else {
		grid_line_name_strings(grid_lines_for_definition(container, template_columns, container_width,
			column_gap, true, empty_areas, true))
	}
	used_row_line_names := if subgridded_rows {
		grid_line_name_strings(subgrid_lines_for_definition(template_rows, [][]css.GridLineName{},
			rows.len))
	} else {
		grid_line_name_strings(grid_lines_for_definition(container, template_rows, row_basis, row_gap,
			container_state.has_definite_height(), empty_areas, false))
	}
	container_state.set_grid_line_names(used_column_line_names, used_row_line_names)

	for placement in placements {
		styled := placement.item.as_node_with_style() or { continue }
		mut item_state := state.get_mutable(styled)
		install_grid_item_subgrid_data(mut state, placement.item, columns, rows, column_lines,
			row_lines, placement, effective_column_gap, effective_row_gap)
		area_width := grid_track_range_size(columns, placement.column, placement.column_span, effective_column_gap)
		area_height := grid_track_range_size(rows, placement.row, placement.row_span, effective_row_gap)
		// FlexFormattingContext.cpp/GridFormattingContext.cpp compute relative
		// insets against the resolved grid-area rectangle, not the grid
		// container's full content box.
		// get_grid_area_rect() walks the interleaved track-and-gap array up to
		// the resolved end line. For an area which does not end at the final
		// grid line this includes the following gap in the rectangle used by
		// compute_inset(), even though item sizing uses the track range itself.
		grid_area_width := area_width.plus(if placement.column + placement.column_span < columns.len {
			effective_column_gap
		} else {
			CSSPixels.new(0)
		})
		grid_area_height := area_height.plus(if placement.row + placement.row_span < rows.len {
			effective_row_gap
		} else {
			CSSPixels.new(0)
		})
		item_state.set_relative_inset_basis(grid_area_width, grid_area_height)
		inline_alignment := grid_inline_alignment(container, placement.item)
		left_margin_auto := property_is_auto(placement.item.computed_values(), .margin_left)
		right_margin_auto := property_is_auto(placement.item.computed_values(), .margin_right)
		block_alignment := grid_block_alignment(container, placement.item)
		top_margin_auto := property_is_auto(placement.item.computed_values(), .margin_top)
		bottom_margin_auto := property_is_auto(placement.item.computed_values(), .margin_bottom)
		mut forced_item_height := ?CSSPixels(none)
		if (block_alignment == .stretch || (block_alignment == .normal
			&& !placement.item.is_replaced_box()))
			&& placement.item.computed_values().size_value(.height).is_auto() && !top_margin_auto
			&& !bottom_margin_auto {
			forced_item_height = area_height.minus(flex_or_grid_item_outer_block_edges(item_state))
		} else if placement.item.is_replaced_box()
			&& placement.item.computed_values().size_value(.height).is_auto() {
			if box := placement.item.as_box() {
				if box.has_preferred_aspect_ratio() {
					// Final grid item sizing transfers the resolved inline size
					// through the preferred ratio using its content- or border-box
					// semantics before block-axis min/max constraints are applied.
					forced_item_height = intrinsic_content_height_from_aspect_ratio(box,
						item_state, item_state.content_width())
				}
			}
		} else if !placement.item.computed_values().size_value(.height).is_auto() {
			forced_item_height = resolve_layout_content_size(placement.item, placement.item.computed_values().size_value(.height), area_height, item_state, false)
		}
		if requested_height := forced_item_height {
			clamped_height := clamp_layout_content_size(placement.item, requested_height, area_height, item_state, false)
			item_state = layout_independent_child(mut state, placement.item, mut container_state, area_width, if container_state.has_definite_height() {
				container_state.content_height()
			} else {
				none
			}, item_state.content_width(), clamped_height)
		} else if placement.item.is_replaced_box()
			&& (placement.item.computed_values().size_value(.height).contains_percentage()
			|| placement.item.computed_values().size_value(.min_height).contains_percentage()
			|| placement.item.computed_values().size_value(.max_height).contains_percentage()) {
			// Percentage block-axis constraints become resolvable only after the
			// grid rows have their final sizes. Re-run replaced sizing with the
			// completed grid area as the percentage basis while retaining the
			// inline size established during column sizing.
			item_state = layout_independent_child(mut state, placement.item, mut container_state,
				area_width, area_height, item_state.content_width(), none)
		}
		if subgridded_columns || subgridded_rows {
			resolve_box_model_edges(styled.computed_values(), mut item_state, area_width.to_double())
			if subgridded_columns {
				apply_subgrid_gap_extra_margins(container, mut item_state, placement, true,
					columns.len, column_gap, container_width)
			}
			if subgridded_rows {
				apply_subgrid_gap_extra_margins(container, mut item_state, placement, false,
					rows.len, row_gap, row_basis)
			}
		}
		inline_margin_space := area_width.minus(item_state.margin_box_width())
		if inline_margin_space.raw_value() > 0 && left_margin_auto && right_margin_auto {
			item_state.margin_left = inline_margin_space.divided_by_float(2)
			item_state.margin_right = inline_margin_space.divided_by_float(2)
		} else if inline_margin_space.raw_value() > 0 && left_margin_auto {
			item_state.margin_left = inline_margin_space
		} else if inline_margin_space.raw_value() > 0 && right_margin_auto {
			item_state.margin_right = inline_margin_space
		} else if inline_alignment == .end {
			if container.computed_values().direction() == .rtl {
				item_state.margin_right = item_state.margin_right.plus(inline_margin_space)
			} else {
				item_state.margin_left = item_state.margin_left.plus(inline_margin_space)
			}
		} else if inline_alignment == .center {
			half := CSSPixels.from_raw(inline_margin_space.raw_value() / 2)
			item_state.margin_left = item_state.margin_left.plus(half)
			item_state.margin_right = item_state.margin_right.plus(half)
		} else if inline_alignment in [.start, .baseline] {
			if container.computed_values().direction() == .rtl {
				item_state.margin_left = item_state.margin_left.plus(inline_margin_space)
			} else {
				item_state.margin_right = item_state.margin_right.plus(inline_margin_space)
			}
		} else if container.computed_values().direction() == .rtl {
			item_state.margin_left = item_state.margin_left.plus(inline_margin_space)
		}
		block_margin_space := area_height.minus(item_state.margin_box_height())
		if block_margin_space.raw_value() > 0 && top_margin_auto && bottom_margin_auto {
			item_state.margin_top = block_margin_space.divided_by_float(2)
			item_state.margin_bottom = block_margin_space.divided_by_float(2)
		} else if block_margin_space.raw_value() > 0 && top_margin_auto {
			item_state.margin_top = block_margin_space
		} else if block_margin_space.raw_value() > 0 && bottom_margin_auto {
			item_state.margin_bottom = block_margin_space
		} else if block_alignment == .end {
			item_state.margin_top = item_state.margin_top.plus(block_margin_space)
		} else if block_alignment == .center {
			half := CSSPixels.from_raw(block_margin_space.raw_value() / 2)
			item_state.margin_top = item_state.margin_top.plus(half)
			item_state.margin_bottom = item_state.margin_bottom.plus(half)
		} else if block_alignment in [.start, .baseline] {
			item_state.margin_bottom = item_state.margin_bottom.plus(block_margin_space)
		}
		area_x := grid_physical_column_offset(container, container_width, columns, placement.column, placement.column_span, effective_column_gap, column_leading_space)
		item_state.set_content_x(area_x.plus(item_state.margin_box_left()))
		item_state.set_content_y(row_leading_space.plus(grid_track_offset(rows, placement.row, effective_row_gap)).plus(item_state.margin_box_top()))
		grid_area_rect := css.CSSPixelRect.new(area_x.to_double(), row_leading_space.plus(grid_track_offset(rows, placement.row, effective_row_gap)).to_double(), grid_area_width.to_double(), grid_area_height.to_double())
		set_grid_abspos_descendant_rects(mut state, container, placement.item, grid_area_rect)
	}

	// CSS Grid 2 absolute-positioned grid children use their resolved grid area
	// as the containing rectangle. An auto grid axis contributes the grid
	// container's padding edges instead of participating in auto-placement.
	for child in container.children() {
		if !child.is_absolutely_positioned() {
			continue
		}
		computed := child.computed_values()
		column_is_auto := grid_axis_is_auto(computed.grid_column_start(), computed.grid_column_end())
		row_is_auto := grid_axis_is_auto(computed.grid_row_start(), computed.grid_row_end())
		column_position := resolve_grid_axis_position_for_context(computed.grid_column_start(), computed.grid_column_end(),
			column_lines.len, column_lines, subgridded_columns)
		row_position := resolve_grid_axis_position_for_context(computed.grid_row_start(), computed.grid_row_end(),
			row_lines.len, row_lines, subgridded_rows)

		mut area_x := CSSPixels.new(0).minus(container_state.padding_left)
		mut area_width :=
			container_state.padding_left.plus(container_width).plus(container_state.padding_right)
		if !column_is_auto {
			column := column_position.start + placement_result.implicit_columns_before
			if column >= columns.len {
				area_width = container_state.padding_right
				area_x = grid_physical_column_offset(container, container_width, columns, columns.len, 0, effective_column_gap, column_leading_space).minus(if container.computed_values().direction() == .rtl {
					area_width
				} else {
					CSSPixels.new(0)
				})
			} else {
				column_start := if column < 0 {
					0
				} else {
					column
				}
				area_width = grid_track_range_size(columns, column_start, column_position.span, effective_column_gap)
				area_x = grid_physical_column_offset(container, container_width, columns, column_start, column_position.span, effective_column_gap, column_leading_space)
			}
		}

		mut area_y := CSSPixels.new(0).minus(container_state.padding_top)
		mut area_height := container_state.padding_top.plus(if container_state.has_definite_height() {
			container_state.content_height()
		} else {
			automatic_height
		}).plus(container_state.padding_bottom)
		if !row_is_auto {
			row := row_position.start + placement_result.implicit_rows_before
			if row >= rows.len {
				area_y =
					row_leading_space.plus(grid_track_offset(rows, rows.len, effective_row_gap))
				area_height = container_state.padding_bottom
			} else {
				area_y = row_leading_space.plus(grid_track_offset(rows, if row < 0 {
					0
				} else {
					row
				}, effective_row_gap))
				area_height = grid_track_range_size(rows, if row < 0 { 0 } else { row }, row_position.span, effective_row_gap)
			}
		}

		rect := css.CSSPixelRect.new(area_x.to_double(), area_y.to_double(), area_width.to_double(), area_height.to_double())
		set_grid_abspos_containing_rect(mut state, container, child, rect)
	}
	return FormattingContextResult{
		automatic_content_width: if width_is_intrinsic {
			intrinsic_container_width
		} else {
			container_width
		}
		automatic_content_height: automatic_height
	}
}
