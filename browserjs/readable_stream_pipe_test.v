module browserjs

import dom

fn native_pipe_document() &dom.Document {
	url := dom.URL{value: 'https://pipe-native.example.test/'}
	return &dom.Document{url: url, origin_: url.origin()}
}

fn test_native_public_pipe_to_keeps_actual_chunks_pending_writes_close_and_capability() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TransformStreamHost.create(native_pipe_document())!
	host.install(mut runtime)!
	runtime.evaluate_host(r'{
 globalThis.pipeChunk={};pipeChunk.self=pipeChunk;globalThis.pipeWritten=[],pipeClosed=0,pipeDone=false,pipeController=undefined;
 globalThis.pipeSource=new ReadableStream({start(controller){pipeController=controller}},{highWaterMark:0});globalThis.pipeDestination=new WritableStream({write(chunk){pipeWritten.push(chunk);return new Promise(resolve=>globalThis.pipeWriteResolve=resolve)},close(){pipeClosed++;return new Promise(resolve=>globalThis.pipeCloseResolve=resolve)}});
 globalThis.pipePromise=pipeSource.pipeTo(pipeDestination);pipePromise.then(()=>pipeDone=true);pipeController.enqueue(pipeChunk);pipeController.close();
}')!
	assert runtime.evaluate_host('pipePromise instanceof Promise&&pipeSource.locked&&pipeDestination.locked&&pipeWritten.length===1&&pipeWritten[0]===pipeChunk&&!pipeDone&&pipeClosed===0')! == 'true'
	actual_promise := runtime.evaluate_host_value('pipePromise')!
	mut readable_host := runtime.readable_stream_host() or { panic('missing actual readable host') }
	mut found_capability := false
	for _, bridge in runtime.webidl_promise_bridges_ {
		if bridge.capability.promise == actual_promise {
			assert actual_promise == readable_host.promise(bridge.native)!
			found_capability = true
			break
		}
	}
	assert found_capability
	runtime.evaluate_host('pipeWriteResolve()')!
	assert runtime.evaluate_host('pipeClosed===1&&!pipeDone&&pipeSource.locked&&pipeDestination.locked')! == 'true'
	runtime.evaluate_host('pipeCloseResolve()')!
	assert runtime.evaluate_host('pipeDone&&!pipeSource.locked&&!pipeDestination.locked')! == 'true'
}

fn test_native_public_pipe_to_uses_actual_signal_and_later_action_rejection() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TransformStreamHost.create(native_pipe_document())!
	host.install(mut runtime)!
	runtime.evaluate_host(r'{
 globalThis.pipeAbortReason={toString(){throw "do not coerce reason"}},pipeLater=Symbol("later abort rejection"),pipeAbortSeen=false,pipeCancelSeen=false,pipeRejected=false,pipeController=new AbortController();
 globalThis.pipeAbortSource=new ReadableStream({cancel(reason){pipeCancelSeen=reason===pipeAbortReason;return new Promise(resolve=>globalThis.pipeCancelResolve=resolve)}},{highWaterMark:0});globalThis.pipeAbortDestination=new WritableStream({abort(reason){pipeAbortSeen=reason===pipeAbortReason;return new Promise((resolve,reject)=>globalThis.pipeAbortReject=reject)}});
 pipeAbortSource.pipeTo(pipeAbortDestination,{signal:pipeController.signal}).catch(reason=>pipeRejected=reason===pipeLater);pipeController.abort(pipeAbortReason);
}')!
	assert runtime.evaluate_host('pipeAbortSeen&&pipeCancelSeen&&!pipeRejected&&pipeAbortSource.locked&&pipeAbortDestination.locked')! == 'true'
	runtime.evaluate_host('pipeAbortReject(pipeLater)')!
	assert runtime.evaluate_host('pipeRejected&&!pipeAbortSource.locked&&!pipeAbortDestination.locked')! == 'true'
	runtime.evaluate_host('pipeCancelResolve()')!
	runtime.evaluate_host(r'{
 globalThis.pipeDefaultReason=undefined,pipeDefaultAbort=false,pipeDefaultCancel=false,pipeDefaultRejected=false;const controller=new AbortController(),source=new ReadableStream({cancel(reason){pipeDefaultCancel=reason===controller.signal.reason&&reason instanceof DOMException&&reason.name==="AbortError"}},{highWaterMark:0}),destination=new WritableStream({abort(reason){pipeDefaultAbort=reason===controller.signal.reason}});source.pipeTo(destination,{signal:controller.signal}).catch(reason=>{pipeDefaultReason=reason;pipeDefaultRejected=reason===controller.signal.reason});controller.abort();
}')!
	assert runtime.evaluate_host('pipeDefaultAbort&&pipeDefaultCancel&&pipeDefaultRejected&&pipeDefaultReason instanceof DOMException&&pipeDefaultReason.name==="AbortError"')! == 'true'
}

