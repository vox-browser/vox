// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn public_attrib_binding_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == expected
}

fn test_public_bind_attrib_source_handle_order_conversion_and_actual_driver_locations() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_attrib_bind",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_attrib_bind_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.program=gl.createProgram();globalThis.foreign=other.createProgram();globalThis.deleted=gl.createProgram();gl.deleteProgram(deleted);globalThis.vertex=gl.createShader(gl.VERTEX_SHADER);globalThis.fragment=gl.createShader(gl.FRAGMENT_SHADER);')!
		mut owner := host.contexts['__created_attrib_bind'] or { panic('binding owner') }
		mut other := host.contexts['__created_attrib_bind_other'] or { panic('binding other') }
		for argument in ['foreign', 'deleted'] {
			other.native.make_current()
			mut unused := i32(0)
			C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
			assert runtime.evaluate_host('gl.bindAttribLocation(${argument},-1,"gl_reserved")===undefined')! == 'true'
			public_attrib_binding_owner([i32(9), 10, 11, 12]!)
			assert C.vox_gl_get_error() == webgl.invalid_enum
			assert C.vox_gl_get_error() == webgl.no_error
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		}
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const order=[];gl.bindAttribLocation(foreign,{valueOf(){order.push("index");return 1}},{toString(){order.push("name");return "position"}});return order.join(",")==="index,name"})()')! == 'true'
		public_attrib_binding_owner([i32(9), 10, 11, 12]!)
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		for expression in ['gl.bindAttribLocation()', 'gl.bindAttribLocation(program,0)',
			'gl.bindAttribLocation(null,0,"position")',
			'gl.bindAttribLocation(Object.create(WebGLProgram.prototype),0,"position")',
			'gl.bindAttribLocation(program,Symbol(),"position")',
			'gl.bindAttribLocation(program,0,Symbol())'] {
			other.native.make_current()
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
			public_attrib_binding_owner([i32(9), 10, 11, 12]!)
		}
		vertex_text := if kind == 'webgl2' {
			'#version 300 es\nin vec4 position;void main(){gl_Position=position;}'
		} else {
			'attribute vec4 position;void main(){gl_Position=position;}'
		}
		fragment_text := if kind == 'webgl2' {
			'#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1);}'
		} else {
			'precision mediump float;void main(){gl_FragColor=vec4(1);}'
		}
		runtime.evaluate_host('gl.shaderSource(vertex,${json2.encode(vertex_text)});gl.shaderSource(fragment,${json2.encode(fragment_text)});gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);')!
		mut program_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() && !record.object.invalidated() {
				program_name = record.object.native_name()
			}
		}
		assert program_name != 0
		for index in [3, 5] {
			other.native.make_current()
			name := if index == 3 { 'position' } else { 'position\x00ignored' }
			assert runtime.evaluate_host('gl.bindAttribLocation(program,${index},${json2.encode(name)})===undefined')! == 'true'
			public_attrib_binding_owner([i32(1), 2, 3, 4]!)
			C.vox_gl_link_program(program_name)
			assert C.vox_gl_attrib_location(program_name, c'position') == index
			assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		}
		for name in ['position', 'gl_reserved'] {
			C.vox_gl_bind_attrib_location(program_name, u32(-1), name.str)
			expected := C.vox_gl_get_error()
			assert expected != webgl.no_error
			other.native.make_current()
			assert runtime.evaluate_host('gl.bindAttribLocation(program,-1,${json2.encode(name)})===undefined')! == 'true'
			public_attrib_binding_owner([i32(1), 2, 3, 4]!)
			assert runtime.evaluate_host('gl.getError()===${expected}')! == 'true'
		}
		assert runtime.evaluate_host('gl.getAttachedShaders(program)[0]===vertex&&gl.getAttachedShaders(program)[1]===fragment')! == 'true'
	}
}
