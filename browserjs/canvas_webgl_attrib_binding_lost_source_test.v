// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn public_attrib_binding_lost_other_driver(program u32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
	C.vox_gl_link_program(program)
	assert C.vox_gl_program_parameter(program, webgl.link_status) == 1
	assert C.vox_gl_attrib_location(program, c'position') == 2
	assert C.vox_gl_program_parameter(program, webgl.attached_shaders) == 2
	assert C.vox_gl_program_parameter(program, webgl.delete_status) == 0
}

fn test_public_lost_bind_attrib_preserves_other_real_linked_location_and_source_conversions() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_attrib_bind_lost",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_attrib_bind_lost_other",width:2,height:2},"${kind}",null);globalThis.original=gl.createProgram();globalThis.sentinel=other.createProgram();globalThis.vertex=other.createShader(other.VERTEX_SHADER);globalThis.fragment=other.createShader(other.FRAGMENT_SHADER);')!
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
		runtime.evaluate_host('other.shaderSource(vertex,${json2.encode(vertex_text)});other.shaderSource(fragment,${json2.encode(fragment_text)});other.compileShader(vertex);other.compileShader(fragment);other.attachShader(sentinel,vertex);other.attachShader(sentinel,fragment);other.bindAttribLocation(sentinel,2,"position");')!
		mut owner := host.contexts['__created_attrib_bind_lost'] or { panic('lost binding owner') }
		mut other := host.contexts['__created_attrib_bind_lost_other'] or { panic('lost binding other') }
		mut program_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == other.identity() {
				program_name = record.object.native_name()
			}
		}
		assert program_name != 0
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		mut unused := i32(0)
		C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
		assert runtime.evaluate_host('globalThis.after=gl.createProgram();after instanceof WebGLProgram')! == 'true'
		for argument in ['original', 'after', 'sentinel'] {
			for name in ['position', 'position\x00ignored', 'gl_reserved'] {
				assert runtime.evaluate_host('gl.bindAttribLocation(${argument},6,${json2.encode(name)})===undefined')! == 'true'
				public_attrib_binding_lost_other_driver(program_name)
			}
		}
		assert runtime.evaluate_host('(function(){const order=[];gl.bindAttribLocation(original,{valueOf(){order.push("index");return 6}},{toString(){order.push("name");return "position"}});return order.join(",")==="index,name"})()')! == 'true'
		public_attrib_binding_lost_other_driver(program_name)
		for expression in ['gl.bindAttribLocation()', 'gl.bindAttribLocation(original,0)',
			'gl.bindAttribLocation(null,0,"position")',
			'gl.bindAttribLocation(Object.create(WebGLProgram.prototype),0,"position")',
			'gl.bindAttribLocation(original,Symbol(),"position")',
			'gl.bindAttribLocation(original,0,Symbol())'] {
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
			public_attrib_binding_lost_other_driver(program_name)
		}
		assert runtime.evaluate_host('gl.deleteProgram(original);gl.bindAttribLocation(original,6,"position")===undefined')! == 'true'
		public_attrib_binding_lost_other_driver(program_name)
		mut unmapped := 0
		for _, record in host.programs {
			if record.object.context_id == owner.identity() && record.object.native_name() == 0 {
				assert record.object.handle(owner.identity(), owner.context_generation())! == 2
				unmapped++
			}
		}
		assert unmapped == 1
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR&&other.getAttachedShaders(sentinel)[0]===vertex&&other.getAttachedShaders(sentinel)[1]===fragment&&other.getError()===other.NO_ERROR')! == 'true'
	}
}
