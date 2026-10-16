module browserjs

import dom
import html
import mediasourceextensions
import page

fn buffer_mode_drain() {
	mut loop := html.main_thread_event_loop()
	queue := loop.task_queue()
	loop.spin_until(fn [queue] () bool { return !queue.has_runnable_tasks() })
}

fn buffer_mode_fixture() !(&Runtime,&dom.Document,&html.HTMLMediaElement,&mediasourceextensions.MediaSource,&mediasourceextensions.SourceBuffer) {
	owner := page.Page.create(1)!
	url := dom.URL{value:'https://buffer-mode.example/'}
	document := html.create_navigation_document_for_page(url,url.origin(),none,unsafe { &dom.Page(owner) })!
	mut runtime := Runtime.create()
	mut host := MediaSourceHost.create(document)!
	host.install(mut runtime)!
	runtime.evaluate_host('globalThis.bmSource=new MediaSource();0')!
	source := runtime.native_media_source(runtime.evaluate_host_value('bmSource')!)!
	element := document.create_element_ns('http://www.w3.org/1999/xhtml','video')!
	mut media := html.html_media_element_for_dom_element(element) or { return error('Missing actual buffer-mode media owner') }
	media.set_src_object(source.as_media_provider())!
	buffer_mode_drain()
	runtime.evaluate_host('globalThis.bmBuffer=bmSource.addSourceBuffer("video/webm; codecs=vp9");globalThis.bmSet=Object.getOwnPropertyDescriptor(SourceBuffer.prototype,"mode").set;0')!
	buffer_mode_drain()
	buffer := source.source_buffers().item(0) or { return error('Missing actual buffer-mode buffer') }
	return runtime,document,media,source,buffer
}

fn buffer_mode_balanced(runtime &Runtime,document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_source_buffer_mode_enum_invalid_values_and_returns_preserve_the_actual_open_owner() {
	$if !darwin { return }
	mut runtime,mut document,mut media,source,buffer := buffer_mode_fixture()!
	defer { media.set_src_object(none) or {};buffer_mode_drain();runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const d=Object.getOwnPropertyDescriptor(SourceBuffer.prototype,"mode");if(d.set!==bmSet||d.set.name!=="set mode"||d.set.length!==1||!d.enumerable||!d.configurable||Object.hasOwn(bmBuffer,"mode")||!Function.prototype.toString.call(d.set).includes("[native code]"))return false;
 globalThis.bmEvents=[];for(const name of ["updatestart","update","updateend","abort","error"])bmBuffer.addEventListener(name,e=>bmEvents.push(e.type));
 for(const valid of ["sequence","segments"]){if(bmSet.call(bmBuffer,valid)!==undefined||bmBuffer.mode!==valid)return false;}
 for(const value of [undefined,null,false,true,0,1n,Symbol(),"","Segments"," sequence","sequence ","segments\0","segments\ud800",{},[],Object.create(null)]){
  if(bmSet.call(bmBuffer,value)!==undefined||bmBuffer.mode!=="segments"||!Reflect.set(bmBuffer,"mode",value))return false;
 }
 const value={toString(){return "bad"}};return bmSet.call(bmBuffer)===undefined&&(bmBuffer.mode=value)===value&&bmBuffer.mode==="segments"&&!bmBuffer.updating&&bmSource.readyState==="open"&&bmEvents.length===0;
})()')! == 'true'
	buffer_mode_drain()
	assert source.ready_state() == .open && buffer.mode() == .segments && !buffer.updating()
	assert buffer.timestamp_offset() == 0 && buffer.input_buffer_length() == 0
	assert runtime.evaluate_host('bmEvents.length===0')! == 'true'
	buffer_mode_balanced(runtime,document)
}

