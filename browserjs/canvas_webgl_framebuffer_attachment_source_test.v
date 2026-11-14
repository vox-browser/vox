// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn public_attachment_source_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == expected
}

fn test_public_source_framebuffer_attachment_owner_validation_and_driver_error_retention() {
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
		key := '__created_attachment_source_${kind}'
		other_key := '__created_attachment_other_${kind}'
		runtime.evaluate_host('globalThis.attachmentOwner=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.attachmentOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);globalThis.attachmentForeignTexture=attachmentOther.createTexture();globalThis.attachmentForeignRenderbuffer=attachmentOther.createRenderbuffer();attachmentOwner.viewport(1,2,3,4);attachmentOther.viewport(9,10,11,12);')!
		mut other := host.contexts[other_key] or { panic('other attachment context') }
		for expression in [
			'framebufferRenderbuffer(0xbad,0xbad,0xbad,attachmentForeignRenderbuffer)',
			'framebufferRenderbuffer(36160,0xbad,0xbad,attachmentForeignRenderbuffer)',
			'framebufferRenderbuffer(36160,36064,0xbad,attachmentForeignRenderbuffer)',
			'framebufferTexture2D(0xbad,0xbad,0xbad,attachmentForeignTexture,-1)',
			'framebufferTexture2D(36160,0xbad,0xbad,attachmentForeignTexture,-1)',
			'framebufferTexture2D(36160,36064,0xbad,attachmentForeignTexture,-1)',
		] {
			other.native.make_current()
			runtime.evaluate_host('attachmentOwner.${expression};')!
			public_attachment_source_owner([i32(1), 2, 3, 4]!)
			assert runtime.evaluate_host('attachmentOwner.getError()')! == '1280'
		}
		other.native.make_current()
		runtime.evaluate_host('attachmentOwner.framebufferTexture2D(36160,36064,3553,attachmentForeignTexture,-1);')!
		public_attachment_source_owner([i32(1), 2, 3, 4]!)
		assert runtime.evaluate_host('attachmentOwner.getError()')! == '1281'
		runtime.evaluate_host('globalThis.attachmentFramebuffer=attachmentOwner.createFramebuffer();globalThis.attachmentTexture=attachmentOwner.createTexture();globalThis.attachmentRenderbuffer=attachmentOwner.createRenderbuffer();attachmentOwner.bindFramebuffer(36160,attachmentFramebuffer);attachmentOwner.bindTexture(3553,attachmentTexture);attachmentOwner.bindRenderbuffer(36161,attachmentRenderbuffer);')!
		mut context := host.contexts[key] or { panic('attachment owner context') }
		context.native.make_current()
		C.vox_gl_bind_framebuffer(webgl.framebuffer, 0)
		mut texture_handle := i32(0)
		C.vox_gl_int_parameter(webgl.texture_binding_2d, &texture_handle)
		mut renderbuffer_handle := i32(0)
		C.vox_gl_int_parameter(webgl.renderbuffer_binding, &renderbuffer_handle)
		for index, pair in [
			['framebufferTexture2D(36160,36064,3553,attachmentTexture,0)', 'attachmentTexture'],
			['framebufferRenderbuffer(36160,36064,36161,attachmentRenderbuffer)',
				'attachmentRenderbuffer'],
		] {
			if index == 0 {
				C.vox_gl_framebuffer_texture(webgl.framebuffer, webgl.color_attachment0,
					webgl.texture_2d, u32(texture_handle), 0)
			} else {
				C.vox_gl_framebuffer_renderbuffer(webgl.framebuffer, webgl.color_attachment0,
					webgl.renderbuffer, u32(renderbuffer_handle))
			}
			expected := C.vox_gl_get_error()
			assert expected != webgl.no_error
			runtime.evaluate_host('attachmentOwner.${pair[0]};')!
			assert runtime.evaluate_host('attachmentOwner.getError()')! == expected.str()
			assert runtime.evaluate_host('attachmentOwner.getFramebufferAttachmentParameter(36160,36064,36049)===${pair[1]}')! == 'true'
		}
		// Generated IDL conversion completes before the source body selects GL.
		other.native.make_current()
		assert runtime.evaluate_host(r'(function(){const marker={};try{attachmentOwner.framebufferTexture2D(36160,36064,3553,null,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		public_attachment_source_owner([i32(9), 10, 11, 12]!)
	}
}
