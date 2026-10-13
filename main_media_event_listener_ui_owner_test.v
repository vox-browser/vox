module main

import browserjs
import dom
import page
import time

fn test_native_media_pointer_release_delivers_one_trusted_click_before_compact_replay() {
	$if !darwin {
		return
	}
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><video id="player"></video><img id="image"><object id="object"></object><svg id="vector"></svg><div id="result">waiting</div>', dom.URL{
		value: 'https://native-media-listener-ui.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'
globalThis.mediaPointerOrder=[];globalThis.mediaPointerChecks=[];globalThis.cancelMediaClick=false;
globalThis.savedMediaClick=null;globalThis.genericClickOrder=[];globalThis.genericClickChecks=[];
for(const name of ["pointerup","click"])player.addEventListener(name,function(event){
 mediaPointerOrder.push(event.type);
 mediaPointerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event instanceof Event&&event.isTrusted&&event.cancelable&&window.event===event);
 if(name==="click"){
  savedMediaClick=event;
  if(cancelMediaClick)event.preventDefault();
  result.textContent=mediaPointerOrder.join(",");
 }
});
for(const target of [image,object,vector])target.addEventListener("click",function(event){
 genericClickOrder.push(this.id);genericClickChecks.push(this===target&&event.target===target&&event.type==="click");
});
',
	], runtime, mut messages)
	assert messages == []
	player := document.get_element_by_id('player')?
	input := page.InputTarget.from_node(player.as_node())
	assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
	assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
	assert owner.event_handler.last_click_allowed()
	assert runtime.evaluate_host('mediaPointerOrder.join(",")==="pointerup,click"&&mediaPointerChecks.every(Boolean)&&savedMediaClick.currentTarget===null&&!savedMediaClick.defaultPrevented&&window.event===undefined')! == 'true'

	// The real DOM release has already delivered click. BrowserApp subsequently
	// runs this same compact replay helper for legacy element listener records.
	mut app := BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
	assert !app.dispatch_javascript_event('click', player)
	assert runtime.evaluate_host('mediaPointerOrder.join(",")==="pointerup,click"&&mediaPointerChecks.length===2')! == 'true'
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'pointerup,click'
	assert app.js_messages == []

	// Cancellation occurs on the actual trusted click and suppresses the
	// compact replay through the same Page flag consumed by BrowserApp release.
	runtime.evaluate_host('cancelMediaClick=true')!
	assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
	assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
	assert !owner.event_handler.last_click_allowed()
	assert runtime.evaluate_host('mediaPointerOrder.join(",")==="pointerup,click,pointerup,click"&&mediaPointerChecks.every(Boolean)&&savedMediaClick.defaultPrevented&&savedMediaClick.currentTarget===null&&window.event===undefined')! == 'true'
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'pointerup,click,pointerup,click'

	// Image, object and SVG facades continue to use their existing compact
	// listener records, so their real release followed by replay delivers once.
	for id in ['image', 'object', 'vector'] {
		target := document.get_element_by_id(id)?
		target_input := page.InputTarget.from_node(target.as_node())
		assert owner.handle_mousedown(target_input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
		assert owner.handle_mouseup(target_input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
		assert owner.event_handler.last_click_allowed()
		assert !app.dispatch_javascript_event('click', target)
	}
	assert runtime.evaluate_host('genericClickOrder.join(",")==="image,object,vector"&&genericClickChecks.every(Boolean)&&mediaPointerOrder.length===4')! == 'true'
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}
