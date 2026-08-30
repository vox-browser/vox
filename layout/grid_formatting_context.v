// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css

struct GridTrack {
mut:
	base_size             CSSPixels
	flex                  f64
	intrinsic             bool
	auto_fit              bool
	auto_min              bool
	auto_max              bool
	growth_limit          CSSPixels
	has_growth_limit      bool
	max_content_max       bool
	fit_content_max       bool
	fit_content_limit     CSSPixels
	has_fit_content_limit bool
}

struct GridItemPlacement {
	item        &Node = unsafe { nil }
	row_span    int   = 1
	column_span int   = 1
mut:
	row    int
	column int
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
			rect: css.CSSPixelRect.new(rect.x.plus(existing_static_position.x()).to_double(),
				rect.y.plus(existing_static_position.y()).to_double(), 0, 0)
		})
		return
	}
	child_state.set_static_position_rect(StaticPositionRect{
		rect:                 rect
		horizontal_alignment: static_position_alignment_for_grid_item(grid_inline_alignment(container,
			child))
		vertical_alignment:   static_position_alignment_for_grid_item(grid_block_alignment(container,
			child))
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

fn resolve_grid_table_wrapper_end_margin(mut state LayoutState, wrapper &Node, grid_area_width CSSPixels) {
	if !wrapper.is_table_wrapper() {
		return
	}
	for child in wrapper.children() {
		if !child.display().is_table_inside() {
			continue
		}
		styled := child.as_node_with_style() or { return }
		mut table_state := state.get_mutable(styled)
		remaining := grid_area_width.minus(table_state.margin_box_width())
		if child.computed_values().direction() == .rtl {
			table_state.margin_left = table_state.margin_left.plus(remaining)
		} else {
			table_state.margin_right = table_state.margin_right.plus(remaining)
		}
		return
	}
}

fn grid_track_from_size(node &Node, size css.GridSize, basis CSSPixels, available_is_definite bool, auto_fit bool) GridTrack {
	if size.is_flexible_length() {
		return GridTrack{
			flex: size.flex_factor()
			// A bare <flex> track has an automatic minimum.
			intrinsic: true
			auto_fit:  auto_fit
		}
	}
	css_size := size.css_size()
	available_size := if available_is_definite {
		css.AvailableSize.make_definite()
	} else {
		css.AvailableSize.make_indefinite()
	}
	if size.is_fixed(available_size) {
		value := resolve_layout_size(node, css_size, basis) or { CSSPixels.new(0) }
		return GridTrack{
			base_size: value
			auto_fit:  auto_fit
		}
	}
	mut track := GridTrack{
		intrinsic:       size.is_intrinsic(available_size)
		auto_fit:        auto_fit
		auto_min:        size.is_auto(available_size) || size.is_fit_content()
		auto_max:        size.is_auto(available_size)
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

fn auto_repeat_count(node &Node, repeat css.GridRepeat, basis CSSPixels, gap CSSPixels, available_is_definite bool) int {
	list := repeat.grid_track_size_list()
	mut repeated_tracks_size := CSSPixels.new(0)
	for track in list.track_list() {
		size := definite_grid_track_size(node, track, basis) or { return 0 }
		repeated_tracks_size = repeated_tracks_size.plus(size)
	}
	if repeated_tracks_size.raw_value() == 0 {
		return 0
	}
	repeated_track_count := expanded_explicit_grid_track_count(node, list, basis, gap,
		available_is_definite)
	with_gaps := repeated_tracks_size.plus(gap.scaled(f64(repeated_track_count)))
	if with_gaps.raw_value() <= 0 {
		return 0
	}
	if available_is_definite {
		count := int(basis.plus(gap).to_double() / with_gaps.to_double())
		return if count > 1 { count } else { 1 }
	}
	return 1
}

fn append_explicit_grid_track(node &Node, track css.ExplicitGridTrack, basis CSSPixels, gap CSSPixels, available_is_definite bool, inherited_auto_fit bool, mut tracks []GridTrack) {
	if track.is_repeat() {
		repeat := track.repeat()
		repeat_count := if repeat.is_fixed() {
			int(repeat.repeat_count())
		} else {
			auto_repeat_count(node, repeat, basis, gap, available_is_definite)
		}
		repeated_track_is_auto_fit := inherited_auto_fit || repeat.is_auto_fit()
		for _ in 0 .. repeat_count {
			append_grid_track_list(node, repeat.grid_track_size_list(), basis, gap,
				available_is_definite, repeated_track_is_auto_fit, mut tracks)
		}
		return
	}
	if track.is_minmax() {
		minmax := track.minmax()
		mut resolved := grid_track_from_size(node, minmax.max_grid_size(), basis,
			available_is_definite, inherited_auto_fit)
		minimum := grid_track_from_size(node, minmax.min_grid_size(), basis, available_is_definite,
			inherited_auto_fit)
		resolved.auto_min = minimum.auto_min
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
	tracks << grid_track_from_size(node, track.grid_size(), basis, available_is_definite,
		inherited_auto_fit)
}

fn append_grid_track_list(node &Node, list css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, available_is_definite bool, inherited_auto_fit bool, mut tracks []GridTrack) {
	for track in list.track_list() {
		append_explicit_grid_track(node, track, basis, gap, available_is_definite,
			inherited_auto_fit, mut tracks)
	}
}

fn expanded_explicit_grid_track_count(node &Node, list css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, available_is_definite bool) int {
	mut count := 0
	for track in list.track_list() {
		if track.is_repeat() {
			repeat := track.repeat()
			repeat_count := if repeat.is_fixed() {
				int(repeat.repeat_count())
			} else {
				auto_repeat_count(node, repeat, basis, gap, available_is_definite)
			}
			count += repeat_count * expanded_explicit_grid_track_count(node,
				repeat.grid_track_size_list(), basis, gap, available_is_definite)
			continue
		}
		count++
	}
	return count
}

fn expand_grid_lines(node &Node, definition css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, available_is_definite bool, mut lines [][]string, mut pending_names []string) {
	for item in definition.list() {
		match item {
			css.GridLineNames {
				for line_name in item.names() {
					pending_names << line_name.name
				}
			}
			css.ExplicitGridTrack {
				if item.is_repeat() {
					repeat := item.repeat()
					repeat_count := if repeat.is_fixed() {
						int(repeat.repeat_count())
					} else {
						auto_repeat_count(node, repeat, basis, gap, available_is_definite)
					}
					for _ in 0 .. repeat_count {
						expand_grid_lines(node, repeat.grid_track_size_list(), basis, gap,
							available_is_definite, mut lines, mut pending_names)
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
fn grid_lines_for_definition(node &Node, definition css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, available_is_definite bool, areas css.GridTemplateAreas, columns bool) [][]string {
	mut lines := [][]string{}
	mut pending_names := []string{}
	expand_grid_lines(node, definition, basis, gap, available_is_definite, mut lines, mut
		pending_names)
	lines << pending_names.clone()
	required_line_count := int(if columns { areas.column_count } else { areas.row_count }) + 1
	for lines.len < required_line_count {
		lines << []string{}
	}
	for name, area in areas.areas {
		start := int(if columns { area.column_start } else { area.row_start })
		end := int(if columns { area.column_end } else { area.row_end })
		lines[start] << '${name}-start'
		lines[end] << '${name}-end'
	}
	return lines
}

fn resolve_grid_tracks(container &Node, list css.GridTrackSizeList, implicit_list css.GridTrackSizeList, available CSSPixels, gap CSSPixels, available_is_definite bool, implicit_before_count int, required_count int) []GridTrack {
	mut tracks := []GridTrack{}
	implicit_tracks := implicit_list.track_list()
	for index in 0 .. implicit_before_count {
		if implicit_tracks.len > 0 {
			implicit_index := (implicit_before_count - index - 1) % implicit_tracks.len
			append_explicit_grid_track(container, implicit_tracks[implicit_index], available, gap,
				available_is_definite, false, mut tracks)
		} else {
			tracks << GridTrack{
				intrinsic: true
				auto_max:  true
			}
		}
	}
	append_grid_track_list(container, list, available, gap, available_is_definite, false, mut
		tracks)
	mut implicit_index := 0
	for tracks.len < required_count {
		if implicit_tracks.len > 0 {
			append_explicit_grid_track(container,
				implicit_tracks[implicit_index % implicit_tracks.len], available, gap,
				available_is_definite, false, mut tracks)
			implicit_index++
		} else {
			tracks << GridTrack{
				intrinsic: true
				auto_max:  true
			}
		}
	}
	if tracks.len == 0 {
		tracks << GridTrack{
			flex: 1
		}
	}
	return tracks
}

fn resolved_grid_line_number(placement css.GridTrackPlacement, explicit_line_count int) ?int {
	if !placement.has_line_number() {
		return none
	}
	line := placement.line_number()
	resolved := line.resolved(css.CalculationResolutionContext{}) or { return none }
	if resolved == 0 {
		return none
	}
	value := int(resolved)
	return if value > 0 { value - 1 } else { explicit_line_count + value }
}

fn grid_axis_is_auto(start css.GridTrackPlacement, end css.GridTrackPlacement) bool {
	return start.is_auto_positioned() && end.is_auto_positioned()
}

fn get_nth_grid_line_index(lines [][]string, name string, nth_line int) ?int {
	if nth_line == 0 {
		return none
	}
	mut remaining := if nth_line < 0 { lines.len + nth_line } else { nth_line - 1 }
	for index, names in lines {
		for candidate in names {
			if candidate != name {
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
	span := placement.span()
	resolved := span.resolved(css.CalculationResolutionContext{}) or { return none }
	if resolved <= 0 {
		return none
	}
	return int(resolved)
}

// GridFormattingContext::resolve_grid_position(). Line indexes are zero-based;
// negative authored indexes are resolved from the end of the explicit grid.
fn resolve_grid_axis_position(start css.GridTrackPlacement, end css.GridTrackPlacement, explicit_line_count int, lines [][]string) GridAxisPlacement {
	mut result := GridAxisPlacement{}
	start_line_number := if start.has_line_number() {
		int(start.line_number().resolved(css.CalculationResolutionContext{}) or { i64(1) })
	} else {
		1
	}
	end_line_number := if end.has_line_number() {
		int(end.line_number().resolved(css.CalculationResolutionContext{}) or { i64(1) })
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
	mut items := []&Node{}
	for child in container.children() {
		if !child.is_box() || child.is_absolutely_positioned() || can_skip_anonymous_text_run(child) {
			continue
		}
		mut mutable_child := unsafe { &Node(child) }
		mutable_child.set_grid_item(true)
		order := child.computed_values().order()
		mut insertion_index := items.len
		for index, existing in items {
			if existing.computed_values().order() > order {
				insertion_index = index
				break
			}
		}
		items.insert(insertion_index, child)
	}
	return items
}

fn grid_cell_key(row int, column int) string {
	return '${row}:${column}'
}

fn grid_area_is_free(occupied map[string]bool, row int, column int, row_span int, column_span int) bool {
	for y in row .. row + row_span {
		for x in column .. column + column_span {
			if occupied[grid_cell_key(y, x)] {
				return false
			}
		}
	}
	return true
}

fn occupy_grid_area(mut occupied map[string]bool, placement GridItemPlacement) {
	for y in placement.row .. placement.row + placement.row_span {
		for x in placement.column .. placement.column + placement.column_span {
			occupied[grid_cell_key(y, x)] = true
		}
	}
}

fn place_grid_items(container &Node, column_lines [][]string, row_lines [][]string) GridPlacementResult {
	mut placements := []GridItemPlacement{}
	mut occupied := map[string]bool{}
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
		column_axis_is_auto := grid_axis_is_auto(computed.grid_column_start(),
			computed.grid_column_end())
		row_axis_is_auto := grid_axis_is_auto(computed.grid_row_start(), computed.grid_row_end())
		column_position := resolve_grid_axis_position(computed.grid_column_start(),
			computed.grid_column_end(), column_lines.len, column_lines)
		row_position := resolve_grid_axis_position(computed.grid_row_start(),
			computed.grid_row_end(), row_lines.len, row_lines)
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
		column_position := resolve_grid_axis_position(computed.grid_column_start(),
			computed.grid_column_end(), column_lines.len, column_lines)
		row_position := resolve_grid_axis_position(computed.grid_row_start(),
			computed.grid_row_end(), row_lines.len, row_lines)
		column_span := column_position.span
		row_span := row_position.span
		placement := GridItemPlacement{
			item:        item
			row:         row_position.start
			column:      column_position.start
			row_span:    row_span
			column_span: column_span
		}
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
		column_position := resolve_grid_axis_position(computed.grid_column_start(),
			computed.grid_column_end(), column_lines.len, column_lines)
		row_position := resolve_grid_axis_position(computed.grid_row_start(),
			computed.grid_row_end(), row_lines.len, row_lines)
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
		placement := GridItemPlacement{
			item:        item
			row:         row
			column:      column
			row_span:    row_span
			column_span: column_span
		}
		placements << placement
		occupy_grid_area(mut occupied, placement)
	}

	// Step 4: place every item whose row is still auto-positioned. Row flow
	// advances columns inside rows; column flow performs the transposed search.
	auto_flow := container.computed_values().grid_auto_flow()
	mut cursor_row := implicit_minimum_row
	mut cursor_column := implicit_minimum_column
	mut occupied_maximum_row := if auto_flow.row {
		if explicit_row_count > 0 { explicit_row_count - 1 } else { 0 }
	} else {
		row_count - 1
	}
	mut occupied_maximum_column := if auto_flow.row {
		column_count - 1
	} else {
		if explicit_column_count > 0 { explicit_column_count - 1 } else { 0 }
	}
	for placement in placements {
		occupied_maximum_row = if placement.row + placement.row_span - 1 > occupied_maximum_row {
			placement.row + placement.row_span - 1
		} else {
			occupied_maximum_row
		}
		occupied_maximum_column = if placement.column + placement.column_span - 1 > occupied_maximum_column {
			placement.column + placement.column_span - 1
		} else {
			occupied_maximum_column
		}
	}
	for item in items {
		computed := item.computed_values()
		if !grid_axis_is_auto(computed.grid_row_start(), computed.grid_row_end()) {
			continue
		}
		column_position := resolve_grid_axis_position(computed.grid_column_start(),
			computed.grid_column_end(), column_lines.len, column_lines)
		row_position := resolve_grid_axis_position(computed.grid_row_start(),
			computed.grid_row_end(), row_lines.len, row_lines)
		column_span := column_position.span
		row_span := row_position.span
		column_is_auto := grid_axis_is_auto(computed.grid_column_start(),
			computed.grid_column_end())
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
		mut found_within_occupation_grid := true
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
			found_within_occupation_grid = row <= occupied_maximum_row
		} else {
			for row + row_span > row_count
				|| !grid_area_is_free(occupied, row, column, row_span, column_span) {
				row++
				if row >= row_count {
					row = implicit_minimum_row
					column++
				}
			}
			found_within_occupation_grid = column <= occupied_maximum_column
		}
		placement := GridItemPlacement{
			item:        item
			row:         row
			column:      column
			row_span:    row_span
			column_span: column_span
		}
		placements << placement
		occupy_grid_area(mut occupied, placement)
		if row + row_span - 1 > occupied_maximum_row {
			occupied_maximum_row = row + row_span - 1
		}
		if column + column_span - 1 > occupied_maximum_column {
			occupied_maximum_column = column + column_span - 1
		}
		if !column_is_auto {
			cursor_column = column
			cursor_row = row
		} else if auto_flow.row {
			if found_within_occupation_grid {
				cursor_column = column + column_span
				cursor_row = implicit_minimum_row
			} else {
				cursor_column = column + column_span - 1
				cursor_row = row + row_span - 1
			}
		} else {
			if found_within_occupation_grid {
				cursor_column = implicit_minimum_column
				cursor_row = row + row_span
			} else {
				cursor_column = column + column_span - 1
				cursor_row = row + row_span - 1
			}
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
		placements:              placements
		implicit_columns_before: columns_before
		implicit_rows_before:    rows_before
	}
}

fn grid_track_range_size(tracks []GridTrack, start int, span int, gap CSSPixels) CSSPixels {
	mut size := gap.scaled(f64(if span > 0 { span - 1 } else { 0 }))
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
	mut offset := gap.scaled(f64(gap_count))
	for track_index in 0 .. index {
		if track_index < tracks.len {
			offset = offset.plus(tracks[track_index].base_size)
		}
	}
	return offset
}

fn grid_inline_content_geometry(container &Node, container_width CSSPixels, tracks []GridTrack, computed_gap CSSPixels) (CSSPixels, CSSPixels) {
	mut tracks_size := CSSPixels.new(0)
	for track in tracks {
		tracks_size = tracks_size.plus(track.base_size)
	}
	gap_count := if tracks.len > 0 { tracks.len - 1 } else { 0 }
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
	gap_count := if tracks.len > 0 { tracks.len - 1 } else { 0 }
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

fn distribute_grid_item_minimum_across_intrinsic_tracks(mut tracks []GridTrack, start int, span int, gap CSSPixels, contribution CSSPixels) {
	current := grid_track_range_size(tracks, start, span, gap)
	mut intrinsic_track_count := 0
	for index in start .. start + span {
		if index >= 0 && index < tracks.len && tracks[index].intrinsic && tracks[index].flex == 0 {
			intrinsic_track_count++
		}
	}
	if intrinsic_track_count == 0 {
		return
	}
	mut remaining := contribution.minus(current)
	if remaining.raw_value() <= 0 {
		return
	}
	for remaining.raw_value() > 0 {
		addition := CSSPixels.from_raw(if remaining.raw_value() / intrinsic_track_count > 0 {
			remaining.raw_value() / intrinsic_track_count
		} else {
			1
		})
		for index in start .. start + span {
			if index < 0 || index >= tracks.len || !tracks[index].intrinsic
				|| tracks[index].flex != 0 {
				continue
			}
			increase := css_pixels_min(addition, remaining)
			tracks[index].base_size = tracks[index].base_size.plus(increase)
			remaining = remaining.minus(increase)
			if remaining.raw_value() <= 0 {
				return
			}
		}
	}
}

fn collapse_empty_auto_fit_tracks(mut tracks []GridTrack, placements []GridItemPlacement, columns bool) {
	for track_index in 0 .. tracks.len {
		if !tracks[track_index].auto_fit {
			continue
		}
		mut occupied := false
		for placement in placements {
			start := if columns { placement.column } else { placement.row }
			span := if columns { placement.column_span } else { placement.row_span }
			if track_index >= start && track_index < start + span {
				occupied = true
				break
			}
		}
		if !occupied {
			tracks[track_index].base_size = CSSPixels.new(0)
			tracks[track_index].flex = 0
			tracks[track_index].intrinsic = false
			tracks[track_index].auto_max = false
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
			if track.has_growth_limit
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
			if !tracks[index].has_growth_limit
				|| tracks[index].base_size.raw_value() >= tracks[index].growth_limit.raw_value() {
				continue
			}
			growth := css_pixels_min(share,
				tracks[index].growth_limit.minus(tracks[index].base_size))
			tracks[index].base_size = tracks[index].base_size.plus(growth)
			distributed = distributed.plus(growth)
		}
		if distributed.raw_value() <= 0 {
			return
		}
		remaining = remaining.minus(distributed)
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
		mut leftover_space := available_size.minus(gap.scaled(f64(if tracks.len > 0 {
			tracks.len - 1
		} else {
			0
		})))
		mut flex_factor_sum := 0.0
		for index, track in tracks {
			if treated_as_inflexible[index] || track.flex <= 0 {
				leftover_space = leftover_space.minus(track.base_size)
			} else {
				flex_factor_sum += track.flex
			}
		}
		if flex_factor_sum < 1 {
			flex_factor_sum = 1
		}
		flex_fraction := leftover_space.to_double() / flex_factor_sum
		mut need_to_restart := false
		for index, track in tracks {
			if treated_as_inflexible[index] || track.flex <= 0 {
				continue
			}
			scaled_fraction := CSSPixels.nearest_value_for(track.flex * flex_fraction)
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
			scaled_fraction := CSSPixels.nearest_value_for(tracks[index].flex * flex_fraction)
			if scaled_fraction.raw_value() > tracks[index].base_size.raw_value() {
				tracks[index].base_size = scaled_fraction
			}
		}
		return
	}
}

fn grid_item_outer_block_contribution(item &Node, item_state &UsedValues, percentage_basis CSSPixels) CSSPixels {
	mut contribution := item_state.margin_box_height()
	maximum := item.computed_values().size_value(.max_height)
	if !maximum.is_none() && !(maximum.contains_percentage() && percentage_basis.raw_value() == 0) {
		if maximum_size := resolve_layout_size(item, maximum, percentage_basis) {
			contribution = css_pixels_min(contribution, maximum_size)
		}
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
	if constraint == .min_content && preferred_behaves_as_auto
		&& flex_item_is_scroll_container(item) {
		styled := item.as_node_with_style() or { return CSSPixels.new(0) }
		mut item_state := state.get_mutable(styled)
		containing_width := if containing := item_state.containing_block_used_values() {
			containing.content_width()
		} else {
			CSSPixels.new(0)
		}
		resolve_box_model_edges(styled.computed_values(), mut item_state,
			containing_width.to_double())
		return flex_or_grid_item_outer_inline_edges(item_state)
	}
	return intrinsic_outer_width_contribution(mut state, box, constraint)
}

fn run_grid_formatting_context(mut state LayoutState, container &Node, mut container_state UsedValues, available_space AvailableSpace) FormattingContextResult {
	// An inline grid is materialized as an atomic inline box. LibWeb retains
	// zero-sized paintables for its otherwise-skippable anonymous whitespace
	// children after the atomic inline sizing passes, although they do not
	// participate in grid placement.
	if container.display().is_inline_outside() {
		for child in container.children() {
			if !can_skip_anonymous_text_run(child) {
				continue
			}
			if styled := child.as_node_with_style() {
				state.get_mutable(styled)
			}
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
	column_gap := resolve_layout_gap(container, .column_gap, container_width)
	row_gap := resolve_layout_gap(container, .row_gap, container_width)
	template_columns := container.computed_values().grid_template_columns()
	template_rows := container.computed_values().grid_template_rows()
	row_basis := if container_state.has_definite_height() {
		container_state.content_height()
	} else {
		CSSPixels.new(0)
	}
	areas := container.computed_values().grid_template_areas()
	column_lines := grid_lines_for_definition(container, template_columns, container_width,
		column_gap, true, areas, true)
	row_lines := grid_lines_for_definition(container, template_rows, row_basis, row_gap,
		container_state.has_definite_height(), areas, false)
	explicit_column_count := if column_lines.len > 0 { column_lines.len - 1 } else { 0 }
	explicit_row_count := if row_lines.len > 0 { row_lines.len - 1 } else { 0 }
	placement_result := place_grid_items(container, column_lines, row_lines)
	placements := placement_result.placements
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
	mut columns := resolve_grid_tracks(container, template_columns,
		container.computed_values().grid_auto_columns(), container_width, column_gap,
		!width_is_intrinsic, placement_result.implicit_columns_before, required_columns)
	collapse_empty_auto_fit_tracks(mut columns, placements, true)

	// Size intrinsic columns from non-spanning items first, then process
	// spanning items in increasing span order as required by track sizing.
	mut intrinsic_flex_fraction := 0.0
	for placement in placements {
		if placement.column_span != 1 || placement.column >= columns.len
			|| (!columns[placement.column].intrinsic && !(available_space.width.is_max_content()
			&& columns[placement.column].flex > 0)) {
			continue
		}
		track := columns[placement.column]
		contribution_constraint := if available_space.width.is_max_content() {
			SizeConstraint.max_content
		} else if track.max_content_max {
			.max_content
		} else {
			.min_content
		}
		contribution := grid_intrinsic_outer_width_contribution(mut state, placement.item,
			contribution_constraint)
		if track.intrinsic {
			mut new_base_size := css_pixels_max(columns[placement.column].base_size, contribution)
			if columns[placement.column].auto_min && columns[placement.column].has_growth_limit {
				if item_styled := placement.item.as_node_with_style() {
					item_values := state.get(item_styled)
					limited_growth :=
						columns[placement.column].growth_limit.plus(flex_or_grid_item_outer_inline_edges(item_values))
					new_base_size = css_pixels_min(new_base_size, limited_growth)
				}
			}
			columns[placement.column].base_size = new_base_size
		}
		if track.auto_max || track.max_content_max || track.fit_content_max {
			mut maximum_contribution := grid_intrinsic_outer_width_contribution(mut state,
				placement.item, .max_content)
			if track.fit_content_max && track.has_fit_content_limit {
				maximum_contribution = css_pixels_min(maximum_contribution, track.fit_content_limit)
			}
			columns[placement.column].growth_limit = if columns[placement.column].has_growth_limit {
				css_pixels_max(columns[placement.column].growth_limit, maximum_contribution)
			} else {
				maximum_contribution
			}
			columns[placement.column].has_growth_limit = true
		}
		if available_space.width.is_max_content() && track.flex > 0 {
			candidate := contribution.to_double() / track.flex
			if candidate > intrinsic_flex_fraction {
				intrinsic_flex_fraction = candidate
			}
		}
		if columns[placement.column].has_growth_limit {
			columns[placement.column].growth_limit = css_pixels_max(columns[placement.column].growth_limit,
				columns[placement.column].base_size)
		}
	}
	mut maximum_column_span := 1
	for placement in placements {
		if placement.column_span > maximum_column_span {
			maximum_column_span = placement.column_span
		}
	}
	for index in 0 .. columns.len {
		if columns[index].has_growth_limit {
			columns[index].growth_limit = css_pixels_max(columns[index].growth_limit,
				columns[index].base_size)
		}
	}
	if width_is_intrinsic && available_space.width.is_max_content() && intrinsic_flex_fraction > 0 {
		for index in 0 .. columns.len {
			if columns[index].flex > 0 {
				columns[index].base_size = css_pixels_max(columns[index].base_size,
					CSSPixels.nearest_value_for(intrinsic_flex_fraction * columns[index].flex))
			}
		}
	}
	for span in 2 .. maximum_column_span + 1 {
		for placement in placements {
			if placement.column_span != span {
				continue
			}
			contribution := grid_intrinsic_outer_width_contribution(mut state, placement.item,
				.min_content)
			distribute_grid_item_minimum_across_intrinsic_tracks(mut columns, placement.column,
				placement.column_span, column_gap, contribution)
		}
	}
	mut column_space_before_growth := column_gap.scaled(f64(if columns.len > 0 {
		columns.len - 1
	} else {
		0
	}))
	for column in columns {
		column_space_before_growth = column_space_before_growth.plus(column.base_size)
	}
	grow_grid_tracks_to_limits(mut columns, container_width.minus(column_space_before_growth))
	if !width_is_intrinsic {
		expand_flexible_grid_tracks(mut columns, container_width, column_gap)
	}
	mut columns_before_alignment := column_gap.scaled(f64(if columns.len > 0 {
		columns.len - 1
	} else {
		0
	}))
	for column in columns {
		columns_before_alignment = columns_before_alignment.plus(column.base_size)
	}
	if container.computed_values().justify_content() in [.normal, .stretch] {
		stretch_auto_grid_tracks(mut columns, container_width.minus(columns_before_alignment))
	}
	column_leading_space, effective_column_gap := grid_inline_content_geometry(container,
		container_width, columns, column_gap)
	mut intrinsic_container_width := effective_column_gap.scaled(f64(if columns.len > 0 {
		columns.len - 1
	} else {
		0
	}))
	for column in columns {
		intrinsic_container_width = intrinsic_container_width.plus(column.base_size)
	}
	if width_is_intrinsic {
		container_state.set_content_width(intrinsic_container_width)
	}

	mut rows := resolve_grid_tracks(container, template_rows,
		container.computed_values().grid_auto_rows(), row_basis, row_gap,
		container_state.has_definite_height(), placement_result.implicit_rows_before, if required_rows > 0 {
		required_rows
	} else {
		1
	})
	collapse_empty_auto_fit_tracks(mut rows, placements, false)
	for placement in placements {
		area_width := grid_track_range_size(columns, placement.column, placement.column_span,
			effective_column_gap)
		styled := placement.item.as_node_with_style() or { continue }
		mut item_state := state.get_mutable(styled)
		item_state.set_containing_block_used_values(container_state)
		resolve_box_model_edges(styled.computed_values(), mut item_state, area_width.to_double())
		inline_alignment := grid_inline_alignment(container, placement.item)
		width_is_auto := placement.item.computed_values().size_value(.width).is_auto()
		has_auto_inline_margin := property_is_auto(placement.item.computed_values(), .margin_left)
			|| property_is_auto(placement.item.computed_values(), .margin_right)
		mut forced_width := if placement.item.is_table_wrapper() {
			?CSSPixels(compute_table_wrapper_content_width(mut state, placement.item, mut
				item_state, area_width))
		} else if inline_alignment in [.normal, .stretch] && width_is_auto
			&& !placement.item.is_replaced_box() && !placement.item.is_table_wrapper()
			&& !has_auto_inline_margin {
			?CSSPixels(area_width.minus(flex_or_grid_item_outer_inline_edges(item_state)))
		} else if width_is_auto && !placement.item.is_replaced_box() {
			if box := placement.item.as_box() {
				?CSSPixels(calculate_fit_content_width(mut state, box,
					AvailableSize.make_definite(area_width)))
			} else {
				?CSSPixels(none)
			}
		} else {
			resolve_layout_content_size(placement.item,
				placement.item.computed_values().size_value(.width), area_width, item_state, true)
		}
		if width := forced_width {
			forced_width =
				clamp_layout_content_size(placement.item, width, area_width, item_state, true)
		}
		item_state = layout_independent_child(mut state, placement.item, mut container_state,
			area_width, if container_state.has_definite_height() {
			container_state.content_height()
		} else {
			none
		}, forced_width, none)
		if placement.row_span == 1 && placement.row < rows.len && (rows[placement.row].intrinsic
			|| (available_space.height.is_intrinsic_sizing_constraint()
			&& rows[placement.row].flex > 0)) {
			outer_block_contribution := grid_item_outer_block_contribution(placement.item,
				item_state, row_basis)
			minimum_block_contribution := if rows[placement.row].auto_min
				&& placement.item.computed_values().overflow_y() in [.hidden, .scroll, .auto_] {
				flex_or_grid_item_outer_block_edges(item_state)
			} else {
				outer_block_contribution
			}
			mut new_base_size := css_pixels_max(rows[placement.row].base_size,
				minimum_block_contribution)
			if rows[placement.row].auto_min && rows[placement.row].has_growth_limit {
				limited_growth :=
					rows[placement.row].growth_limit.plus(flex_or_grid_item_outer_block_edges(item_state))
				new_base_size = css_pixels_min(new_base_size, limited_growth)
			}
			rows[placement.row].base_size = new_base_size
			if rows[placement.row].auto_max || rows[placement.row].max_content_max
				|| rows[placement.row].fit_content_max {
				mut maximum_contribution := outer_block_contribution
				if rows[placement.row].fit_content_max && rows[placement.row].has_fit_content_limit {
					maximum_contribution = css_pixels_min(maximum_contribution,
						rows[placement.row].fit_content_limit)
				}
				rows[placement.row].growth_limit = if rows[placement.row].has_growth_limit {
					css_pixels_max(rows[placement.row].growth_limit, maximum_contribution)
				} else {
					maximum_contribution
				}
				rows[placement.row].has_growth_limit = true
			}
			if rows[placement.row].has_growth_limit {
				rows[placement.row].growth_limit = css_pixels_max(rows[placement.row].growth_limit,
					rows[placement.row].base_size)
			}
		}
	}
	mut maximum_row_span := 1
	for placement in placements {
		if placement.row_span > maximum_row_span {
			maximum_row_span = placement.row_span
		}
	}
	for span in 2 .. maximum_row_span + 1 {
		for placement in placements {
			if placement.row_span != span {
				continue
			}
			styled := placement.item.as_node_with_style() or { continue }
			item_state := state.get(styled)
			distribute_grid_item_minimum_across_intrinsic_tracks(mut rows, placement.row,
				placement.row_span, row_gap, grid_item_outer_block_contribution(placement.item,
				item_state, row_basis))
		}
	}
	if container_state.has_definite_height() {
		mut row_space_before_growth := row_gap.scaled(f64(if rows.len > 0 {
			rows.len - 1
		} else {
			0
		}))
		for row in rows {
			row_space_before_growth = row_space_before_growth.plus(row.base_size)
		}
		grow_grid_tracks_to_limits(mut rows,
			container_state.content_height().minus(row_space_before_growth))
		expand_flexible_grid_tracks(mut rows, container_state.content_height(), row_gap)
	}
	if !container_state.has_definite_height() {
		grow_grid_tracks_to_limits(mut rows, CSSPixels.max())
		// With an indefinite available size, the used flex fraction is the
		// largest max-content contribution divided by that track's flex
		// factor. Every flexible track is then sized from that fraction.
		mut flex_fraction := 0.0
		for row in rows {
			if row.flex > 0 {
				candidate := row.base_size.to_double() / row.flex
				if candidate > flex_fraction {
					flex_fraction = candidate
				}
			}
		}
		if flex_fraction > 0 {
			for index in 0 .. rows.len {
				if rows[index].flex > 0 {
					rows[index].base_size = css_pixels_max(rows[index].base_size,
						CSSPixels.nearest_value_for(flex_fraction * rows[index].flex))
				}
			}
		}
	}
	if alignment_height := grid_alignment_height {
		if container.computed_values().align_content() in [.normal, .stretch] {
			mut rows_before_alignment := row_gap.scaled(f64(if rows.len > 0 {
				rows.len - 1
			} else {
				0
			}))
			for row in rows {
				rows_before_alignment = rows_before_alignment.plus(row.base_size)
			}
			stretch_auto_grid_tracks(mut rows, alignment_height.minus(rows_before_alignment))
		}
	}

	mut row_leading_space := CSSPixels.new(0)
	mut effective_row_gap := row_gap
	if alignment_height := grid_alignment_height {
		row_leading_space, effective_row_gap = grid_block_content_geometry(container,
			alignment_height, rows, row_gap)
	}
	mut automatic_height := effective_row_gap.scaled(f64(if rows.len > 0 {
		rows.len - 1
	} else {
		0
	}))
	for row in rows {
		automatic_height = automatic_height.plus(row.base_size)
	}
	for placement in placements {
		styled := placement.item.as_node_with_style() or { continue }
		mut item_state := state.get_mutable(styled)
		area_width := grid_track_range_size(columns, placement.column, placement.column_span,
			effective_column_gap)
		area_height := grid_track_range_size(rows, placement.row, placement.row_span,
			effective_row_gap)
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
		item_state.relative_inset_basis_width_ = grid_area_width
		item_state.relative_inset_basis_height_ = grid_area_height
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
		} else if !placement.item.computed_values().size_value(.height).is_auto() {
			forced_item_height = resolve_layout_content_size(placement.item,
				placement.item.computed_values().size_value(.height), area_height, item_state,
				false)
		}
		if requested_height := forced_item_height {
			clamped_height := clamp_layout_content_size(placement.item, requested_height,
				area_height, item_state, false)
			item_state = layout_independent_child(mut state, placement.item, mut container_state,
				area_width, if container_state.has_definite_height() {
				container_state.content_height()
			} else {
				none
			}, item_state.content_width(), clamped_height)
		}
		// The anonymous table wrapper shrink-wraps, but the principal table's
		// CSS 2.1 width equation still uses the grid area as its containing
		// inline size upstream. Preserve that consumed end margin separately
		// from the wrapper's own fit-content width.
		resolve_grid_table_wrapper_end_margin(mut state, placement.item, area_width)
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
		area_x := grid_physical_column_offset(container, container_width, columns,
			placement.column, placement.column_span, effective_column_gap, column_leading_space)
		item_state.set_content_x(area_x.plus(item_state.margin_box_left()))
		item_state.set_content_y(row_leading_space.plus(grid_track_offset(rows, placement.row,
			effective_row_gap)).plus(item_state.margin_box_top()))
		grid_area_rect := css.CSSPixelRect.new(area_x.to_double(), row_leading_space.plus(grid_track_offset(rows,
			placement.row, effective_row_gap)).to_double(), grid_area_width.to_double(),
			grid_area_height.to_double())
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
		column_is_auto := grid_axis_is_auto(computed.grid_column_start(),
			computed.grid_column_end())
		row_is_auto := grid_axis_is_auto(computed.grid_row_start(), computed.grid_row_end())
		column_position := resolve_grid_axis_position(computed.grid_column_start(),
			computed.grid_column_end(), column_lines.len, column_lines)
		row_position := resolve_grid_axis_position(computed.grid_row_start(),
			computed.grid_row_end(), row_lines.len, row_lines)

		mut area_x := CSSPixels.new(0).minus(container_state.padding_left)
		mut area_width :=
			container_state.padding_left.plus(container_width).plus(container_state.padding_right)
		if !column_is_auto {
			column := column_position.start + placement_result.implicit_columns_before
			if column >= columns.len {
				area_width = container_state.padding_right
				area_x = grid_physical_column_offset(container, container_width, columns,
					columns.len, 0, effective_column_gap, column_leading_space).minus(if container.computed_values().direction() == .rtl {
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
				area_width = grid_track_range_size(columns, column_start, column_position.span,
					effective_column_gap)
				area_x = grid_physical_column_offset(container, container_width, columns,
					column_start, column_position.span, effective_column_gap, column_leading_space)
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
				area_y = row_leading_space.plus(grid_track_offset(rows,
					if row < 0 { 0 } else { row }, effective_row_gap))
				area_height = grid_track_range_size(rows, if row < 0 { 0 } else { row },
					row_position.span, effective_row_gap)
			}
		}

		rect := css.CSSPixelRect.new(area_x.to_double(), area_y.to_double(),
			area_width.to_double(), area_height.to_double())
		set_grid_abspos_containing_rect(mut state, container, child, rect)
	}
	return FormattingContextResult{
		automatic_content_width:  if width_is_intrinsic {
			intrinsic_container_width
		} else {
			container_width
		}
		automatic_content_height: automatic_height
	}
}
