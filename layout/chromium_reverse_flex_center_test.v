module layout

import html

fn test_chromium_reverse_flex_center_uses_the_physical_truncated_half() {
	for direction in ['ltr', 'rtl'] {
		for flex_direction in ['row', 'row-reverse', 'column', 'column-reverse'] {
			for extent in ['374.265625', '824.265625'] {
				mut document := html.parse_document('<!doctype html><style>
                body{margin:0}#container{display:flex;direction:${direction};flex-direction:${flex_direction};
                justify-content:center;align-items:flex-start;width:800px;height:800px}
                #item{flex:none;width:${extent}px;height:${extent}px}</style>
                <div id="container"><div id="item"></div></div>')
				defer { document.finalize() }
				document.set_font_rendering_policy(.chromium)
				result := run_document_layout(document, 1024, 1024) or { panic('layout failed') }
				element := document.get_element_by_id('item') or { panic('item') }
				bridge := element.as_node().layout_node() or { panic('layout node') }
				node := unsafe { &Node(bridge.layout_handle) }
				used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
				expected := if extent == '374.265625' { 212.859375 } else { -12.125 }
				actual := if flex_direction.starts_with('row') {
					used.offset.x()
				} else {
					used.offset.y()
				}
				assert actual.to_double() == expected
			}
		}
	}
}

fn test_libweb_reverse_flex_center_keeps_upstream_remainder_placement() {
	mut document := html.parse_document('<!doctype html><style>
    body{margin:0}#container{display:flex;flex-direction:row-reverse;justify-content:center;width:800px}
    #item{flex:none;width:374.265625px;height:20px}</style><div id="container"><div id="item"></div></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 1024, 768) or { panic('layout failed') }
	element := document.get_element_by_id('item') or { panic('item') }
	bridge := element.as_node().layout_node() or { panic('layout node') }
	node := unsafe { &Node(bridge.layout_handle) }
	used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
	assert used.offset.x().to_double() == 212.875
}
