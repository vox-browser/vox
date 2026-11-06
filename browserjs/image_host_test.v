module browserjs

import dom
import html
import webidl

fn image_host_fixture() (&Runtime, &ImageHost, &html.EventLoop, &html.HTMLImageElementModel) {
	document := html.parse_navigation_document('<!doctype html><img id="source">', dom.URL{value: 'https://image-host.test/'}, dom.URL{value: 'https://image-host.test/'}.origin(), none) or { panic(err) }
	mut runtime := Runtime.create()
	mut host := ImageHost.create(document, none, none) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	image := document.get_element_by_id('source') or { panic('missing image') }
	mut key := ''
	for candidate, element in host.elements_for_binding() {
		if voidptr(element) == voidptr(image) { key = candidate }
	}
	runtime.evaluate_host('globalThis.image={};__ladybirdImageBind(image,"${key}")') or { panic(err) }
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(image) })
	return runtime, host, host.settings.responsible_event_loop(), model
}

fn image_host_drain(owner &html.EventLoop) {
	mut loop := unsafe { &html.EventLoop(owner) }
	for _ in 0 .. 50 {
		loop.perform_a_microtask_checkpoint()
		mut queue := loop.task_queue()
		task := queue.take_first_runnable() or { break }
		task.execute()
	}
	loop.perform_a_microtask_checkpoint()
}

fn test_native_image_load_property_handler_receives_the_actual_request_event_in_listener_order() {
	$if !darwin { return }
	mut runtime, _, owner, mut model := image_host_fixture()
	defer { runtime.close() }
	model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
		bitmap := &dom.Bitmap_{ width: 1, height: 1, pitch: 4, data: [u8(0), 128, 0, 255] }
		return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{ frame: dom.DecodedImageFrame_.create(bitmap) }], 0, false)
	})
	runtime.evaluate_host(r'
 globalThis.imageEvents=[];
 image.addEventListener("load",()=>imageEvents.push("before"));
 globalThis.imageLoaded=function(event){
  imageEvents.push(this===image&&event.target===image&&event.currentTarget===image&&image.naturalWidth===1?"property":"wrong owner");
 };
 image.onload=imageLoaded;
 image.addEventListener("load",()=>imageEvents.push("after"));
 __ladybirdImageSetAttribute(image,"src","/loaded.png");
 ')!
	image_host_drain(owner)
	assert runtime.evaluate_host('JSON.stringify(imageEvents)')! == '["before","property","after"]'
	assert runtime.evaluate_host('image.onload===imageLoaded&&image.onerror===null')! == 'true'
	runtime.evaluate_host('image.onload=null;image.dispatchEvent(new Event("load"));')!
	assert runtime.evaluate_host('image.onload===null')! == 'true'
	assert runtime.evaluate_host('JSON.stringify(imageEvents)')! == '["before","property","after","before","after"]'
}

fn test_native_image_error_property_handler_replacement_null_conversion_and_receiver_checks() {
	$if !darwin { return }
	mut runtime, _, owner, mut model := image_host_fixture()
	defer { runtime.close() }
	model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return error('image failed') })
	runtime.evaluate_host(r'
 globalThis.imageErrors=[];
 image.onerror=()=>imageErrors.push("replaced");
 globalThis.imageFailed=function(event){imageErrors.push(this===image&&event.target===image&&event.type==="error"?"error":"wrong owner");};
 image.onerror=imageFailed;
 __ladybirdImageSetAttribute(image,"src","/broken.png");
 ')!
	image_host_drain(owner)
	assert runtime.evaluate_host('JSON.stringify(imageErrors)')! == '["error"]'
	assert runtime.evaluate_host(r'(function(){
 if(image.onerror!==imageFailed)return false;
 image.onerror=42;if(image.onerror!==null)return false;
 const property=Object.getOwnPropertyDescriptor(HTMLImageElement.prototype,"onload");
 let invalid=0;for(const call of [()=>property.get.call({}),()=>property.set.call({},function(){})])try{call()}catch(error){if(error instanceof TypeError)invalid++;}
 return property.enumerable&&property.configurable&&invalid===2;
 })()')! == 'true'
}

