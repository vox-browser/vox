// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_attachment_first_exposure_wraps_actual_retained_deleted_record() {
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
		key := '__created_attachment_record_${kind}'
		runtime.evaluate_host('globalThis.recordGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);')!
		mut context := host.contexts[key] or { panic('attachment record context') }
		framebuffer := context.create_framebuffer()
		mut texture := context.create_texture()
		texture.object.set_label('retained deleted texture')
		context.bind_framebuffer(webgl.framebuffer, framebuffer)
		context.bind_texture(webgl.texture_2d, texture)
		context.tex_image2d(webgl.texture_2d, 0, int(webgl.rgba), 1, 1, 0, webgl.rgba,
			webgl.unsigned_byte, [u8(1), 2, 3, 255])
		context.framebuffer_texture2d(webgl.framebuffer, webgl.color_attachment0,
			webgl.texture_2d, texture, 0)
		context.delete_texture(texture)
		assert voidptr(&texture.object) !in host.platform_objects
		assert runtime.evaluate_host(r'(function(){globalThis.retainedTexture=recordGL.getFramebufferAttachmentParameter(36160,36064,36049);return retainedTexture instanceof WebGLTexture&&retainedTexture===recordGL.getFramebufferAttachmentParameter(36160,36064,36049)&&recordGL.getFramebufferAttachmentParameter(36160,36064,36048)===recordGL.TEXTURE&&!recordGL.isTexture(retainedTexture)&&recordGL.getError()===recordGL.NO_ERROR})()')! == 'true'
		texture_wrapper := host.platform_objects[voidptr(&texture.object)] or { panic('texture wrapper') }
		registered_texture := host.textures[texture_wrapper] or { panic('registered texture') }
		assert registered_texture == texture
		assert registered_texture.object.label() == 'retained deleted texture'
		assert runtime.evaluate_host(r'(function(){recordGL.bindTexture(3553,retainedTexture);if(recordGL.getError()!==recordGL.INVALID_OPERATION)return false;recordGL.deleteTexture(retainedTexture);return recordGL.getFramebufferAttachmentParameter(36160,36064,36049)===retainedTexture&&recordGL.getError()===recordGL.NO_ERROR})()')! == 'true'
		mut renderbuffer := context.create_renderbuffer()
		renderbuffer.object.set_label('retained deleted renderbuffer')
		context.bind_renderbuffer(webgl.renderbuffer, renderbuffer)
		context.renderbuffer_storage(webgl.renderbuffer, 0x8056, 1, 1)
		context.framebuffer_renderbuffer(webgl.framebuffer, webgl.color_attachment0,
			webgl.renderbuffer, renderbuffer)
		context.delete_renderbuffer(renderbuffer)
		assert voidptr(&renderbuffer.object) !in host.platform_objects
		assert runtime.evaluate_host(r'(function(){globalThis.retainedRenderbuffer=recordGL.getFramebufferAttachmentParameter(36160,36064,36049);return retainedRenderbuffer instanceof WebGLRenderbuffer&&retainedRenderbuffer===recordGL.getFramebufferAttachmentParameter(36160,36064,36049)&&recordGL.getFramebufferAttachmentParameter(36160,36064,36048)===recordGL.RENDERBUFFER&&!recordGL.isRenderbuffer(retainedRenderbuffer)&&recordGL.getError()===recordGL.NO_ERROR})()')! == 'true'
		renderbuffer_wrapper := host.platform_objects[voidptr(&renderbuffer.object)] or { panic('renderbuffer wrapper') }
		registered_renderbuffer := host.renderbuffers[renderbuffer_wrapper] or { panic('registered renderbuffer') }
		assert registered_renderbuffer == renderbuffer
		assert registered_renderbuffer.object.label() == 'retained deleted renderbuffer'
		assert runtime.evaluate_host(r'(function(){recordGL.bindRenderbuffer(36161,retainedRenderbuffer);if(recordGL.getError()!==recordGL.INVALID_OPERATION)return false;recordGL.deleteRenderbuffer(retainedRenderbuffer);return recordGL.getFramebufferAttachmentParameter(36160,36064,36049)===retainedRenderbuffer&&recordGL.getError()===recordGL.NO_ERROR})()')! == 'true'
		assert runtime.evaluate_host(r'(function(){recordGL.framebufferRenderbuffer(36160,36064,36161,null);return recordGL.getFramebufferAttachmentParameter(36160,36064,36048)===recordGL.NONE&&recordGL.getError()===recordGL.NO_ERROR})()')! == 'true'
	}
}
