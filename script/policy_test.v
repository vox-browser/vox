module main

import browserjs
import dom
import page

fn test_script_policy_launch_overrides_do_not_change_engine_selection() {
	assert parse_launch_options([])!.script_policy == .automatic
	assert parse_launch_options([])!.js_engine == .javascriptcore
	options := parse_launch_options(['--disable-javascript', '--js-engine=libjs', 'page.html'])!
	assert options.script_policy == .disabled && options.js_engine == .libjs
	assert options.js_engine_explicit
	assert !parse_launch_options([])!.js_engine_explicit
	assert parse_launch_options(['--js-engine','javascriptcore'])!.js_engine_explicit
	assert options.source == 'page.html'
	assert parse_launch_options(['--enable-javascript', 'https://wikipedia.org'])!.script_policy == .enabled
	assert parse_launch_options(['--disable-javascript', '--enable-javascript'])!.script_policy == .enabled
}

fn test_html_css_only_document_skips_all_script_sources_and_preserves_other_resources() {
	address := dom.URL{value: 'https://www.wikipedia.org/'}
	mut document := parse_browser_navigation_document_with_scripting('<!doctype html><head><link rel="stylesheet" href="/screen.css"><link rel="modulepreload" href="/module.js"></head><body><noscript><p id="fallback">HTML content</p></noscript><img src="/globe.png"><script src="/app.js"></script><script type="module" src="/module.js"></script><script>let invalid = ;</script><script type="application/json" id="data">{"value":42}</script>', address, none, none, none, 1, false)
	defer { document.finalize() }
	assert document.as_node().is_scripting_disabled()
	assert document.get_element_by_id('fallback') != none
	assert document.get_element_by_id('data')?.as_node().text_content()? == '{"value":42}'
	assert document_preload_resource_urls(document, address.serialize()) == [
		'https://www.wikipedia.org/screen.css', 'https://www.wikipedia.org/globe.png',
	]
	mut messages := []string{}
	sources := script_sources(document, address.serialize(), map[string]PreloadedResource{}, mut messages)
	assert sources == []browserjs.ScriptSource{} && messages == []
}

fn test_wikipedia_install_has_no_runtime_and_next_site_preserves_page_preference() {
	mut owner := page.Page.create(1)!
	mut app := BrowserApp{page_model: owner, layout_tree_only: true, viewport_width: 320, viewport_height: 200}
	markup := '<!doctype html><style>#result{width:73px;height:21px}</style><body onload="missing()"><p id="result">HTML content</p><noscript><b id="fallback">No scripts</b></noscript><script src="http://127.0.0.1:9/never-request.js"></script><script>let invalid = ;</script>'
	app.install_loaded_page(LoadedPage{url: 'https://en.wikipedia.org/wiki/V', markup: markup, content_type: 'text/html'}, false)
	assert app.js_runtime == unsafe { nil }
	assert app.js_messages == []
	assert app.resource_cache.len == 0
	assert owner.is_scripting_enabled()
	assert app.document.get_element_by_id('fallback') != none
	assert app.document.get_element_by_id('result')?.as_node().text_content()? == 'HTML content'
	assert app.document.get_element_by_id('result')?.get_bounding_client_rect().width == 73
	assert !document_has_window_event_handlers(app.document)
	app.install_loaded_page(LoadedPage{url: 'https://other.example/', markup: '<!doctype html><p>Next site</p>', content_type: 'text/html'}, false)
	assert app.document.as_node().is_scripting_enabled()
	assert owner.is_scripting_enabled()
	owner.set_is_scripting_enabled(false)
	app.script_policy = .enabled
	app.install_loaded_page(LoadedPage{url: 'https://www.wikipedia.org/', markup: '<p>Preference wins</p><script>let invalid = ;</script>', content_type: 'text/html'}, false)
	assert app.js_runtime == unsafe { nil }
	assert app.document.as_node().is_scripting_disabled()
	assert !owner.is_scripting_enabled()
	mut document := app.document
	document.finalize()
}

fn test_javascript_override_and_navigation_create_and_release_the_runtime() {
	$if !darwin { return }
	mut owner := page.Page.create(1)!
	mut app := BrowserApp{page_model: owner, layout_tree_only: true, viewport_width: 320, viewport_height: 200}
	markup := '<!doctype html><p id="result">HTML</p><script>result.textContent="JavaScript";</script>'
	app.script_policy = .enabled
	app.install_loaded_page(LoadedPage{url: 'https://www.wikipedia.org/', markup: markup, content_type: 'text/html'}, false)
	assert app.js_runtime != unsafe { nil }
	assert app.document.get_element_by_id('result')?.as_node().text_content()? == 'JavaScript'
	assert app.js_messages == []
	app.script_policy = .automatic
	app.install_loaded_page(LoadedPage{url: 'https://www.wikipedia.org/', markup: markup, content_type: 'text/html'}, false)
	assert app.js_runtime == unsafe { nil }
	assert app.document.get_element_by_id('result')?.as_node().text_content()? == 'HTML'
	app.install_loaded_page(LoadedPage{url: 'https://other.example/', markup: markup, content_type: 'text/html'}, false)
	assert app.js_runtime != unsafe { nil }
	assert app.document.get_element_by_id('result')?.as_node().text_content()? == 'JavaScript'
	app.script_policy = .disabled
	app.install_loaded_page(LoadedPage{url: 'https://other.example/', markup: markup, content_type: 'text/html'}, false)
	assert app.js_runtime == unsafe { nil }
	assert app.document.get_element_by_id('result')?.as_node().text_content()? == 'HTML'
	mut document := app.document
	document.finalize()
}
