module browserjs

import dom
import html
import page

fn native_buffer_owner_runtime() !(&Runtime, &dom.Document, &html.HTMLMediaElement) {
	address := dom.URL{
		value: 'https://native-buffer-owner.example.test/page'
	}
	owner := page.Page.create(1)!
	document := html.create_navigation_document_for_page(address, address.origin(), none,
		unsafe { &dom.Page(owner) })!
	mut runtime := Runtime.create()
	mut queries := URLSearchParamsHost.create(document)!
	queries.install(mut runtime)!
	mut urls := URLHost.create(document)!
	urls.install(mut runtime)!
	mut sources := MediaSourceHost.create(document)!
	sources.install(mut runtime)!
	runtime.evaluate_host('globalThis.source=new MediaSource();globalThis.sourceAddress=URL.createObjectURL(source);')!
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video')!
	mut media := html.html_media_element_for_dom_element(element) or {
		return error('missing actual media owner')
	}
	media.set_source(runtime.native_utf16_string(runtime.evaluate_host_value('sourceAddress')!)!.str())
	media.load()!
	drain_native_buffer_owner_tasks()
	return runtime, document, media
}

fn drain_native_buffer_owner_tasks() {
	mut loop := html.main_thread_event_loop()
	queue := loop.task_queue()
	loop.spin_until(fn [queue] () bool {
		return !queue.has_runnable_tasks()
	})
}

fn test_native_buffer_list_and_buffer_metadata_have_real_event_target_owners() {
	$if !darwin { return }
	mut runtime, mut document, mut media := native_buffer_owner_runtime()!
	defer {
		media.set_source(none)
		media.load() or {}
		drain_native_buffer_owner_tasks()
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{
 const get=Object.getOwnPropertyDescriptor;globalThis.list=source.sourceBuffers;globalThis.active=source.activeSourceBuffers;
 if(typeof SourceBuffer!=="function"||typeof SourceBufferList!=="function"||!list)return false;
 globalThis.added=[];list.onaddsourcebuffer=function(event){added.push(this===list&&event.target===list&&event.currentTarget===list&&event.isTrusted)};
 globalThis.buffer=source.addSourceBuffer("video/webm; codecs=vp9");
 const flags=["mode","updating","timestampOffset","onupdatestart","onupdate","onupdateend","onerror","onabort"].every(name=>{const d=get(SourceBuffer.prototype,name);return d.enumerable&&d.configurable&&d.get.name==="get "+name&&d.get.length===0&&Function.prototype.toString.call(d.get).includes("[native code]")});
 const methods=[["appendBuffer",1],["abort",0],["changeType",1],["remove",2]].every(([name,length])=>SourceBuffer.prototype[name].name===name&&SourceBuffer.prototype[name].length===length&&Function.prototype.toString.call(SourceBuffer.prototype[name]).includes("[native code]"));
 const illegal=[()=>SourceBuffer(),()=>new SourceBuffer(),()=>SourceBufferList(),()=>new SourceBufferList()].every(call=>{try{call();return false}catch(error){return error instanceof TypeError}});
 return flags&&methods&&illegal&&list===source.sourceBuffers&&active===source.activeSourceBuffers&&list!==active&&list instanceof SourceBufferList&&list instanceof EventTarget&&buffer instanceof SourceBuffer&&buffer instanceof EventTarget&&Object.getPrototypeOf(SourceBuffer)===EventTarget&&Object.getPrototypeOf(SourceBufferList)===EventTarget&&Object.getPrototypeOf(SourceBuffer.prototype)===EventTarget.prototype&&Object.getPrototypeOf(SourceBufferList.prototype)===EventTarget.prototype&&Object.prototype.toString.call(buffer)==="[object SourceBuffer]"&&Object.prototype.toString.call(list)==="[object SourceBufferList]"&&list.length===1&&active.length===0&&list[0]===buffer&&list[1]===undefined&&buffer.mode==="segments"&&!buffer.updating&&buffer.timestampOffset===0&&buffer.onupdate===null&&added.length===0&&SourceBuffer.length===0&&SourceBufferList.length===0&&!get(SourceBuffer,"prototype").writable&&!get(SourceBufferList,"prototype").writable;
})()')! == 'true'
	source := runtime.native_media_source(runtime.evaluate_host_value('source')!)!
	buffer := source.source_buffers().item(0) or { panic('missing actual buffer') }
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('buffer')!)!) == voidptr(&buffer.EventTarget)
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('list')!)!) == voidptr(&source.source_buffers().EventTarget)
	drain_native_buffer_owner_tasks()
	assert runtime.evaluate_host('added.length===1&&added[0]')! == 'true'
}

