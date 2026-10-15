module main

import browserjs
import css
import dom
import html

fn test_scripted_initial_style_read_uses_native_viewport_and_retains_its_layout() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><link rel="stylesheet" href="site.css"><style>html,body{margin:0}#target{width:10vw;height:25vh}@media(min-width:900px){#target{width:50vw}}</style><div id="target">viewport</div>',
		dom.URL{value:'https://initial-viewport.test/page'}, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	sheet := 'https://initial-viewport.test/site.css'
	mut app := BrowserApp{
		document: document
		js_runtime: runtime
		layout_tree_only: true
		viewport_width: 1024
		viewport_height: 656
		resource_cache: {sheet: PreloadedResource{url:sheet,body:'@media(min-height:650px){#target{font-size:22px}}'}}
	}
	// Match install_loaded_page: the cosmetic stylesheet precedes any script query.
	install_browser_adblock_styles(document, '')!
	loaded := app.preload_initial_document_resources(document.base_url().serialize())
	assert loaded[sheet].body.contains('min-height')
	assert document.viewport_rect().width == 1024
	assert document.viewport_rect().height == 656
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const firstViewportStyle=getComputedStyle(document.getElementById("target"));
globalThis.initialViewportWidth=firstViewportStyle.width;
globalThis.initialViewportHeight=firstViewportStyle.height;
globalThis.initialViewportFontSize=firstViewportStyle.fontSize;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('initialViewportWidth')! == '512px'
	assert runtime.evaluate_host('initialViewportHeight')! == '164px'
	assert runtime.evaluate_host('initialViewportFontSize')! == '22px'
	window_pointer := document.get_window() or { panic('missing native Window') }
	window := unsafe { &html.WindowModel(window_pointer) }
	assert window.inner_width() == 1024
	assert window.inner_height() == 656
	assert window.match_media('(min-width:900px) and (min-height:650px)').matches()
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert target.get_bounding_client_rect().width == 512
	assert target.get_bounding_client_rect().height == 164
	before := document.layout_root
	style := css.computed_properties_for_element(target) or { panic('missing computed style') }
	app.relayout(1024, 656 + app.chrome_height())
	assert voidptr(document.layout_root) == voidptr(before)
	assert voidptr(css.computed_properties_for_element(target) or { panic('missing retained style') }) == voidptr(style)
	assert target.get_bounding_client_rect().width == 512
}

fn test_initial_preload_installs_fallback_viewport_for_both_scripting_policies() {
	for scripting_enabled in [true, false] {
		mut document := parse_browser_navigation_document('<!doctype html><div>fallback viewport</div>',
			dom.URL{value:'https://initial-viewport.test/'}, none)
		document.set_scripting_enabled_by_embedder(scripting_enabled)
		mut app := BrowserApp{document:document}
		loaded := app.preload_initial_document_resources(document.url.serialize())
		assert loaded.len == 0
		assert document.viewport_rect().width == initial_width
		assert document.viewport_rect().height == initial_height - app.chrome_height()
		document.finalize()
	}
}
