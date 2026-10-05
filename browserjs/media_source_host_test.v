module browserjs

import dom
import fetch
import fileapi
import html
import page
import url as liburl

fn native_media_source_runtime() !(&Runtime, &dom.Document, &MediaSourceHost) {
	address := dom.URL{
		value: 'https://native-media-source.example.test/page'
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
	return runtime, document, sources
}

fn native_media_source_tasks() {
	mut event_loop := html.main_thread_event_loop()
	queue := event_loop.task_queue()
	event_loop.spin_until(fn [queue] () bool {
		return !queue.has_runnable_tasks()
	})
}

fn native_media_source_network_is_unused(_ &fetch.Request) !&fetch.Response {
	return error('MediaSource tag must not reach network transport')
}

fn test_native_media_source_constructor_has_actual_owner_identity_and_source_metadata() {
	$if !darwin { return }
	mut runtime, mut document, host := native_media_source_runtime()!
	defer {
		document.run_unloading_cleanup_steps()
		runtime.close()
		document.finalize()
	}
	actual := runtime.evaluate_host_value('globalThis.source=new MediaSource();source')!
	source := runtime.native_media_source(actual)!
	assert source.relevant_global_impl() == host.settings.global_object()
	assert voidptr(runtime.native_event_target(actual)!) == voidptr(&source.EventTarget)
	assert runtime.javascript_media_source(source)! == actual
	assert runtime.evaluate_host(r'(()=>{
 const get=Object.getOwnPropertyDescriptor,proto=MediaSource.prototype;
 const initial=source instanceof MediaSource&&source instanceof EventTarget&&source.readyState==="closed"&&Number.isNaN(source.duration)&&source.onsourceopen===null&&Object.prototype.toString.call(source)==="[object MediaSource]";
 const chain=Object.getPrototypeOf(proto)===EventTarget.prototype&&Object.getPrototypeOf(MediaSource)===EventTarget;
 const flags=["readyState","duration","onsourceopen","onsourceended","onsourceclose"].every(name=>{const d=get(proto,name);return d.enumerable&&d.configurable&&d.get.name==="get "+name&&d.get.length===0&&Function.prototype.toString.call(d.get).includes("[native code]")});
 const methods=proto.endOfStream.name==="endOfStream"&&proto.endOfStream.length===0&&MediaSource.isTypeSupported.name==="isTypeSupported"&&MediaSource.isTypeSupported.length===1&&Function.prototype.toString.call(proto.endOfStream).includes("[native code]");
 const worker=get(MediaSource,"canConstructInDedicatedWorker");
 class Derived extends MediaSource{};const derived=new Derived();
 const marker={};let caught;const target=new Proxy(function(){},{get(object,key){if(key==="prototype")throw marker;return Reflect.get(object,key)}});try{Reflect.construct(MediaSource,[],target)}catch(reason){caught=reason}
 return initial&&chain&&flags&&methods&&worker.enumerable&&worker.configurable&&worker.set===undefined&&worker.get.call({})===false&&derived instanceof Derived&&derived instanceof MediaSource&&caught===marker&&MediaSource.length===0&&!get(MediaSource,"prototype").writable;
})()')! == 'true'
}

fn test_native_media_source_object_url_union_uses_native_brand_and_real_store_pointer() {
	$if !darwin { return }
	mut runtime, mut document, host := native_media_source_runtime()!
	defer {
		document.run_unloading_cleanup_steps()
		runtime.close()
		document.finalize()
	}
	value := runtime.native_utf16_string(runtime.evaluate_host_value(r'
 globalThis.source=new MediaSource();globalThis.sourceAddress=URL.createObjectURL.call(null,source);sourceAddress
')!)!.str()
	source := runtime.native_media_source(runtime.evaluate_host_value('source')!)!
	record := liburl.parse(value)?
	entry := fileapi.resolve_a_blob_url(record)?
	assert entry.object.kind == .media_source
	assert entry.object.media_source_handle == voidptr(source)
	assert entry.object.media_source_attach != none
	assert entry.environment.blob_url_settings_identity() == voidptr(host.settings)
	mut request := fetch.Request.create()
	request.set_url(host.settings.parse_url(value)?)
	request.set_client(host.settings)
	request.destination = .document
	response := fetch.scheme_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: native_media_source_network_is_unused
	}).response()?
	assert response.is_network_error()
	assert runtime.evaluate_host(r'(()=>{
 let reads=0;const fake=Object.create(MediaSource.prototype),tagged={get readyState(){reads++;throw 1},[Symbol.toStringTag]:"MediaSource"},proxy=new Proxy(source,{get(){reads++;throw 2},getPrototypeOf(){reads++;throw 3}});
 const rejected=[fake,tagged,proxy,{},null,undefined].every(value=>{try{URL.createObjectURL(value);return false}catch(reason){return reason instanceof TypeError&&reason.message==="No union types matched"}});
 Object.defineProperty(MediaSource,Symbol.hasInstance,{value(){reads++;throw 4}});Object.setPrototypeOf(source,null);
 const other=URL.createObjectURL(source);URL.revokeObjectURL(other);
 return rejected&&reads===0&&other!==sourceAddress;
})()')! == 'true'
	assert runtime.evaluate_host('URL.revokeObjectURL(sourceAddress)===undefined')! == 'true'
	assert fileapi.resolve_a_blob_url(record) == none
}

