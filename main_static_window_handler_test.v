module main

import dom
import html
import page
import time

fn test_static_native_parser_body_handler_is_retained_before_runtime_startup() {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><body onload="original parser body"><div id="result">initial</div>', dom.URL{value: 'https://static-handlers.example/'}, none, none, unsafe { &dom.Page(owner) }, 123456700000)
	defer {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.finalize()
	}
	assert document.is_active()
	assert document.relevant_settings_object() != unsafe { nil }
	assert document_has_window_event_handlers(document)
	window := document.get_window() or { panic('actual Window') }
	handler := window.data.event_handler('load') or { panic('parser-created Window handler') }
	assert handler.value.kind == .string && handler.value.string_data == 'original parser body'
	mut messages := []string{}
	assert script_sources(document, document.base_url().serialize(), {}, mut messages).len == 0
	body := document.body() or { panic('parser body') }
	assert !unsafe { &dom.EventTarget(body) }.has_event_listener('load')
}

fn test_static_native_body_onload_initializes_actual_runtime_without_synthetic_script_sources() {
	$if !darwin {
		return
	}
	mut owner := page.Page.create(1)!
	mut app := BrowserApp{ page_model: owner, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.install_loaded_page(LoadedPage{
		url:          'https://static-handlers.example/page'
		content_type: 'text/html'
		markup:       '<!doctype html><body onload="result.textContent=typeof onload+&quot;:&quot;+(this===window)+&quot;:&quot;+(event.target===document);globalThis.staticLoadEvent=event"><div id="result">initial</div>'
	}, false)
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	assert app.js_runtime != unsafe { nil }
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'function:true:true'
	assert app.js_runtime.evaluate_host('staticLoadEvent instanceof Event&&staticLoadEvent.isTrusted&&!staticLoadEvent.bubbles&&staticLoadEvent.target===document&&window.onload.name==="onload"')! == 'true'
	assert app.js_messages == []
}

fn test_static_native_body_handler_uses_actual_page_gate_and_keeps_raw_source_while_disabled() {
	$if !darwin {
		return
	}
	mut owner := page.Page.create(1)!
	owner.set_is_scripting_enabled(false)
	mut app := BrowserApp{ page_model: owner, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.install_loaded_page(LoadedPage{
		url:          'https://static-handlers.example/disabled'
		content_type: 'text/html'
		markup:       '<!doctype html><body onload="result.textContent=&quot;executed&quot;"><noscript><b id="fallback">disabled</b></noscript><div id="result">initial</div>'
	}, false)
	mut document := app.document
	defer {
		if app.js_runtime != unsafe { nil } {
			app.js_runtime.close()
		}
		document.finalize()
	}
	assert app.js_runtime == unsafe { nil }
	assert document.get_element_by_id('fallback') != none
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'initial'
	window := document.get_window() or { panic('owning Window') }
	assert (window.data.event_handler('load') or { panic('raw handler') }).value.kind == .string
	assert app.js_messages == []
}

fn test_static_native_body_handler_can_queue_source_animation_frame_without_any_script_element() {
	$if !darwin {
		return
	}
	mut owner := page.Page.create(1)!
	mut client := owner.client()
	client.set_manual_rendering_opportunities(true)
	mut app := BrowserApp{ page_model: owner, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.install_loaded_page(LoadedPage{
		url:          'https://static-handlers.example/frame'
		content_type: 'text/html'
		markup:       '<!doctype html><body onload="requestAnimationFrame(()=>result.textContent=&quot;source frame&quot;)"><div id="result">initial</div>'
	}, false)
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'initial'
	app.deliver_rendering_opportunity(time.sys_mono_now(), 16)
	mut event_loop := html.main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() { event_loop.process() }
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'source frame'
	assert app.js_messages == []
}
