module main

import browserjs
import dom
import html
import layout

fn view_transition_process_callback(transition &dom.ViewTransition) {
	mut event_loop := html.main_thread_event_loop()
	for _ in 0 .. 8 {
		if transition.phase() != .pending_capture { return }
		event_loop.process()
	}
	assert transition.phase() != .pending_capture
}

fn test_compact_view_transition_replays_native_callback_mutations_before_async_capture() {
	$if !darwin { return }
	mut document :=
		html.parse_document('<!doctype html><style>:root {view-transition-name:none} #hero {view-transition-name:hero;width:20px;height:10px}</style><div id="hero"></div>')
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
 let callbackCalls=0,readyCalls=0,finishedCalls=0;
 const barrier=Promise.withResolvers();
	 const transition=document.startViewTransition(function(){
	  callbackCalls++;
	  console.log("view transition callback");
  document.getElementById("hero").style.cssText="width:40px;height:30px";
  return barrier.promise;
 });
 transition.ready.then(function(){readyCalls++;});
 transition.finished.then(function(){finishedCalls++;});
 ',
	], runtime, mut messages)
	assert messages.len == 0
	assert runtime.evaluate_host('callbackCalls===0&&document.activeViewTransition===transition&&transition instanceof ViewTransition&&transition.ready===transition.ready&&transition.finished===transition.finished&&Object.prototype.toString.call(transition)==="[object ViewTransition]"')! == 'true'
	hero := document.get_element_by_id('hero') or { panic('hero') }
	_ = layout.run_document_layout(document, 160, 120) or { panic('layout') }
	native_transition := document.get_active_view_transition() or { panic('native transition') }
	document.perform_pending_transition_operations()
	assert (native_transition.captured_element('hero') or { panic('old') }).old_width == 20
	view_transition_process_callback(native_transition)
	assert runtime.evaluate_host('callbackCalls===1&&readyCalls===0')! == 'true'
	assert native_transition.phase() == .update_callback_called
	// The callback has returned a still-pending Promise, but its synchronous DOM
	// mutations already reached the source document without a later draw poll.
	assert hero.get_attribute_value('style').contains('40px')
	assert hero.get_attribute_value('style').contains('30px')
	runtime.evaluate_host('barrier.resolve();')!
	assert native_transition.phase() == .update_callback_called
	html.perform_a_microtask_checkpoint()
	assert native_transition.phase() == .animating
	assert runtime.evaluate_host('callbackCalls===1&&readyCalls===1&&finishedCalls===0&&document.activeViewTransition===transition')! == 'true'
	capture := native_transition.captured_element('hero') or { panic('new capture') }
	assert (capture.new_element or { panic('new') }).width == 40
	assert (capture.new_element or { panic('new') }).height == 30
	assert hero.captured_in_a_view_transition()
	document.perform_pending_transition_operations()
	html.perform_a_microtask_checkpoint()
	assert native_transition.phase() == .done
	assert runtime.evaluate_host('finishedCalls===1&&document.activeViewTransition===null')! == 'true'
	assert !hero.captured_in_a_view_transition()
}

fn test_compact_skipped_transition_finished_preserves_actual_callback_rejection_identity() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><div></div>')
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
 let callbackCalls=0,readyReason,doneReason,finishedReason;
 const reason={message:"actual rejection",run:function(){}};reason.self=reason;
 const barrier=Promise.withResolvers();
 const transition=document.startViewTransition(function(){callbackCalls++;return barrier.promise;});
 transition.ready.catch(function(error){readyReason=error;});
 transition.updateCallbackDone.catch(function(error){doneReason=error;});
 transition.finished.catch(function(error){finishedReason=error;});
 ',
	], runtime, mut messages)
	assert messages.len == 0
	_ = layout.run_document_layout(document, 160, 120) or { panic('layout') }
	native_transition := document.get_active_view_transition() or { panic('native transition') }
	document.perform_pending_transition_operations()
	view_transition_process_callback(native_transition)
	runtime.evaluate_host('transition.skipTransition();')!
	assert native_transition.phase() == .done
	assert runtime.evaluate_host('document.activeViewTransition===null')! == 'true'
	html.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('readyReason instanceof DOMException&&readyReason.code===DOMException.ABORT_ERR&&readyReason.name==="AbortError"&&doneReason===undefined&&finishedReason===undefined')! == 'true'
	runtime.evaluate_host('barrier.reject(reason);')!
	assert native_transition.finished().state == .pending
	html.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('callbackCalls===1&&doneReason===reason&&finishedReason===reason&&readyReason.name==="AbortError"')! == 'true'
	assert native_transition.finished().state == .rejected
}

