module browserjs

import html
import dom

fn native_size_document() &dom.Document {
	url := dom.URL{value: 'https://size-order.example.test/'}
	return &dom.Document{url: url, origin_: url.origin()}
}

fn test_native_stream_size_results_require_actual_numbers_without_coercion() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	document := native_size_document()
	mut writable_host := WritableStreamHost.create(document)!
	writable_host.install(mut runtime)!
	mut readable_host := ReadableStreamHost.create(document)!
	readable_host.install(mut runtime)!
	runtime.evaluate_host(r'
 globalThis.sizeConversions=0,sizeWrites=0,sizeRangeErrors=0,sizeReadErrors=0,sizeReadClosedErrors=0;
 const invalid=[undefined,null,true,"1",1n,Symbol("size"),NaN,Infinity,-1,{valueOf(){sizeConversions++;throw "must not coerce"},[Symbol.toPrimitive](){sizeConversions++;throw "must not coerce"}}];
 for(const result of invalid){
  const writer=new WritableStream({write(){sizeWrites++}},{size(){return result}}).getWriter();writer.closed.catch(()=>{});writer.write({}).catch(error=>{if(error instanceof RangeError)sizeRangeErrors++});
  let controller;const readable=new ReadableStream({start(value){controller=value}},{size(){return result}});const reader=readable.getReader();reader.closed.catch(error=>{if(error instanceof RangeError)sizeReadClosedErrors++});
  try{controller.enqueue({})}catch(error){if(error instanceof RangeError)sizeReadErrors++}
 }
 globalThis.sizeValidWrites=0,sizeNumericFulfilled=0;for(const result of [-0,0,1.25]){const writer=new WritableStream({write(){sizeValidWrites++}},{size(){return result}}).getWriter();writer.write({}).then(()=>sizeNumericFulfilled++)}
')!
	assert runtime.evaluate_host('sizeConversions===0&&sizeWrites===0&&sizeRangeErrors===10&&sizeReadErrors===10&&sizeReadClosedErrors===10&&sizeValidWrites===3&&sizeNumericFulfilled===3')! == 'true'
}

fn test_native_writer_rechecks_lock_and_state_before_raw_size_validation() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := WritableStreamHost.create(native_size_document())!
	host.install(mut runtime)!
	runtime.evaluate_host(r'
 globalThis.sizeReleasedError=false,sizeReleasedWrites=0,sizeReleasedConversions=0;
 globalThis.sizeReleased=new WritableStream({write(){sizeReleasedWrites++}},{size(){sizeReleasedWriter.releaseLock();return {valueOf(){sizeReleasedConversions++;return 1}}}});globalThis.sizeReleasedWriter=sizeReleased.getWriter();sizeReleasedWriter.closed.catch(()=>{});sizeReleasedWriter.write({}).catch(error=>sizeReleasedError=error instanceof TypeError);
 globalThis.sizeClosingError=false,sizeClosingDone=false,sizeClosingWrites=0;
 globalThis.sizeClosing=new WritableStream({write(){sizeClosingWrites++}},{size(){sizeClosingWriter.close().then(()=>sizeClosingDone=true);return {valueOf(){sizeReleasedConversions++;return 1}}}});globalThis.sizeClosingWriter=sizeClosing.getWriter();sizeClosingWriter.write({}).catch(error=>sizeClosingError=error instanceof TypeError);
 globalThis.sizeOriginalReason=Symbol("original size throw"),sizeThrowReleased=false,sizeNewWriterError=false;
 globalThis.sizeThrowStream=new WritableStream({}, {size(){sizeThrowWriter.releaseLock();throw sizeOriginalReason}});globalThis.sizeThrowWriter=sizeThrowStream.getWriter();sizeThrowWriter.closed.catch(()=>{});sizeThrowWriter.write({}).catch(error=>sizeThrowReleased=error instanceof TypeError);sizeThrowStream.getWriter().closed.catch(reason=>sizeNewWriterError=reason===sizeOriginalReason);
')!
	assert runtime.evaluate_host('sizeReleasedError&&!sizeReleased.locked&&sizeReleasedWrites===0&&sizeReleasedConversions===0&&sizeClosingError&&sizeClosingDone&&sizeClosingWrites===0&&sizeThrowReleased&&sizeNewWriterError')! == 'true'
}

