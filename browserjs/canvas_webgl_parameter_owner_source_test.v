// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn public_parameter_source_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == expected
}

fn test_public_get_parameter_cpu_wrappers_browser_state_and_early_errors_preserve_other_driver() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_parameter_owner",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_parameter_owner_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.buffer=gl.createBuffer();globalThis.texture=gl.createTexture();globalThis.framebuffer=gl.createFramebuffer();globalThis.renderbuffer=gl.createRenderbuffer();globalThis.program=gl.createProgram();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bindTexture(gl.TEXTURE_2D,texture);gl.bindFramebuffer(gl.FRAMEBUFFER,framebuffer);gl.bindRenderbuffer(gl.RENDERBUFFER,renderbuffer);gl.useProgram(program);gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,1);gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,1);gl.pixelStorei(gl.UNPACK_COLORSPACE_CONVERSION_WEBGL,-1);gl.deleteBuffer(buffer);')!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		mut other := host.contexts['__created_parameter_owner_other'] or { panic('parameter other') }
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
		for expression in ['gl.getParameter(gl.ARRAY_BUFFER_BINDING)===buffer',
			'gl.getParameter(gl.ELEMENT_ARRAY_BUFFER_BINDING)===null',
			'gl.getParameter(gl.FRAMEBUFFER_BINDING)===framebuffer',
			'gl.getParameter(gl.RENDERBUFFER_BINDING)===renderbuffer',
			'gl.getParameter(gl.CURRENT_PROGRAM)===program',
			'gl.getParameter(gl.TEXTURE_BINDING_2D)===texture',
			'gl.getParameter(gl.TEXTURE_BINDING_CUBE_MAP)===null',
			'gl.getParameter(gl.COMPRESSED_TEXTURE_FORMATS) instanceof Uint32Array',
			'gl.getParameter(gl.UNPACK_FLIP_Y_WEBGL)===true',
			'gl.getParameter(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL)===true',
			'gl.getParameter(gl.UNPACK_COLORSPACE_CONVERSION_WEBGL)===4294967295'] {
			assert runtime.evaluate_host(expression)! == 'true'
			public_parameter_source_owner([i32(9), 10, 11, 12]!)
		}
		mut invalid_names := [u32(0xbad), 0x9245, 0x9246, 0x84ff]
		if kind == 'webgl' { invalid_names << [u32(0x8b8b), 0x85b5, 0x8919, 0x8a30] }
		for pname in invalid_names {
			other.native.make_current()
			assert runtime.evaluate_host('gl.getParameter(${pname})===null')! == 'true'
			public_parameter_source_owner([i32(9), 10, 11, 12]!)
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM')! == 'true'
			public_parameter_source_owner([i32(1), 2, 3, 4]!)
		}
		other.native.make_current()
		if kind == 'webgl2' {
			for name in ['TEXTURE_BINDING_3D', 'TEXTURE_BINDING_2D_ARRAY', 'COPY_READ_BUFFER_BINDING',
				'COPY_WRITE_BUFFER_BINDING', 'PIXEL_PACK_BUFFER_BINDING', 'PIXEL_UNPACK_BUFFER_BINDING',
				'UNIFORM_BUFFER_BINDING', 'TRANSFORM_FEEDBACK_BUFFER_BINDING',
				'TRANSFORM_FEEDBACK_BINDING', 'VERTEX_ARRAY_BINDING'] {
				assert runtime.evaluate_host('gl.getParameter(gl.${name})===null')! == 'true'
				public_parameter_source_owner([i32(9), 10, 11, 12]!)
			}
		}
		for expression in ['gl.getParameter()', 'gl.getParameter(Symbol())'] {
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
			public_parameter_source_owner([i32(9), 10, 11, 12]!)
		}
		assert runtime.evaluate_host('(function(){let count=0;const p=gl.getParameter({valueOf(){count++;return gl.CURRENT_PROGRAM}});return count===1&&p===program})()')! == 'true'
		public_parameter_source_owner([i32(9), 10, 11, 12]!)
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('Array.from(gl.getParameter(gl.VIEWPORT)).join(",")==="1,2,3,4"')! == 'true'
		public_parameter_source_owner([i32(1), 2, 3, 4]!)
		runtime.evaluate_host('gl.enable(gl.BLEND)')!
		other.native.make_current()
		assert runtime.evaluate_host('gl.getParameter(gl.BLEND)===true')! == 'true'
		public_parameter_source_owner([i32(1), 2, 3, 4]!)
		if kind == 'webgl2' {
			runtime.evaluate_host('globalThis.sampler=gl.createSampler();gl.bindSampler(0,sampler)')!
			other.native.make_current()
			assert runtime.evaluate_host('gl.getParameter(gl.SAMPLER_BINDING) instanceof WebGLSampler')! == 'true'
			public_parameter_source_owner([i32(1), 2, 3, 4]!)
		}
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
	}
}
