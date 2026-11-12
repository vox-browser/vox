// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn C.glGetAttachedShaders(u32, int, &i32, &u32)
fn C.glIsShader(u32) u8

fn test_public_get_attached_shaders_wraps_retained_deleted_and_first_exposed_records() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	runtime.evaluate_host('const __canvases=Object.create(null);function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	for kind in ['webgl', 'webgl2'] {
		key := '__created_attached_shader_records_${kind}'
		other_key := '__created_attached_shader_other_${kind}'
		runtime.evaluate_host('globalThis.recordShaderGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.recordShaderOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);recordShaderGL.viewport(1,2,3,4);recordShaderOther.viewport(9,10,11,12);')!
		assert runtime.evaluate_host(r'(function(){const gl=recordShaderGL,vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER),program=gl.createProgram();gl.attachShader(program,fragment);gl.attachShader(program,vertex);gl.deleteShader(vertex);gl.deleteShader(fragment);const first=gl.getAttachedShaders(program),second=gl.getAttachedShaders(program);return first!==second&&first.length===2&&first[0]===vertex&&first[1]===fragment&&first[0]===second[0]&&first[1]===second[1]&&first.every(shader=>shader instanceof WebGLShader)&&!gl.isShader(vertex)&&!gl.isShader(fragment)&&gl.getError()===gl.NO_ERROR})()')! == 'true'
		runtime.evaluate_host('globalThis.typedRecordProgram=recordShaderGL.createProgram();')!
		mut context := host.contexts[key] or { panic('shader record context') }
		mut other := host.contexts[other_key] or { panic('other shader context') }
		other.native.make_current()
		assert runtime.evaluate_host('recordShaderGL.getAttachedShaders(typedRecordProgram).length===0')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		// The last registered program belongs to the public wrapper above.
		program_wrapper := host.next_handle.str()
		mut program := host.programs[program_wrapper] or { panic('typed record program') }
		mut vertex := context.create_shader(webgl.vertex_shader) or { panic('typed vertex') }
		mut fragment := context.create_shader(webgl.fragment_shader) or { panic('typed fragment') }
		vertex.object.set_label('retained deleted vertex')
		fragment.object.set_label('retained deleted fragment')
		context.attach_shader(mut program, fragment)
		context.attach_shader(mut program, vertex)
		vertex_native := vertex.object.native_name()
		fragment_native := fragment.object.native_name()
		context.delete_shader(vertex)
		context.delete_shader(fragment)
		assert voidptr(&vertex.object) !in host.platform_objects
		assert voidptr(&fragment.object) !in host.platform_objects
		mut count := 0
		mut native_names := [u32(0), 0]!
		C.glGetAttachedShaders(program.object.native_name(),
			2, &count, &native_names[0])
		assert count == 2
		assert vertex_native in native_names
		assert fragment_native in native_names
		assert C.glIsShader(vertex_native) == 1
		assert C.glIsShader(fragment_native) == 1
		other.native.make_current()
		assert runtime.evaluate_host(r'(function(){globalThis.firstTypedShaders=recordShaderGL.getAttachedShaders(typedRecordProgram);const second=recordShaderGL.getAttachedShaders(typedRecordProgram);return firstTypedShaders.length===2&&firstTypedShaders!==second&&firstTypedShaders.every((shader,index)=>shader instanceof WebGLShader&&shader===second[index])})()')! == 'true'
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		vertex_wrapper := host.platform_objects[voidptr(&vertex.object)] or { panic('vertex wrapper') }
		fragment_wrapper := host.platform_objects[voidptr(&fragment.object)] or { panic('fragment wrapper') }
		registered_vertex := host.shaders[vertex_wrapper] or { panic('vertex record') }
		registered_fragment := host.shaders[fragment_wrapper] or { panic('fragment record') }
		assert registered_vertex == vertex
		assert registered_fragment == fragment
		assert registered_vertex.object.label() == 'retained deleted vertex'
		assert registered_fragment.object.label() == 'retained deleted fragment'
		assert runtime.evaluate_host(r'(function(){const gl=recordShaderGL;for(const shader of firstTypedShaders){if(gl.getShaderSource(shader)!==null||gl.getError()!==gl.INVALID_OPERATION)return false;gl.deleteShader(shader);if(gl.getError()!==gl.NO_ERROR)return false}return gl.getAttachedShaders(typedRecordProgram)[0]===firstTypedShaders[0]})()')! == 'true'
		context.delete_program(program)
		assert C.glIsShader(vertex_native) == 0
		assert C.glIsShader(fragment_native) == 0
		other.native.make_current()
		assert runtime.evaluate_host('recordShaderGL.getAttachedShaders(typedRecordProgram)===null')! == 'true'
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('recordShaderGL.getError()===recordShaderGL.INVALID_OPERATION')! == 'true'
		runtime.evaluate_host('globalThis.foreignAttachedProgram=recordShaderOther.createProgram();')!
		other.native.make_current()
		assert runtime.evaluate_host('recordShaderGL.getAttachedShaders(foreignAttachedProgram)===null')! == 'true'
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('recordShaderGL.getError()===recordShaderGL.INVALID_OPERATION')! == 'true'
	}
}
