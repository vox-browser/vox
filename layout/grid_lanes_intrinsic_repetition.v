module layout

import css

// Intrinsic lane repetitions can use definite item contributions even when
// their track sizing function itself is auto or content based. Other items
// keep the ordinary intrinsic sizing path until their contribution is known.
fn grid_lanes_definite_repeat_item_size(container &Node, horizontal bool) ?CSSPixels {
	if !container.display().is_grid_lanes_inside() || grid_lanes_axis_is_horizontal(container) != horizontal {
		return none
	}
	mut maximum := CSSPixels.new(0)
	for item in ordered_grid_items(container) {
		style := item.computed_values()
		preferred := style.size_value(if horizontal { css.PropertyID.width } else { .height })
		if !preferred.is_length() || preferred.contains_percentage() { return none }
		mut size := resolve_layout_size(item, preferred, CSSPixels.new(0)) or { return none }
		minimum := style.size_value(if horizontal { css.PropertyID.min_width } else { .min_height })
		limit := style.size_value(if horizontal { css.PropertyID.max_width } else { .max_height })
		if minimum.contains_percentage() || limit.contains_percentage() { return none }
		if !limit.is_none() {
			if value := resolve_layout_size(item, limit, CSSPixels.new(0)) {
				size = css_pixels_min(size, value)
			}
		}
		if !minimum.is_auto() {
			if value := resolve_layout_size(item, minimum, CSSPixels.new(0)) {
				size = css_pixels_max(size, value)
			}
		}
		for property in [css.PropertyID.margin_left, .margin_right, .margin_top, .margin_bottom,
			.padding_left, .padding_right, .padding_top, .padding_bottom] {
			if value := style.property(property, .yes) {
				if value.css_text.contains('%') { return none }
			}
		}
		edges := style.resolved_box_model_edges(0)
		if horizontal {
			size = size.plus(edges.margin_left).plus(edges.margin_right)
			if style.box_sizing() != .border_box {
				size = size.plus(edges.padding_left).plus(edges.padding_right).plus(edges.border_left).plus(edges.border_right)
			}
		} else {
			size = size.plus(edges.margin_top).plus(edges.margin_bottom)
			if style.box_sizing() != .border_box {
				size = size.plus(edges.padding_top).plus(edges.padding_bottom).plus(edges.border_top).plus(edges.border_bottom)
			}
		}
		maximum = css_pixels_max(maximum, size)
	}
	return maximum
}

fn grid_lanes_repeat_reads_items(container &Node, list css.GridTrackSizeList, basis CSSPixels) bool {
	if !container.display().is_grid_lanes_inside() { return false }
	for track in list.track_list() {
		if !track.is_repeat() { continue }
		repeat := track.repeat()
		if !repeat.is_fixed() {
			for inner in repeat.grid_track_size_list().track_list() {
				if definite_grid_track_size(container, inner, basis) == none { return true }
			}
		}
		if grid_lanes_repeat_reads_items(container, repeat.grid_track_size_list(), basis) {
			return true
		}
	}
	return false
}
