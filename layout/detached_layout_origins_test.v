module layout

import dom
import html
import os

fn detached_origins_match_full_rebuild(mut document dom.Document, label string) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before, label
}

// A style change that also rebuilds an element's boxes first records the old
// box as an origin, then the in-place tree update detaches it and records its
// parent. The detached origin no longer stops the incremental pass, also when
// such changes outnumber the limit on separate changes.
fn test_rebuilt_boxes_do_not_stop_incremental_relayout() {
	mut spans := []string{}
	for index in 0 .. 80 {
		spans << '<span id="s${index}">item ${index}</span> '
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px sans-serif}#box{width:300px;height:400px;overflow:hidden;border:1px solid}#other{height:30px}</style><body><div id="box"><p id="line">${spans.join('')}</p></div><div id="other">other</div></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	retained := os.getenv('VOX_RETAIN_DETACHED_LAYOUT_ORIGINS') != ''
	enabled := os.getenv('VOX_DISABLE_INCREMENTAL_LAYOUT') == ''
	for step in ['one', 'many'] {
		count := if step == 'one' { 1 } else { 80 }
		before := incremental_layout_pass_count()
		for index in 0 .. count {
			mut span := document.get_element_by_id('s${index}') or { panic('s${index}') }
			span.set_attribute_value('style', if step == 'one' {
				'display:inline-block'
			} else {
				'display:inline-block;color:red'
			})
		}
		document.update_layout(.debugging)
		if enabled {
			if retained {
				assert incremental_layout_pass_count() == before, step
			} else {
				assert incremental_layout_pass_count() > before, step
			}
		}
		detached_origins_match_full_rebuild(mut document, step)
	}
}
