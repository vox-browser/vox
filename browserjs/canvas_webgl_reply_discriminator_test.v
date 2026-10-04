// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import math
import webgl

fn test_public_driver_reply_discriminators_ignore_inherited_author_getters() {
	$if !darwin {
		return
	}
	for kind in ['webgl', 'webgl2'] {
		mut document := html.parse_document('<canvas></canvas>')
		mut host := CanvasWebGLHost.create(document)
		mut runtime := Runtime.create()
		defer { runtime.close() }
		host.install(mut runtime)!
		runtime.evaluate_host('const __canvases=Object.create(null);function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {state:s};}')!
		runtime.evaluate_host(webgl_bootstrap())!
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_reply_discriminator",width:1,height:1},"${kind}",null);const NativeFloat=Float32Array;')!
		mut context := host.contexts['__created_reply_discriminator'] or { panic('reply discriminator owner') }
		context.native.make_current()
		mut values := [f32(math.nan()), f32(math.inf(1)), f32(math.inf(-1)), f32(math.copysign(0, -1))]!
		C.vox_gl_vertex_attrib_floats(2, &values[0])
		C.vox_gl_polygon_offset(1, f32(math.inf(1)))
		mut actual := [f32(0), 0, 0, 0]!
		C.vox_gl_vertex_attrib_float_parameter(2, &actual[0])
		assert math.is_nan(actual[0]) && actual[1] == f32(math.inf(1)) && actual[2] == f32(math.inf(-1))
		assert actual[3] == 0 && math.signbit(f64(actual[3]))
		assert C.vox_gl_get_error() == webgl.no_error
		if kind == 'webgl2' {
			runtime.evaluate_host('globalThis.foreignProgram=__webglContext({bridgeKey:"__created_reply_discriminator_foreign",width:1,height:1},"webgl2",null).createProgram();')!
		}
		for prototype in ['Object.prototype', 'Number.prototype'] {
			assert runtime.evaluate_host('(function(){const prototype=${prototype},keys=["error","webglUndefined","webglNumber","handle"];let touched=0;for(const key of keys)Object.defineProperty(prototype,key,{get(){touched++;throw key},configurable:true});try{const a=gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB),b=gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB),buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);const retained=gl.getParameter(gl.ARRAY_BUFFER_BINDING);const sourceUndefined=typeof foreignProgram==="undefined"||(gl.getActiveUniforms(foreignProgram,[0],gl.UNIFORM_TYPE)===undefined&&gl.getError()===gl.INVALID_OPERATION);return sourceUndefined&&a instanceof NativeFloat&&a!==b&&a.buffer!==b.buffer&&Number.isNaN(a[0])&&a[1]===Infinity&&a[2]===-Infinity&&Object.is(a[3],-0)&&gl.getParameter(gl.POLYGON_OFFSET_FACTOR)===1&&gl.getParameter(gl.POLYGON_OFFSET_UNITS)===Infinity&&buffer!==null&&retained===buffer&&gl.getError()===gl.NO_ERROR&&touched===0}finally{for(const key of keys)delete prototype[key]}})()')! == 'true'
		}
		// The discriminator check itself uses the native intrinsics captured
		// before the author replaces their global/prototype properties.
		assert runtime.evaluate_host('(function(){const own=Object.prototype.hasOwnProperty,apply=Reflect.apply;let touched=0;Object.prototype.hasOwnProperty=function(){touched++;throw "author own"};Reflect.apply=function(){touched++;throw "author apply"};try{const a=gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB);return Number.isNaN(a[0])&&Object.is(a[3],-0)&&gl.getParameter(gl.POLYGON_OFFSET_UNITS)===Infinity&&gl.getParameter(gl.POLYGON_OFFSET_FACTOR)===1&&touched===0}finally{Object.prototype.hasOwnProperty=own;Reflect.apply=apply}})()')! == 'true'
	}
}
