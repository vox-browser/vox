module main

import dom
import html
import layout
import page
import time

fn child_repaint_fixture(markup string) &BrowserApp {
	owner := page.Page.create(1) or { panic(err) }
	document := parse_browser_navigation_document_for_page_with_response_time(markup,
		dom.URL{ value: 'https://frame-repaint.example/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut host := browser_child_document_host(document, .javascriptcore)
	layout.enable_native_paint_tree_storage(document)
	mut messages := []string{}
	host.discover(document, mut messages)
	assert messages.len == 0, messages.join('\n')
	return &BrowserApp{ document: document, page_model: owner, child_document_host: host, viewport_width: 320, viewport_height: 200 }
}

fn close_child_repaint_fixture(mut app BrowserApp) {
	if mut host := app.child_document_host { host.close() }
	app.document.destroy_a_document_and_its_descendants()
	app.document.finalize()
	app.document.release_native_storage()
}

fn test_blank_frame_service_initialization_keeps_parent_layout_geometry() {
	$if !darwin {
		return
	}
	mut app := child_repaint_fixture('<!doctype html><body><p id="outside">Parent content</p><iframe></iframe>')
	defer { close_child_repaint_fixture(mut app) }
	app.relayout(320, 200 + app.chrome_height())
	before := layout.document_layout_result(app.document)?.root
	generation := app.document.layout_pass_generation
	for _ in 0 .. 3 {
		app.begin_frame_preparation()
		app.poll_browser_child_documents()
		app.finish_frame_preparation()
	}
	after := layout.document_layout_result(app.document)?.root
	assert voidptr(after) == voidptr(before)
	assert app.document.layout_pass_generation == generation
	host := app.child_document_host?
	service := host.children[0].service?
	assert service.initialized
	assert app.document.get_element_by_id('outside')?.text_content()? == 'Parent content'
}

fn test_child_text_repaint_refreshes_nested_commands_without_rebuilding_parent() {
	$if !darwin {
		return
	}
	mut app := child_repaint_fixture('<!doctype html><body><p id="outside">Parent content</p><iframe srcdoc="<p id=inside>Initial child</p><script>0</script>"></iframe>')
	defer { close_child_repaint_fixture(mut app) }
	mut loop := html.main_thread_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	loop.spin_until(fn [app, deadline] () bool {
		mut browser := unsafe { &BrowserApp(app) }
		browser.begin_frame_preparation()
		browser.poll_browser_child_documents()
		browser.finish_frame_preparation()
		host := browser.child_document_host or { return false }
		if service := host.children[0].service {
			if service.initialized && service.load_fired { return true }
		}
		return time.sys_mono_now() >= deadline
	})
	host := app.child_document_host?
	service := host.children[0].service?
	assert service.initialized && service.load_fired
	assert service.runtime != unsafe { nil }
	before := layout.document_layout_result(app.document)?.root
	generation := app.document.layout_pass_generation
	before_list := app.document.record_display_list()?
	before_scene := layout.retain_display_list_scene(before_list)
	defer { layout.release_display_list_scene(before_scene) }
	before_commands := layout.display_list_commands(before_list)
	assert before_commands.any(it.kind == 'paint_nested_display_list' && it.nested_viewport_commands.any(it.text == 'Initial child'))
	service.runtime.evaluate_host('setTimeout(()=>{document.getElementById("inside").textContent="Updated child";},0);0')!
	update_deadline := time.sys_mono_now() + 3 * time.second
	loop.spin_until(fn [app, update_deadline] () bool {
		mut browser := unsafe { &BrowserApp(app) }
		browser.begin_frame_preparation()
		browser.poll_browser_child_documents()
		browser.finish_frame_preparation()
		// A timer can mutate the DOM while spin_until is servicing tasks. Wait
		// for a completed shell recording, rather than stopping at that mutation.
		return browser.paint_commands.any(it.kind == 'paint_nested_display_list'
			&& it.nested_viewport_commands.any(it.text == 'Updated child'))
			|| time.sys_mono_now() >= update_deadline
	})
	after := layout.document_layout_result(app.document)?.root
	assert voidptr(after) == voidptr(before)
	assert app.document.layout_pass_generation == generation
	// Inspect the shell's published viewport recording. Raw paint-tree traversal
	// bypasses its per-box cache and can hide a stale iframe recording.
	commands := app.paint_commands
	assert commands.any(it.kind == 'paint_nested_display_list' && it.nested_viewport_commands.any(it.text == 'Updated child'))
	assert before_commands.any(it.kind == 'paint_nested_display_list' && it.nested_viewport_commands.any(it.text == 'Initial child'))
	assert app.document.get_element_by_id('inside') == none
}
