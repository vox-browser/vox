module layout

import dom
import html

fn hit_identity(hit ?dom.HitTestResult) string {
	value := hit or { return 'none' }
	return '${voidptr(value.node)}:${voidptr(value.element)}:${value.index_in_node}'
}

fn assert_culled_hits_match(document &dom.Document, width int, height int, step int) int {
	target := voidptr(document_layout_result(document) or { panic('missing result') })
	mut compared := 0
	for y := 0; y < height; y += step {
		for x := 0; x < width; x += step {
			for offset in [0.0, 0.5, 0.75] {
				px := f64(x) + offset
				py := f64(y) + offset
				culled := viewport_hit_test_with_culling(target, px, py, .exact, true)
				full := viewport_hit_test_with_culling(target, px, py, .exact, false)
				assert hit_identity(culled) == hit_identity(full), 'x=${px} y=${py}'
				compared++
			}
		}
	}
	return compared
}

// Culled exact queries return the same node, element and text offset as the
// full reverse walk across text, nested tables and spacer images, a scrolled
// overflow container with its scrollbar chrome, transforms, clips, positioned,
// fixed and pointer-events:none content.
fn test_culled_exact_hits_match_the_full_walk() {
	mut rows := ''
	for index in 0 .. 40 {
		rows += '<tr><td><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width="${index * 4}" height="1"></td><td><span class="c"><a href="#a${index}">user${index}</a> | <u>reply</u></span><div class="t">comment text ${index} with several words that wrap</div></td></tr>'
	}
	source := '<!doctype html><style>html,body{margin:0}td{padding:2px}.t{width:120px}#scroller{height:50px;overflow:scroll;width:150px}#scroller p{margin:0;height:20px}#turned{transform:rotate(12deg) translate(30px,5px);width:90px}#clipped{overflow:hidden;width:30px;height:16px;white-space:nowrap}#abs{position:absolute;left:180px;top:40px;width:40px;height:40px;background:red}#fixed{position:fixed;left:200px;top:5px;width:30px;height:30px;background:blue}#ghost{position:absolute;left:150px;top:10px;width:80px;height:80px;pointer-events:none;background:green}</style><div id="scroller">' + '<p>row</p>'.repeat(8) + '</div><div id="turned"><span>turned text</span></div><div id="clipped">clipped overflowing text here</div><div id="abs"></div><div id="fixed"></div><div id="ghost"></div><table>${rows}</table>'
	mut document := html.parse_document(source)
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 260, 200)
	mut scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	scroller.set_scroll_top(30)
	document.update_layout(.debugging)
	_ = document.record_viewport_display_list() or { panic('missing list') }
	mut compared := assert_culled_hits_match(document, 260, 200, 7)
	result := document_layout_result(document) or { panic('missing result') }
	assert result.hit_test_culling.valid
	assert result.hit_test_culling.blocks.any(!it.scan && !it.empty)
	// Viewport scrolling keeps the bounds; points map through the new offset.
	for y in [f64(120), 333.5, 900] {
		document.set_viewport_rect(dom.Rect{0, y, 260, 200})
		_ = document.record_viewport_display_list() or { panic('missing list') }
		compared += assert_culled_hits_match(document, 260, 200, 9)
	}
	// A layout change advances the paint revision and rebuilds the bounds.
	revision := result.hit_test_culling.revision
	mut abs := document.get_element_by_id('abs') or { panic('missing abs') }
	abs.set_attribute_value('style', 'left:20px;top:300px;width:200px;height:60px')
	document.update_layout(.debugging)
	_ = document.record_viewport_display_list() or { panic('missing list') }
	compared += assert_culled_hits_match(document, 260, 200, 9)
	current := document_layout_result(document) or { panic('missing result') }
	assert current.hit_test_culling.revision != revision || voidptr(current) != voidptr(result)
	assert compared > 2000
}

fn test_text_cursor_hits_do_not_use_culling() {
	mut document := html.parse_document('<!doctype html><style>html,body,p{margin:0}p{line-height:20px}</style><p contenteditable>first line</p><p>second</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	_ = document.record_viewport_display_list() or { panic('missing list') }
	target := voidptr(document_layout_result(document) or { panic('missing result') })
	for point in [[f64(300), 5]!, [f64(5), 90]!, [f64(150), 30]!] {
		culled := viewport_hit_test_with_culling(target, point[0], point[1], .text_cursor, true)
		full := viewport_hit_test_with_culling(target, point[0], point[1], .text_cursor, false)
		assert hit_identity(culled) == hit_identity(full)
	}
}
