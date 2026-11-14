// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn test_public_lost_program_queries_keep_initialized_source_outputs_and_other_driver() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_program_lost_query",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_program_lost_query_other",width:2,height:2},"${kind}",null);globalThis.first=gl.createProgram();globalThis.second=gl.createProgram();globalThis.valid=other.createProgram();globalThis.invalid=other.createProgram();globalThis.vertex=other.createShader(other.VERTEX_SHADER);globalThis.fragment=other.createShader(other.FRAGMENT_SHADER);')!
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
		runtime.evaluate_host('other.shaderSource(vertex,${json2.encode(vertex)});other.shaderSource(fragment,${json2.encode(fragment)});other.compileShader(vertex);other.compileShader(fragment);other.attachShader(valid,vertex);other.attachShader(valid,fragment);other.linkProgram(valid);')!
		mut owner := host.contexts['__created_program_lost_query'] or { panic('lost program query owner') }
		mut other := host.contexts['__created_program_lost_query_other'] or { panic('lost program query other') }
		mut valid_name := u32(0)
		mut invalid_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id != other.identity() { continue }
			id := record.object.handle(other.identity(), other.context_generation())!
			if id == 1 { valid_name = record.object.native_name() }
			if id == 2 { invalid_name = record.object.native_name() }
		}
		assert valid_name != 0
		assert invalid_name != 0
		other.native.make_current()
		C.vox_gl_link_program(invalid_name)
		assert C.vox_gl_program_parameter(valid_name, webgl.link_status) == 1
		log_length := C.vox_gl_program_parameter(invalid_name, u32(0x8b84))
		assert log_length > 1
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		assert runtime.evaluate_host('globalThis.after=gl.createProgram();after instanceof WebGLProgram')! == 'true'
		mut numeric := ['ATTACHED_SHADERS', 'ACTIVE_ATTRIBUTES', 'ACTIVE_UNIFORMS']
		if kind == 'webgl2' {
			numeric << ['TRANSFORM_FEEDBACK_BUFFER_MODE', 'TRANSFORM_FEEDBACK_VARYINGS',
				'ACTIVE_UNIFORM_BLOCKS']
		}
		for program in ['first', 'second', 'after'] {
			mut queries := ['gl.getProgramInfoLog(${program})===""']
			for pname in numeric { queries << 'gl.getProgramParameter(${program},gl.${pname})===0' }
			for pname in ['LINK_STATUS', 'DELETE_STATUS', 'VALIDATE_STATUS'] {
				queries << 'gl.getProgramParameter(${program},gl.${pname})===false'
			}
			for query in queries {
				assert runtime.evaluate_host(query)! == 'true'
				mut selected := [i32(0), 0, 0, 0]!
				C.vox_gl_int_parameter(webgl.viewport, &selected[0])
				assert selected == [i32(9), 10, 11, 12]!
				assert C.vox_gl_program_parameter(valid_name, webgl.link_status) == 1
				assert C.vox_gl_program_parameter(invalid_name, u32(0x8b84)) == log_length
			}
		}
		assert runtime.evaluate_host('(function(){let conversions=0;const value=gl.getProgramParameter(first,{valueOf(){conversions++;return gl.LINK_STATUS}});return value===false&&conversions===1})()')! == 'true'
		assert runtime.evaluate_host('(function(){const marker={};try{gl.getProgramParameter(first,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		assert C.vox_gl_get_error() == webgl.invalid_value
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR&&other.getProgramParameter(valid,other.LINK_STATUS)===true&&other.getProgramInfoLog(invalid).length>0&&other.getError()===other.NO_ERROR')! == 'true'
	}
}