fn test_native_append_copies_the_actual_view_span_and_dispatches_on_the_buffer() {
	$if !darwin { return }
	mut runtime, mut document, mut media := native_buffer_owner_runtime()!
	defer {
		media.set_source(none)
		media.load() or {}
		drain_native_buffer_owner_tasks()
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.buffer=source.addSourceBuffer("video/webm; codecs=vp9");globalThis.events=[];
 for(const name of ["updatestart","update","updateend","abort","error"])buffer.addEventListener(name,function(event){events.push([event.type,this===buffer,event.target===buffer,event.currentTarget===buffer,event.isTrusted].join(":"))});
 const backing=new Uint8Array([99,0x1a,0x45,99]);const view=new DataView(backing.buffer,1,2);
 for(const name of ["buffer","byteLength","byteOffset"])Object.defineProperty(view,name,{get(){throw "author view getter"}});
 buffer.appendBuffer(view);backing.fill(0);buffer.updating&&events.length===0
')! == 'true'
	source := runtime.native_media_source(runtime.evaluate_host_value('source')!)!
	buffer := source.source_buffers().item(0) or { panic('missing appended buffer') }
	assert buffer.input_buffer_length() == 2 && buffer.updating()
	drain_native_buffer_owner_tasks()
	assert runtime.evaluate_host('!buffer.updating&&events.join(",")==="updatestart:true:true:true:true,update:true:true:true:true,updateend:true:true:true:true"')! == 'true'
	assert buffer.input_buffer_length() == 2
	assert runtime.evaluate_host('buffer.changeType("audio/webm; codecs=opus")===undefined&&(buffer.mode="sequence")==="sequence"&&(buffer.timestampOffset=2.5)===2.5&&buffer.timestampOffset===2.5')! == 'true'
	assert buffer.mode() == .sequence && buffer.timestamp_offset() == 2.5
	assert runtime.evaluate_host('source.duration=10;events.length=0;buffer.remove(1,Infinity)===undefined&&buffer.updating')! == 'true'
	drain_native_buffer_owner_tasks()
	assert runtime.evaluate_host('!buffer.updating&&events.length===3&&events[2]==="updateend:true:true:true:true"')! == 'true'
}

fn test_native_abort_from_updatestart_and_fatal_append_use_the_actual_algorithms() {
	$if !darwin { return }
	mut runtime, mut document, mut media := native_buffer_owner_runtime()!
	defer {
		media.set_source(none)
		media.load() or {}
		drain_native_buffer_owner_tasks()
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
 globalThis.buffer=source.addSourceBuffer("video/webm; codecs=vp9");globalThis.events=[];
 buffer.onupdatestart=function(event){events.push(event.type+":"+(this===buffer&&event.target===buffer));buffer.abort()};
 buffer.onabort=function(event){events.push(event.type+":"+(this===buffer&&event.target===buffer))};
 buffer.onupdateend=function(event){events.push(event.type+":"+(this===buffer&&event.target===buffer))};
 buffer.appendBuffer(new Uint8Array([0x1a,0x45]));
')!
	drain_native_buffer_owner_tasks()
	assert runtime.evaluate_host('!buffer.updating&&events.join(",")==="updatestart:true,abort:true,updateend:true"')! == 'true'
	source := runtime.native_media_source(runtime.evaluate_host_value('source')!)!
	buffer := source.source_buffers().item(0) or { panic('missing aborted buffer') }
	assert buffer.input_buffer_length() == 0
	runtime.evaluate_host(r'events.length=0;buffer.onupdatestart=null;buffer.onerror=function(event){events.push("error:"+(this===buffer&&event.target===buffer))};buffer.appendBuffer(new Uint8Array([0x1f,0x43,0xb6,0x75,0x80]).buffer);')!
	drain_native_buffer_owner_tasks()
	assert runtime.evaluate_host('source.readyState==="ended"&&!buffer.updating&&events.join(",")==="error:true,updateend:true"')! == 'true'
}

fn test_native_buffer_conversions_brand_checks_and_engine_exceptions() {
	$if !darwin { return }
	mut runtime, mut document, mut media := native_buffer_owner_runtime()!
	defer {
		media.set_source(none)
		media.load() or {}
		drain_native_buffer_owner_tasks()
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{
 globalThis.buffer=source.addSourceBuffer("video/webm; codecs=vp9");const marker={},get=Object.getOwnPropertyDescriptor;let reads=0;
 const actualExceptions=[()=>source.addSourceBuffer({toString(){throw marker}}),()=>buffer.changeType({toString(){throw marker}}),()=>{buffer.timestampOffset={valueOf(){throw marker}}},()=>buffer.remove({valueOf(){throw marker}},1)].every(call=>{try{call();return false}catch(reason){return reason===marker}});
 const rejected=[()=>source.addSourceBuffer(),()=>source.addSourceBuffer(Symbol()),()=>buffer.appendBuffer(),()=>buffer.appendBuffer({}),()=>buffer.appendBuffer(new Proxy(new Uint8Array(2),{})),()=>buffer.appendBuffer(new Uint8Array(new ArrayBuffer(2,{maxByteLength:4}))),()=>{buffer.timestampOffset=NaN},()=>{buffer.timestampOffset=Infinity},()=>{buffer.timestampOffset=1n},()=>buffer.remove(),()=>buffer.remove(0),()=>buffer.remove(Infinity,1),()=>buffer.remove(0,NaN)].every(call=>{try{call();return false}catch(reason){return reason instanceof TypeError}});
 if(typeof SharedArrayBuffer==="function"){for(const value of [new SharedArrayBuffer(2),new Uint8Array(new SharedArrayBuffer(2))]){try{buffer.appendBuffer(value);return false}catch(reason){if(!(reason instanceof TypeError))return false}}}
 const fake=Object.create(SourceBuffer.prototype),proxy=new Proxy(buffer,{get(){reads++;throw marker},getPrototypeOf(){reads++;throw marker}}),value={valueOf(){reads++;throw marker},toString(){reads++;throw marker}};
 const brands=[()=>get(SourceBuffer.prototype,"timestampOffset").set.call(fake,value),()=>get(SourceBuffer.prototype,"mode").set.call(proxy,value),()=>SourceBuffer.prototype.changeType.call(proxy,value),()=>MediaSource.prototype.addSourceBuffer.call({},value),()=>get(SourceBufferList.prototype,"length").get.call(new Proxy(source.sourceBuffers,{}))].every(call=>{try{call();return false}catch(reason){return reason instanceof TypeError}});
 const unsupported=[()=>source.addSourceBuffer("application/no-media"),()=>buffer.changeType("application/no-media")].every(call=>{try{call();return false}catch(reason){return reason instanceof DOMException&&reason.name==="NotSupportedError"}});
 source.duration=10;const order=[];buffer.remove({valueOf(){order.push("start");return 0}},{valueOf(){order.push("end");return 1}});
 const setMode=get(SourceBuffer.prototype,"mode").set,ignored=setMode.call(buffer,"bad")===undefined&&setMode.call(buffer,{toString(){throw marker}})===undefined&&buffer.mode==="segments";return actualExceptions&&rejected&&ignored&&brands&&reads===0&&unsupported&&order.join(",")==="start,end"&&buffer.updating;
})()')! == 'true'
	drain_native_buffer_owner_tasks()
}

fn test_native_buffer_list_indices_stay_live_and_late_callbacks_do_not_enter_closed_runtime() {
	$if !darwin { return }
	mut runtime, mut document, mut media := native_buffer_owner_runtime()!
	defer {
		media.set_source(none)
		media.load() or {}
		drain_native_buffer_owner_tasks()
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{
 globalThis.list=source.sourceBuffers;globalThis.buffer=source.addSourceBuffer("video/webm; codecs=vp9");const get=Object.getOwnPropertyDescriptor,d=get(list,"0"),symbol=Symbol();list.extra=1;list[symbol]=2;
 const keys=Reflect.ownKeys(list),indexed=d.value===buffer&&!d.writable&&d.enumerable&&d.configurable&&("0" in list)&&!("1" in list)&&!Reflect.set(list,"0",null)&&!Reflect.defineProperty(list,"1",{value:null})&&!Reflect.deleteProperty(list,"0")&&Reflect.deleteProperty(list,"1")&&!Reflect.preventExtensions(list)&&Object.isExtensible(list)&&keys.length===3&&keys[0]==="0"&&keys[1]==="extra"&&keys[2]===symbol&&list["00"]===undefined&&list["-0"]===undefined;
 Object.setPrototypeOf(buffer,null);if(get(SourceBuffer.prototype,"mode").get.call(buffer)!=="segments")return false;
 buffer=source.sourceBuffers[0];SourceBuffer.prototype.appendBuffer.call(buffer,new Uint8Array([0x1a,0x45]));
 SourceBuffer.prototype.addEventListener.call(buffer,"updatestart",function(){throw "released runtime"});return indexed;
})()')! == 'true'
	source := runtime.native_media_source(runtime.evaluate_host_value('source')!)!
	buffer := source.source_buffers().item(0) or { panic('missing live buffer') }
	runtime.close()
	drain_native_buffer_owner_tasks()
	assert !buffer.updating()
	media.set_source(none)
	media.load()!
	drain_native_buffer_owner_tasks()
	assert source.source_buffers().length() == 0
}

fn test_native_detached_buffer_sources_are_empty_and_typed_view_bytes_are_copied() {
	$if !darwin { return }
	mut runtime, mut document, mut media := native_buffer_owner_runtime()!
	defer {
		media.set_source(none)
		media.load() or {}
		drain_native_buffer_owner_tasks()
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host('globalThis.buffer=source.addSourceBuffer("video/webm; codecs=vp9");')!
	source := runtime.native_media_source(runtime.evaluate_host_value('source')!)!
	buffer := source.source_buffers().item(0) or { panic('missing detached-input buffer') }
	runtime.evaluate_host('globalThis.errorBrandReads=0;Object.defineProperty(TypeError,Symbol.hasInstance,{value(){errorBrandReads++;throw "author error-brand hook"},configurable:true});')!
	for expression in ['storage', 'new Uint8Array(storage)', 'new DataView(storage)'] {
		assert runtime.evaluate_host('(()=>{const storage=new ArrayBuffer(4),value=${expression};storage.transfer();return buffer.appendBuffer(value)===undefined&&buffer.updating})()')! == 'true'
		assert buffer.input_buffer_length() == 0
		drain_native_buffer_owner_tasks()
		assert !buffer.updating()
	}
	assert runtime.evaluate_host('errorBrandReads')! == '0'
	assert runtime.evaluate_host(r'(()=>{
 globalThis.failure=[];buffer.onerror=function(event){failure.push(this===buffer&&event.target===buffer)};
 const backing=new Uint8Array([99,0x1f,0x43,0xb6,0x75,0x80,99]),view=backing.subarray(1,6);
 for(const name of ["buffer","byteLength","byteOffset"])Object.defineProperty(view,name,{get(){throw "author typed-array getter"}});
 buffer.appendBuffer(view);backing.fill(0);return buffer.updating&&failure.length===0;
})()')! == 'true'
	assert buffer.input_buffer_length() == 5
	drain_native_buffer_owner_tasks()
	assert runtime.evaluate_host('source.readyState==="ended"&&!buffer.updating&&failure.length===1&&failure[0]')! == 'true'
}

fn test_native_detachment_clears_live_list_indices_and_preserves_existing_wrappers() {
	$if !darwin { return }
	mut runtime, mut document, mut media := native_buffer_owner_runtime()!
	defer {
		drain_native_buffer_owner_tasks()
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'globalThis.list=source.sourceBuffers;globalThis.buffer=source.addSourceBuffer("video/webm; codecs=vp9");globalThis.aborts=[];buffer.onabort=function(event){aborts.push(this===buffer&&event.target===buffer)};buffer.appendBuffer(new Uint8Array([0x1a,0x45]));')!
	assert runtime.evaluate_host(r'(()=>{
 const attempts=[()=>buffer.appendBuffer(new Uint8Array()),()=>{buffer.mode="sequence"},()=>{buffer.timestampOffset=1},()=>buffer.remove(0,1),()=>buffer.changeType("video/webm; codecs=vp9")];
 return attempts.every(call=>{try{call();return false}catch(reason){return reason instanceof DOMException&&reason.name==="InvalidStateError"}});
})()')! == 'true'
	media.set_source(none)
	media.load()!
	assert runtime.evaluate_host(r'(()=>{
 const attempts=[()=>buffer.abort(),()=>buffer.appendBuffer(new Uint8Array()),()=>{buffer.mode="sequence"},()=>{buffer.timestampOffset=1},()=>buffer.remove(0,1)];
 return source.readyState==="closed"&&source.sourceBuffers===list&&list.length===0&&list[0]===undefined&&!("0" in list)&&Object.keys(list).length===0&&Object.getOwnPropertyDescriptor(list,"0")===undefined&&!buffer.updating&&buffer.mode==="segments"&&attempts.every(call=>{try{call();return false}catch(reason){return reason instanceof DOMException&&reason.name==="InvalidStateError"}});
})()')! == 'true'
	drain_native_buffer_owner_tasks()
	assert runtime.evaluate_host('aborts.length===1&&aborts[0]')! == 'true'
}
