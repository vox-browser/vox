// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/ReplacementEndpoints.{h,cpp}.
module editing

import dom

@[heap]
pub struct ReplacementEndpoints {
	start_ &MutationTrackedRange
	end_   &MutationTrackedRange
}

pub fn ReplacementEndpoints.new(start dom.BoundaryPoint, end dom.BoundaryPoint) &ReplacementEndpoints {
	start_range := dom.Range.create_from_boundary_points(start.node, start.offset, start.node,
		start.offset)
	end_range := dom.Range.create_from_boundary_points(end.node, end.offset, end.node, end.offset)
	return &ReplacementEndpoints{
		start_: MutationTrackedRange.new(start_range)
		end_: MutationTrackedRange.new(end_range)
	}
}

pub fn (endpoints &ReplacementEndpoints) start() dom.BoundaryPoint {
	return endpoints.start_.range().start()
}

pub fn (endpoints &ReplacementEndpoints) end() dom.BoundaryPoint {
	return endpoints.end_.range().start()
}

fn set_collapsed_tracked_range(tracked &MutationTrackedRange, boundary dom.BoundaryPoint) {
	mut range_ := unsafe { &dom.Range(tracked.range()) }
	range_.set_start(boundary.node, boundary.offset) or { return }
	range_.set_end(boundary.node, boundary.offset) or { return }
}

pub fn (mut endpoints ReplacementEndpoints) set_start(start dom.BoundaryPoint) {
	set_collapsed_tracked_range(endpoints.start_, start)
}

pub fn (mut endpoints ReplacementEndpoints) set_end(end dom.BoundaryPoint) {
	set_collapsed_tracked_range(endpoints.end_, end)
}

fn relocate_for_merging_left_text_into_right(endpoint &MutationTrackedRange, left &dom.Text, right &dom.Text, left_length int) {
	mut boundary := endpoint.range().start()
	if boundary.node == right.as_node() && boundary.offset == 0 {
		boundary = dom.BoundaryPoint{
			node: right.as_node()
			offset: left_length
		}
	} else if boundary.node == left.as_node() {
		boundary = dom.BoundaryPoint{
			node: right.as_node()
			offset: boundary.offset
		}
	}
	set_collapsed_tracked_range(endpoint, boundary)
}

fn relocate_for_merging_right_text_into_left(endpoint &MutationTrackedRange, left &dom.Text, right &dom.Text, left_length int) {
	boundary := endpoint.range().start()
	if boundary.node != right.as_node() {
		return
	}
	set_collapsed_tracked_range(endpoint, dom.BoundaryPoint{
		node: left.as_node()
		offset: boundary.offset + left_length
	})
}

pub fn (mut endpoints ReplacementEndpoints) prepare_for_merging_left_text_into_right(left &dom.Text, right &dom.Text, left_length int) {
	relocate_for_merging_left_text_into_right(endpoints.start_, left, right, left_length)
	relocate_for_merging_left_text_into_right(endpoints.end_, left, right, left_length)
}

pub fn (mut endpoints ReplacementEndpoints) prepare_for_merging_right_text_into_left(left &dom.Text, right &dom.Text, left_length int) {
	relocate_for_merging_right_text_into_left(endpoints.start_, left, right, left_length)
	relocate_for_merging_right_text_into_left(endpoints.end_, left, right, left_length)
}

pub fn (mut endpoints ReplacementEndpoints) release() {
	mut start := unsafe { &MutationTrackedRange(endpoints.start_) }
	mut end := unsafe { &MutationTrackedRange(endpoints.end_) }
	start.release()
	end.release()
}
