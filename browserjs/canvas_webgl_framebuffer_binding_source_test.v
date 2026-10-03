// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_actual_framebuffer_renderbuffer_source_binds_keep_owned_records_after_driver_errors() {
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
	result := runtime.evaluate_host(r'
 (function(){for(const kind of ["webgl","webgl2"]){const gl=__webglContext({bridgeKey:"__created_fb_source_"+kind,width:2,height:2},kind,null),foreign=__webglContext({bridgeKey:"__created_fb_foreign_"+kind,width:2,height:2},kind,null),f=gl.createFramebuffer(),r=gl.createRenderbuffer();
 gl.bindFramebuffer(0xbad,f);if(gl.getError()!==gl.INVALID_ENUM||gl.getParameter(gl.FRAMEBUFFER_BINDING)!==f)return "framebuffer retained";
 gl.bindRenderbuffer(0xbad,r);if(gl.getError()!==gl.INVALID_ENUM||gl.getParameter(gl.RENDERBUFFER_BINDING)!==r)return "renderbuffer retained";
 gl.bindFramebuffer(0xbad,foreign.createFramebuffer());if(gl.getError()!==gl.INVALID_OPERATION||gl.getParameter(gl.FRAMEBUFFER_BINDING)!==f)return "foreign framebuffer";
 gl.bindRenderbuffer(0xbad,foreign.createRenderbuffer());if(gl.getError()!==gl.INVALID_OPERATION||gl.getParameter(gl.RENDERBUFFER_BINDING)!==r)return "foreign renderbuffer";
 gl.bindFramebuffer(0xbad,null);if(gl.getError()!==gl.INVALID_ENUM||gl.getParameter(gl.FRAMEBUFFER_BINDING)!==null)return "clear framebuffer";
 gl.bindRenderbuffer(0xbad,null);if(gl.getError()!==gl.INVALID_ENUM||gl.getParameter(gl.RENDERBUFFER_BINDING)!==null)return "clear renderbuffer";
 gl.bindFramebuffer(0xbad,f);gl.getError();gl.deleteFramebuffer(f);if(gl.getParameter(gl.FRAMEBUFFER_BINDING)!==null||gl.getError()!==gl.NO_ERROR)return "delete framebuffer";
 }return true})()
 ')!
	assert result == 'true'
	// First exposure of a typed source slot creates one real branded wrapper.
	mut context := host.contexts['__created_fb_source_webgl2'] or { panic('source framebuffer context') }
	framebuffer := context.create_framebuffer()
	context.bind_framebuffer(webgl.framebuffer, framebuffer)
	assert runtime.evaluate_host(r'(function(){const gl=__webglContext({bridgeKey:"__created_fb_source_webgl2",width:2,height:2},"webgl2",null),first=gl.getParameter(gl.FRAMEBUFFER_BINDING),second=gl.getParameter(gl.FRAMEBUFFER_BINDING);if(!(first instanceof WebGLFramebuffer)||first!==second)return false;gl.deleteFramebuffer(first);return gl.getParameter(gl.FRAMEBUFFER_BINDING)===null&&gl.getError()===gl.NO_ERROR})()')! == 'true'
}
