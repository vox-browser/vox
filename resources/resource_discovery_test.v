module main

import css

fn test_scripted_resource_discovery_preserves_dom_base_and_noscript_without_building_unused_sheets() {
	loaded := LoadedPage{url:'https://discovery.test/page',markup:'<!doctype html><base href="/assets/"><style id="sheet">img{display:none}</style><noscript><img src="inert.png"></noscript><img src="content.png"><svg><style id="svg-sheet">path{fill:red}</style></svg>'}
	mut document := parse_page_preload_document(loaded,true)
	defer { document.finalize() }
	assert document.base_url().serialize() == 'https://discovery.test/assets/'
	assert document.is_scripting_enabled_by_embedder()
	for id in ['sheet','svg-sheet'] {
		element := document.get_element_by_id(id) or { panic('missing style element') }
		assert element.as_node().text_content() or { '' } != ''
		style := element.style_element_base() or { panic('missing style model') }
		assert style.sheet() == unsafe { nil }
	}
	assert document_preload_resource_urls(document,document.base_url().serialize()) == ['https://discovery.test/assets/content.png']
}

fn test_non_scripted_resource_discovery_keeps_styles_for_hidden_image_planning() {
	loaded := LoadedPage{url:'https://discovery.test/page',markup:'<!doctype html><style id="sheet">#hidden{display:none}</style><img id="hidden" src="hidden.png"><img src="content.png">'}
	mut document := parse_page_preload_document(loaded,false)
	defer { document.finalize() }
	element := document.get_element_by_id('sheet') or { panic('missing style element') }
	assert element.style_element_base()?.sheet() != unsafe { nil }
	css.sync_document_style_elements(document)
	foreground,background := partition_nonrendered_image_preloads(document,document.base_url().serialize(),document_preload_resource_urls(document,document.base_url().serialize()))
	assert foreground == ['https://discovery.test/content.png']
	assert background == ['https://discovery.test/hidden.png']
}
