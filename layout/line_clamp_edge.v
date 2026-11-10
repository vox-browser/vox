// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import css

// Ladybird 715cb96bf184: commit the formatting context's clamp edge with
// layout geometry. A float keeps its size; only the part before that edge
// paints. Store the clip relative to the float's border box so retained paint
// projection can move the whole context without rediscovering its ancestry.
fn commit_line_clamp_edges(mut state LayoutState, root &Node) {
	commit_line_clamp_edges_in_subtree(mut state, root, none)
}

fn line_clamp_area_before_block_end(node &Node, state &LayoutState, used &UsedValues) css.CSSPixelRect {
	position := paint_cumulative_offset(node, state, used)
	// Keep ample room on the unbounded sides without saturating CSSPixels.
	extent := f64(css.css_pixels_max_dimension_value) / 4
	if node.computed_values().writing_mode() == .horizontal_tb {
		return css.CSSPixelRect.new(-extent, -extent, extent * 2,
			extent + position.y().to_double() + used.content_height().to_double())
	}
	if layout_block_axis_is_reverse(node.computed_values().writing_mode()) {
		return css.CSSPixelRect.new(position.x().to_double(), -extent,
			extent - position.x().to_double(), extent * 2)
	}
	return css.CSSPixelRect.new(-extent, -extent,
		extent + position.x().to_double() + used.content_width().to_double(), extent * 2)
}

fn commit_line_clamp_edges_in_subtree(mut state LayoutState, node &Node,
	ancestor_clip ?css.CSSPixelRect) {
	mut child_clip := ancestor_clip
	if styled := node.as_node_with_style() {
		if original_used := state.try_get(styled) {
			mut used := state.get_mutable(styled)
			if original_used.is_invisible_for_line_clamp() {
				used.set_clip_decided_by_parent(css.CSSPixelRect{})
				return
			}
			used.set_clip_decided_by_parent(none)
			if node.is_floating() {
				if clip := ancestor_clip {
					position := paint_cumulative_offset(node, state, used)
					border_x := position.x().minus(used.padding_left).minus(used.border_left)
					border_y := position.y().minus(used.padding_top).minus(used.border_top)
					used.set_clip_decided_by_parent(css.CSSPixelRect{
						x: clip.x.minus(border_x)
						y: clip.y.minus(border_y)
						width: clip.width
						height: clip.height
					})
				}
			}
			// Each independent formatting context owns its floats. In particular,
			// a float which clamps its own lines does not clip its own padding.
			if used.has_line_clamp_point() {
				child_clip = line_clamp_area_before_block_end(node, state, used)
			} else if creates_block_formatting_context(styled)
				|| !node.display().is_flow_inside() {
				child_clip = none
			}
		}
	}
	for child in node.children() {
		commit_line_clamp_edges_in_subtree(mut state, child, child_clip)
	}
}