fn test_source_buffer_mode_enum_conversion_reentry_precedes_updating_state_validation() {
	$if !darwin { return }
	mut runtime,mut document,mut media,_,buffer := buffer_mode_fixture()!
	defer { media.set_src_object(none) or {};buffer_mode_drain();runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const hints=[];bmBuffer.mode={[Symbol.toPrimitive](hint){hints.push(hint);bmBuffer.mode="segments";return "sequence"},toString(){throw "second conversion"}};
 if(hints.join(",")!=="string"||bmBuffer.mode!=="sequence")return false;
 bmBuffer.mode={toString(){bmBuffer.mode="segments";return "invalid"}};if(bmBuffer.mode!=="segments")return false;
 const marker={};bmBuffer.mode={toString(){bmBuffer.mode="sequence";throw marker}};if(bmBuffer.mode!=="sequence")return false;
 bmBuffer.mode="segments";let calls=0;
 try{bmSet.call(bmBuffer,{toString(){calls++;bmBuffer.appendBuffer(new Uint8Array([0x1a,0x45]));return "sequence"}});return false}catch(e){if(!(e instanceof DOMException)||e.name!=="InvalidStateError")return false;}
 if(calls!==1||!bmBuffer.updating||bmBuffer.mode!=="segments")return false;
 if(bmSet.call(bmBuffer,Symbol())!==undefined||!bmBuffer.updating)return false;
 bmBuffer.mode={toString(){bmBuffer.abort();return "sequence"}};
 return !bmBuffer.updating&&bmBuffer.mode==="sequence";
})()')! == 'true'
	buffer_mode_drain()
	assert buffer.mode() == .sequence && !buffer.updating() && buffer.input_buffer_length() == 0
	buffer_mode_balanced(runtime,document)
}

fn test_source_buffer_mode_enum_receiver_checks_and_ignored_exception_roots_remain_separate() {
	$if !darwin { return }
	mut runtime,mut document,mut media,_,buffer := buffer_mode_fixture()!
	defer { media.set_src_object(none) or {};buffer_mode_drain();runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 let traps=0;const value={toString(){traps++;throw "converted"}},proxy=new Proxy(bmBuffer,{get(){traps++;throw "get"},getPrototypeOf(){traps++;throw "prototype"}}),revoked=Proxy.revocable(bmBuffer,{});revoked.revoke();
 for(const receiver of [null,undefined,1,{},Object.create(bmBuffer),SourceBuffer.prototype,bmSource,bmSource.sourceBuffers,new EventTarget(),proxy,revoked.proxy])try{bmSet.call(receiver,value);return false}catch(e){if(!(e instanceof TypeError)||e.message!=="Not an object of type SourceBuffer")return false;}
 globalThis.bmReason={};globalThis.bmBad=[Symbol(),{get [Symbol.toPrimitive](){throw bmReason}},{[Symbol.toPrimitive](){throw bmReason}},{toString(){throw bmReason}},{[Symbol.toPrimitive]:1},{[Symbol.toPrimitive](){return {}}},new Proxy({},{get(){throw bmReason}})];
 return traps===0&&bmBuffer.mode==="segments";
})()')! == 'true'
	protected := runtime.protected_values_.len
	assert runtime.evaluate_host('(()=>{for(let i=0;i<20;i++)for(const value of bmBad)if(bmSet.call(bmBuffer,value)!==undefined||bmBuffer.mode!=="segments")return false;return true})()')! == 'true'
	assert runtime.protected_values_.len == protected && buffer.mode() == .segments
	buffer_mode_balanced(runtime,document)
}

fn test_source_buffer_mode_enum_failure_skips_ended_reopening_and_detached_state_algorithms() {
	$if !darwin { return }
	mut runtime,mut document,mut media,source,buffer := buffer_mode_fixture()!
	defer { media.set_src_object(none) or {};buffer_mode_drain();runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'globalThis.bmStates=[];bmSource.onsourceopen=e=>bmStates.push("open");bmSource.onsourceended=e=>bmStates.push("ended");bmSource.endOfStream();bmSource.readyState==="ended"&&bmSet.call(bmBuffer,"bad")===undefined&&bmSet.call(bmBuffer,Symbol())===undefined&&bmSource.readyState==="ended"')! == 'true'
	buffer_mode_drain()
	assert source.ready_state() == .ended && buffer.mode() == .segments
	assert runtime.evaluate_host('bmStates.join(",")==="ended"&&bmSet.call(bmBuffer,"sequence")===undefined&&bmSource.readyState==="open"&&bmStates.length===1')! == 'true'
	buffer_mode_drain()
	assert runtime.evaluate_host('bmStates.join(",")==="ended,open"')! == 'true'
	media.set_src_object(none)!
	buffer_mode_drain()
	assert source.ready_state() == .closed && source.source_buffers().length() == 0
	assert runtime.evaluate_host(r'(()=>{
 for(const value of ["bad",Symbol(),{toString(){throw {}}}])if(bmSet.call(bmBuffer,value)!==undefined)return false;
 for(const value of ["segments","sequence",{toString(){return "sequence"}}])try{bmSet.call(bmBuffer,value);return false}catch(e){if(!(e instanceof DOMException)||e.name!=="InvalidStateError")return false;}
 return bmBuffer.mode==="sequence"&&bmSource.readyState==="closed"&&bmSource.sourceBuffers.length===0;
})()')! == 'true'
	buffer_mode_balanced(runtime,document)
}
