@[has_globals]
module html

import dom

__global executed_scripts []string
__global connection_urls []string

fn resource_test_element(node &dom.Node, local_name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == local_name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := resource_test_element(child, local_name) {
			return element
		}
	}
	return none
}

fn script_test_fetch(url dom.URL, kind ScriptElementType) !string {
	assert kind == .module
	return 'from:${url.serialize()}'
}

fn script_test_execute(kind ScriptElementType, source string, url dom.URL) ! {
	executed_scripts << '${kind}:${source}:${url.serialize()}'
}

fn link_test_fetch(url dom.URL, kind LinkResourceKind, cors CORSSettingAttribute) !LinkResourceResponse {
	_ = url
	_ = cors
	return match kind {
		.stylesheet {
			LinkResourceResponse{
				content_type: 'text/css'
				body: 'a { color: red; }'.bytes()
			}
		}
		.icon {
			LinkResourceResponse{
				content_type: 'image/png'
				body: [u8(1), 2, 3]
			}
		}
		.preload {
			LinkResourceResponse{
				content_type: 'application/octet-stream'
				body: [u8(9)]
			}
		}
		else {
			error('unexpected kind')
		}
	}
}

fn link_connection_hook(url dom.URL) ! {
	connection_urls << url.serialize()
}

fn test_script_inline_external_parser_and_import_map() {
	executed_scripts = []
	mut inline := HTMLScriptElementModel.create(dom.URL{ value: 'https://example.test/' })
	inline.set_execute_hook(script_test_execute)
	inline.set_text('inline()')
	inline.prepare_script(none)
	assert inline.script_type() == .classic
	assert executed_scripts.len == 1

	mut external := HTMLScriptElementModel.create(dom.URL{ value: 'https://example.test/' })
	external.set_type('module')
	external.set_src('/app.js')
	external.set_fetch_hook(script_test_fetch)
	external.set_execute_hook(script_test_execute)
	external.prepare_script(none)
	assert external.event_count('load') == 1
	assert !external.failed_to_load()

	document := dom.Document.create(dom.url_about_blank())
	mut ready_document := unsafe { &dom.Document(document) }
	ready_document.set_ready_to_run_scripts()
	mut parser_script := HTMLScriptElementModel.create(dom.url_about_blank())
	parser_script.set_parser_document(document)
	parser_script.set_text('parser()')
	parser_script.set_execute_hook(script_test_execute)
	parser_script.prepare_script(document)
	assert parser_script.is_ready_to_be_parser_executed()
	parser_script.parser_execute_ready_script()
	assert !parser_script.is_ready_to_be_parser_executed()

	mut import_map := HTMLScriptElementModel.create(dom.URL{ value: 'https://example.test/' })
	import_map.set_type('importmap')
	import_map.set_text('{"imports":{"x":"/x.js"}}')
	import_map.prepare_script(none)
	assert import_map.registered_import_map().imports.entries.len == 1
}

fn test_script_failures_and_supports() {
	assert html_script_element_supports('classic')
	assert !html_script_element_supports('speculationrules')
	mut script := HTMLScriptElementModel.create(dom.url_about_blank())
	script.set_type('importmap')
	script.set_src('/map.json')
	script.prepare_script(none)
	assert script.failed_to_load()
	assert script.event_count('error') == 1
}

fn test_parser_inserted_inline_script_is_prepared_and_executed() {
	executed_scripts = []
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	document.set_ready_to_run_scripts()
	mut parser := HTMLParser.create(document, '<script>parser_inline()</script><p>after</p>')
	parser.scripting_mode = .normal
	parser.set_script_hooks(none, script_test_execute)
	parser.run()
	assert executed_scripts == ['classic:parser_inline():https://example.test/page']
	assert parser.current_script_nesting_level() == 0
}

