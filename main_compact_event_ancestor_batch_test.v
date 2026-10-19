module main

import browserjs
import html

fn test_native_event_ancestors_follow_dom_moves_and_keep_the_dispatch_path_after_callbacks() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><body id="event-root"><div id="first"><a id="control">expand</a></div><div id="second"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.order=[];
globalThis.eventControl=document.getElementById("control");
// Exercise a live native owner even when using the complete snapshot adapter.
eventControl.__state.nativeParent=true;
eventControl.addEventListener("click",function(){order.push("target");first.appendChild(eventControl);});
first.addEventListener("click",function(){order.push("first");});
second.addEventListener("click",function(){order.push("second");});
document.body.addEventListener("click",function(){order.push(this===document.body?"body":"wrong root");});
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('eventControl.__state.nativeParent===true')! == 'true'
	target := document.get_element_by_id('control')?
	mut second := document.get_element_by_id('second')?.as_node()
	second.append_child(target.as_node())!
	// The facade still has its earlier parentKey. Native dispatch must snapshot
	// the actual path, then retain it when the target listener moves the node.
	first_state := runtime.evaluate_host('__ladybirdDispatch("click","",{key:eventControl.__state.bridgeKey})')!
	apply_javascript_runtime_state(document, first_state, runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('order.join(",")')! == 'target,second,body'
	_ = runtime.evaluate_host('order=[];__ladybirdDispatch("click","",{key:eventControl.__state.bridgeKey})')!
	assert runtime.evaluate_host('order.join(",")')! == 'target,first,body'
}

fn test_native_event_ancestor_snapshot_preserves_owner_identity_and_cancellation() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><body id="event-root"><section id="scope"><div data-role="owner"><button id="control">expand</button></div></section>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.order=[];globalThis.eventControl=document.getElementById("control");
eventControl.__state.nativeParent=true;
eventControl.addEventListener("click",event=>{
 const owner=eventControl.parentElement;
 order.push(owner.localName==="div"&&owner.getAttribute("data-role")==="owner"&&event.target===eventControl);
 event.preventDefault();event.stopPropagation();
});
document.body.addEventListener("click",()=>order.push("propagation was not stopped"));
'], runtime, mut messages)
	assert messages == []string{}
	state := runtime.evaluate_host('__ladybirdDispatch("click","",{key:eventControl.__state.bridgeKey})')!
	assert state.contains('"defaultPrevented":true')
	assert runtime.evaluate_host('order.join(",")')! == 'true'
}
