module layout

import os

// Automatic height answers. A column flex container lays each item out with
// an automatic height at the item's used width, and then asks for the item's
// max-content height to find its flex base size. That question lays the
// item's whole subtree out again in a throwaway state, at the same width and
// again without a height: every box below nested column containers was laid
// out once more for each such ancestor on a changed path.
//
// The inner layout that just ran already produced the answer. Remember the
// automatic content height of the last inner layout that ran at a definite
// width with no height at all, and let it answer the max-content height
// question for the same box at the same width.
//
// Only block containers answer. The measurement runs the box's own
// formatting context in intrinsic-sizing mode, and a flex or grid container
// sizes and wraps its items differently there (a wrapping row inside a
// clipped navigation bar measures both of its lines). A block formatting
// context lays its block-level children and lines out alike in both modes;
// line clamping, which counts lines differently, keeps the measurement.
const disable_automatic_height_answers = os.getenv('VOX_DISABLE_AUTOMATIC_HEIGHT_ANSWERS') != ''
// Runs the measurement as well and reports every answer it disagrees with.
const verify_automatic_height_answers = os.getenv('VOX_VERIFY_AUTOMATIC_HEIGHT_ANSWERS') != ''

__global automatic_height_answer_counts [3]u64
// Tests compare a layout with answers against one that measures everything.
__global automatic_height_answers_suspended bool

// Answers given, measurements run without an answer, and (when verifying)
// answers the measurement disagreed with, in this process.
pub fn automatic_height_answer_statistics() (u64, u64, u64) {
	return automatic_height_answer_counts[0], automatic_height_answer_counts[1], automatic_height_answer_counts[2]
}

fn report_automatic_height_answers() {
	if !incremental_layout_diagnostics { return }
	eprintln('VOX_AUTOMATIC_HEIGHT_ANSWERS answered=${automatic_height_answer_counts[0]} measured=${automatic_height_answer_counts[1]} mismatched=${automatic_height_answer_counts[2]}')
}

// Called after an inner layout of `box` at its used content width. The
// answer stands only when nothing gave the box a height: no definite or
// forced height, and an indefinite available height.
fn note_automatic_height_answer(mut state LayoutState, box &Node, box_state &UsedValues,
	available_height AvailableSize, has_height bool, automatic_height CSSPixels) {
	if disable_automatic_height_answers || automatic_height_answers_suspended { return }
	display := box.display()
	if has_height || !available_height.is_indefinite() || box_state.has_definite_height()
		|| box_state.height_constraint != .none || !box.is_block_container()
		|| !(display.is_flow_inside() || display.is_flow_root_inside())
		|| box.computed_values().writing_mode() != .horizontal_tb
		|| line_clamp_is_active(box.computed_values()) {
		state.automatic_height_answer_node_ = unsafe { nil }
		return
	}
	state.automatic_height_answer_node_ = voidptr(box)
	state.automatic_height_answer_width_ = box_state.content_width()
	state.automatic_height_answer_ = automatic_height
}

// The max-content height of `box` at `width`, when the last inner layout of
// this state produced it.
fn automatic_height_answer(mut state LayoutState, box &Box, width CSSPixels) ?CSSPixels {
	if state.automatic_height_answer_node_ != voidptr(box) || state.automatic_height_answer_width_ != width {
		return none
	}
	state.automatic_height_answer_node_ = unsafe { nil }
	return state.automatic_height_answer_
}