fn test_parser_blocking_stylesheet_resumes_parser_asynchronously() {
	unsafe {
		executed_scripts.clear()
	}
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	document.set_ready_to_run_scripts()
	mut blocking_style := document.create_element('style') or { panic(err) }
	document.script_blocking_style_sheet_set << blocking_style
	mut parser := HTMLParser.create(document, '<script>blocked()</script><p>after</p>')
	parser.scripting_mode = .normal
	parser.set_script_hooks(none, script_test_execute)
	parser.run()
	assert parser.paused()
	assert resource_test_element(unsafe { &dom.Node(document) }, 'p') == none
	unsafe {
		assert executed_scripts.len == 0
	}

	document.script_blocking_style_sheet_set.clear()
	document.schedule_html_parser_end_check()
	mut event_loop := main_thread_event_loop()
	for _ in 0 .. 8 {
		if !parser.paused() {
			break
		}
		event_loop.process()
	}
	assert !parser.paused()
	assert resource_test_element(unsafe { &dom.Node(document) }, 'p') != none
	unsafe {
		assert executed_scripts == ['classic:blocked():https://example.test/page']
	}
}

fn test_script_dom_receiver_lifecycle_and_text_idl_algorithms() {
	executed_scripts = []
	mut document := parse_document('<body><script></script></body>')
	document.set_ready_to_run_scripts()
	script_element := resource_test_element(unsafe { &dom.Node(document) }, 'script') or {
		panic('missing script')
	}
	script := unsafe { &dom.HTMLScriptElement(script_element) }
	model := html_script_element_model_for_dom_element(script)

	html_script_element_set_text_content(script, 'first')
	assert html_script_element_text_content(script) == 'first'
	assert html_script_element_text(script) == 'first'
	html_script_element_prepare_script_text(script)
	assert model.text_ == 'first'
	html_script_element_set_inner_text(script, 'a\nb')
	assert html_script_element_inner_text(script).contains('a')
	assert model.text_ == 'a\nb'
	set_html_script_element_async(script, true)
	assert html_script_element_async(script)
	set_html_script_element_async(script, false)
	assert !html_script_element_async(script)
	html_script_element_begin_delaying_document_load_event(script, document)
	assert model.document_load_event_delaying_

	copy_node := script_element.as_node().clone_single_node(document)!
	html_script_element_cloned(script, copy_node, false)!
	copy_element := copy_node.as_element() or { panic('missing script clone element') }
	copy_model := html_script_element_model_for_dom_element(unsafe {
		&dom.HTMLScriptElement(copy_element)
	})
	assert copy_model.already_started_ == model.already_started_

	mut dynamic_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'script')!
	body := document.body() or { panic('missing body') }
	mut body_node := body.as_node()
	body_node.append_child(dynamic_element.as_node())!
	dynamic_script := unsafe { &dom.HTMLScriptElement(dynamic_element) }
	mut dynamic_model := unsafe {
		&HTMLScriptElementModel(html_script_element_model_for_dom_element(dynamic_script))
	}
	dynamic_model.set_execute_hook(script_test_execute)
	set_html_script_element_text(dynamic_script, 'dynamic()')
	html_script_element_post_connection(dynamic_script)
	assert executed_scripts.last().contains('dynamic()')
}

fn test_contextual_fragment_resets_script_parser_state() {
	mut document := parse_document('<body><div id="context"></div></body>')
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	context := document.get_element_by_id('context') or { panic('missing context') }
	mut range := dom.Range.create(document)
	range.set_start(context.as_node(), 0)!
	fragment := range.create_contextual_fragment('<script>contextual()</script>')!
	script_element := fragment.as_node().first_child()?.as_element() or {
		panic('missing contextual script')
	}
	script := unsafe { &dom.HTMLScriptElement(script_element) }
	model := html_script_element_model_for_dom_element(script)
	assert !model.already_started_
	assert !model.is_parser_inserted()
}

