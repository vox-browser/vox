module html

import dom
import page

fn embedder_scripting_document(owner &page.Page, address string) !&dom.Document {
	url := dom.URL{value: address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	return document
}

fn test_embedder_scripting_policy_reaches_node_settings_and_execution_without_changing_page_preference() {
	mut owner := page.Page.create(1)!
	mut document := embedder_scripting_document(owner, 'https://www.wikipedia.org/')!
	defer { document.finalize() }
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	node := document.create_element('button')!.as_node()
	assert document.is_scripting_enabled_by_embedder()
	assert node.is_scripting_enabled() && is_scripting_enabled_for_settings(settings)
	document.set_scripting_enabled_by_embedder(false)
	assert owner.is_scripting_enabled()
	assert node.is_scripting_disabled() && is_scripting_disabled_for_settings(settings)
	assert can_run_script_for_settings(settings) == .do_not_run
	document.set_scripting_enabled_by_embedder(true)
	assert node.is_scripting_enabled() && can_run_script_for_settings(settings) == .run
	owner.set_is_scripting_enabled(false)
	assert node.is_scripting_disabled() && is_scripting_disabled_for_settings(settings)
	assert can_run_script_for_settings(settings) == .do_not_run
}

fn test_embedder_scripting_policy_is_local_to_each_navigation_document() {
	owner := page.Page.create(1)!
	mut first := embedder_scripting_document(owner, 'https://www.wikipedia.org/')!
	first.set_scripting_enabled_by_embedder(false)
	mut second := embedder_scripting_document(owner, 'https://example.test/')!
	defer {
		first.finalize()
		second.finalize()
	}
	assert !first.is_scripting_enabled_by_embedder()
	assert second.is_scripting_enabled_by_embedder()
	assert first.page() == second.page()
	assert owner.is_scripting_enabled()
	assert first.as_node().is_scripting_disabled()
	assert second.as_node().is_scripting_enabled()
}

fn test_embedder_disabled_parser_renders_noscript_without_allocating_script_models_or_handlers() {
	owner := page.Page.create(1)!
	mut document := embedder_scripting_document(owner, 'https://www.wikipedia.org/')!
	defer { document.finalize() }
	document.set_scripting_enabled_by_embedder(false)
	mut parser := HTMLParser.create(document, '<!doctype html><html><head><script id="external" src="/external.js"></script><script id="inline">invalid javascript {{{</script><script id="importmap" type="importmap">{invalid json</script></head><body onload="invalid javascript {{{"><noscript><strong id="fallback">HTML fallback</strong></noscript><button id="button" onclick="invalid javascript {{{">Button</button><svg><script id="svg-script" href="/svg.js">invalid javascript {{{</script></svg></body></html>')
	parser.run()
	assert parser.scripting_mode == .disabled
	assert parser.script_models.len == 0
	assert !parser.paused() && !document.has_pending_parsing_blocking_script()
	assert document.pending_parsing_blocking_svg_script() == none
	assert document.get_element_by_id('fallback')?.as_node().text_content()? == 'HTML fallback'
	for id in ['external', 'inline', 'importmap'] {
		element := document.get_element_by_id(id)?
		assert unsafe { &dom.HTMLScriptElement(element) }.script_element_model_ == unsafe { nil }
	}
	svg_script := document.get_element_by_id('svg-script')?
	assert unsafe { &dom.SVGScriptElement(svg_script) }.script_element_model_ == unsafe { nil }
	button := document.get_element_by_id('button')?
	assert button.get_attribute_value('onclick') == 'invalid javascript {{{'
	assert unsafe { &dom.EventTarget(button) }.data.event_handler_count() == 0
	body := document.body()?
	assert unsafe { &dom.EventTarget(body) }.data.event_handler_count() == 0
	window := document.get_window()?
	assert unsafe { &dom.EventTarget(window) }.data.event_handler_count() == 0
}

fn test_embedder_policy_applies_to_a_document_without_window_settings() {
	mut document := dom.Document.create(dom.URL{value: 'https://www.wikipedia.org/'})
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	assert document.as_node().is_scripting_enabled()
	document.set_scripting_enabled_by_embedder(false)
	assert document.as_node().is_scripting_disabled()
}

fn test_embedder_disabled_fragment_parsing_keeps_scripts_inert_without_models() {
	owner := page.Page.create(1)!
	mut document := embedder_scripting_document(owner, 'https://www.wikipedia.org/')!
	defer { document.finalize() }
	document.set_scripting_enabled_by_embedder(false)
	context := document.create_element('div')!
	for mode in [dom.ParserScriptingMode.inert, dom.ParserScriptingMode.fragment] {
		nodes := parse_html_fragment_with_options(context, '<script onclick="invalid {{{">raw script text</script><svg><script href="/script.js">raw SVG text</script></svg>', .no, mode)
		assert nodes.len == 2
		html_element := nodes[0].as_element()?
		assert html_element.namespace_uri()? == 'http://www.w3.org/1999/xhtml'
		assert html_element.local_name() == 'script'
		html_script := unsafe { &dom.HTMLScriptElement(html_element) }
		assert html_script.script_element_model_ == unsafe { nil }
		assert nodes[0].text_content()? == 'raw script text'
		assert unsafe { &dom.EventTarget(html_script) }.data.event_handler_count() == 0
		svg_element := nodes[1].first_child()?.as_element()?
		assert svg_element.namespace_uri()? == 'http://www.w3.org/2000/svg'
		assert svg_element.local_name() == 'script'
		svg_script := unsafe { &dom.SVGScriptElement(svg_element) }
		assert svg_script.script_element_model_ == unsafe { nil }
		assert unsafe { &dom.Node(svg_script) }.text_content()? == 'raw SVG text'
		assert nodes[0].document() == document
	}
}

fn test_embedder_disabled_script_attribute_and_connection_hooks_do_not_allocate_models() {
	owner := page.Page.create(1)!
	mut document := embedder_scripting_document(owner, 'https://www.wikipedia.org/')!
	defer { document.finalize() }
	document.set_scripting_enabled_by_embedder(false)
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'script')!
	script := unsafe { &dom.HTMLScriptElement(element) }
	html_script_element_attribute_changed(script, 'src', none, '/never-fetch.js', none)
	html_script_element_attribute_changed(script, 'onclick', none, 'invalid {{{', none)
	html_script_element_post_connection(script)
	assert script.script_element_model_ == unsafe { nil }
	assert unsafe { &dom.EventTarget(script) }.data.event_handler_count() == 0
}
