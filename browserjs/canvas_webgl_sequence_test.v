// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn webgl_sequence_fixture() &Runtime {
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	host.install(mut runtime) or { panic(err) }
	key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
	runtime.evaluate_host('const __canvases=Object.create(null),state={bridgeKey:"${key}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}') or { panic(err) }
	runtime.evaluate_host(webgl_bootstrap()) or { panic(err) }
	runtime.evaluate_host('const gl=__webglContext(state,"webgl2",{preserveDrawingBuffer:true});') or { panic(err) }
	return runtime
}

fn test_public_webgl_sequences_cache_iterator_method_and_next_in_source_order() {
	$if !darwin {
		return
	}
	mut runtime := webgl_sequence_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(function(){
 const order=[];let index=0;const framebuffer=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,framebuffer);
 const iterator={get next(){order.push("next getter");return function(){
  order.push("next");const finished=index++!==0;
  return {get done(){order.push("done");return finished},get value(){
   if(finished)throw "finished value";order.push("value");
   return {valueOf(){order.push("number");return gl.COLOR_ATTACHMENT0}};
  }};
 }}};
 const list={get [Symbol.iterator](){order.push("iterator");return function(){order.push("call");return iterator}}};
 gl.drawBuffers(list);
 gl.bindFramebuffer(gl.FRAMEBUFFER,null);
 return order.join(",")==="iterator,call,next getter,next,done,value,number,next,done"&&gl.getError()===gl.NO_ERROR;
})()')! == 'true'
	// The generic sequence snapshot precedes the later srcOffset conversion,
	// while an exact typed-list member follows the operation-body copy boundary.
	assert runtime.evaluate_host(r'(function(){const order=[],values=[1,0,0,1],list={get [Symbol.iterator](){order.push("iterator");return function(){let index=0;return {next(){return index<4?{value:{valueOf(){order.push("value");return values[index++]}},done:false}:{done:true}}}}}};gl.clearBufferfv(gl.COLOR,0,list,{valueOf(){order.push("offset");values[0]=0;values[1]=1;return 0}});const pixels=new Uint8Array(4);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);return order.join(",")==="iterator,value,value,value,value,offset"&&pixels.join(",")==="255,0,0,255"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
}

fn test_public_webgl_sequence_item_errors_do_not_close_iterator_or_convert_later_arguments() {
	$if !darwin {
		return
	}
	mut runtime := webgl_sequence_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(function(){const marker={},order=[],list={[Symbol.iterator](){return {next(){return {done:false,value:{valueOf(){order.push("item");throw marker}}}},get return(){order.push("return getter");throw "closed"}}}};try{gl.uniform4fv(null,list,{valueOf(){order.push("later");return 0}});return false}catch(error){return error===marker&&order.join(",")==="item"&&gl.getError()===gl.NO_ERROR}})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){let closed=0;const list={[Symbol.iterator](){return {next(){return {done:false,value:Symbol("item")}},return(){closed++;return {done:true}}}}};try{gl.drawBuffers(list);return false}catch(error){return error instanceof TypeError&&closed===0&&gl.getError()===gl.NO_ERROR}})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){const marker={},list={get [Symbol.iterator](){throw marker}};try{gl.drawBuffers(list);return false}catch(error){return error===marker}})()')! == 'true'
}

fn test_public_webgl_direct_sequences_and_list_unions_preserve_source_failure_selection() {
	$if !darwin {
		return
	}
	mut runtime := webgl_sequence_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(function(){function rejects(call,message){try{call();return false}catch(error){return error instanceof TypeError&&error.message===message}}return rejects(()=>gl.drawBuffers("x"),"x is not an object")&&rejects(()=>gl.drawBuffers({}),"[object Object] is not iterable")&&rejects(()=>gl.uniform1fv(null,"x"),"No union types matched")&&rejects(()=>gl.uniform1fv(null,{}),"No union types matched")&&rejects(()=>gl.uniform1fv(null,{[Symbol.iterator]:0}),"0 is not a function")&&rejects(()=>gl.drawBuffers({[Symbol.iterator](){return 1}}),"[object Object] is not iterable")&&rejects(()=>gl.drawBuffers({[Symbol.iterator](){return {next(){return 1}}}}),"1 is not an object")&&gl.getError()===gl.NO_ERROR})()')! == 'true'
}
