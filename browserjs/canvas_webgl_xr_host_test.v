// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn xr_host_fixture() (&Runtime, &CanvasWebGLHost, &html.EventLoop) {
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	host.install(mut runtime) or { panic(err) }
	runtime.evaluate_host('const __canvases=Object.create(null);function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return s.element||(s.element={state:s});}') or { panic(err) }
	runtime.evaluate_host(webgl_bootstrap()) or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	return runtime, host, settings.responsible_event_loop()
}

fn xr_host_task(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	task := queue.dequeue() or { panic('missing WebGL XR task') }
	assert task.source() == .unspecified
	task.execute()
}

fn xr_host_jobs(owner &html.EventLoop) {
	mut loop := unsafe { &html.EventLoop(owner) }
	for _ in 0 .. 100 {
		job := loop.dequeue_microtask() or { return }
		job.execute()
	}
	panic('WebGL XR jobs did not drain')
}

fn test_actual_webgl_xr_promise_owns_source_work_settlement_and_reactions() {
	$if !darwin {
		return
	}
	mut runtime, host, mut owner := xr_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	initial := runtime.evaluate_host(r'
 const xrState={bridgeKey:"__created_xr",width:2,height:2},xr=__webglContext(xrState,"webgl2",null);
 globalThis.xrOrder=[];globalThis.xrResult="pending";
 const xrMethod=xr.makeXRCompatible,descriptor=Object.getOwnPropertyDescriptor(WebGL2RenderingContext.prototype,"makeXRCompatible");
 globalThis.xrPromise=xrMethod.call(xr,{get ignored(){throw "extra argument"}});xrPromise.then(value=>{xrResult=value;xrOrder.push("reaction")});xrOrder.push("return");
 xrPromise instanceof Promise&&xrMethod.name==="makeXRCompatible"&&xrMethod.length===0&&!Object.prototype.hasOwnProperty.call(xrMethod,"prototype")&&descriptor.enumerable&&descriptor.configurable&&descriptor.writable&&xrResult==="pending"&&xrOrder.join(",")==="return";
 ')!
	assert initial == 'true'
	context := host.contexts['__created_xr'] or { panic('native XR context') }
	assert !context.xr_compatible()
	xr_host_task(owner)
	assert !context.xr_compatible()
	assert owner.microtask_queue_empty()
	xr_host_task(owner)
	assert context.xr_compatible()
	assert !owner.microtask_queue_empty()
	before_jobs := runtime.evaluate_host('xrResult==="pending"&&xrOrder.join(",")==="return"')!
	assert before_jobs == 'true'
	xr_host_jobs(owner)
	settled := runtime.evaluate_host('xrResult===undefined&&xrOrder.join(",")==="return,reaction"')!
	assert settled == 'true'
	// The source's already-compatible branch also returns a new capability.
	fresh := runtime.evaluate_host(r'globalThis.xrSecondResult="pending";globalThis.__ladybirdWebGLMakeXRCompatible=function(){throw "author replacement"};globalThis.xrSecond=xr.makeXRCompatible();xrSecond.then(value=>xrSecondResult=value);xrSecond instanceof Promise&&xrSecond!==xrPromise&&xrSecondResult==="pending"')!
	assert fresh == 'true'
	xr_host_task(owner)
	xr_host_task(owner)
	xr_host_jobs(owner)
	second := runtime.evaluate_host('xrSecondResult===undefined')!
	assert second == 'true'
}

fn test_actual_webgl_xr_loss_rejects_with_dom_exception_after_source_settlement() {
	$if !darwin {
		return
	}
	mut runtime, host, mut owner := xr_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'const lostState={bridgeKey:"__created_xr_lost",width:2,height:2},lost=__webglContext(lostState,"webgl",null);globalThis.xrLostReason=null;globalThis.xrLost=lost.makeXRCompatible();xrLost.catch(reason=>xrLostReason=reason);')!
	mut context := host.contexts['__created_xr_lost'] or { panic('native lost XR context') }
	context.set_xr_compatible(true)
	context.lose_context('before source deferred invocation')
	xr_host_task(owner)
	assert context.xr_compatible()
	xr_host_task(owner)
	assert !context.xr_compatible()
	before_jobs := runtime.evaluate_host('xrLost instanceof Promise&&xrLostReason===null')!
	assert before_jobs == 'true'
	xr_host_jobs(owner)
	rejected := runtime.evaluate_host(r'xrLostReason instanceof DOMException&&xrLostReason.name==="InvalidStateError"&&xrLostReason.code===11&&xrLostReason.message==="The WebGL context has been lost."')!
	assert rejected == 'true'
}

fn test_actual_webgl_xr_receiver_failures_are_rejected_promises_with_original_values() {
	$if !darwin {
		return
	}
	mut runtime, _, mut owner := xr_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	initial := runtime.evaluate_host(r'
 const xrOne=__webglContext({bridgeKey:"__created_xr_one",width:2,height:2},"webgl",null);
 globalThis.xrReceiverReasons=[];globalThis.xrOriginal={marker:true};globalThis.xrOriginalReason=null;
 const calls=[()=>WebGL2RenderingContext.prototype.makeXRCompatible.call({}),()=>WebGL2RenderingContext.prototype.makeXRCompatible.call(xrOne),()=>WebGLRenderingContext.prototype.makeXRCompatible.call(Object.create(WebGLRenderingContext.prototype))];
 const rejected=calls.every(call=>{try{const promise=call();promise.catch(reason=>xrReceiverReasons.push(reason));return promise instanceof Promise}catch(error){return false}});
 const original=__ladybirdWebGLMakeXRCompatible(undefined,xrOriginal);original.catch(reason=>xrOriginalReason=reason);
 rejected&&original instanceof Promise&&xrReceiverReasons.length===0&&xrOriginalReason===null;
 ')!
	assert initial == 'true'
	assert owner.task_queue().is_empty()
	xr_host_jobs(owner)
	values := runtime.evaluate_host(r'xrReceiverReasons.length===3&&xrReceiverReasons.every(reason=>reason instanceof TypeError)&&xrReceiverReasons[0].message==="Not an object of type WebGL2RenderingContext"&&xrReceiverReasons[1].message==="Not an object of type WebGL2RenderingContext"&&xrReceiverReasons[2].message==="Not an object of type WebGLRenderingContext"&&xrOriginalReason===xrOriginal')!
	assert values == 'true'
}

fn test_closed_actual_webgl_xr_owner_does_not_touch_released_engine_on_settlement() {
	$if !darwin {
		return
	}
	mut runtime, host, mut owner := xr_host_fixture()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'const xrClosing=__webglContext({bridgeKey:"__created_xr_closed",width:2,height:2},"webgl2",null);globalThis.xrClosingPromise=xrClosing.makeXRCompatible();')!
	runtime.close()
	xr_host_task(owner)
	xr_host_task(owner)
	xr_host_jobs(owner)
	context := host.contexts['__created_xr_closed'] or { panic('closed owner native context') }
	assert context.xr_compatible()
}