fn test_native_public_pipe_through_returns_actual_readable_with_source_lock_checks() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TransformStreamHost.create(native_pipe_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'{
 globalThis.pipeThroughChunk={},pipeThroughValue=false,pipeThroughSourceController=undefined;
 globalThis.pipeThroughSource=new ReadableStream({start(controller){pipeThroughSourceController=controller}},{highWaterMark:0});globalThis.pipeTransform=new TransformStream({transform(chunk,controller){controller.enqueue(chunk)}});globalThis.pipeThroughResult=pipeThroughSource.pipeThrough(pipeTransform);const reader=pipeThroughResult.getReader();reader.read().then(result=>pipeThroughValue=result.value===pipeThroughChunk&&!result.done);pipeThroughSourceController.enqueue(pipeThroughChunk);pipeThroughSourceController.close();
 pipeThroughResult===pipeTransform.readable
}')! == 'true'
	assert runtime.evaluate_host('pipeThroughValue')! == 'true'
	assert runtime.evaluate_host(r'{
 const readable=new ReadableStream();readable.getReader();const source=new ReadableStream({start(controller){controller.close()}});const writable=new WritableStream();source.pipeThrough({readable,writable})===readable
}')! == 'true'
	assert runtime.evaluate_host(r'{
 globalThis.pipeOriginal=Symbol("already failed source");const source=new ReadableStream({start(controller){controller.error(pipeOriginal)}});const readable=new ReadableStream();const writable=new WritableStream();source.pipeThrough({readable,writable})===readable
}')! == 'true'
}

fn test_native_public_pipe_generated_dictionary_order_brand_and_original_getter_exception() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TransformStreamHost.create(native_pipe_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'{
 globalThis.pipeDictionaryOrder=[];const source=new ReadableStream({start(controller){controller.close()}}),readable=new ReadableStream(),writable=new WritableStream();
 const pair={get readable(){pipeDictionaryOrder.push("readable");return readable},get writable(){pipeDictionaryOrder.push("writable");return writable}};const options={get preventAbort(){pipeDictionaryOrder.push("preventAbort");return {valueOf(){throw "ToBoolean must not coerce"}}},get preventCancel(){pipeDictionaryOrder.push("preventCancel");return true},get preventClose(){pipeDictionaryOrder.push("preventClose");return true},get signal(){pipeDictionaryOrder.push("signal");return undefined}};
 source.pipeThrough(pair,options)===readable&&pipeDictionaryOrder.join(",")==="readable,writable,preventAbort,preventCancel,preventClose,signal"&&ReadableStream.prototype.pipeTo.length===1&&ReadableStream.prototype.pipeThrough.length===1
}')! == 'true'
	runtime.evaluate_host(r'{
 globalThis.pipeGetterReason={},pipeGetterRejected=false,pipeGetterThrown=false;const source=new ReadableStream(),destination=new WritableStream();source.pipeTo(destination,{get signal(){throw pipeGetterReason}}).catch(reason=>pipeGetterRejected=reason===pipeGetterReason);try{source.pipeThrough({get readable(){throw pipeGetterReason}})}catch(reason){pipeGetterThrown=reason===pipeGetterReason}
 globalThis.pipeBrandRejected=false;ReadableStream.prototype.pipeTo.call({},destination).catch(error=>pipeBrandRejected=error instanceof TypeError);
}')!
	assert runtime.evaluate_host('pipeGetterRejected&&pipeGetterThrown&&pipeBrandRejected')! == 'true'
	assert runtime.evaluate_host(r'{
 const source=new ReadableStream();const invalid=[()=>source.pipeThrough(),()=>source.pipeThrough({}),()=>source.pipeThrough({readable:new ReadableStream(),writable:{}}),()=>source.pipeThrough({readable:{},writable:new WritableStream()}),()=>source.pipeThrough({readable:new ReadableStream(),writable:new WritableStream()},{signal:null}),()=>ReadableStream.prototype.pipeThrough.call({},{})];invalid.every(operation=>{try{operation();return false}catch(error){return error instanceof TypeError}})
}')! == 'true'
}
