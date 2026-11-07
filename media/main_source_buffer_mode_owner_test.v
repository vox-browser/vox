module main

import browserjs
import dom
import html
import page
import time

fn buffer_mode_page_document() !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time('<!doctype html><video id="bmp-player" preload="none"></video><p id="bmp-result">waiting</p>',dom.URL{value:'https://buffer-mode-page.example/'},none,none,unsafe { &dom.Page(owner) },time.sys_mono_now())
}

fn buffer_mode_page_run(document &dom.Document,runtime &browserjs.Runtime,script string) {
	mut messages := []string{}
	run_document_javascript(document,document.url.serialize(),[script],runtime,mut messages)
	assert messages == []
}

fn buffer_mode_page_drain() {
	mut loop := html.main_thread_event_loop()
	queue := loop.task_queue()
	loop.spin_until(fn [queue] () bool { return !queue.has_runnable_tasks() })
}

fn buffer_mode_page_flush(document &dom.Document,runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document,snapshot,runtime,mut messages)
	assert messages == []
	runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn buffer_mode_page_balanced(document &dom.Document,runtime &browserjs.Runtime) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_source_buffer_mode_enum_ignored_failures_continue_actual_sourceopen_and_update_callbacks() {
	$if !darwin { return }
	mut document := buffer_mode_page_document()!
	mut runtime := browserjs.Runtime.create()
	defer { html.run_blob_url_unloading_cleanup_steps(document);buffer_mode_page_drain();runtime.close();document.finalize() }
	buffer_mode_page_run(document,runtime,r'
globalThis.bmpSource=new MediaSource();globalThis.bmpEvents=[];globalThis.bmpChecks=[];globalThis.bmpReason={};
bmpSource.onsourceopen=function(e){
 bmpEvents.push(e.type);bmpChecks.push(this===bmpSource&&e.target===this&&e.currentTarget===this&&e.isTrusted);
 globalThis.bmpBuffer=this.addSourceBuffer("video/webm; codecs=vp9");globalThis.bmpSet=Object.getOwnPropertyDescriptor(SourceBuffer.prototype,"mode").set;
 if(bmpSet.call(bmpBuffer,"invalid")!==undefined||bmpSet.call(bmpBuffer,{toString(){throw bmpReason}})!==undefined)throw "mode conversion threw";
 try{this.endOfStream("invalid");throw "enum argument accepted"}catch(e){if(!(e instanceof TypeError))throw e}
 try{bmpBuffer.changeType({toString(){throw bmpReason}});throw "string argument exception swallowed"}catch(e){if(e!==bmpReason)throw e}
 bmpBuffer.onupdatestart=function(e){bmpEvents.push(e.type);bmpChecks.push(this===bmpBuffer&&e.target===this&&e.currentTarget===this&&e.isTrusted&&this.updating);if(bmpSet.call(this,Symbol())!==undefined)throw "busy invalid conversion";try{bmpSet.call(this,"sequence");throw "busy valid setter accepted"}catch(e){if(!(e instanceof DOMException)||e.name!=="InvalidStateError")throw e}document.getElementById("bmp-result").textContent="update callback continued";};
 bmpBuffer.onupdate=function(e){bmpEvents.push(e.type);bmpChecks.push(this===bmpBuffer&&e.target===this&&e.currentTarget===this&&!this.updating);};
 bmpBuffer.onupdateend=function(e){bmpEvents.push(e.type);bmpChecks.push(this===bmpBuffer&&e.target===this&&e.currentTarget===this&&!this.updating&&bmpSet.call(this,"sequence")===undefined);};
 bmpBuffer.appendBuffer(new Uint8Array([0x1a,0x45]));
};document.getElementById("bmp-player").setAttribute("src",URL.createObjectURL(bmpSource));
')
	source := runtime.native_media_source(runtime.evaluate_host_value('bmpSource')!)!
	media := html.html_media_element_for_dom_element(document.get_element_by_id('bmp-player')?)?
	assert source.media_element_assigned_to()? == media && source.source_buffers().length() == 0
	buffer_mode_page_drain()
	assert runtime.evaluate_host('bmpEvents.join(",")==="sourceopen,updatestart,update,updateend"&&bmpChecks.length===4&&bmpChecks.every(Boolean)&&bmpBuffer.mode==="sequence"&&!bmpBuffer.updating&&bmpSource.readyState==="open"&&bmpSource.sourceBuffers[0]===bmpBuffer')! == 'true'
	buffer := source.source_buffers().item(0)?
	assert buffer.mode() == .sequence && !buffer.updating() && buffer.input_buffer_length() == 2
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('bmpBuffer')!)!) == voidptr(&buffer.EventTarget)
	buffer_mode_page_flush(document,runtime)!
	assert document.get_element_by_id('bmp-result')?.as_node().text_content()? == 'update callback continued'
	buffer_mode_page_balanced(document,runtime)
}

fn test_source_buffer_mode_enum_invalid_values_do_not_reopen_but_valid_native_setter_queues_sourceopen() {
	$if !darwin { return }
	mut document := buffer_mode_page_document()!
	mut runtime := browserjs.Runtime.create()
	defer { html.run_blob_url_unloading_cleanup_steps(document);buffer_mode_page_drain();runtime.close();document.finalize() }
	buffer_mode_page_run(document,runtime,r'
globalThis.bmpSource=new MediaSource();globalThis.bmpEvents=[];globalThis.bmpChecks=[];globalThis.bmpSet=Object.getOwnPropertyDescriptor(SourceBuffer.prototype,"mode").set;
bmpSource.onsourceopen=function(e){bmpEvents.push(e.type);bmpChecks.push(this===bmpSource&&e.target===this&&e.currentTarget===this&&e.isTrusted&&this.readyState==="open");if(bmpEvents.length===1){globalThis.bmpBuffer=this.addSourceBuffer("video/webm; codecs=vp9");this.endOfStream();}else document.getElementById("bmp-result").textContent="native mode reopened source";};
bmpSource.onsourceended=function(e){bmpEvents.push(e.type);bmpChecks.push(this===bmpSource&&e.target===this&&e.currentTarget===this&&e.isTrusted&&this.readyState==="ended");for(const value of ["invalid",Symbol(),{toString(){throw {}}}])if(bmpSet.call(bmpBuffer,value)!==undefined||this.readyState!=="ended")throw "invalid conversion reopened";if(bmpSet.call(bmpBuffer,"sequence")!==undefined||this.readyState!=="open"||bmpEvents.length!==2)throw "native reopen ordering";};
document.getElementById("bmp-player").setAttribute("src",URL.createObjectURL(bmpSource));
')
	buffer_mode_page_drain()
	source := runtime.native_media_source(runtime.evaluate_host_value('bmpSource')!)!
	buffer := source.source_buffers().item(0)?
	assert runtime.evaluate_host('bmpEvents.join(",")==="sourceopen,sourceended,sourceopen"&&bmpChecks.length===3&&bmpChecks.every(Boolean)&&bmpBuffer.mode==="sequence"&&bmpSource.readyState==="open"&&bmpSource.sourceBuffers[0]===bmpBuffer')! == 'true'
	assert source.ready_state() == .open && buffer.mode() == .sequence && !buffer.updating()
	buffer_mode_page_flush(document,runtime)!
	assert document.get_element_by_id('bmp-result')?.as_node().text_content()? == 'native mode reopened source'
	buffer_mode_page_balanced(document,runtime)
}
