module layout

import dom
import html

fn chromium_flex_replaced_values(result DocumentLayoutResult, id string) &UsedValues {
	mut pending := [result.root]
	for pending.len > 0 {
		node := pending.pop()
		if dom_node := node.dom_node() {
			if element := dom_node.as_element() {
				if element.get_attribute_value('id') == id {
					styled := node.as_node_with_style() or { panic('missing style') }
					return result.used_values_for(styled) or { panic('missing geometry') }
				}
			}
		}
		for child in node.children() { pending << child }
	}
	panic('missing #${id}')
}

fn chromium_flex_replaced_minimum_widths(policy dom.FontRenderingPolicy) (f64, f64) {
	// Discord's chat image: a replaced item with a percentage width beside an
	// overflow-clipped percentage-width sibling in a shrinking flex row.
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#row { display:flex; align-items:center; width:400px }
		#image { width:100%; max-width:760px; display:block }
		#wrapper { width:100%; overflow:hidden }
	</style><div id="row"><canvas id="image" width="1024" height="781"></canvas><div id="wrapper"></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(policy)
	layout_document_typed_in_viewport(document, 1024, 768)
	result := document_layout_result(document) or { panic('missing layout') }
	return chromium_flex_replaced_values(result, 'image').content_width().to_double(),
		chromium_flex_replaced_values(result, 'wrapper').content_width().to_double()
}

fn test_chromium_replaced_flex_items_keep_their_specified_size_suggestion() {
	// The natural width is the content size suggestion, so min-width:auto
	// stops at the 400px specified size; the scroll container absorbs the
	// whole shrink.
	image, wrapper := chromium_flex_replaced_minimum_widths(.chromium)
	assert image == 400
	assert wrapper == 0
}

fn test_libweb_replaced_flex_items_keep_the_upstream_compressible_minimum() {
	image, wrapper := chromium_flex_replaced_minimum_widths(.libweb)
	assert image == 200
	assert wrapper == 200
}

fn test_chromium_replaced_suggestion_leaves_the_intrinsic_flex_contribution_compressible() {
	// The image's wrapper is itself a shrinkable flex item. Its min-content
	// contribution still treats the percentage-width image as compressible,
	// so the wrapper keeps the space left beside a 276px text column.
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#row { display:flex; gap:34.6px; width:842px }
		#wrapper { flex:0 1 auto; width:100%; display:flex; justify-content:center; align-items:center }
		#image { width:100%; max-width:760px; display:block }
		#clip { width:100%; overflow:hidden }
		#text { width:276px; max-width:276px; flex:0 1 auto }
	</style><div id="row"><div id="wrapper"><canvas id="image" width="1080" height="824"></canvas>
		<div id="clip"></div></div><div id="text"><div style="width:300px"></div></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	layout_document_typed_in_viewport(document, 1024, 768)
	result := document_layout_result(document) or { panic('missing layout') }
	assert chromium_flex_replaced_values(result, 'wrapper').content_width().to_double() == 531.40625
	image := chromium_flex_replaced_values(result, 'image')
	assert image.content_width().to_double() == 531.40625
	assert image.content_height().to_double() == 405.4375
	assert chromium_flex_replaced_values(result, 'clip').content_width().to_double() == 0
}
