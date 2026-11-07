module main

import browserjs
import dom
import html
import layout

// Pikabu uses a Document root and an identity-keyed callback registry before
// creating its image backdrop. Exercise the compact facade and native delivery.
fn test_compact_intersection_observer_document_root_preserves_connected_target_identity() {
	$if !darwin {
		return
	}
	url := dom.URL{ value: 'https://intersection.test/' }
	mut document := parse_browser_navigation_document('<!doctype html><style>body{margin:0}#target{position:absolute;left:101px;top:479px;width:626px;height:533px}</style><div id="target"></div>', url, none)
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{0, 0, 1024, 768})
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), [r'
 globalThis.intersectionLog=[];
 const handlers=new WeakMap();
 globalThis.visibilityObserver=new IntersectionObserver(entries=>entries.forEach(entry=>{
  const callbacks=handlers.get(entry.target);
  intersectionLog.push([entry.target===target,entry.target instanceof HTMLElement,
   entry.target.isConnected,entry.isIntersecting,!!callbacks,
   entry.boundingClientRect.width,entry.rootBounds.height]);
  if(callbacks&&entry.target.isConnected)callbacks.forEach(callback=>callback(entry));
 }),{root:document,rootMargin:"300px 0px"});
 handlers.set(target,new Set([entry=>{
  if(entry.isIntersecting){
   const canvas=document.createElement("canvas");canvas.id="backdrop";
   canvas.width=entry.target.clientWidth;canvas.height=entry.target.clientHeight;
   entry.target.after(canvas);visibilityObserver.unobserve(entry.target);
  }
 }]));
 if(!(target instanceof HTMLElement))throw new Error("target facade prototype");
 visibilityObserver.observe(target);
 '], runtime, mut messages)
	assert messages == []
	layout.install_document_layout_hook(document)
	document.needs_full_layout_tree_update = true
	document.update_layout(.debugging)
	document.run_the_update_intersection_observations_steps(100)
	mut queue := html.main_thread_event_loop().task_queue()
	for _ in 0 .. 50 {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .intersection_observer
		}) or { break }
		task.execute()
	}
	assert runtime.evaluate_host('JSON.stringify(intersectionLog)')! == '[[true,true,true,true,true,626,1368]]'
	assert runtime.evaluate_host('(()=>{const canvas=document.getElementById("backdrop");return canvas.width+","+canvas.height})()')! == '626,533'
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_runtime_state(document, state, runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('backdrop') != none
}
