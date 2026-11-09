module layout

import css
import dom
import html

fn scroll_query_test_color(element &dom.Element) string {
	style := css.up_to_date_computed_properties_for_element(element)
	return (style.property(.color, .no) or { panic('missing color') }).css_text
}

fn test_scroll_query_snapshots_commit_geometry_and_stay_frozen_between_frames() {
	mut document := html.parse_document('<!doctype html><style>
		#scroller { width:200px;height:100px;overflow:auto;container-type:scroll-state }
		#target { height:300px;color:red }
		@container scroll-state(scrollable:bottom) { #target { color:green } }
	</style><div id="scroller"><div id="target"></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	_ = document.snapshot_scroll_state_queries(true)
	document.update_layout(.debugging)
	scroller := document.get_element_by_id('scroller') or { panic('scroller') }
	target := document.get_element_by_id('target') or { panic('target') }
	assert scroll_query_test_color(target) == 'rgb(0, 128, 0)'
	mut box := scroller.as_node().unsafe_paintable_box() or { panic('scroller paintable') }
	assert box.set_scroll_offset(dom.CSSPixelPoint_{y_: 200})
	assert scroll_query_test_color(target) == 'rgb(0, 128, 0)'
	assert !document.snapshot_scroll_state_queries(true)
	assert document.snapshot_scroll_state_queries(false)
	document.update_layout(.debugging)
	assert scroll_query_test_color(target) == 'rgb(255, 0, 0)'
}
