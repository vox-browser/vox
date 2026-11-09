module main

import browserjs
import dom
import html
import layout
import page
import painting
import time

fn svg_animation_rendering_frame(document &dom.Document) {
	mut owner := page.Page.create(1) or { panic(err) }
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_page(unsafe { &dom.Page(owner) })
	owner.set_local_root_navigable(document.navigable() or { panic('navigable') }) or { panic(err) }
	mutable_document.update_the_visibility_state(.visible)
	mut app := BrowserApp{document: mutable_document, page_model: owner}
	app.deliver_rendering_opportunity(time.sys_mono_now(), 16)
	mut event_loop := html.main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() { event_loop.process() }
}

fn test_native_frame_keeps_finished_svg_stop_color_in_the_referenced_gradient() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg width="100" height="100"><linearGradient id="paint"><stop id="stop" offset="0" stop-color="red"/><stop offset="1" stop-color="green"/></linearGradient><rect width="100" height="100" fill="url(#paint)"/></svg>')
	document.set_font_rendering_policy(.chromium)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
requestAnimationFrame(()=>requestAnimationFrame(()=>{
 const animation=document.getElementById("stop").animate([{stopColor:"red"},{stopColor:"green"}],{duration:50,fill:"forwards"});
 animation.finish();
 animation.finished.then(()=>console.log("gradient finished"));
}));
'], runtime, mut messages)
	assert messages == []
	mut finished := false
	for _ in 0 .. 6 {
		svg_animation_rendering_frame(document)
		mut app := BrowserApp{document: document, js_runtime: runtime, layout_tree_only: true, viewport_width: 100, viewport_height: 100}
		app.poll_javascript_tasks()
		assert app.js_messages.all(it == 'gradient finished')
		if 'gradient finished' in app.js_messages { finished = true }
	}
	assert finished
	result := layout.run_document_layout(document, 100, 100) or { panic('layout') }
	commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_svg_path' && it.fill_linear_gradient() != none)
	assert commands.len == 1
	gradient := commands[0].fill_linear_gradient() or { panic('gradient') }
	assert gradient.gradient.color_stops[0].color == painting.Color{0, 128, 0, 255}
	assert gradient.gradient.color_stops[1].color == painting.Color{0, 128, 0, 255}
}
