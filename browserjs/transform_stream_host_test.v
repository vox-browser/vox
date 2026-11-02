module browserjs

import dom
import html
import streams

fn native_transform_document() &dom.Document {
	url := dom.URL{value: 'https://native-transform.example.test/document.html'}
	return &dom.Document{url: url, origin_: url.origin()}
}

fn test_native_transform_prepares_real_components_before_pending_start_transform_and_flush() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TransformStreamHost.create(native_transform_document())!
	host.install(mut runtime)!
	host_handle := voidptr(host)
	runtime.define_value_host_function('__transformPreparedOwner', fn [host_handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &TransformStreamHost(host_handle) }
		record := host.record(args[0], .default_controller)!
		controller := unsafe { &streams.TransformStreamDefaultController(record.native) }
		native := controller.stream()
		assert native.wrappers_are_prepared()
		assert voidptr(html.incumbent_settings_object()) == voidptr(host.settings)
		assert host.settings.realm().script_execution_depth >= 2 && host.settings.realm().callback_execution_depth >= 1
		assert host.runtime.libjs_vm().has_running_execution_context()
		readable_host := host.runtime.readable_stream_host() or { panic('missing owning readable binding') }
		assert voidptr(native.readable()) in readable_host.records
		assert voidptr(native.writable()) in host.writable_host.records
		return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, true)
	})!
	runtime.evaluate_host(r'
 globalThis.nativeTransformChunk={};nativeTransformChunk.self=nativeTransformChunk;globalThis.nativeFlushChunk=Symbol("flush chunk");globalThis.nativeTransforms=0,nativeTransformWritten=false,nativeTransformRead=false,nativeTransformClosed=false;
 globalThis.nativeTransformer={start(controller){globalThis.nativeTransformController=controller;globalThis.nativeTransformStartOwner=this===nativeTransformer&&__transformPreparedOwner(controller);return new Promise(resolve=>globalThis.nativeTransformStartResolve=resolve)},transform(chunk,controller){nativeTransforms++;globalThis.nativeTransformOwner=this===nativeTransformer&&controller===nativeTransformController&&__transformPreparedOwner(controller);controller.enqueue(chunk);return new Promise(resolve=>globalThis.nativeTransformResolve=resolve)},flush(controller){globalThis.nativeFlushOwner=this===nativeTransformer&&controller===nativeTransformController&&__transformPreparedOwner(controller);controller.enqueue(nativeFlushChunk);return new Promise(resolve=>globalThis.nativeFlushResolve=resolve)}};
 globalThis.nativeTransform=new TransformStream(nativeTransformer);globalThis.nativeTransformWriter=nativeTransform.writable.getWriter();globalThis.nativeTransformReader=nativeTransform.readable.getReader();nativeTransformReader.read().then(result=>nativeTransformRead=result.value===nativeTransformChunk&&!result.done);nativeTransformWriter.write(nativeTransformChunk).then(()=>nativeTransformWritten=true);
')!
	native := runtime.native_transform_stream(runtime.evaluate_host_value('nativeTransform')!)!
	assert voidptr(runtime.native_readable_stream(runtime.evaluate_host_value('nativeTransform.readable')!)!) == voidptr(native.readable())
	assert voidptr(runtime.native_writable_stream(runtime.evaluate_host_value('nativeTransform.writable')!)!) == voidptr(native.writable())
	assert !native.writable().controller().started()
	assert runtime.evaluate_host('nativeTransformStartOwner&&nativeTransform instanceof TransformStream&&nativeTransformController instanceof TransformStreamDefaultController&&nativeTransform.readable instanceof ReadableStream&&nativeTransform.writable instanceof WritableStream&&nativeTransform.readable===nativeTransform.readable&&nativeTransform.writable===nativeTransform.writable&&nativeTransforms===0&&!nativeTransformRead&&!nativeTransformWritten')! == 'true'
	runtime.evaluate_host('nativeTransformStartResolve()')!
	assert runtime.evaluate_host('nativeTransformOwner&&nativeTransforms===1&&nativeTransformRead&&!nativeTransformWritten')! == 'true'
	runtime.evaluate_host('nativeTransformWriter.close().then(()=>nativeTransformClosed=true);nativeTransformResolve()')!
	assert runtime.evaluate_host('nativeTransformWritten&&nativeFlushOwner&&!nativeTransformClosed')! == 'true'
	runtime.evaluate_host('globalThis.nativeFlushRead=false;nativeTransformReader.read().then(result=>nativeFlushRead=result.value===nativeFlushChunk&&!result.done);nativeFlushResolve();globalThis.nativeTransformEOF=false;nativeTransformReader.read().then(result=>nativeTransformEOF=result.done&&result.value===undefined)')!
	assert runtime.evaluate_host('nativeFlushRead&&nativeTransformClosed&&nativeTransformEOF&&nativeTransformController.desiredSize===0')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_transform_default_identity_backpressure_and_original_controller_error() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TransformStreamHost.create(native_transform_document())!
	host.install(mut runtime)!
	runtime.evaluate_host(r'
 globalThis.nativeIdentityChunk=Symbol("identity chunk");globalThis.nativeIdentityTransform=new TransformStream();globalThis.nativeIdentityWriter=nativeIdentityTransform.writable.getWriter();globalThis.nativeIdentityWritten=false;nativeIdentityWriter.write(nativeIdentityChunk).then(()=>nativeIdentityWritten=true);
')!
	assert runtime.evaluate_host('!nativeIdentityWritten')! == 'true'
	runtime.evaluate_host('globalThis.nativeIdentityRead=false;globalThis.nativeIdentityReader=nativeIdentityTransform.readable.getReader();nativeIdentityReader.read().then(result=>nativeIdentityRead=result.value===nativeIdentityChunk&&!result.done)')!
	assert runtime.evaluate_host('nativeIdentityWritten&&nativeIdentityRead')! == 'true'
	runtime.evaluate_host(r'
 globalThis.nativeControllerReason={toString(){throw "do not stringify controller reason"}};globalThis.nativeErroredTransform=new TransformStream({start(controller){globalThis.nativeErrorTransformController=controller}});globalThis.nativeErroredWriter=nativeErroredTransform.writable.getWriter(),nativeErroredReader=nativeErroredTransform.readable.getReader();globalThis.nativeErrorRead=false,nativeErrorClosed=false,nativeErrorWrite=false;nativeErroredReader.read().catch(reason=>nativeErrorRead=reason===nativeControllerReason);nativeErroredWriter.closed.catch(reason=>nativeErrorClosed=reason===nativeControllerReason);nativeErrorTransformController.error(nativeControllerReason);nativeErroredWriter.write().catch(reason=>nativeErrorWrite=reason===nativeControllerReason);let actualThrown;try{nativeErrorTransformController.enqueue({})}catch(reason){actualThrown=reason}globalThis.nativeEnqueueClosedType=actualThrown instanceof TypeError;
')!
	assert runtime.evaluate_host('nativeErrorRead&&nativeErrorClosed&&nativeErrorWrite&&nativeErrorTransformController.desiredSize===null&&nativeEnqueueClosedType')! == 'true'
}

fn test_native_transform_pending_rejection_cancel_and_original_thrown_values() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TransformStreamHost.create(native_transform_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'
 globalThis.nativeTransformReason=Symbol("original transform rejection");globalThis.nativeTransformStartThrow=false;try{new TransformStream({start(){throw nativeTransformReason}})}catch(reason){nativeTransformStartThrow=reason===nativeTransformReason}
 globalThis.nativeRejectTransform=new TransformStream({transform(){return new Promise((resolve,reject)=>globalThis.nativeTransformReject=reject)}});globalThis.nativeRejectReader=nativeRejectTransform.readable.getReader(),nativeRejectWriter=nativeRejectTransform.writable.getWriter();globalThis.nativeRejectRead=false,nativeRejectWrite=false,nativeRejectClosed=false;nativeRejectReader.read().catch(reason=>nativeRejectRead=reason===nativeTransformReason);nativeRejectWriter.closed.catch(reason=>nativeRejectClosed=reason===nativeTransformReason);nativeRejectWriter.write({}).catch(reason=>nativeRejectWrite=reason===nativeTransformReason);nativeTransformStartThrow
')! == 'true'
	assert runtime.evaluate_host('typeof nativeTransformReject==="function"&&!nativeRejectRead&&!nativeRejectWrite')! == 'true'
	runtime.evaluate_host('nativeTransformReject(nativeTransformReason)')!
	assert runtime.evaluate_host('nativeRejectRead&&nativeRejectWrite&&nativeRejectClosed')! == 'true'
	runtime.evaluate_host(r'
 globalThis.nativeCancelReason={};globalThis.nativeCancelDone=false,nativeCancelWriterReason=false;globalThis.nativeCancelTransformer={cancel(reason){globalThis.nativeCancelReceiver=this===nativeCancelTransformer&&reason===nativeCancelReason;return new Promise(resolve=>globalThis.nativeCancelResolve=resolve)}};globalThis.nativeCancelTransform=new TransformStream(nativeCancelTransformer);globalThis.nativeCancelWriter=nativeCancelTransform.writable.getWriter();nativeCancelWriter.closed.catch(reason=>nativeCancelWriterReason=reason===nativeCancelReason);nativeCancelTransform.readable.cancel(nativeCancelReason).then(()=>nativeCancelDone=true);
')!
	assert runtime.evaluate_host('nativeCancelReceiver&&!nativeCancelDone')! == 'true'
	runtime.evaluate_host('nativeCancelResolve()')!
	assert runtime.evaluate_host('nativeCancelDone&&nativeCancelWriterReason')! == 'true'
}

fn test_native_transform_dictionary_order_reserved_any_brands_subclasses_and_termination() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TransformStreamHost.create(native_transform_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'
 globalThis.nativeTransformerConversions=[];globalThis.nativeReservedTransformerStarted=false,nativeReservedTransformerError=false,nativeTransformerCoercions=0;
 const writableStrategy={get highWaterMark(){nativeTransformerConversions.push("writable strategy")}},readableStrategy={get highWaterMark(){nativeTransformerConversions.push("readable strategy")}};
 const transformer={get cancel(){nativeTransformerConversions.push("cancel")},get flush(){nativeTransformerConversions.push("flush")},get readableType(){nativeTransformerConversions.push("readableType");return {toString(){nativeTransformerCoercions++;throw "coercion"}}},get start(){nativeTransformerConversions.push("start");return ()=>nativeReservedTransformerStarted=true},get transform(){nativeTransformerConversions.push("transform")},get writableType(){nativeTransformerConversions.push("writableType");return Symbol("reserved")}};
 try{new TransformStream(transformer,writableStrategy,readableStrategy)}catch(error){nativeReservedTransformerError=error instanceof RangeError&&error.message==="Invalid use of reserved key "+String.fromCharCode(39)+"readableType"+String.fromCharCode(39)}
 nativeReservedTransformerError&&!nativeReservedTransformerStarted&&nativeTransformerCoercions===0&&nativeTransformerConversions.join(",")==="writable strategy,readable strategy,cancel,flush,readableType,start,transform,writableType"
')! == 'true'
	assert runtime.evaluate_host(r'
 const marker={};let original=false;try{new TransformStream({get transform(){throw marker}})}catch(reason){original=reason===marker}
 const invalid=[()=>TransformStream(),()=>new TransformStream(null),()=>new TransformStream({transform:1}),()=>new TransformStream({},{highWaterMark:1n}),()=>new TransformStreamDefaultController(),()=>Object.getOwnPropertyDescriptor(TransformStream.prototype,"readable").get.call({}),()=>TransformStreamDefaultController.prototype.enqueue.call({})];
 class DerivedTransform extends TransformStream{};const derived=new DerivedTransform();original&&derived instanceof DerivedTransform&&derived instanceof TransformStream&&invalid.every(operation=>{try{operation();return false}catch(error){return error instanceof TypeError}})&&TransformStream.length===0&&TransformStreamDefaultController.prototype.enqueue.length===0&&TransformStreamDefaultController.prototype.error.length===0
')! == 'true'
	runtime.evaluate_host(r'
 globalThis.nativeTerminatedTransform=new TransformStream({start(controller){globalThis.nativeTerminateController=controller}});globalThis.nativeTerminateWriter=nativeTerminatedTransform.writable.getWriter(),nativeTerminateReader=nativeTerminatedTransform.readable.getReader();globalThis.nativeTerminatedRead=false,nativeTerminatedWrite=false;nativeTerminateReader.read().then(result=>nativeTerminatedRead=result.done);nativeTerminateWriter.closed.catch(error=>nativeTerminatedWrite=error instanceof TypeError);nativeTerminateController.terminate();
')!
	assert runtime.evaluate_host('nativeTerminatedRead&&nativeTerminatedWrite&&nativeTerminateController.desiredSize===0')! == 'true'
}
