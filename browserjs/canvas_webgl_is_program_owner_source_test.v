// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn test_public_is_program_optional_gate_preserves_other_owner_and_native_identity() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_is_program",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_is_program_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut owner := host.contexts['__created_is_program'] or { panic('program owner') }
		mut other := host.contexts['__created_is_program_other'] or { panic('program other') }
		owner.native.make_current()
		mut reserved := []u32{}
		for _ in 0 .. 8 { reserved << C.vox_gl_create_program() }
		runtime.evaluate_host('globalThis.program=gl.createProgram();globalThis.foreign=other.createProgram();globalThis.vertex=gl.createShader(gl.VERTEX_SHADER);globalThis.fragment=gl.createShader(gl.FRAGMENT_SHADER);')!
		vertex := if kind == 'webgl2' {
			'#version 300 es
void main(){gl_Position=vec4(0);}'
		} else {
			'void main(){gl_Position=vec4(0);}'
		}
		fragment := if kind == 'webgl2' {
			'#version 300 es
precision mediump float;out vec4 color;void main(){color=vec4(1);}'
		} else {
			'precision mediump float;void main(){gl_FragColor=vec4(1);}'
		}
		runtime.evaluate_host('gl.shaderSource(vertex,${json2.encode(vertex)});gl.shaderSource(fragment,${json2.encode(fragment)});gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);')!
		assert runtime.evaluate_host('gl.getProgramParameter(program,gl.LINK_STATUS)===true')! == 'true'
		owner.native.make_current()
		C.vox_gl_delete_program(reserved[0])
		mut name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() {
				name = record.object.native_name()
				assert record.object.handle(owner.identity(), owner.context_generation())! == 1
			}
		}
		assert name !in reserved
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		assert runtime.evaluate_host('gl.isProgram(foreign)===false')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert C.vox_gl_get_error() == webgl.invalid_value
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('(function(){try{gl.isProgram(Object.create(WebGLProgram.prototype));return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.isProgram(program)===true')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		runtime.evaluate_host('gl.useProgram(program);gl.deleteProgram(program)')!
		assert C.vox_gl_is_object(10, name) == 1
		other.native.make_current()
		assert runtime.evaluate_host('gl.isProgram(program)===false')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		runtime.evaluate_host('other.deleteProgram(foreign)')!
		other.native.make_current()
		assert runtime.evaluate_host('gl.isProgram(foreign)===false')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		owner.native.make_current()
		C.vox_gl_use_program(0)
		assert C.vox_gl_is_object(10, name) == 0
		for native in reserved[1..] { C.vox_gl_delete_program(native) }
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
	}
}
