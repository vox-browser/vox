module main

import browserjs
import css
import dom
import html
import layout
import page
import painting
import time

fn identity_test_rendering_frame(document &dom.Document) {
	mut page_ := page.Page.create(1) or { panic(err) }
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_page(unsafe { &dom.Page(page_) })
	page_.set_local_root_navigable(document.navigable() or { panic('missing navigable') }) or { panic(err) }
	mutable_document.update_the_visibility_state(.visible)
	mut app := BrowserApp{ document: mutable_document, page_model: page_ }
	app.deliver_rendering_opportunity(time.sys_mono_now(), 16)
	mut event_loop := html.main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() { event_loop.process() }
}

fn test_native_frame_replay_keeps_removed_and_reordered_svg_element_identity() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><svg width="200" height="100"><linearGradient id="collision"><stop stop-color="red"/></linearGradient><linearGradient id="collision"><stop stop-color="green"/></linearGradient><linearGradient id="move"><stop id="green-stop" offset="0" stop-color="green"/><stop offset="0" stop-color="red"/></linearGradient><rect width="100" height="100" fill="url(#collision)"/><rect x="100" width="100" height="100" fill="url(#move)"/></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	first := document.get_element_by_id('collision')?
	green_stop := document.get_element_by_id('green-stop')?
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
requestAnimationFrame(()=>requestAnimationFrame(()=>{
 document.getElementById("collision").remove();
 document.getElementById("move").moveBefore(document.getElementById("green-stop"),null);
 requestAnimationFrame(()=>requestAnimationFrame(()=>document.documentElement.classList.remove("reftest-wait")));
}));
'], runtime, mut messages)
	assert messages == []
	for _ in 0 .. 5 {
		identity_test_rendering_frame(document)
		mut app := BrowserApp{ document: document, js_runtime: runtime, layout_tree_only: true, viewport_width: 200, viewport_height: 100 }
		app.poll_javascript_tasks()
		assert app.js_messages == []
	}
	assert first.as_node().parent() == none
	assert voidptr(document.get_element_by_id('green-stop')?) == voidptr(green_stop)
	assert document.get_element_by_id('collision')?.as_node().first_child()?.as_element()?.get_attribute_value('stop-color') == 'green'
	gradient := document.get_element_by_id('move')?
	assert voidptr(gradient.as_node().last_child()?) == voidptr(green_stop.as_node())
	result := layout.run_document_layout(document, 200, 100) or { panic('missing source layout') }
	commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_svg_path' && it.fill_linear_gradient() != none)
	assert commands.len == 2
	for command in commands {
		paint := command.fill_linear_gradient()?
		assert paint.gradient.color_stops.last().color == painting.Color{0, 128, 0, 255}
	}
}

fn test_native_frame_snapshots_deliver_created_svg_tree_mutations_once() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><svg><linearGradient id="gradient"><stop stop-color="red"/></linearGradient></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
requestAnimationFrame(()=>{
 const stop=document.createElementNS("http://www.w3.org/2000/svg","stop");stop.id="created-stop";
 stop.setAttribute("stop-color","green");document.getElementById("gradient").appendChild(stop);
 requestAnimationFrame(()=>requestAnimationFrame(()=>console.log("settled")));
});
'], runtime, mut messages)
	assert messages == []
	for _ in 0 .. 4 {
		identity_test_rendering_frame(document)
		mut app := BrowserApp{ document: document, js_runtime: runtime, layout_tree_only: true, viewport_width: 200, viewport_height: 100 }
		app.poll_javascript_tasks()
	}
	root := unsafe { &dom.Node(document) }
	assert css.query_selector_all(root, 'stop').len == 2
	assert document.get_element_by_id('created-stop')?.get_attribute_value('stop-color') == 'green'
}

fn test_native_initial_load_dispatch_keeps_mutations_until_the_consumed_snapshot() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><div id="target"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
window.addEventListener("DOMContentLoaded",()=>{const child=document.createElement("span");child.id="ready-child";target.appendChild(child)});
window.addEventListener("load",()=>{const child=document.createElement("span");child.id="load-child";target.appendChild(child)});
'], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('ready-child') != none
	assert document.get_element_by_id('load-child') != none
	root := unsafe { &dom.Node(document) }
	assert css.query_selector_all(root, 'span').len == 2
}