fn test_native_readable_size_callback_has_source_context_receiver_and_original_throw() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(native_size_document())!
	host.install(mut runtime)!
	settings := host.settings
	owner_handle := voidptr(runtime)
	runtime.define_value_host_function('__actualReadableSizeContext', fn [owner_handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		owner := unsafe { &Runtime(owner_handle) }
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return C.vox_jsc_JSValueMakeBoolean(owner.context, true)
	})!
	assert runtime.evaluate_host(r'
 globalThis.sizeChunk={},sizeContextCalls=0,sizeReadableController=undefined;
 globalThis.sizeContextReadable=new ReadableStream({start(controller){sizeReadableController=controller}},{highWaterMark:5,size:function(chunk){"use strict";if(this!==undefined||chunk!==sizeChunk||!__actualReadableSizeContext())throw "source callback context";sizeContextCalls++;return 1.5}});
 sizeReadableController.enqueue(sizeChunk);sizeContextCalls===1&&sizeReadableController.desiredSize===3.5
')! == 'true'
	runtime.evaluate_host(r'
 globalThis.sizeReadableReason=Symbol("actual size callback throw"),sizeOriginalCaught=false,sizeOriginalClosed=false,sizeThrowController=undefined;
 globalThis.sizeThrowReadable=new ReadableStream({start(controller){sizeThrowController=controller}},{size(){throw sizeReadableReason}});sizeThrowReadable.getReader().closed.catch(reason=>sizeOriginalClosed=reason===sizeReadableReason);try{sizeThrowController.enqueue({})}catch(reason){sizeOriginalCaught=reason===sizeReadableReason}
')!
	assert runtime.evaluate_host('sizeOriginalCaught&&sizeOriginalClosed')! == 'true'
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_transform_component_strategies_retain_actual_size_result_until_queue() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TransformStreamHost.create(native_size_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'
 globalThis.sizeTransformConversions=0,sizeTransformReadableController=undefined,sizeTransformReadableError=false;
 try{new TransformStream({start(controller){sizeTransformReadableController=controller;controller.enqueue({})}}, {}, {size(){return {valueOf(){sizeTransformConversions++;return 1}}}})}catch(error){sizeTransformReadableError=error instanceof RangeError}
 globalThis.sizeTransformCalls=0,sizeTransformWriteError=false;
 globalThis.sizeTransform=new TransformStream({transform(){sizeTransformCalls++}},{size(){return {valueOf(){sizeTransformConversions++;return 1}}}},{highWaterMark:1});const writer=sizeTransform.writable.getWriter();writer.closed.catch(()=>{});writer.write({}).catch(error=>sizeTransformWriteError=error instanceof RangeError);
 sizeTransformReadableError
')! == 'true'
	assert runtime.evaluate_host('sizeTransformWriteError&&sizeTransformCalls===0&&sizeTransformConversions===0')! == 'true'
	runtime.evaluate_host(r'
 globalThis.sizeRangeCaught=undefined,sizeRangeClosed=undefined,sizeRangeController=undefined;
 const readable=new ReadableStream({start(controller){sizeRangeController=controller}},{size(){return {}}});readable.getReader().closed.catch(reason=>sizeRangeClosed=reason);try{sizeRangeController.enqueue({})}catch(reason){sizeRangeCaught=reason}
 globalThis.sizeWriteRange=undefined,sizeWriterClosedRange=undefined;const rangeWriter=new WritableStream({},{size(){return {}}}).getWriter();rangeWriter.closed.catch(reason=>sizeWriterClosedRange=reason);rangeWriter.write({}).catch(reason=>sizeWriteRange=reason);
')!
	assert runtime.evaluate_host('sizeRangeCaught instanceof RangeError&&sizeRangeCaught===sizeRangeClosed&&sizeWriteRange instanceof RangeError&&sizeWriteRange===sizeWriterClosedRange')! == 'true'
}
