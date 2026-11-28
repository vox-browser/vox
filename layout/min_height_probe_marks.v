module layout

import os
import platform

// BlockFormattingContext::layout_block_level_box() lays an independent
// formatting context with automatic height and a non-auto min-height out once
// at its width and an indefinite height, and gives the real layout the
// minimum as a definite height only when that probe falls short of it. A box
// laid out in that probe is marked as sized by an ancestor's measurement
// (incremental_layout.v), which keeps every relayout root out of it and its
// subtree. Pages commonly wrap their whole content in such a box (an app
// shell with `min-height: 100vh`), so no change inside the page had a root.
//
// When the probe reaches the minimum, the real layout runs with the probe's
// own available space and ignores its result, so it is the same layout as the
// probe. Nothing then depends on the probe beyond what a relayout root's own
// automatic size check verifies: the probe's result is the box's automatic
// height, which no change below an unchanged root can alter. Clear the marks
// the probe itself made in that case. Measurements nested inside the probe
// use their own states and keep theirs.
const retain_min_height_probe_marks = os.getenv('VOX_RETAIN_MIN_HEIGHT_PROBE_MARKS') != ''

__global min_height_probe_state voidptr
__global min_height_probe_marks []voidptr
__global min_height_probe_cleared u64

// Marks cleared after probes the real layout ignored, in this process (tests
// and diagnostics).
pub fn min_height_probe_cleared_mark_count() u64 {
	return min_height_probe_cleared
}

struct MinHeightProbeMarks {
	previous_state voidptr
	start          int
}

fn begin_min_height_probe_marks(probe &LayoutState) MinHeightProbeMarks {
	saved := MinHeightProbeMarks{
		previous_state: min_height_probe_state
		start:          min_height_probe_marks.len
	}
	min_height_probe_state = voidptr(probe)
	return saved
}

// Called before the probe state marks `box` for a normal-mode layout.
fn note_min_height_probe_mark(state &LayoutState, box &Node) {
	if min_height_probe_state == unsafe { nil } || voidptr(state) != min_height_probe_state
		|| box.sized_by_ancestor_measurement_ {
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	min_height_probe_marks << voidptr(box)
}

fn finish_min_height_probe_marks(saved MinHeightProbeMarks, ignored bool) {
	if ignored && !retain_min_height_probe_marks {
		for index in saved.start .. min_height_probe_marks.len {
			mut node := unsafe { &Node(min_height_probe_marks[index]) }
			node.sized_by_ancestor_measurement_ = false
			min_height_probe_cleared++
		}
	}
	min_height_probe_marks.trim(saved.start)
	min_height_probe_state = saved.previous_state
}
