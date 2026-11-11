module layout

import css

fn grid_repeat_used_box_adjustment(state &LayoutState, node &Node, horizontal bool) CSSPixels {
	if node.computed_values().box_sizing() != .border_box { return CSSPixels.new(0) }
	styled := node.as_node_with_style() or { return CSSPixels.new(0) }
	values := state.get(styled)
	return if horizontal {
		values.border_box_left().plus(values.border_box_right())
	} else {
		values.border_box_top().plus(values.border_box_bottom())
	}
}

// Resolve automatic repetition counts on a disposable copy. Percentage
// padding uses the containing inline size, including for row repetitions;
// resolving it against the row-size placeholder incorrectly supplies zero.
// Keeping the repeat kind preserves auto-fit collapse and line-name behavior.
fn grid_template_with_used_repeat_counts(state &LayoutState, node &Node, definition css.GridTrackSizeList, basis CSSPixels, gap CSSPixels, definite bool, horizontal bool) css.GridTrackSizeList {
	if definite || node.computed_values().box_sizing() != .border_box || definition.is_subgrid() {
		return definition
	}
	mut result := css.GridTrackSizeList.make_none()
	repeat_basis, repeat_definite, minimum_only := grid_repeat_axis_constraint_with_adjustment(node, horizontal, basis, definite, grid_repeat_used_box_adjustment(state, node, horizontal))
	for item in definition.list() {
		if item is css.ExplicitGridTrack {
			if item.is_repeat() {
				repeat := item.repeat()
				if !repeat.is_fixed() {
					count := auto_repeat_count_for_constraint(node, repeat, definition, repeat_basis, gap, repeat_definite, minimum_only, horizontal)
					resolved := css.GridRepeat{ ...repeat, repeat_count_: css.StyleValue(css.IntegerStyleValue.create(count)) }
					result.append_explicit_track(css.ExplicitGridTrack.from_repeat(resolved))
					continue
				}
			}
		}
		result.append(item)
	}
	return result
}
