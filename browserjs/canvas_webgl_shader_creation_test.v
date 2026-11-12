// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_shader_creation_source_type_gate_and_conversion_precede_driver_owner() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_shader_type",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_shader_type_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut other := host.contexts['__created_shader_type_other'] or { panic('shader type other') }
		for type_ in ['0', '0xbad', '0xffff', '-1'] {
			other.native.make_current()
			assert runtime.evaluate_host('gl.createShader(${type_})===null')! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR')! == 'true'
		}
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.createShader({valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		for type_ in ['gl.VERTEX_SHADER', 'gl.FRAGMENT_SHADER'] {
			other.native.make_current()
			assert runtime.evaluate_host('gl.createShader(${type_}) instanceof WebGLShader')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		}
	}
}

fn test_public_source_shader_creation_exposes_records_for_actual_native_zero() {
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
		key := '__created_shader_zero_${kind}'
		runtime.evaluate_host('globalThis.zeroGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);')!
		mut context := host.contexts[key] or { panic('shader creation context') }
		assert !context.native.is_lost()
		context.lose_context_from_compositor_loss()
		native_handle := C.vox_gl_create_shader(0x8b31)
		assert native_handle == 0
		previous_shader_count := host.shaders.len
		actual := runtime.evaluate_host(r'
 globalThis.zeroVertex=zeroGL.createShader(zeroGL.VERTEX_SHADER);
 globalThis.zeroFragment=zeroGL.createShader(zeroGL.FRAGMENT_SHADER);
 zeroVertex!==null&&zeroFragment!==null&&zeroVertex!==zeroFragment&&
 zeroVertex instanceof WebGLShader&&zeroFragment instanceof WebGLShader&&
 zeroGL.isContextLost()&&zeroGL.getError()===zeroGL.CONTEXT_LOST_WEBGL&&zeroGL.getError()===zeroGL.NO_ERROR;
 ')!
		assert actual == 'true'
		assert host.shaders.len == previous_shader_count + 2
	}
}

fn test_public_lost_shader_creation_retains_owned_ids_and_other_driver_untouched() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_lost_shader",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_lost_shader_other",width:1,height:1},"${kind}",null);other.viewport(9,10,11,12);globalThis.sentinel=other.createShader(other.VERTEX_SHADER);other.shaderSource(sentinel,"void main(){gl_Position=vec4(0);}");')!
		mut context := host.contexts['__created_lost_shader'] or { panic('lost shader owner') }
		mut other := host.contexts['__created_lost_shader_other'] or { panic('lost shader other') }
		context.lose_context_from_compositor_loss()
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		previous_records := host.shaders.len
		assert runtime.evaluate_host('globalThis.zeroVertex=gl.createShader(gl.VERTEX_SHADER);globalThis.zeroFragment=gl.createShader(gl.FRAGMENT_SHADER);zeroVertex instanceof WebGLShader&&zeroFragment instanceof WebGLShader&&zeroVertex!==zeroFragment')! == 'true'
		assert host.shaders.len == previous_records + 2
		mut retained_ids := []webgl.GLuint{}
		for _, shader in host.shaders {
			if shader.object.context_id != context.identity() { continue }
			assert shader.object.bookkeeping_id() != 0
			assert shader.object.handle(context.identity(), context.context_generation())! != 0
			assert shader.object.native_name() == 0
			assert context.owns(&shader.object)
			retained_ids << shader.object.bookkeeping_id()
		}
		assert retained_ids[0] != retained_ids[1]
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert C.vox_gl_get_error() == webgl.invalid_value
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('other.getShaderSource(sentinel)==="void main(){gl_Position=vec4(0);}"&&other.getError()===other.NO_ERROR&&gl.isContextLost()&&gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
	}
}
