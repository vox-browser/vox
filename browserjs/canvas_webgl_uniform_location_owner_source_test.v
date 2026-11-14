// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn public_uniform_location_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == expected
}

fn test_public_uniform_location_source_handle_order_real_values_and_fresh_wrapper_parent_records() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_uniform_location_owner",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_uniform_location_owner_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.program=gl.createProgram();globalThis.foreign=other.createProgram();globalThis.deleted=gl.createProgram();gl.deleteProgram(deleted);globalThis.vertex=gl.createShader(gl.VERTEX_SHADER);globalThis.fragment=gl.createShader(gl.FRAGMENT_SHADER);')!
		mut owner := host.contexts['__created_uniform_location_owner'] or { panic('location owner') }
		mut other := host.contexts['__created_uniform_location_owner_other'] or { panic('location other') }
		for argument in ['foreign', 'deleted'] {
			other.native.make_current()
			mut unused := i32(0)
			C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
			assert runtime.evaluate_host('gl.getUniformLocation(${argument},"first")===null')! == 'true'
			public_uniform_location_owner([i32(9), 10, 11, 12]!)
			assert C.vox_gl_get_error() == webgl.invalid_enum
			assert C.vox_gl_get_error() == webgl.no_error
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		}
		other.native.make_current()
		assert runtime.evaluate_host('(function(){let converted=0;const result=gl.getUniformLocation(foreign,{toString(){converted++;return "first"}});return converted===1&&result===null})()')! == 'true'
		public_uniform_location_owner([i32(9), 10, 11, 12]!)
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		for expression in ['gl.getUniformLocation()', 'gl.getUniformLocation(program)',
			'gl.getUniformLocation(null,"first")',
			'gl.getUniformLocation(Object.create(WebGLProgram.prototype),"first")',
			'gl.getUniformLocation(program,Symbol())'] {
			other.native.make_current()
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
			public_uniform_location_owner([i32(9), 10, 11, 12]!)
		}
		vertex_text := if kind == 'webgl2' {
			'#version 300 es\nuniform vec4 first;uniform vec4 second;void main(){gl_Position=first+second;}'
		} else {
			'uniform vec4 first;uniform vec4 second;void main(){gl_Position=first+second;}'
		}
		fragment_text := if kind == 'webgl2' {
			'#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1);}'
		} else {
			'precision mediump float;void main(){gl_FragColor=vec4(1);}'
		}
		runtime.evaluate_host('gl.shaderSource(vertex,${json2.encode(vertex_text)});gl.shaderSource(fragment,${json2.encode(fragment_text)});gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);')!
		mut program_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() && !record.object.invalidated() {
				program_name = record.object.native_name()
			}
		}
		assert program_name != 0
		for name in ['first', 'second', 'first\x00ignored'] {
			expected := C.vox_gl_uniform_location(program_name, name.str)
			assert expected >= 0
			before := host.uniform_locations.keys()
			other.native.make_current()
			assert runtime.evaluate_host('(function(){const a=gl.getUniformLocation(program,${json2.encode(name)}),b=gl.getUniformLocation(program,${json2.encode(name)});return a!==b&&a instanceof WebGLUniformLocation&&b instanceof WebGLUniformLocation})()')! == 'true'
			public_uniform_location_owner([i32(1), 2, 3, 4]!)
			assert host.uniform_locations.len == before.len + 2
			for handle, record in host.uniform_locations {
				if handle !in before {
					assert record.handle_ == u32(expected)
				}
				if parent := record.parent_program {
					assert parent.object.context_id == owner.identity()
					assert parent.object.native_name() == program_name
					assert record.relevant_global_impl() or { panic('source location global') } == owner.identity()
				}
			}
			assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		}
		for name in ['missing', 'gl_reserved'] {
			assert C.vox_gl_uniform_location(program_name, name.str) == -1
			other.native.make_current()
			assert runtime.evaluate_host('gl.getUniformLocation(program,${json2.encode(name)})===null')! == 'true'
			public_uniform_location_owner([i32(1), 2, 3, 4]!)
			assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		}
		assert runtime.evaluate_host('globalThis.unlinked=gl.createProgram()')! != ''
		mut unlinked_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() && !record.object.invalidated() && record.object.native_name() != program_name {
				unlinked_name = record.object.native_name()
			}
		}
		assert unlinked_name != 0
		owner.native.make_current()
		assert C.vox_gl_uniform_location(unlinked_name, c'first') == -1
		expected := C.vox_gl_get_error()
		assert expected != webgl.no_error
		other.native.make_current()
		assert runtime.evaluate_host('gl.getUniformLocation(unlinked,"first")===null')! == 'true'
		public_uniform_location_owner([i32(1), 2, 3, 4]!)
		assert runtime.evaluate_host('gl.getError()===${expected}')! == 'true'
	}
}
