// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import math
import webgl

fn test_public_clear_setters_preserve_float_abi_and_idl_before_real_driver_commands() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_clear_setters",width:1,height:1},"${kind}",{stencil:true});globalThis.other=__webglContext({bridgeKey:"__created_clear_other",width:1,height:1},"${kind}",null);other.viewport(9,10,11,12);')!
		mut context := host.contexts['__created_clear_setters'] or { panic('clear owner') }
		mut other := host.contexts['__created_clear_other'] or { panic('other owner') }
		context.native.make_current()
		C.vox_gl_clear_color(f32(math.inf(-1)), f32(math.inf(1)), f32(math.nan()), -0.0)
		C.vox_gl_clear_depth(f32(math.nan()))
		expected_error := C.vox_gl_get_error()
		mut expected_color := [f32(0), 0, 0, 0]!
		mut expected_depth := f32(0)
		C.vox_gl_float_parameter(webgl.color_clear_value, &expected_color[0])
		C.vox_gl_float_parameter(webgl.depth_clear_value, &expected_depth)
		other.native.make_current()
		runtime.evaluate_host('gl.clearColor(-Infinity,Infinity,NaN,-0);gl.clearDepth(NaN);')!
		mut actual_color := [f32(0), 0, 0, 0]!
		mut actual_depth := f32(0)
		C.vox_gl_float_parameter(webgl.color_clear_value, &actual_color[0])
		C.vox_gl_float_parameter(webgl.depth_clear_value, &actual_depth)
		for index, value in expected_color {
			assert actual_color[index] == value || (math.is_nan(actual_color[index]) && math.is_nan(value))
		}
		assert actual_depth == expected_depth || (math.is_nan(actual_depth) && math.is_nan(expected_depth))
		assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
		for expression in ['clearColor(0,0,{valueOf(){throw marker}},1)',
			'clearDepth({valueOf(){throw marker}})', 'clearStencil({valueOf(){throw marker}})'] {
			other.native.make_current()
			assert runtime.evaluate_host('(function(){const marker={};try{gl.${expression};return false}catch(error){return error===marker}})()')! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
		assert runtime.evaluate_host('(function(){const v=gl.createShader(gl.VERTEX_SHADER),f=gl.createShader(gl.FRAGMENT_SHADER),p=gl.createProgram();gl.shaderSource(v,"void main(){gl_Position=vec4(0,0,0,1);gl_PointSize=1.0;}");gl.shaderSource(f,"precision mediump float;void main(){gl_FragColor=vec4(1,0,0,1);}");gl.compileShader(v);gl.compileShader(f);gl.attachShader(p,v);gl.attachShader(p,f);gl.linkProgram(p);if(!gl.getProgramParameter(p,gl.LINK_STATUS))return false;gl.useProgram(p);gl.clearColor(0,0,1,1);gl.clearDepth(0.25);gl.clearStencil(0x1ab);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT);gl.depthMask(false);gl.clearDepth(1);gl.stencilMask(0);gl.clearStencil(0);gl.clear(gl.DEPTH_BUFFER_BIT|gl.STENCIL_BUFFER_BIT);gl.enable(gl.DEPTH_TEST);gl.depthFunc(gl.GREATER);gl.enable(gl.STENCIL_TEST);gl.stencilFunc(gl.EQUAL,0xab,0xff);let touched=0;const truth={valueOf(){touched++;throw 1}};gl.colorMask(truth,truth,false,truth);gl.drawArrays(gl.POINTS,0,1);const pixel=new Uint8Array(4);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixel);return touched===0&&Array.from(pixel).join(",")==="255,0,255,255"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
		assert other.get_error() == webgl.no_error
	}
}
