// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import math
import webgl

fn public_raster_float_source_state() []f32 {
	mut values := []f32{}
	for pname in [webgl.line_width, webgl.depth_range, webgl.polygon_offset_factor,
		webgl.polygon_offset_units, webgl.sample_coverage_value, webgl.sample_coverage_invert] {
		mut result := [f32(0), 0]!
		C.vox_gl_float_parameter(pname, &result[0])
		values << result[0]
		if pname == webgl.depth_range { values << result[1] }
	}
	return values
}

fn public_raster_float_source_reset() {
	C.vox_gl_line_width(1)
	C.vox_gl_depth_range(0, 1)
	C.vox_gl_polygon_offset(0, 0)
	C.vox_gl_sample_coverage(1, 0)
	assert C.vox_gl_get_error() == webgl.no_error
}

fn test_public_float_raster_setters_use_source_unrestricted_float_and_driver_errors() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_raster_float",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_raster_float_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut context := host.contexts['__created_raster_float'] or { panic('float raster owner') }
		mut other := host.contexts['__created_raster_float_other'] or { panic('other owner') }
		for expression in ['lineWidth(0)', 'lineWidth(NaN)', 'depthRange(-Infinity,Infinity)',
			'polygonOffset(NaN,Infinity)', 'sampleCoverage(NaN,true)'] {
			context.native.make_current()
			public_raster_float_source_reset()
			match expression {
				'lineWidth(0)' { C.vox_gl_line_width(0) }
				'lineWidth(NaN)' { C.vox_gl_line_width(f32(math.nan())) }
				'depthRange(-Infinity,Infinity)' {
					C.vox_gl_depth_range(f32(math.inf(-1)), f32(math.inf(1)))
				}
				'polygonOffset(NaN,Infinity)' {
					C.vox_gl_polygon_offset(f32(math.nan()), f32(math.inf(1)))
				}
				else { C.vox_gl_sample_coverage(f32(math.nan()), 1) }
			}
			expected_error := C.vox_gl_get_error()
			expected := public_raster_float_source_state()
			public_raster_float_source_reset()
			context.set_error(webgl.invalid_operation)
			other.native.make_current()
			runtime.evaluate_host('gl.${expression};')!
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			actual := public_raster_float_source_state()
			for index, value in expected {
				assert actual[index] == value || (math.is_nan(actual[index]) && math.is_nan(value))
			}
			if expected_error != webgl.no_error {
				assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
			}
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION&&gl.getError()===gl.NO_ERROR')! == 'true'
		}
		for expression in ['lineWidth({valueOf(){throw marker}})',
			'depthRange(0,{valueOf(){throw marker}})', 'polygonOffset(0,{valueOf(){throw marker}})',
			'sampleCoverage({valueOf(){throw marker}},true)'] {
			other.native.make_current()
			assert runtime.evaluate_host('(function(){const marker={};try{gl.${expression};return false}catch(error){return error===marker}})()')! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
		assert runtime.evaluate_host('(function(){let touched=0;gl.lineWidth(1.5);gl.depthRange(0.25,0.75);gl.polygonOffset(0.125,-2.75);gl.sampleCoverage(0.625,{valueOf(){touched++;throw 1}});return touched===0&&gl.getParameter(gl.LINE_WIDTH)===1.5&&Array.from(gl.getParameter(gl.DEPTH_RANGE)).join(",")==="0.25,0.75"&&gl.getParameter(gl.POLYGON_OFFSET_FACTOR)===0.125&&gl.getParameter(gl.POLYGON_OFFSET_UNITS)===-2.75&&gl.getParameter(gl.SAMPLE_COVERAGE_VALUE)===0.625&&gl.getParameter(gl.SAMPLE_COVERAGE_INVERT)===true&&gl.getError()===gl.NO_ERROR})()')! == 'true'
		assert other.get_error() == webgl.no_error
	}
}
