module main

import adblock
import browserjs
import page
import platform
import time

fn test_event_target_registry_outlives_registration_arena() {
	browserjs.check_event_target_registry_storage()
}

fn test_event_target_registry_survivors_outlive_removal_arena() {
	browserjs.check_event_target_registry_removal_storage()
}

fn wait_for_replacement_readiness(mut app BrowserApp) ! {
	deadline := time.now().add(2 * time.second)
	for time.now() < deadline {
		app.poll_browser_script_requests()
		app.poll_browser_child_documents()
		app.poll_browser_image_requests()
		app.poll_javascript_tasks()
		platform.pump_native_events(0.002)
		if app.js_runtime != unsafe { nil }
			&& app.js_runtime.evaluate_host('Boolean(globalThis.readyEvents&&globalThis.readyEvents.includes("load"))')! == 'true' {
			return
		}
	}
	return error('document load callback was not delivered')
}

fn test_replacement_document_keeps_context_and_delivers_native_readiness_after_retirement() {
	filtering := adblock.is_enabled()
	adblock.set_enabled(false)
	defer { adblock.set_enabled(filtering) }
	owner := page.Page.create(1)!
	mut app := BrowserApp{page_model: owner, script_policy: .enabled, layout_tree_only: true,
		viewport_width: 800, viewport_height: 600}
	defer { app.dispose_browser_tab() }
	header := r'<script>globalThis.readyEvents=[];document.addEventListener("readystatechange",()=>readyEvents.push(document.readyState));document.addEventListener("DOMContentLoaded",()=>readyEvents.push("domcontent"));window.addEventListener("load",()=>readyEvents.push("load"));</script>'
	app.install_loaded_page(LoadedPage{
		url: 'https://replacement-readiness.example/warmup'
		content_type: 'text/html'
		markup: '<!doctype html>${header}<p>Warm up</p>'
	}, false)
	assert app.js_messages.len == 0
	wait_for_replacement_readiness(mut app)!
	assert app.document.get_browsing_context() != none
	assert app.js_runtime.evaluate_host('globalThis.readyEvents?globalThis.readyEvents.join(","):"missing readyEvents"')! == 'interactive,domcontent,complete,load'
	previous := app.document
	context := previous.get_browsing_context() or { panic('missing first context') }
	app.install_loaded_page(LoadedPage{
		url: 'https://replacement-readiness.example/form'
		content_type: 'text/html'
		markup: '<!doctype html>${header}<form><input name=field><object name=unused></object></form><script>globalThis.formReady=new FormData(document.querySelector("form")).get("field")==="";</script>'
	}, false)
	assert app.js_messages.len == 0
	wait_for_replacement_readiness(mut app)!
	assert previous.has_been_destroyed()
	assert !previous.is_fully_active()
	assert app.document.is_fully_active()
	actual := app.document.get_browsing_context() or { panic('replacement lost its context') }
	assert voidptr(actual) == voidptr(context)
	assert app.document.readiness() == .complete
	assert app.js_runtime.evaluate_host('globalThis.formReady')! == 'true'
	assert app.js_runtime.evaluate_host('globalThis.readyEvents?globalThis.readyEvents.join(","):"missing readyEvents"')! == 'interactive,domcontent,complete,load'
}
