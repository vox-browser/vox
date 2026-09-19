module html

import editing
import dom

fn test_mutation_tracked_replacement_endpoints_relocate_for_text_merges() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut parent := document.create_element('div') or { panic(err) }
	left := document.create_text_node('abc')
	right := document.create_text_node('def')
	parent_node := parent.as_node()
	mut mutable_parent := unsafe { &dom.Node(parent_node) }
	mutable_parent.append_child(left.as_node()) or { panic(err) }
	mutable_parent.append_child(right.as_node()) or { panic(err) }

	baseline := editing.MutationTrackedRange.ranges().len
	live_range_baseline := dom.Range.live_ranges().len
	mut endpoints := editing.ReplacementEndpoints.new(dom.BoundaryPoint{
		node: left.as_node()
		offset: 2
	}, dom.BoundaryPoint{
		node: right.as_node()
		offset: 0
	})
	assert editing.MutationTrackedRange.ranges().len == baseline + 2
	assert dom.Range.live_ranges().len == live_range_baseline + 2

	endpoints.prepare_for_merging_left_text_into_right(left, right, 3)
	assert endpoints.start().node == right.as_node()
	assert endpoints.start().offset == 2
	assert endpoints.end().node == right.as_node()
	assert endpoints.end().offset == 3

	endpoints.set_start(dom.BoundaryPoint{ node: right.as_node(), offset: 1 })
	endpoints.set_end(dom.BoundaryPoint{ node: left.as_node(), offset: 2 })
	mut merged_left := unsafe { &dom.Text(left) }
	merged_left.append_data('def') or { panic(err) }
	endpoints.prepare_for_merging_right_text_into_left(left, right, 3)
	assert endpoints.start().node == left.as_node()
	assert endpoints.start().offset == 4
	assert endpoints.end().node == left.as_node()
	assert endpoints.end().offset == 2

	endpoints.release()
	assert editing.MutationTrackedRange.ranges().len == baseline
	assert dom.Range.live_ranges().len == live_range_baseline
}
