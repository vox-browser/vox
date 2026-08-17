@[has_globals]
module html

import dom

__global executed_scripts []string
__global connection_urls []string

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
				body:         'a { color: red; }'.bytes()
			}
		}
		.icon {
			LinkResourceResponse{
				content_type: 'image/png'
				body:         [u8(1), 2, 3]
			}
		}
		.preload {
			LinkResourceResponse{
				content_type: 'application/octet-stream'
				body:         [u8(9)]
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

	mut preload := HTMLLinkElementModel.create(dom.URL{ value: 'https://example.test/' })
	preload.set_rel('dns-prefetch preconnect preload')
	preload.set_href('/asset.bin')
	preload.set_fetch_hook(link_test_fetch)
	preload.set_connection_hooks(link_connection_hook, link_connection_hook)
	preload.fetch_and_process_linked_resource()
	assert connection_urls.len == 2
	assert preload.preloaded_response()?.body == [u8(9)]
}
