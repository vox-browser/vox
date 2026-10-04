// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import math
import webgl
import webidl

fn public_gl_number_expression(value f32) string {
	if value == 0 && math.signbit(f64(value)) { return '-0' }
	return webidl.to_string(webidl.number_value(f64(value))) or { panic(err) }
}

fn test_public_driver_numbers_preserve_nonfinite_values_and_signed_zero() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_number_transport",width:1,height:1},"${kind}",null);')!
		mut context := host.contexts['__created_number_transport'] or { panic('number transport owner') }
		context.native.make_current()
		mut input := [f32(math.nan()), f32(math.inf(1)), f32(math.inf(-1)), f32(math.copysign(0, -1))]!
		C.vox_gl_vertex_attrib_floats(2, &input[0])
		mut expected := [f32(0), 0, 0, 0]!
		C.vox_gl_vertex_attrib_float_parameter(2, &expected[0])
		assert math.is_nan(expected[0])
		assert expected[1] == f32(math.inf(1)) && expected[2] == f32(math.inf(-1))
		assert expected[3] == 0 && math.signbit(f64(expected[3]))
		assert C.vox_gl_get_error() == webgl.no_error
		// The source copies real driver floats into a fresh native Float32Array.
		// Author replacement of globals must not intercept primitive conversion
		// or the captured constructor used by the compatibility adapter.
		runtime.evaluate_host('const NativeFloat=Float32Array;let intercepted=0;Number.isFinite=function(){intercepted++;throw "author finite"};globalThis.String=function(){intercepted++;throw "author string"};globalThis.Float32Array=function(){intercepted++;throw "author array"};')!
		assert runtime.evaluate_host('(function(){const a=gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB),b=gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB);return a instanceof NativeFloat&&Object.getPrototypeOf(a)===NativeFloat.prototype&&a!==b&&a.buffer!==b.buffer&&a.length===4&&Number.isNaN(a[0])&&a[1]===Infinity&&a[2]===-Infinity&&Object.is(a[3],-0)&&intercepted===0})()')! == 'true'
		mut baseline := [f32(1), 2, 3, 4]!
		for invocation in ['gl.vertexAttrib4f(2,NaN,Infinity,-Infinity,-0);',
			'gl.vertexAttrib4fv(2,[NaN,Infinity,-Infinity,-0]);',
			'gl.vertexAttrib4fv(2,new NativeFloat([NaN,Infinity,-Infinity,-0]));'] {
			C.vox_gl_vertex_attrib_floats(2, &baseline[0])
			runtime.evaluate_host(invocation)!
			mut actual := [f32(0), 0, 0, 0]!
			C.vox_gl_vertex_attrib_float_parameter(2, &actual[0])
			for index, value in expected {
				assert actual[index] == value || (math.is_nan(actual[index]) && math.is_nan(value))
				if value == 0 {
					assert math.signbit(f64(actual[index])) == math.signbit(f64(value))
				}
			}
			assert runtime.evaluate_host('(function(){const a=gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB);return Number.isNaN(a[0])&&a[1]===Infinity&&a[2]===-Infinity&&Object.is(a[3],-0)&&intercepted===0&&gl.getError()===gl.NO_ERROR})()')! == 'true'
		}
		// The driver's scalar result, including its own NaN normalization, is
		// authoritative. This does not invent getter clamping or NaN behavior.
		assert runtime.evaluate_host('(function(){Object.defineProperty(Object.prototype,"webglNumber",{get(){intercepted++;throw "author number tag"},configurable:true});try{const a=gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB),b=gl.createBuffer();return b!==null&&a instanceof NativeFloat&&Number.isNaN(a[0])&&Object.is(a[3],-0)&&intercepted===0}finally{delete Object.prototype.webglNumber}})()')! == 'true'
		for value in input {
			C.vox_gl_polygon_offset(value, value)
			mut factor := f32(0)
			mut units := f32(0)
			C.vox_gl_float_parameter(webgl.polygon_offset_factor, &factor)
			C.vox_gl_float_parameter(webgl.polygon_offset_units, &units)
			assert C.vox_gl_get_error() == webgl.no_error
			expected_factor := public_gl_number_expression(factor)
			expected_units := public_gl_number_expression(units)
			assert runtime.evaluate_host('Object.is(gl.getParameter(gl.POLYGON_OFFSET_FACTOR),${expected_factor})&&Object.is(gl.getParameter(gl.POLYGON_OFFSET_UNITS),${expected_units})&&intercepted===0')! == 'true'
		}
	}
}
