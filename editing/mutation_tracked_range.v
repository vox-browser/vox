// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/MutationTrackedRange.{h,cpp}.
module editing

import dom

__global editing_mutation_tracked_ranges map[u64]&dom.Range

@[heap]
pub struct MutationTrackedRange {
	range_ &dom.Range
mut:
	registered_ bool = true
}

pub fn MutationTrackedRange.new(range_ &dom.Range) &MutationTrackedRange {
	tracked := &MutationTrackedRange{
		range_: range_
	}
	editing_mutation_tracked_ranges[u64(voidptr(range_))] = range_
	return tracked
}

pub fn (tracked &MutationTrackedRange) range() &dom.Range {
	return tracked.range_
}

pub fn MutationTrackedRange.ranges() []&dom.Range {
	return editing_mutation_tracked_ranges.values()
}

pub fn (mut tracked MutationTrackedRange) release() {
	if !tracked.registered_ {
		return
	}
	editing_mutation_tracked_ranges.delete(u64(voidptr(tracked.range_)))
	mut range_ := unsafe { &dom.Range(tracked.range_) }
	range_.finalize()
	tracked.registered_ = false
}
