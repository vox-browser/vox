// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_source_proxy_ids_and_native_names_preserve_compact_wrapper_identity() {
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
	runtime.evaluate_host('globalThis.handleGL=__webglContext({bridgeKey:"__created_object_handle_source",width:2,height:2},"webgl2",null);')!
	mut context := host.contexts['__created_object_handle_source'] or { panic('handle source context') }
	context.native.make_current()
	mut reserved := []u32{}
	for _ in 0 .. 8 {
		name := C.vox_gl_gen_object(0)
		C.vox_gl_bind_buffer(webgl.array_buffer, name)
		reserved << name
	}
	assert runtime.evaluate_host(r'(function(){const gl=handleGL;globalThis.handleBuffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,handleBuffer);if(gl.getParameter(gl.ARRAY_BUFFER_BINDING)!==handleBuffer)return false;const f=gl.createFramebuffer(),r=gl.createRenderbuffer(),t=gl.createTexture();gl.bindFramebuffer(gl.FRAMEBUFFER,f);gl.bindRenderbuffer(gl.RENDERBUFFER,r);gl.bindTexture(gl.TEXTURE_2D,t);if(gl.getParameter(gl.FRAMEBUFFER_BINDING)!==f||gl.getParameter(gl.RENDERBUFFER_BINDING)!==r||gl.getParameter(gl.TEXTURE_BINDING_2D)!==t)return false;gl.bindFramebuffer(gl.FRAMEBUFFER,null);const vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER),program=gl.createProgram();gl.shaderSource(vertex,"#version 300 es\nvoid main(){gl_Position=vec4(0,0,0,1);}");gl.shaderSource(fragment,"#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1);}");gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);gl.useProgram(program);const attached=gl.getAttachedShaders(program);return gl.getProgramParameter(program,gl.LINK_STATUS)&&gl.getParameter(gl.CURRENT_PROGRAM)===program&&attached.length===2&&attached[0]===vertex&&attached[1]===fragment&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	mut actual := i32(0)
	C.vox_gl_int_parameter(webgl.array_buffer_binding, &actual)
	assert u32(actual) !in reserved
	for _, buffer in host.buffers {
		if buffer.object.context_id != context.identity() { continue }
		assert buffer.object.handle(context.identity(), context.context_generation())! == 1
		assert buffer.object.native_name() == u32(actual)
		assert buffer.object.bookkeeping_id() != u32(actual)
	}
	assert runtime.evaluate_host(r'(function(){handleGL.deleteBuffer(handleBuffer);if(handleGL.getParameter(handleGL.ARRAY_BUFFER_BINDING)!==handleBuffer)return false;handleGL.bindBuffer(handleGL.ARRAY_BUFFER,handleBuffer);return handleGL.getError()===handleGL.INVALID_OPERATION})()')! == 'true'
	assert C.vox_gl_is_object(0, u32(actual)) == 0
	for name in reserved {
		assert C.vox_gl_is_object(0, name) == 1
		C.vox_gl_delete_object(0, name)
	}
}
