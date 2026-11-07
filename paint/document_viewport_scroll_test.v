module main

import browserjs
import dom
import page
import time

fn viewport_scroll_app(markup string) (&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1) or { panic(err) }
	mut document := parse_browser_navigation_document_for_page_with_response_time(markup,
		dom.URL{ value: 'https://scroll.example.test/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, 'https://scroll.example.test/', []string{}, runtime, mut messages)
	assert messages == []string{}
	mut app := &BrowserApp{ document: document, page_model: owner, js_runtime: runtime }
	app.relayout(320, 312)
	runtime.take_document_state_dirty()
	runtime.take_document_replay_effects()
	return app, document, runtime
}

// Script scrolls mark the compact document state dirty; the shell adopts them
// when it polls that state after the task, exactly as after a timer callback.
fn run_viewport_scroll_script(mut app BrowserApp, mut runtime browserjs.Runtime, source string) {
	result := runtime.evaluate_host('(()=>{try{${source};return "ok"}catch(error){return String(error)}})()') or { panic(err) }
	assert result == 'ok'
	app.poll_javascript_tasks()
}

// A script's window.scrollTo() moved the document viewport, then the next
// relayout wrote the shell's unchanged offset back and the page jumped to the top.
fn test_script_viewport_scroll_survives_the_next_relayout() {
	mut app, mut document, mut runtime := viewport_scroll_app('<!doctype html><style>html,body{margin:0}#tall{height:3000px}#mark{position:absolute;left:0;top:400px;width:10px;height:10px}</style><div id="tall"></div><div id="mark"></div>')
	defer {
		runtime.close()
		document.finalize()
	}
	run_viewport_scroll_script(mut app, mut runtime, 'window.scrollTo(0,150)')
	assert app.scroll_y == 150
	app.relayout(320, 312)
	assert app.scroll_y == 150
	assert document.viewport_rect().y == 150
	assert runtime.evaluate_host('scrollY')! == '150'
	mark := document.get_element_by_id('mark') or { panic('mark') }
	assert mark.get_bounding_client_rect().y == 250
	run_viewport_scroll_script(mut app, mut runtime, 'window.scrollBy(0,-50)')
	assert app.scroll_y == 100
	run_viewport_scroll_script(mut app, mut runtime, 'document.documentElement.scrollTop=300')
	assert app.scroll_y == 300
	app.relayout(320, 312)
	assert runtime.evaluate_host('scrollY')! == '300'
}

// The shell's own offset (wheel input, history restoration) still reaches
// the document, and is not mistaken for a script scroll.
fn test_shell_scroll_stays_authoritative_without_script_scrolls() {
	mut app, mut document, mut runtime := viewport_scroll_app('<!doctype html><style>html,body{margin:0}#tall{height:3000px}</style><div id="tall"></div>')
	defer {
		runtime.close()
		document.finalize()
	}
	app.set_scroll_y(220, 312)
	assert !app.adopt_document_viewport_scroll()
	app.relayout(320, 312)
	assert app.scroll_y == 220
	assert document.viewport_rect().y == 220
	assert runtime.evaluate_host('scrollY')! == '220'
}
