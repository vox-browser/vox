module main

import browserjs
import dom
import page
import time

const fragment_page_url = 'https://fragment.example.test/page'

fn fragment_app() (&BrowserApp, &dom.Document, &browserjs.Runtime) {
	markup := '<!doctype html><style>html,body{margin:0}#tall{height:3000px}#target{position:absolute;left:0;top:900px;width:10px;height:10px}</style><div id="tall"></div><div id="target"></div><a id="jump" href="#target">jump</a>'
	mut owner := page.Page.create(1) or { panic(err) }
	mut document := parse_browser_navigation_document_for_page_with_response_time(markup,
		dom.URL{ value: fragment_page_url }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, fragment_page_url, [r'
globalThis.changes=[];
addEventListener("hashchange",event=>changes.push(event.type+":"+event.isTrusted+":"+location.hash));
globalThis.urls=[];addEventListener("hashchange",event=>urls.push((event instanceof HashChangeEvent)+" "+event.oldURL+" "+event.newURL));
'], runtime, mut messages)
	assert messages == []string{}
	mut app := &BrowserApp{ document: document, page_model: owner, js_runtime: runtime }
	app.history << HistoryEntry{ url: fragment_page_url, markup: markup }
	app.history_index = 0
	app.install_compact_navigation_handler()
	app.relayout(320, 312)
	runtime.take_document_state_dirty()
	runtime.take_document_replay_effects()
	return app, document, runtime
}

// Clicking an in-page #anchor refetched and reinstalled the whole document.
fn test_fragment_links_scroll_the_current_document_and_fire_hashchange() {
	mut app, mut document, mut runtime := fragment_app()
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host('jump.click()')!
	app.poll_native_navigation()
	assert voidptr(app.document) == voidptr(document)
	assert !app.load_status.starts_with('Loading')
	assert document.url.serialize() == fragment_page_url + '#target'
	assert app.address == fragment_page_url + '#target'
	assert app.history.len == 2 && app.history_index == 1
	assert app.scroll_y == 900
	assert runtime.evaluate_host('location.hash+"|"+document.querySelector(":target").id+"|"+changes.join()')! == '#target|target|hashchange:true:#target'
	// The same URL again re-scrolls but neither adds an entry nor fires hashchange.
	app.set_scroll_y(0, 312)
	app.navigate('#target', true)
	assert app.scroll_y == 900
	assert app.history.len == 2
	assert runtime.evaluate_host('changes.length')! == '1'
	// Reloading still fetches the page.
	assert !app.navigate_to_a_fragment('https://fragment.example.test/other#target')
}

fn test_fragment_history_traversal_restores_scroll_without_reloading() {
	mut app, mut document, mut runtime := fragment_app()
	defer {
		runtime.close()
		document.finalize()
	}
	app.set_scroll_y(120, 312)
	app.navigate('#target', true)
	assert app.scroll_y == 900
	app.history_go(-1)
	assert voidptr(app.document) == voidptr(document)
	assert document.url.serialize() == fragment_page_url
	assert app.history_index == 0
	assert app.scroll_y == 120
	assert runtime.evaluate_host('location.hash+"|"+changes.join()')! == '|hashchange:true:#target,hashchange:true:'
	app.history_go(1)
	assert voidptr(app.document) == voidptr(document)
	assert document.url.serialize() == fragment_page_url + '#target'
	assert app.scroll_y == 900
	assert runtime.evaluate_host('location.hash')! == '#target'
	assert runtime.evaluate_host('urls.join("|")')! == 'true ${fragment_page_url} ${fragment_page_url}#target|true ${fragment_page_url}#target ${fragment_page_url}|true ${fragment_page_url} ${fragment_page_url}#target'
}
