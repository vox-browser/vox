// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_webgl_native_reflection_returns_source_branded_readonly_records() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
	runtime.evaluate_host('const __canvases=Object.create(null),state={bridgeKey:"${key}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	runtime.evaluate_host(r'const gl=__webglContext(state,"webgl2",{preserveDrawingBuffer:true}),vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER),program=gl.createProgram();gl.shaderSource(vertex,"#version 300 es\nin vec2 position;void main(){gl_Position=vec4(position,0,1);}");gl.shaderSource(fragment,"#version 300 es\nprecision mediump float;uniform vec4 tint;out vec4 color;void main(){color=tint;}");gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);')!
	assert runtime.evaluate_host(r'(function(){const info=gl.getActiveAttrib(program,0),uniform=gl.getActiveUniform(program,0),copy=gl.getActiveUniform(program,0);return gl.getProgramParameter(program,gl.LINK_STATUS)&&info instanceof WebGLActiveInfo&&uniform instanceof WebGLActiveInfo&&info.name==="position"&&info.type===gl.FLOAT_VEC2&&info.size===1&&uniform.name==="tint"&&uniform.type===gl.FLOAT_VEC4&&uniform.size===1&&copy!==uniform&&Object.keys(info).length===0&&Object.getOwnPropertyNames(uniform).length===0&&Object.prototype.toString.call(info)==="[object WebGLActiveInfo]"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){const info=gl.getActiveUniform(program,0),properties=["size","type","name"];for(const name of properties){const descriptor=Object.getOwnPropertyDescriptor(WebGLActiveInfo.prototype,name);if(!descriptor.enumerable||!descriptor.configurable||descriptor.set!==undefined||descriptor.get.name!=="get "+name||descriptor.get.length!==0||descriptor.get.call(info)!==info[name])return false;try{(function(){"use strict";info[name]="changed"})();return false}catch(error){if(!(error instanceof TypeError))return false}}const getter=Object.getOwnPropertyDescriptor(WebGLActiveInfo.prototype,"name").get;for(const receiver of [{},null,Object.create(WebGLActiveInfo.prototype),gl.getShaderPrecisionFormat(gl.VERTEX_SHADER,gl.HIGH_FLOAT)]){try{getter.call(receiver);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type WebGLActiveInfo")return false}}Object.defineProperty(info,"name",{value:"shadow"});return info.name==="shadow"&&gl.getActiveUniform(program,0).name==="tint"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){const precision=gl.getShaderPrecisionFormat(gl.FRAGMENT_SHADER,gl.HIGH_FLOAT);if(!(precision instanceof WebGLShaderPrecisionFormat)||precision.rangeMin<1||precision.rangeMax<1||precision.precision<8||Object.getOwnPropertyNames(precision).length!==0||Object.prototype.toString.call(precision)!=="[object WebGLShaderPrecisionFormat]")return false;for(const name of ["rangeMin","rangeMax","precision"]){const descriptor=Object.getOwnPropertyDescriptor(WebGLShaderPrecisionFormat.prototype,name);if(!descriptor.enumerable||!descriptor.configurable||descriptor.set!==undefined)return false;try{descriptor.get.call({});return false}catch(error){if(error.message!=="Not an object of type WebGLShaderPrecisionFormat")return false}}return gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){for(const Constructor of [WebGLActiveInfo,WebGLShaderPrecisionFormat]){if(Constructor.length!==0||Object.getOwnPropertyDescriptor(Constructor,"prototype").writable)return false;try{new Constructor();return false}catch(error){if(!(error instanceof TypeError)||error.message!==Constructor.name+" is not a constructor")return false}try{Constructor();return false}catch(error){if(!(error instanceof TypeError)||error.message!==Constructor.name+" constructor must be called with \u0027new\u0027")return false}}return true})()')! == 'true'
}