fn test_link_stylesheet_icon_preload_and_connections() {
	connection_urls = []
	mut stylesheet := HTMLLinkElementModel.create(dom.URL{ value: 'https://example.test/' })
	stylesheet.set_rel('alternate stylesheet stylesheet')
	stylesheet.set_href('/style.css')
	stylesheet.set_fetch_hook(link_test_fetch)
	assert stylesheet.rel_list() == ['alternate', 'stylesheet']
	stylesheet.fetch_and_process_linked_resource()
	assert stylesheet.sheet()? == 'a { color: red; }'
	assert stylesheet.event_count('load') == 1
	assert !stylesheet.is_implicitly_potentially_render_blocking()

	mut icon := HTMLLinkElementModel.create(dom.URL{ value: 'https://example.test/' })
	icon.set_rel('icon')
	icon.set_href('/favicon.png')
	icon.set_fetch_hook(link_test_fetch)
	icon.fetch_and_process_linked_resource()
	assert icon.has_loaded_icon()
	assert icon.loaded_icon()? == [u8(1), 2, 3]
	document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	assert decode_favicon(icon.loaded_icon()?, icon.loaded_icon_url()?, document)!
	if _ := decode_favicon([], dom.URL{ value: 'https://example.test/empty.ico' }, document) {
		assert false
	} else {
		assert err.msg().contains('empty favicon')
	}

	mut preload := HTMLLinkElementModel.create(dom.URL{ value: 'https://example.test/' })
	preload.set_rel('dns-prefetch preconnect preload')
	preload.set_href('/asset.bin')
	preload.set_as('fetch')
	preload.set_fetch_hook(link_test_fetch)
	preload.set_connection_hooks(link_connection_hook, link_connection_hook)
	preload.fetch_and_process_linked_resource()
	// The literal relationship dispatch gives preload precedence over the
	// speculative preconnect and DNS-prefetch relations.
	assert connection_urls.len == 0
	assert preload.preloaded_response()?.body == [u8(9)]

	mut dns_prefetch := HTMLLinkElementModel.create(dom.URL{ value: 'https://example.test/' })
	dns_prefetch.set_rel('dns-prefetch')
	dns_prefetch.set_href('/asset.bin')
	dns_prefetch.set_connection_hooks(link_connection_hook, link_connection_hook)
	dns_prefetch.fetch_and_process_linked_resource()
	mut preconnect := HTMLLinkElementModel.create(dom.URL{ value: 'https://example.test/' })
	preconnect.set_rel('preconnect')
	preconnect.set_href('/asset.bin')
	preconnect.set_connection_hooks(link_connection_hook, link_connection_hook)
	preconnect.fetch_and_process_linked_resource()
	assert connection_urls.len == 2
}

fn test_document_selects_last_loaded_favicon_in_head_tree_order() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	mut html_element := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut head := document.create_element_ns(dom.namespace_html_uri, 'head')!
	mut first := document.create_element_ns(dom.namespace_html_uri, 'link')!
	mut second := document.create_element_ns(dom.namespace_html_uri, 'link')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html_element.as_node())!
	mut html_node := html_element.as_node()
	html_node.append_child(head.as_node())!
	mut head_node := head.as_node()
	head_node.append_child(first.as_node())!
	head_node.append_child(second.as_node())!

	first_link := unsafe { &dom.HTMLLinkElement(first) }
	second_link := unsafe { &dom.HTMLLinkElement(second) }
	mut first_model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(first_link)) }
	mut second_model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(second_link)) }
	first_model.process_icon_resource(true, dom.URL{ value: 'https://example.test/first.png' },
		[u8(1)])
	assert voidptr(document.active_favicon) == voidptr(first_link)
	second_model.process_icon_resource(true, dom.URL{ value: 'https://example.test/second.png' },
		[u8(2)])
	assert voidptr(document.active_favicon) == voidptr(second_link)

	// A later re-check still picks the last loaded link in tree order.
	document.check_favicon_after_loading_link_resource()
	assert voidptr(document.active_favicon) == voidptr(second_link)
}