fn test_native_media_source_url_attaches_actual_document_media_and_dispatches_queued_events() {
	$if !darwin { return }
	mut runtime, mut document, host := native_media_source_runtime()!
	defer {
		document.run_unloading_cleanup_steps()
		runtime.close()
		document.finalize()
	}
	actual := runtime.evaluate_host_value(r'
 globalThis.source=new MediaSource();globalThis.sourceAddress=URL.createObjectURL(source);globalThis.sourceEvents=[];
 source.addEventListener("sourceopen",function(event){sourceEvents.push([event.type,this===source,event.target===source,event.currentTarget===source,event.isTrusted,source.readyState].join(":"))});
 source.onsourceopen=function(event){sourceEvents.push("handler:"+(this===source&&event.target===source))};
 source.addEventListener("sourceended",function(event){sourceEvents.push(event.type+":"+source.readyState)});
 source.onsourceclose=function(event){sourceEvents.push(event.type+":"+source.readyState)};source
')!
	source := runtime.native_media_source(actual)!
	value := runtime.native_utf16_string(runtime.evaluate_host_value('sourceAddress')!)!.str()
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video')!
	mut media := html.html_media_element_for_dom_element(element)?
	media.set_source(value)
	media.load()!
	assert source.media_element_assigned_to()? == media
	assert source.ready_state() == .open
	assert runtime.evaluate_host('source.readyState==="open"&&sourceEvents.length===0')! == 'true'
	native_media_source_tasks()
	assert runtime.native_utf16_string(runtime.evaluate_host_value('sourceEvents.join(",")')!)!.str() == 'sourceopen:true:true:true:true:open,handler:true'
	assert runtime.evaluate_host('source.duration=12.5;source.duration===12.5')! == 'true'
	assert media.duration() == 12.5
	assert runtime.evaluate_host('source.endOfStream(undefined)===undefined&&source.readyState==="ended"&&sourceEvents.length===2')! == 'true'
	native_media_source_tasks()
	assert runtime.evaluate_host('sourceEvents[2]==="sourceended:ended"')! == 'true'
	assert runtime.evaluate_host('URL.revokeObjectURL(sourceAddress)===undefined')! == 'true'
	assert fileapi.resolve_a_blob_url(liburl.parse(value)?) == none
	assert source.media_element_assigned_to()? == media
	assert source.ready_state() == .ended
	media.set_source(none)
	media.load()!
	assert source.media_element_assigned_to() == none
	native_media_source_tasks()
	assert runtime.evaluate_host('source.readyState==="closed"&&Number.isNaN(source.duration)&&sourceEvents[3]==="sourceclose:closed"')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
	assert host.settings.realm().script_execution_depth == 0
}

fn test_native_media_source_conversions_errors_and_callback_close_use_actual_engine_values() {
	$if !darwin { return }
	mut runtime, mut document, host := native_media_source_runtime()!
	defer {
		document.run_unloading_cleanup_steps()
		runtime.close()
		document.finalize()
	}
	result := runtime.evaluate_host(r'(()=>{
 globalThis.source=new MediaSource();const marker={};let numberReason,stringReason,enumReason;
 try{source.duration={valueOf(){throw marker}}}catch(reason){numberReason=reason}
 try{MediaSource.isTypeSupported({[Symbol.toPrimitive](hint){if(hint!=="string")throw 1;throw marker}})}catch(reason){stringReason=reason}
 try{source.endOfStream({toString(){throw marker}})}catch(reason){enumReason=reason}
 globalThis.mediaSourceTypeErrors=[()=>MediaSource(),()=>MediaSource.isTypeSupported(),()=>MediaSource.isTypeSupported(Symbol()),()=>source.endOfStream(null),()=>source.endOfStream("invalid"),()=>{source.duration=-1},()=>{source.duration=NaN},()=>{source.duration=1n},()=>Object.getOwnPropertyDescriptor(MediaSource.prototype,"duration").set.call({},{valueOf(){throw marker}}),()=>MediaSource.prototype.endOfStream.call({})].map(call=>{try{call();return "no error"}catch(reason){return reason.name}});
 const typeErrors=mediaSourceTypeErrors.every(name=>name==="TypeError");
 const invalidStates=[()=>{source.duration=1},()=>source.endOfStream(),()=>source.endOfStream("decode")].every(call=>{try{call();return false}catch(reason){return reason instanceof DOMException&&reason.name==="InvalidStateError"}});
 source.onsourceopen=1;const cleared=source.onsourceopen===null;const handler=function(){};source.onsourceopen=handler;
 return numberReason===marker&&stringReason===marker&&enumReason===marker&&typeErrors&&invalidStates&&cleared&&source.onsourceopen===handler&&MediaSource.isTypeSupported.call(null,"video/webm; codecs=vp8")&&!MediaSource.isTypeSupported("");
})()')!
	assert runtime.evaluate_host('mediaSourceTypeErrors.join(",")')! == 'TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError'
	assert result == 'true'
	mut source := runtime.native_media_source(runtime.evaluate_host_value('source')!)!
	assert runtime.evaluate_host('source.onsourceopen=function(){throw "released engine"};true')! == 'true'
	runtime.close()
	assert host.closed
	source.set_ready_state_to_open_and_fire_sourceopen_event()
	native_media_source_tasks()
	assert source.ready_state() == .open
}
