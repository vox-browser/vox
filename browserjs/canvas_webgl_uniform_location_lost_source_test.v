// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn public_uniform_location_lost_other_driver(program u32, location int) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
	mut bound := i32(-1)
	C.vox_gl_int_parameter(webgl.current_program, &bound)
	assert bound == int(program)
	assert C.vox_gl_program_parameter(program, webgl.link_status) == 1
	assert C.vox_gl_program_parameter(program, webgl.attached_shaders) == 2
	assert C.vox_gl_program_parameter(program, webgl.delete_status) == 0
	mut values := [f32(0), 0, 0, 0]!
	C.vox_gl_get_uniform_floats(program, location, &values[0])
	assert values == [f32(3), 4, 5, 6]!
}

fn test_public_lost_uniform_location_constructs_fresh_zero_records_and_preserves_other_uniforms() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_uniform_location_lost",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_uniform_location_lost_other",width:2,height:2},"${kind}",null);globalThis.original=gl.createProgram();globalThis.sentinel=other.createProgram();globalThis.vertex=other.createShader(other.VERTEX_SHADER);globalThis.fragment=other.createShader(other.FRAGMENT_SHADER);')!
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
		runtime.evaluate_host('other.shaderSource(vertex,${json2.encode(vertex_text)});other.shaderSource(fragment,${json2.encode(fragment_text)});other.compileShader(vertex);other.compileShader(fragment);other.attachShader(sentinel,vertex);other.attachShader(sentinel,fragment);other.linkProgram(sentinel);other.useProgram(sentinel);')!
		mut owner := host.contexts['__created_uniform_location_lost'] or { panic('lost location owner') }
		mut other := host.contexts['__created_uniform_location_lost_other'] or { panic('lost location other') }
		mut program_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == other.identity() {
				program_name = record.object.native_name()
			}
		}
		assert program_name != 0
		first_native := C.vox_gl_uniform_location(program_name, c'first')
		second_native := C.vox_gl_uniform_location(program_name, c'second')
		assert first_native >= 0 && second_native >= 0 && first_native != second_native
		name := if first_native > 0 { 'first' } else { 'second' }
		positive := if first_native > 0 { first_native } else { second_native }
		assert positive > 0
		C.vox_gl_uniform4f(positive, 3, 4, 5, 6)
		assert C.vox_gl_get_error() == webgl.no_error
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		mut unused := i32(0)
		C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
		assert runtime.evaluate_host('globalThis.after=gl.createProgram();after instanceof WebGLProgram')! == 'true'
		for argument in ['original', 'after'] {
			for query in [name, 'missing', 'gl_reserved'] {
				assert runtime.evaluate_host('(function(){const a=gl.getUniformLocation(${argument},${json2.encode(query)}),b=gl.getUniformLocation(${argument},${json2.encode(query)});return a!==b&&a instanceof WebGLUniformLocation&&b instanceof WebGLUniformLocation})()')! == 'true'
				public_uniform_location_lost_other_driver(program_name, positive)
			}
		}
		assert runtime.evaluate_host('(function(){let count=0;const a=gl.getUniformLocation(original,{toString(){count++;return "missing"}});return count===1&&a instanceof WebGLUniformLocation})()')! == 'true'
		public_uniform_location_lost_other_driver(program_name, positive)
		for expression in ['gl.getUniformLocation()', 'gl.getUniformLocation(original)',
			'gl.getUniformLocation(null,"first")',
			'gl.getUniformLocation(Object.create(WebGLProgram.prototype),"first")',
			'gl.getUniformLocation(original,Symbol())'] {
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
			public_uniform_location_lost_other_driver(program_name, positive)
		}
		assert runtime.evaluate_host('gl.getUniformLocation(sentinel,"first")===null')! == 'true'
		public_uniform_location_lost_other_driver(program_name, positive)
		mut original_count := 0
		mut after_count := 0
		for _, record in host.uniform_locations {
			parent := record.parent_program or { panic('actual lost source parent') }
			assert parent.object.context_id == owner.identity()
			assert record.handle_ == 0
			assert record.relevant_global_impl() or { panic('owning parent global') } == parent.object.relevant_global_impl()
			if parent.object.native_name() == 0 { after_count++ } else { original_count++ }
		}
		assert original_count == 7 && after_count == 6
		assert runtime.evaluate_host('globalThis.retained=gl.getUniformLocation(original,"missing");gl.deleteProgram(original);gl.getUniformLocation(original,"missing")===null&&retained instanceof WebGLUniformLocation')! == 'true'
		public_uniform_location_lost_other_driver(program_name, positive)
		mut retained_deleted := 0
		for _, record in host.uniform_locations {
			if parent := record.parent_program {
				if parent.object.invalidated() {
					assert record.handle(parent)! == 0
					retained_deleted++
				}
			}
		}
		assert retained_deleted == 8
		assert runtime.evaluate_host('globalThis.next=gl.createProgram();next instanceof WebGLProgram')! == 'true'
		mut unmapped_ids := []u32{}
		for _, record in host.programs {
			if record.object.context_id == owner.identity() && record.object.native_name() == 0 {
				unmapped_ids << record.object.handle(owner.identity(), owner.context_generation())!
			}
		}
		unmapped_ids.sort()
		assert unmapped_ids == [u32(2), 3]
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR&&other.getParameter(other.CURRENT_PROGRAM)===sentinel&&other.getError()===other.NO_ERROR')! == 'true'
	}
}
