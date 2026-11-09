module main

import adblock
import browserjs
import css
import dom
import html
import layout
import os
import page
import platform
import requestserver
import time

// A fresh native worker/filter process uses this executable's normal role.
fn test_upstream_native_process_role() {
	if code := browserjs.run_worker_process_role(os.args) { exit(code) }
	if code := adblock.run_default_worker_role(os.args) { exit(code) }
}

// Optional HTTP integration check. The server supplies the original pinned
// HTML/support files and the stock harness with a collecting report script.
fn test_upstream_testharness_in_native_document() {
	address := os.getenv('VOX_UPSTREAM_WPT_URL')
	if address == '' { return }
	output := os.getenv('VOX_UPSTREAM_WPT_RESULT')
	assert output != ''
	requestserver.install_native_font_fetch_host()!
	install_browser_font_resource_cache()
	css.install_remote_style_sheet_loader(load_browser_imported_style_sheet)
	defer { requestserver.close_native_font_fetch_host() }
	loaded := fetch_page(address, '')!
	url := dom.URL{value: loaded.url}
	mut owner := page.Page.create(1)!
	prepared := prepare_loaded_browser_navigation_document(loaded, url, none, none, unsafe { &dom.Page(owner) }, true)
	mut document := prepared.document
	owner.set_local_root_navigable(document.navigable() or { panic('missing root navigable') })!
	assert document.is_fully_active()
	document.update_the_visibility_state(.visible)
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut service := new_browser_hosted_document(document,.javascriptcore)
	mut manager := browser_child_document_host(document, .javascriptcore)
	defer { manager.close(); service.close(); document.finalize() }
	mut messages := []string{}
	deadline := time.now().add(70 * time.second)
	parse_prepared_browser_navigation_document(prepared)
	_ = layout.layout_document_typed_in_viewport(document,800,600)
	for {
		service.poll(mut messages)
		service.initialize(mut messages)
		manager.poll(mut messages)
		html.main_thread_event_loop().process()
		mut client := owner.client()
		client.rendering_opportunity(time.sys_mono_now(), 16.667)
		html.main_thread_event_loop().update_the_rendering()
		platform.pump_native_events(0.001)
		if service.runtime != unsafe { nil } {
			if service.runtime.evaluate_host('typeof nativeWptResult!=="undefined"&&nativeWptResult!==null')! == 'true' { break }
		}
		if time.now() > deadline {
			os.write_file(output+'.messages', messages.join('\n'))!
			assert false, 'upstream document harness did not report: '+messages.join('\n')
		}
	}
	runtime := service.runtime
	result := runtime.evaluate_host('JSON.stringify(nativeWptResult)')!
	os.write_file(output, result)!
	os.write_file(output+'.state', runtime.evaluate_host('JSON.stringify({readyState:document.readyState,location:location.href})')!+' loadDelayed=${document.anything_is_delaying_the_load_event()}')!
	os.write_file(output+'.messages', messages.join('\n'))!
	println(result)
	assert runtime.evaluate_host('nativeWptResult.harness===0&&nativeWptResult.tests.length>0&&nativeWptResult.tests.every(t=>t.status===0)')! == 'true', result
}
