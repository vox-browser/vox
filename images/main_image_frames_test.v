module main

import browserjs
import dom
import html
import css
import page
import layout
import time
import os

fn test_svg_image_source_switch_retains_green_paint_through_actual_source_frames() {
	$if !darwin {
		return
	}
	input := os.read_file('/Users/alex/code/3rd/ladybird/Tests/LibWeb/Ref/input/svg-image-source-switch-same-size.html')!
	mut document := parse_browser_navigation_document_with_response_time(input, dom.URL{value: 'about:blank'}, none, none, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_script_sources(document, 'about:blank', css.query_selector_all(unsafe { &dom.Node(document) }, 'script').map(browserjs.ScriptSource{ code: it.as_node().text_content() or { '' } }), runtime, mut messages)
	assert messages == []
	mut app := BrowserApp{ document: document, js_runtime: runtime }
	app.relayout(800, 600 + app.chrome_height())
	for _ in 0 .. 4 {
		image_test_rendering_frame(document)
		app.poll_javascript_tasks()
	}
	retained := app.paint_commands.filter(it.kind == 'paint_nested_display_list')
	assert retained.len == 1
	assert retained[0].nested_viewport_commands.any(it.kind == 'draw_svg_path' && it.color == css.Color{0, 128, 0, 255}.serialize())
	assert document.get_element_by_id('target')?.get_attribute_value('src').contains("fill='green'")
	result := layout.run_document_layout(document, 800, 600)?
	images := result.paint_tree.paint_commands().filter(it.kind == 'paint_nested_display_list')
	assert images.len == 1
	assert images[0].nested_viewport_commands.any(it.kind == 'draw_svg_path' && it.color == css.Color{0, 128, 0, 255}.serialize())
}

fn image_test_rendering_frame(document &dom.Document) {
	mut page_ := page.Page.create(1) or { panic(err) }
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_page(unsafe { &dom.Page(page_) })
	page_.set_local_root_navigable(document.navigable() or { panic('missing navigable') }) or { panic(err) }
	mutable_document.update_the_visibility_state(.visible)
	mut app := BrowserApp{ document: mutable_document, page_model: page_ }
	app.deliver_rendering_opportunity(time.sys_mono_now(), 16)
	mut loop := html.main_thread_event_loop()
	for loop.task_queue().has_runnable_tasks() { loop.process() }
}