fn test_compact_transition_throwing_callback_and_idl_receiver_conversion() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><div></div>')
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
 let badArguments=0,badReceivers=0,callbackCalls=0;
 for(const argument of [null,{},3]){try{document.startViewTransition(argument);}catch(error){if(error instanceof TypeError)badArguments++;}}
 try{document.startViewTransition.call({},function(){});}catch(error){if(error instanceof TypeError)badReceivers++;}
 try{ViewTransition.prototype.skipTransition.call({});}catch(error){if(error instanceof TypeError)badReceivers++;}
 try{new ViewTransition();}catch(error){if(error instanceof TypeError)badReceivers++;}
 const reason={message:"callback throw"};let readyReason,doneReason,finishedReason;
 const transition=document.startViewTransition(function(){callbackCalls++;throw reason;});
 transition.ready.catch(function(error){readyReason=error;});
 transition.updateCallbackDone.catch(function(error){doneReason=error;});
 transition.finished.catch(function(error){finishedReason=error;});
 ',
	], runtime, mut messages)
	assert messages.len == 0
	assert runtime.evaluate_host('badArguments===3&&badReceivers===3&&callbackCalls===0')! == 'true'
	assert runtime.evaluate_host('document.startViewTransition.length===0&&ViewTransition.length===0&&Object.getOwnPropertyDescriptor(ViewTransition.prototype,"ready").enumerable&&Object.getOwnPropertyDescriptor(ViewTransition.prototype,"skipTransition").enumerable')! == 'true'
	_ = layout.run_document_layout(document, 160, 120) or { panic('layout') }
	native_transition := document.get_active_view_transition() or { panic('native transition') }
	document.perform_pending_transition_operations()
	view_transition_process_callback(native_transition)
	html.perform_a_microtask_checkpoint()
	assert native_transition.phase() == .done
	assert runtime.evaluate_host('callbackCalls===1&&readyReason===reason&&doneReason===reason&&finishedReason===reason&&document.activeViewTransition===null')! == 'true'
}

fn test_compact_hidden_no_callback_and_external_active_transition_bind_actual_source_promises() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><div></div>')
	defer { document.finalize() }
	_ = html.WindowModel.create_top_level(document, none, 'hidden-transition')!
	document.visibility_state = .hidden
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
 let readyReason,doneCalls=0,finishedCalls=0;
 const hiddenTransition=document.startViewTransition();
 hiddenTransition.ready.catch(function(reason){readyReason=reason;});
 hiddenTransition.updateCallbackDone.then(function(){doneCalls++;});
 hiddenTransition.finished.then(function(){finishedCalls++;});
 ',
	], runtime, mut messages)
	assert messages.len == 0
	assert document.get_active_view_transition() == none
	mut event_loop := html.main_thread_event_loop()
	for _ in 0 .. 4 {
		event_loop.process()
	}
	assert runtime.evaluate_host('readyReason instanceof DOMException&&readyReason.code===DOMException.INVALID_STATE_ERR&&readyReason.name==="InvalidStateError"&&doneCalls===1&&finishedCalls===1&&document.activeViewTransition===null')! == 'true'
	document.visibility_state = .visible
	_ = layout.run_document_layout(document, 160, 120) or { panic('layout') }
	native_transition := document.start_view_transition(none)
	runtime.evaluate_host(r'
 const externalTransition=document.activeViewTransition;
 let externalReady=0,externalFinished=0;
 externalTransition.ready.then(function(){externalReady++;});
 externalTransition.finished.then(function(){externalFinished++;});
 ')!
	assert runtime.evaluate_host('externalTransition instanceof ViewTransition&&document.activeViewTransition===externalTransition')! == 'true'
	document.perform_pending_transition_operations()
	view_transition_process_callback(native_transition)
	html.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('externalReady===1&&externalFinished===0')! == 'true'
	document.perform_pending_transition_operations()
	html.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('externalFinished===1&&document.activeViewTransition===null')! == 'true'
}
