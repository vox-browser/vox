// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module layout

import dom

// Ladybird 04369cdad5e8b6db5bd996823ba70c299fd16e54. A hit inside a
// block container's padding belongs to its own closest line, including when
// that box is an atomic inline. Replaced/empty boxes retain the box fallback.
fn compatibility_caret_in_box_lines(box &BlockBox,
	mut memo CompatibilityHitPointMemo) ?dom.HitTestResult {
	if !box.paintable_with_lines { return none }
	local := if box.stacking_context {
		memo.local(box.accumulated_visual_context_index) or { return none }
	} else {
		memo.local(box.accumulated_visual_context_for_descendants_idx) or { return none }
	}
	mut closest := ?dom.HitTestResult(none)
	mut best_block_distance := f64(0)
	mut best_inline_distance := f64(0)
	for line in box.lines {
		for fragment in line.fragments {
			if fragment.layout_handle == unsafe { nil } { continue }
			node := unsafe { &Node(fragment.layout_handle) }
			if !node.is_text_node() || node.user_select_used_value() == .none_
				|| node.computed_values().visibility() != .visible { continue }
			source := node.dom_node() or { continue }
			if !source.is_text() { continue }
			paintable := fragment.paintable_fragment
			x := paintable.offset.x + paintable.containing_block_offset.x
			y := paintable.offset.y + paintable.containing_block_offset.y
			right := x + paintable.size.width
			bottom := y + paintable.size.height
			horizontal := paintable.orientation == .horizontal
			block_point := if horizontal { local.y } else { local.x }
			block_low := if horizontal { y } else { x }
			block_high := if horizontal { bottom } else { right }
			inline_point := if horizontal { local.x } else { local.y }
			inline_low := if horizontal { x } else { y }
			inline_high := if horizontal { right } else { bottom }
			block_distance := if block_point < block_low { block_low - block_point } else if block_point > block_high { block_point - block_high } else { 0.0 }
			inline_distance := if inline_point < inline_low { inline_low - inline_point } else if inline_point > inline_high { inline_point - inline_high } else { 0.0 }
			if closest != none && (block_distance > best_block_distance
				|| (block_distance == best_block_distance && inline_distance >= best_inline_distance)) { continue }
			block_reversed := !horizontal
				&& box.writing_mode in [.vertical_rl, .sideways_rl]
			before_line := if block_reversed { block_point >= block_high } else { block_point < block_low }
			after_line := if block_reversed { block_point < block_low } else { block_point >= block_high }
			offset := if before_line {
				paintable.start_offset
			} else if after_line {
				paintable.source_end_offset()
			} else if inline_point <= inline_low {
				paintable.start_offset
			} else if inline_point >= inline_high {
				paintable.source_end_offset()
			} else {
				paintable.index_in_node_for_point(local)
			}
			caret_rect := compatibility_caret_rect_for_fragment(box, paintable, offset,
				memo.tree, memo.snapshot)
			closest = compatibility_hit_test_result_for_node(source, offset, f64(0), f64(0), caret_rect)
			best_block_distance = block_distance
			best_inline_distance = inline_distance
		}
	}
	return closest
}
