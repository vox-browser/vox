module browserjs

import dom
import html
import streams

fn test_native_component_stream_wrapper_reuses_exact_model_and_engine_identity() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	document := native_readable_document()
	mut readable_host := ReadableStreamHost.create(document)!
	readable_host.install(mut runtime)!
	readable_host.install(mut runtime)!
	mut writable_host := WritableStreamHost.create(document)!
	writable_host.install(mut runtime)!
	readable := readable_host.settings.create_readable_stream(streams.UnderlyingSource{}, streams.QueuingStrategy{high_water_mark: 0})!
	writable := readable_host.settings.create_writable_stream(streams.UnderlyingSink{}, streams.QueuingStrategy{})!
	actual_readable := runtime.javascript_readable_stream(readable)!
	actual_writable := runtime.javascript_writable_stream(writable)!
	assert actual_readable == runtime.javascript_readable_stream(readable)!
	assert actual_writable == runtime.javascript_writable_stream(writable)!
	assert voidptr(runtime.native_readable_stream(actual_readable)!) == voidptr(readable)
	assert voidptr(runtime.native_writable_stream(actual_writable)!) == voidptr(writable)
	runtime.define_value_host_function('__actualReadableComponent', fn [actual_readable] (_ voidptr, _ []voidptr) !voidptr { return actual_readable })!
	runtime.define_value_host_function('__actualWritableComponent', fn [actual_writable] (_ voidptr, _ []voidptr) !voidptr { return actual_writable })!
	assert runtime.evaluate_host('__actualReadableComponent() instanceof ReadableStream&&__actualReadableComponent()===__actualReadableComponent()&&__actualWritableComponent() instanceof WritableStream&&__actualWritableComponent()===__actualWritableComponent()')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn native_readable_document() &dom.Document {
	url := dom.URL{value: 'https://native-readable.example.test/'}
	return &dom.Document{url: url, origin_: url.origin()}
}

fn test_native_readable_constructor_keeps_real_pending_callback_chunk_and_controller_identity() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(native_readable_document())!
	host.install(mut runtime)!
	settings := host.settings
	owner_handle := voidptr(runtime)
	runtime.define_value_host_function('__actualCallbackContext', fn [settings, owner_handle] (_ voidptr, _ []voidptr) !voidptr {
		owner := unsafe { &Runtime(owner_handle) }
		assert settings.realm().callback_execution_depth >= 1
		assert settings.realm().script_execution_depth >= 2
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(owner.libjs_vm().running_execution_context()) == voidptr(owner.realm_context)
		return C.vox_jsc_JSValueMakeUndefined(owner.context)
	})!
	runtime.evaluate_host('globalThis.chunk={};chunk.self=chunk;globalThis.pullCalls=0;globalThis.source={start(c){__actualCallbackContext();globalThis.controller=c;globalThis.sourceReceiver=this===source;return new Promise(resolve=>globalThis.startResolve=resolve)},pull(c){__actualCallbackContext();pullCalls++;globalThis.sameController=c===controller;return new Promise(resolve=>globalThis.pullResolve=resolve)}};globalThis.stream=new ReadableStream(source,{highWaterMark:0});globalThis.reader=stream.getReader();globalThis.readSettled=false;reader.read().then(result=>{globalThis.result=result;readSettled=true})')!
	object := runtime.evaluate_host_value('stream')!
	record := host.record(object, .stream)!
	native := unsafe { &streams.ReadableStream(record.native) }
	assert native.realm().id == u64(voidptr(host.settings.realm()))
	assert !native.default_controller()!.started()
	assert runtime.evaluate_host('sourceReceiver&&stream instanceof ReadableStream&&reader instanceof ReadableStreamDefaultReader&&controller instanceof ReadableStreamDefaultController&&stream.locked&&!readSettled&&pullCalls===0&&reader.closed===reader.closed')! == 'true'
	runtime.evaluate_host('startResolve();')!
	assert native.default_controller()!.started()
	assert runtime.evaluate_host('sameController&&pullCalls===1&&!readSettled')! == 'true'
	runtime.evaluate_host('controller.enqueue(chunk)')!
	assert runtime.evaluate_host('readSettled&&result.value===chunk&&!result.done&&pullCalls===1')! == 'true'
	runtime.evaluate_host('pullResolve();controller.close();globalThis.closed=false;reader.closed.then(()=>closed=true);globalThis.finalRead=false;reader.read().then(result=>finalRead=result.done&&result.value===undefined)')!
	assert runtime.evaluate_host('closed&&finalRead&&controller.desiredSize===0')! == 'true'
	runtime.evaluate_host('reader.releaseLock()')!
	assert runtime.evaluate_host('!stream.locked')! == 'true'
}