fn test_native_image_decode_fulfills_on_actual_owning_task_and_has_distinct_capabilities() {
	$if !darwin {
		return
	}
	mut runtime, host, owner, mut model := image_host_fixture()
	defer { runtime.close() }
	mut request := model.current_request()
	request.set_state(.completely_available)
	assert runtime.evaluate_host('globalThis.result="pending";globalThis.first=image.decode();globalThis.second=image.decode();first.then(value=>result=value===undefined?"decoded":"wrong");first instanceof Promise&&first!==second&&image instanceof HTMLImageElement&&image.decode.length===0')! == 'true'
	assert runtime.evaluate_host('result')! == 'pending'
	mut queue := owner.task_queue()
	mut task := queue.take_first_runnable() or { panic('source settlement task missing') }
	for task.source() != .dom_manipulation {
		task.execute()
		task = queue.take_first_runnable() or { panic('decode task missing') }
	}
	assert task.source() == .dom_manipulation
	assert voidptr(task.document()?) == voidptr(host.document)
	task.execute()
	assert runtime.evaluate_host('result')! == 'decoded'
	image_host_drain(owner)
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_image_decode_rejects_with_retained_actual_encoding_error_and_binding_error_promises() {
	$if !darwin {
		return
	}
	mut runtime, host, owner, mut model := image_host_fixture()
	defer { runtime.close() }
	mut request := model.current_request()
	request.set_state(.broken)
	assert runtime.evaluate_host('globalThis.failure=null;globalThis.bindingFailure=null;let threw=false;let rejected;try{rejected=HTMLImageElement.prototype.decode.call({})}catch(e){threw=true}rejected.catch(e=>bindingFailure=e);image.decode().catch(e=>failure=e);!threw&&rejected instanceof Promise')! == 'true'
	image_host_drain(owner)
	assert runtime.evaluate_host('failure instanceof DOMException&&failure.name==="EncodingError"&&failure.message==="Current request state is broken"&&failure.code===0&&bindingFailure instanceof TypeError')! == 'true'
	actual := runtime.evaluate_host_value('failure')!
	defer { runtime.release_javascript_value(actual) }
	exception := runtime.native_dom_exception(actual)!
	assert webidl.dom_exception_from_object(exception)?.name() == 'EncodingError'
	assert voidptr(host.image_for_binding(runtime.evaluate_host_value('image')!)!) == voidptr(model.to_html_element()?)
}

fn test_native_image_decode_preserves_original_engine_replay_abrupt_completion_value() {
	$if !darwin {
		return
	}
	document := html.parse_navigation_document('<!doctype html><img id="source">', dom.URL{value: 'https://image-replay.test/'}, dom.URL{value: 'https://image-replay.test/'}.origin(), none)!
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ImageHost.create(document, none, fn (runtime &Runtime) ! {
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw decodeReason')!
	})!
	host.install(mut runtime)!
	mut key := ''
	for candidate, element in host.elements_for_binding() {
		if element.get_attribute_value('id') == 'source' { key = candidate }
	}
	assert runtime.evaluate_host('globalThis.image={};__ladybirdImageBind(image,"${key}");globalThis.decodeReason={};globalThis.caughtReason=null;image.decode().catch(e=>caughtReason=e);')! != ''
	image_host_drain(host.settings.responsible_event_loop())
	assert runtime.evaluate_host('caughtReason===decodeReason')! == 'true'
}

fn test_native_image_decode_owner_capability_can_settle_after_runtime_closes() {
	$if !darwin {
		return
	}
	mut runtime, host, owner, mut model := image_host_fixture()
	mut request := model.current_request()
	request.set_state(.completely_available)
	runtime.evaluate_host('image.decode().then(()=>{throw "released engine must not be entered"})')!
	runtime.close()
	image_host_drain(owner)
	assert host.closed
	assert runtime.context == unsafe { nil }
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_image_attribute_replacement_updates_the_same_request_model_before_decode() {
	$if !darwin {
		return
	}
	mut runtime, host, owner, mut model := image_host_fixture()
	defer { runtime.close() }
	model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
		bitmap := &dom.Bitmap_{ width: 1, height: 1, pitch: 4, data: [u8(0), 128, 0, 255] }
		return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{ frame: dom.DecodedImageFrame_.create(bitmap) }], 0, false)
	})
	assert runtime.evaluate_host('__ladybirdImageSetAttribute(image,"src","/green.png");globalThis.attributeDecoded=false;image.decode().then(()=>attributeDecoded=true);image.naturalWidth===1&&image.naturalHeight===1&&image.currentSrc==="https://image-host.test/green.png"')! == 'true'
	actual := runtime.evaluate_host_value('image')!
	defer { runtime.release_javascript_value(actual) }
	native := host.image_for_binding(actual)!
	assert native.get_attribute_value('src') == '/green.png'
	assert host.document.cached_display_list() == none
	image_host_drain(owner)
	assert runtime.evaluate_host('attributeDecoded')! == 'true'
}
