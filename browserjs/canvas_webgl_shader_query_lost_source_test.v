// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn test_public_lost_shader_queries_keep_source_output_shapes_and_other_driver_untouched() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_shader_lost_query",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_shader_lost_query_other",width:2,height:2},"${kind}",null);globalThis.first=gl.createShader(gl.VERTEX_SHADER);globalThis.second=gl.createShader(gl.VERTEX_SHADER);globalThis.valid=other.createShader(other.VERTEX_SHADER);globalThis.invalid=other.createShader(other.VERTEX_SHADER);')!
		text := if kind == 'webgl2' {
			r'#version 300 es
void main(){gl_Position=vec4(0);}'
		} else {
			'void main(){gl_Position=vec4(0);}'
		}
		runtime.evaluate_host('other.shaderSource(valid,${json2.encode(text)});other.compileShader(valid);other.shaderSource(invalid,"this is not a shader");other.compileShader(invalid);')!
		mut owner := host.contexts['__created_shader_lost_query'] or { panic('lost query owner') }
		mut other := host.contexts['__created_shader_lost_query_other'] or { panic('lost query other') }
		mut valid_name := u32(0)
		mut invalid_name := u32(0)
		for _, record in host.shaders {
			if record.object.context_id != other.identity() { continue }
			id := record.object.handle(other.identity(), other.context_generation())!
			if id == 1 {
				valid_name = record.object.native_name()
			} else if id == 2 {
				invalid_name = record.object.native_name()
			}
		}
		assert valid_name != 0
		assert invalid_name != 0
		other.native.make_current()
		assert C.vox_gl_shader_parameter(valid_name, webgl.compile_status) == 1
		log_length := C.vox_gl_shader_parameter(invalid_name, u32(0x8b84))
		assert log_length > 1
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		assert runtime.evaluate_host('globalThis.after=gl.createShader(gl.VERTEX_SHADER);after instanceof WebGLShader')! == 'true'
		for shader in ['first', 'second', 'after'] {
			for query in ['gl.getShaderSource(${shader})===""', 'gl.getShaderInfoLog(${shader})===""',
				'gl.getShaderParameter(${shader},gl.SHADER_TYPE)===0',
				'gl.getShaderParameter(${shader},gl.COMPILE_STATUS)===false',
				'gl.getShaderParameter(${shader},gl.DELETE_STATUS)===false'] {
				assert runtime.evaluate_host(query)! == 'true'
				mut selected := [i32(0), 0, 0, 0]!
				C.vox_gl_int_parameter(webgl.viewport, &selected[0])
				assert selected == [i32(9), 10, 11, 12]!
				assert C.vox_gl_shader_parameter(valid_name, webgl.compile_status) == 1
				assert C.vox_gl_shader_parameter(invalid_name, u32(0x8b84)) == log_length
			}
		}
		assert runtime.evaluate_host('(function(){let conversions=0;const value=gl.getShaderParameter(first,{valueOf(){conversions++;return gl.SHADER_TYPE}});return value===0&&conversions===1})()')! == 'true'
		assert runtime.evaluate_host('(function(){const marker={};try{gl.getShaderParameter(first,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		assert C.vox_gl_get_error() == webgl.invalid_value
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.isContextLost()&&gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR&&other.getShaderParameter(valid,other.COMPILE_STATUS)===true&&other.getShaderInfoLog(invalid).length>0&&other.getError()===other.NO_ERROR')! == 'true'
	}
}
