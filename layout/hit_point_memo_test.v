module layout

import html
import painting

// The per-query memo must give each box exactly the point and clip rejection
// of the uncached ancestor walk, for its own and its descendants' contexts.
fn test_hit_point_memo_matches_uncached_transforms_and_clips() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{height:60px;overflow:scroll}#scroller p{height:30px;margin:0}#turned{transform:rotate(30deg) scale(1.5);width:80px;height:40px}#clipped{overflow:hidden;width:20px;height:20px}#clipped span{display:block;width:90px;height:90px}</style><div id="scroller">' + '<p>row</p>'.repeat(8) + '</div><div id="turned"><span>turned</span></div><div id="clipped"><span>clipped</span></div>' + '<p>tail</p>'.repeat(30))
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 120)
	mut scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	scroller.set_scroll_top(45)
	document.update_layout(.debugging)
	_ = document.record_viewport_display_list() or { panic('missing display list') }
	mut result := document_layout_result(document) or { panic('missing result') }
	viewport_build_hit_test_display_list(voidptr(result))
	tree := &result.visual_context_tree
	snapshot := result.scroll_state_snapshot
	assert tree.nodes.len > 2
	mut rejected := 0
	for point in [painting.Point{10, 20}, painting.Point{30, 95}, painting.Point{25, 110}, painting.Point{300, 5}] {
		mut memo := new_compatibility_hit_point_memo(tree, snapshot, point.x, point.y)
		for _ in 0 .. 2 {
			for entry in result.paint_order {
				box := entry.box
				for index in [box.accumulated_visual_context_index, box.accumulated_visual_context_for_descendants_idx] {
					expected := if index == box.accumulated_visual_context_index {
						paintable_box_transform_point_to_local(box, point, 1.0, tree, snapshot)
					} else {
						paintable_box_transform_point_to_local_for_descendants(box, point, 1.0, tree, snapshot)
					}
					actual := memo.local(index)
					if want := expected {
						got := actual or { panic('memo rejected context ${index}') }
						assert got == want
					} else {
						assert actual == none
						rejected++
					}
				}
			}
		}
		// Out-of-range contexts are rejected like the uncached walk.
		assert memo.local(tree.nodes.len) == none
		assert memo.local(-1) == none
	}
	assert rejected > 0
	// The shared-memo scan returns the same hits as the public queries.
	viewport := document.paintable_box() or { panic('missing viewport') }
	for point in [painting.Point{10, 20}, painting.Point{30, 95}, painting.Point{12, 112}] {
		hit := viewport.hit_test(point.x, point.y, .exact) or { continue }
		again := viewport_hit_test(voidptr(result), point.x, point.y, .exact) or { panic('lost hit') }
		assert voidptr(hit.node) == voidptr(again.node)
	}
}
