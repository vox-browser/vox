module layout

import html

fn test_typed_paint_adapter_omits_atomic_inline_truncated_after_an_ellipsis() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#target { width: 100px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap }
	</style><div id="target">This text is long enough to overflow<img id="atomic" src="" width="20" height="20"></div>')
	root := layout_document_typed_in_viewport(document, 320, 120)
	target := document.get_element_by_id('target') or { panic('missing target') }
	target_box := root.find_box(i64(target.as_node().unique_id())) or { panic('missing target box') }
	assert target_box.lines.len == 1
	assert target_box.lines[0].fragments.len == 1
	run := target_box.lines[0].fragments[0].paintable_fragment.glyph_run or {
		panic('missing ellipsized glyph run')
	}
	assert run.glyphs_.last().code_point == u32(0x2026)

	atomic_element := document.get_element_by_id('atomic') or { panic('missing atomic inline') }
	assert root.find_box(i64(atomic_element.as_node().unique_id())) == none
}