fn test_native_default_reader_retains_actual_reasons_and_source_lock_release_algorithms() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(native_readable_document())!
	host.install(mut runtime)!
	runtime.evaluate_host('globalThis.reason=Symbol("native cancel reason");globalThis.source={cancel(value){globalThis.cancelIdentity=this===source&&value===reason;return new Promise(resolve=>globalThis.cancelResolve=resolve)}};globalThis.stream=new ReadableStream(source,{highWaterMark:0});globalThis.reader=new ReadableStreamDefaultReader(stream);globalThis.cancelDone=false;reader.cancel(reason).then(()=>cancelDone=true)')!
	assert runtime.evaluate_host('cancelIdentity&&!cancelDone&&stream.locked')! == 'true'
	runtime.evaluate_host('cancelResolve();reader.releaseLock();globalThis.releasedRead=false;reader.read().catch(error=>releasedRead=error instanceof TypeError);globalThis.releasedClosed=false;reader.closed.catch(error=>releasedClosed=error instanceof TypeError)')!
	assert runtime.evaluate_host('cancelDone&&!stream.locked&&releasedRead&&releasedClosed')! == 'true'
	runtime.evaluate_host('globalThis.actualReason={toString(){throw new Error("unexpected reason coercion")}};globalThis.errorController;globalThis.errorStream=new ReadableStream({start(c){errorController=c}},{highWaterMark:0});globalThis.errorReader=errorStream.getReader();globalThis.readReason=false,closedReason=false,futureReason=false;errorReader.read().catch(error=>readReason=error===actualReason);errorReader.closed.catch(error=>closedReason=error===actualReason);errorController.error(actualReason);errorReader.read().catch(error=>futureReason=error===actualReason)')!
	assert runtime.evaluate_host('readReason&&closedReason&&futureReason')! == 'true'
	runtime.evaluate_host('globalThis.stringReason="TypeError: author reason";globalThis.stringStream=new ReadableStream({start(c){c.error(stringReason)}});globalThis.stringIdentity=false;stringStream.getReader().read().catch(error=>stringIdentity=error===stringReason)')!
	assert runtime.evaluate_host('stringIdentity')! == 'true'
	assert runtime.evaluate_host('let failed=false;try{new ReadableStreamDefaultReader(errorStream)}catch(error){failed=error instanceof TypeError}failed')! == 'true'
	assert runtime.evaluate_host('let brandFailed=false;try{ReadableStreamDefaultReader.prototype.releaseLock.call({})}catch(error){brandFailed=error instanceof TypeError}brandFailed')! == 'true'
}

fn test_native_readable_dictionaries_and_size_callbacks_keep_actual_getters_and_thrown_completions() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(native_readable_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host('globalThis.order=[];const source={get autoAllocateChunkSize(){order.push("auto");return undefined},get cancel(){order.push("cancel");return undefined},get pull(){order.push("pull");return undefined},get start(){order.push("start");return undefined},get type(){order.push("type");return undefined}};const strategy={get highWaterMark(){order.push("hwm");return 0},get size(){order.push("size");return undefined}};new ReadableStream(source,strategy);order.join(",")')! == 'hwm,size,auto,cancel,pull,start,type'
	assert runtime.evaluate_host('globalThis.getterReason={};let same=false;try{new ReadableStream({get pull(){throw getterReason}})}catch(error){same=error===getterReason}same')! == 'true'
	assert runtime.evaluate_host('let errors=0;for(const source of [null,42,"source"]){try{new ReadableStream(source)}catch(error){errors+=error instanceof TypeError}}for(const highWaterMark of [-1,NaN]){try{new ReadableStream({}, {highWaterMark})}catch(error){errors+=error instanceof RangeError}}errors')! == '5'
	runtime.evaluate_host('globalThis.sizeReason={};globalThis.sizeReceiver=false;globalThis.sizeController;globalThis.sizeStream=new ReadableStream({start(c){sizeController=c}},{highWaterMark:0,size(chunk){"use strict";sizeReceiver=this===undefined;throw sizeReason}});globalThis.sizeClosed=false;globalThis.sizeReader=sizeStream.getReader();sizeReader.closed.catch(error=>sizeClosed=error===sizeReason);globalThis.sameSizeThrow=false;try{sizeController.enqueue({})}catch(error){sameSizeThrow=error===sizeReason}')!
	assert runtime.evaluate_host('sizeReceiver&&sizeClosed&&sameSizeThrow')! == 'true'
	assert runtime.evaluate_host('let brands=0;for(const action of [()=>ReadableStream(),()=>ReadableStreamDefaultReader(sizeStream),()=>new ReadableStreamDefaultController(),()=>new ReadableByteStreamController(),()=>ReadableStream.prototype.getReader.call({})]){try{action()}catch(error){brands+=error instanceof TypeError}}brands')! == '5'
}
