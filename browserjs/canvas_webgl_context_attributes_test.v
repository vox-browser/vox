// Copyright (c) 2022, Luke Wilde <lukew@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_webgl_context_creation_preserves_source_attribute_getter_order_and_single_reads() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	runtime.evaluate_host('const __canvases=Object.create(null);function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	assert runtime.evaluate_host(r'(function(){
 const order=[],options={},values={alpha:{valueOf(){throw "boolean conversion"}},antialias:false,depth:true,desynchronized:true,failIfMajorPerformanceCaveat:false,powerPreference:{[Symbol.toPrimitive](hint){order.push(hint);return "low-power"}},premultipliedAlpha:false,preserveDrawingBuffer:true,stencil:true};
 for(const name of Object.keys(values))Object.defineProperty(options,name,{get(){order.push(name);return values[name]}});
 Object.defineProperty(options,"xrCompatible",{get(){throw "source omitted"}});
 const state={bridgeKey:"__created_attribute_order",width:2,height:2},gl=__webglContext(state,"webgl2",options),attributes=gl.getContextAttributes();
 const reused=__webglContext(state,"experimental-webgl",{get alpha(){throw "existing mismatched kind"}});
 const same=__webglContext(state,"webgl2",{get alpha(){throw "existing context"}});
 if(Object.getPrototypeOf(attributes)!==Object.prototype||Object.keys(attributes).join(",")!=="alpha,antialias,depth,desynchronized,failIfMajorPerformanceCaveat,powerPreference,premultipliedAlpha,preserveDrawingBuffer,stencil,xrCompatible")return false;
 const copy=gl.getContextAttributes();copy.alpha=false;if(gl.getContextAttributes().alpha!==true)return false;
 return order.join(",")==="alpha,antialias,depth,desynchronized,failIfMajorPerformanceCaveat,powerPreference,string,premultipliedAlpha,preserveDrawingBuffer,stencil"&&attributes.alpha&&!attributes.antialias&&attributes.depth&&attributes.desynchronized&&attributes.powerPreference==="low-power"&&!attributes.premultipliedAlpha&&attributes.preserveDrawingBuffer&&attributes.stencil&&!attributes.xrCompatible&&reused===null&&same===gl&&gl.getError()===gl.NO_ERROR;
})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){let later=0;const state={bridgeKey:"__created_invalid_power",width:2,height:2},options={powerPreference:"fastest",get premultipliedAlpha(){later++;throw "later"}};try{__webglContext(state,"webgl",options);return false}catch(error){const gl=__webglContext(state,"webgl",null);return error instanceof TypeError&&error.message==="Invalid value \u0027fastest\u0027 for enumeration type \u0027WebGLPowerPreference\u0027"&&later===0&&gl!==null&&gl.getContextAttributes().powerPreference==="default"}})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){const values=[undefined,null,true,1,"options",Symbol("options"),1n];return values.every((value,index)=>{const gl=__webglContext({bridgeKey:"__created_primitive_options"+index,width:2,height:2},"webgl",value),attributes=gl.getContextAttributes();return attributes.alpha&&attributes.depth&&attributes.antialias&&!attributes.stencil&&attributes.premultipliedAlpha&&!attributes.preserveDrawingBuffer&&attributes.powerPreference==="default"&&!attributes.xrCompatible&&gl.getError()===gl.NO_ERROR})})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){const marker={},options={get depth(){throw marker},get powerPreference(){throw "later"}};try{__webglContext({bridgeKey:"__created_throwing_options",width:2,height:2},"webgl",options);return false}catch(error){return error===marker}})()')! == 'true'
}
