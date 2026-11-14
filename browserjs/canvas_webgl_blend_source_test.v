// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import math
import webgl

fn public_blend_source_state() []int {
	mut result := []int{}
	for pname in [webgl.blend_equation_rgb, webgl.blend_equation_alpha, webgl.blend_src_rgb,
		webgl.blend_dst_rgb, webgl.blend_src_alpha, webgl.blend_dst_alpha] {
		mut value := i32(0)
		C.vox_gl_int_parameter(pname, &value)
		result << value
	}
	return result
}

fn test_public_blend_preserves_source_driver_validation_unrestricted_floats_and_idl_order() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_blend_source",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_blend_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut context := host.contexts['__created_blend_source'] or { panic('blend owner') }
		mut other := host.contexts['__created_blend_other'] or { panic('other owner') }
		for operation in 0 .. 4 {
			context.native.make_current()
			C.vox_gl_blend_equation(webgl.func_add)
			C.vox_gl_blend_func(webgl.gl_one, webgl.gl_zero)
			match operation {
				0 { C.vox_gl_blend_equation(0xbad) }
				1 { C.vox_gl_blend_equation_separate(webgl.func_add, 0xbad) }
				2 { C.vox_gl_blend_func(webgl.constant_color, webgl.constant_alpha) }
				else {
					C.vox_gl_blend_func_separate(webgl.gl_one, webgl.gl_zero, webgl.constant_color, webgl.constant_alpha)
				}
			}
			expected_error := C.vox_gl_get_error()
			expected_state := public_blend_source_state()
			C.vox_gl_blend_equation(webgl.func_add)
			C.vox_gl_blend_func(webgl.gl_one, webgl.gl_zero)
			context.set_error(webgl.invalid_value)
			other.native.make_current()
			expression := match operation {
				0 { 'blendEquation(0xbad)' }
				1 { 'blendEquationSeparate(gl.FUNC_ADD,0xbad)' }
				2 { 'blendFunc(gl.CONSTANT_COLOR,gl.CONSTANT_ALPHA)' }
				else { 'blendFuncSeparate(gl.ONE,gl.ZERO,gl.CONSTANT_COLOR,gl.CONSTANT_ALPHA)' }
			}
			runtime.evaluate_host('gl.${expression}')!
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert public_blend_source_state() == expected_state
			if expected_error != webgl.no_error {
				assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
			}
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_VALUE&&gl.getError()===gl.NO_ERROR')! == 'true'
		}
		context.native.make_current()
		C.vox_gl_blend_color(f32(math.nan()), f32(math.inf(1)), f32(math.inf(-1)), -0.0)
		expected_color_error := C.vox_gl_get_error()
		mut expected_color := [f32(0), 0, 0, 0]!
		C.vox_gl_float_parameter(webgl.blend_color, &expected_color[0])
		other.native.make_current()
		runtime.evaluate_host('gl.blendColor(NaN,Infinity,-Infinity,-0);')!
		mut actual_color := [f32(0), 0, 0, 0]!
		C.vox_gl_float_parameter(webgl.blend_color, &actual_color[0])
		for index, value in expected_color {
			assert actual_color[index] == value || (math.is_nan(actual_color[index]) && math.is_nan(value))
		}
		assert runtime.evaluate_host('gl.getError()')! == expected_color_error.str()
		for expression in ['blendColor(0,0,{valueOf(){throw marker}},1)',
			'blendEquation({valueOf(){throw marker}})',
			'blendEquationSeparate(gl.FUNC_ADD,{valueOf(){throw marker}})',
			'blendFunc(gl.ONE,{valueOf(){throw marker}})',
			'blendFuncSeparate(gl.ONE,gl.ZERO,gl.ONE,{valueOf(){throw marker}})'] {
			other.native.make_current()
			assert runtime.evaluate_host('(function(){const marker={};try{gl.${expression};return false}catch(error){return error===marker}})()')! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
		assert runtime.evaluate_host('(function(){gl.viewport(0,0,1,1);const v=gl.createShader(gl.VERTEX_SHADER),f=gl.createShader(gl.FRAGMENT_SHADER),p=gl.createProgram();gl.shaderSource(v,"void main(){gl_Position=vec4(0,0,0,1);gl_PointSize=1.0;}");gl.shaderSource(f,"precision mediump float;void main(){gl_FragColor=vec4(0.25,0,0,1);}");gl.compileShader(v);gl.compileShader(f);gl.attachShader(p,v);gl.attachShader(p,f);gl.linkProgram(p);if(!gl.getProgramParameter(p,gl.LINK_STATUS))return false;gl.useProgram(p);gl.clearColor(0,0,0.25,1);gl.clear(gl.COLOR_BUFFER_BIT);gl.enable(gl.BLEND);gl.blendColor(0.5,0.5,0.5,1);gl.blendEquation(gl.FUNC_SUBTRACT);gl.blendEquationSeparate(gl.FUNC_ADD,gl.FUNC_ADD);gl.blendFunc(gl.ZERO,gl.ZERO);gl.blendFuncSeparate(gl.ONE,gl.ONE,gl.ONE,gl.ONE);gl.drawArrays(gl.POINTS,0,1);const pixel=new Uint8Array(4);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixel);return Array.from(pixel).join(",")==="64,0,64,255"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
		assert other.get_error() == webgl.no_error
	}
}
