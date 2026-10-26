module browserjs

import dom
import html

fn native_writable_document() &dom.Document {
	url := dom.URL{value: 'https://native-writable.example.test/document.html'}
	return &dom.Document{url: url, origin_: url.origin()}
}

fn test_native_writable_pending_start_write_close_backpressure_capabilities_and_owner_context() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := WritableStreamHost.create(native_writable_document())!
	host.install(mut runtime)!
	settings := host.settings
	owner_handle := voidptr(runtime)
	runtime.define_value_host_function('__writableOwnerContext', fn [settings, owner_handle] (_ voidptr, _ []voidptr) !voidptr {
		owner := unsafe { &Runtime(owner_handle) }
		assert owner.libjs_vm().has_running_execution_context()
		assert settings.realm().script_execution_depth >= 2 && settings.realm().callback_execution_depth >= 1
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return C.JSValueMakeBoolean(owner.context, true)
	})!
	runtime.evaluate_host(r'
 globalThis.nativeWritableChunk={};nativeWritableChunk.self=nativeWritableChunk;globalThis.nativeSecondChunk=Symbol("second chunk");globalThis.nativeWrites=[];globalThis.nativeWriteSettled=0;
 globalThis.nativeSink={start(controller){globalThis.nativeController=controller;globalThis.nativeStartReceiver=this===nativeSink&&__writableOwnerContext();return new Promise(resolve=>globalThis.nativeStartResolve=resolve)},write(chunk,controller){nativeWrites.push(chunk);globalThis.nativeWriteReceiver=this===nativeSink&&controller===nativeController&&__writableOwnerContext();return new Promise(resolve=>globalThis.nativeWriteResolve=resolve)},close(){globalThis.nativeCloseReceiver=this===nativeSink&&__writableOwnerContext();return new Promise(resolve=>globalThis.nativeCloseResolve=resolve)}};
 globalThis.nativeWritable=new WritableStream(nativeSink);globalThis.nativeWriter=nativeWritable.getWriter();globalThis.nativeClosed=nativeWriter.closed;globalThis.initialReady=nativeWriter.ready;
 nativeWriter.write(nativeWritableChunk).then(()=>nativeWriteSettled++);nativeWriter.write(nativeSecondChunk).then(()=>nativeWriteSettled++);globalThis.pressuredReady=nativeWriter.ready;globalThis.nativeReadySettled=false;pressuredReady.then(()=>nativeReadySettled=true);
')!
	native := runtime.native_writable_stream(runtime.evaluate_host_value('nativeWritable')!)!
	assert native.realm().id == u64(voidptr(settings.realm()))
	assert !native.controller().started()
	assert runtime.evaluate_host('nativeStartReceiver&&nativeWritable instanceof WritableStream&&nativeWriter instanceof WritableStreamDefaultWriter&&nativeController instanceof WritableStreamDefaultController&&nativeWritable.locked&&nativeWrites.length===0&&nativeWriter.desiredSize===-1&&nativeClosed===nativeWriter.closed&&initialReady!==pressuredReady&&pressuredReady===nativeWriter.ready&&!nativeReadySettled')! == 'true'
	runtime.evaluate_host('nativeStartResolve()')!
	assert native.controller().started()
	assert runtime.evaluate_host('nativeWrites.length===1&&nativeWrites[0]===nativeWritableChunk&&nativeWriteReceiver&&nativeWriteSettled===0&&!nativeReadySettled')! == 'true'
	runtime.evaluate_host('nativeWriteResolve()')!
	assert runtime.evaluate_host('nativeWrites.length===2&&nativeWrites[1]===nativeSecondChunk&&nativeWriteSettled===1&&!nativeReadySettled')! == 'true'
	runtime.evaluate_host('nativeWriteResolve()')!
	assert runtime.evaluate_host('nativeWriteSettled===2&&nativeReadySettled&&nativeWriter.desiredSize===1&&nativeWriter.ready===pressuredReady')! == 'true'
	runtime.evaluate_host('globalThis.nativeCloseSettled=false,nativeClosedSettled=false;nativeClosed.then(()=>nativeClosedSettled=true);nativeWriter.close().then(()=>nativeCloseSettled=true)')!
	assert runtime.evaluate_host('nativeCloseReceiver&&!nativeCloseSettled&&!nativeClosedSettled&&nativeWriter.closed===nativeClosed')! == 'true'
	runtime.evaluate_host('nativeCloseResolve()')!
	assert runtime.evaluate_host('nativeCloseSettled&&nativeClosedSettled&&nativeWriter.desiredSize===0&&nativeController.signal===nativeController.signal&&!nativeController.signal.aborted')! == 'true'
	runtime.evaluate_host('nativeWriter.releaseLock();globalThis.releasedDesiredError=false;try{nativeWriter.desiredSize}catch(error){releasedDesiredError=error instanceof TypeError};globalThis.releasedReadiness=false;nativeWriter.ready.catch(error=>releasedReadiness=error instanceof TypeError)')!
	assert runtime.evaluate_host('!nativeWritable.locked&&releasedDesiredError&&releasedReadiness')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_writable_abort_signal_and_pending_abort_keep_original_and_later_reasons() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := WritableStreamHost.create(native_writable_document())!
	host.install(mut runtime)!
	runtime.evaluate_host(r'
 globalThis.nativeAbortReason=Symbol("original abort reason");globalThis.nativeAbortLater={toString(){throw "must not coerce later abort reason"}};globalThis.nativeAbortCalled=false;
 globalThis.nativeAbortSink={start(controller){globalThis.nativeAbortController=controller},write(){return new Promise(resolve=>globalThis.nativeAbortWriteResolve=resolve)},abort(reason){nativeAbortCalled=this===nativeAbortSink&&reason===nativeAbortReason;return new Promise((resolve,reject)=>globalThis.nativeAbortReject=reject)}};
 globalThis.nativeAbortWritable=new WritableStream(nativeAbortSink);globalThis.nativeAbortWriter=new WritableStreamDefaultWriter(nativeAbortWritable);globalThis.nativeAbortSignal=nativeAbortController.signal;
 globalThis.nativeAbortEvent=null;nativeAbortSignal.addEventListener("abort",function(event){nativeAbortEvent=event;globalThis.nativeAbortEventReceiver=this===nativeAbortSignal});
 nativeAbortWriter.write({});
')!
	// Let source startup jobs initiate the write before requesting abort; an
	// abort in the constructor's task would instead reject the queued write.
	assert runtime.evaluate_host('typeof nativeAbortWriteResolve==="function"')! == 'true'
	runtime.evaluate_host('globalThis.nativeAbortDone=false,nativeAbortError=false,nativeAbortClosedError=false;nativeAbortWriter.closed.catch(reason=>nativeAbortClosedError=reason===nativeAbortReason);nativeAbortWriter.abort(nativeAbortReason).catch(reason=>{nativeAbortDone=true;nativeAbortError=reason===nativeAbortLater})')!
	native := runtime.native_writable_stream(runtime.evaluate_host_value('nativeAbortWritable')!)!
	actual_signal := runtime.native_abort_signal(runtime.evaluate_host_value('nativeAbortSignal')!)!
	assert voidptr(actual_signal) == voidptr(native.controller().signal().dom_signal())
	assert runtime.evaluate_host('nativeAbortSignal instanceof AbortSignal&&nativeAbortSignal instanceof EventTarget&&nativeAbortSignal===nativeAbortController.signal&&nativeAbortSignal.aborted&&nativeAbortSignal.reason===nativeAbortReason&&nativeAbortEventReceiver&&nativeAbortEvent.target===nativeAbortSignal&&nativeAbortEvent.isTrusted&&!nativeAbortCalled&&!nativeAbortDone&&nativeAbortWriter.desiredSize===null')! == 'true'
	runtime.evaluate_host('nativeAbortWriteResolve()')!
	assert runtime.evaluate_host('nativeAbortCalled&&!nativeAbortDone&&!nativeAbortClosedError')! == 'true'
	runtime.evaluate_host('nativeAbortReject(nativeAbortLater)')!
	assert runtime.evaluate_host('nativeAbortDone&&nativeAbortError&&nativeAbortClosedError&&nativeAbortSignal.reason===nativeAbortReason')! == 'true'
}

fn test_native_writable_callback_size_and_thenable_abrupt_values_keep_engine_identity() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := WritableStreamHost.create(native_writable_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'
 globalThis.nativeWritableReason={toString(){throw "do not stringify original reason"}};globalThis.nativeStartThrow=false;
 try{new WritableStream({start(){throw nativeWritableReason}})}catch(reason){nativeStartThrow=reason===nativeWritableReason}
 globalThis.nativeWriteError=false,nativeWriteClosedError=false;globalThis.nativeThrowStream=new WritableStream({write(){throw nativeWritableReason}});globalThis.nativeThrowWriter=nativeThrowStream.getWriter();nativeThrowWriter.closed.catch(reason=>nativeWriteClosedError=reason===nativeWritableReason);nativeThrowWriter.write(Symbol("chunk")).catch(reason=>nativeWriteError=reason===nativeWritableReason);
 nativeStartThrow
')! == 'true'
	assert runtime.evaluate_host('nativeWriteError&&nativeWriteClosedError&&nativeThrowWriter.desiredSize===null')! == 'true'
	runtime.evaluate_host(r'
 globalThis.nativeSizeReason=Symbol("must not convert size result");globalThis.nativeSizeWrites=0,nativeSizeConversions=0;globalThis.nativeSizeError=false,nativeSizeClosedError=false;
 globalThis.nativeSizeStream=new WritableStream({write(){nativeSizeWrites++}},{size(chunk){return {[Symbol.toPrimitive](){nativeSizeConversions++;throw nativeSizeReason}}}});globalThis.nativeSizeWriter=nativeSizeStream.getWriter();nativeSizeWriter.closed.catch(reason=>nativeSizeClosedError=reason instanceof RangeError);nativeSizeWriter.write(nativeWritableReason).catch(reason=>nativeSizeError=reason instanceof RangeError);
')!
	assert runtime.evaluate_host('nativeSizeError&&nativeSizeClosedError&&nativeSizeWrites===0&&nativeSizeConversions===0')! == 'true'
	runtime.evaluate_host(r'
 globalThis.nativeThenableError=false,nativeThenableClosedError=false;globalThis.nativeThenableStream=new WritableStream({write(){return {get then(){throw nativeWritableReason}}}});globalThis.nativeThenableWriter=nativeThenableStream.getWriter();nativeThenableWriter.closed.catch(reason=>nativeThenableClosedError=reason===nativeWritableReason);nativeThenableWriter.write().catch(reason=>nativeThenableError=reason===nativeWritableReason);
 globalThis.nativeStringReason="TypeError: author string reason";globalThis.nativeStringIdentity=false;new WritableStream({write(){return Promise.reject(nativeStringReason)}}).getWriter().write().catch(reason=>nativeStringIdentity=reason===nativeStringReason);
')!
	assert runtime.evaluate_host('nativeThenableError&&nativeThenableClosedError&&nativeStringIdentity')! == 'true'
}

fn test_native_writable_constructor_conversion_order_reserved_any_brands_and_subclasses() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := WritableStreamHost.create(native_writable_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'
 globalThis.nativeWritableConversions=[];globalThis.nativeReservedCoercions=0,nativeReservedStarted=false,nativeReservedError=false;
 globalThis.nativeOrderedStrategy={get highWaterMark(){nativeWritableConversions.push("highWaterMark");return {valueOf(){nativeWritableConversions.push("number");return 1}}},get size(){nativeWritableConversions.push("size");return undefined}};
 globalThis.nativeOrderedSink={get abort(){nativeWritableConversions.push("abort")},get close(){nativeWritableConversions.push("close")},get start(){nativeWritableConversions.push("start");return ()=>nativeReservedStarted=true},get type(){nativeWritableConversions.push("type");return {toString(){nativeReservedCoercions++;throw "must not coerce reserved any"}}},get write(){nativeWritableConversions.push("write")}};
 try{new WritableStream(nativeOrderedSink,nativeOrderedStrategy)}catch(error){nativeReservedError=error instanceof RangeError}
 nativeReservedError&&!nativeReservedStarted&&nativeReservedCoercions===0&&nativeWritableConversions.join(",")==="highWaterMark,number,size,abort,close,start,type,write"
')! == 'true'
	assert runtime.evaluate_host(r'
 globalThis.nativeDictionaryReason={};globalThis.nativeDictionaryThrow=false;try{new WritableStream({get write(){throw nativeDictionaryReason}})}catch(reason){nativeDictionaryThrow=reason===nativeDictionaryReason}
 const invalid=[()=>WritableStream(),()=>new WritableStream(null),()=>new WritableStream({},5),()=>new WritableStream({write:5}),()=>new WritableStream({},{highWaterMark:1n}),()=>new WritableStream({},{highWaterMark:Symbol()}),()=>new WritableStream({},{size:{}}),()=>new WritableStreamDefaultWriter(),()=>new WritableStreamDefaultWriter({}),()=>new WritableStreamDefaultController(),()=>Object.getOwnPropertyDescriptor(WritableStream.prototype,"locked").get.call({}),()=>WritableStreamDefaultController.prototype.error.call({})];
 nativeDictionaryThrow&&invalid.every(operation=>{try{operation();return false}catch(error){return error instanceof TypeError}})
')! == 'true'
	assert runtime.evaluate_host(r'
 class DerivedWritable extends WritableStream{};class DerivedWriter extends WritableStreamDefaultWriter{};
 globalThis.nativeDerived=new DerivedWritable();globalThis.nativeDerivedWriter=new DerivedWriter(nativeDerived);
 globalThis.nativeLockedAbort=false,nativeLockedClose=false,nativeBadWrite=false;nativeDerived.abort().catch(error=>nativeLockedAbort=error instanceof TypeError);nativeDerived.close().catch(error=>nativeLockedClose=error instanceof TypeError);WritableStreamDefaultWriter.prototype.write.call({}).catch(error=>nativeBadWrite=error instanceof TypeError);
 nativeDerived instanceof DerivedWritable&&nativeDerived instanceof WritableStream&&nativeDerivedWriter instanceof DerivedWriter&&nativeDerivedWriter instanceof WritableStreamDefaultWriter&&WritableStream.length===0&&WritableStreamDefaultWriter.length===1&&WritableStream.prototype.abort.length===0&&WritableStreamDefaultWriter.prototype.write.length===0&&WritableStreamDefaultController.prototype.error.length===0
')! == 'true'
	assert runtime.evaluate_host('nativeLockedAbort&&nativeLockedClose&&nativeBadWrite')! == 'true'
}
