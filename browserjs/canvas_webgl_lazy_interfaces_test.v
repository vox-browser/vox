// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn lazy_webgl_runtime(mut host CanvasWebGLHost) &Runtime {
	mut runtime := Runtime.create()
	host.install(mut runtime) or { panic(err) }
	runtime.evaluate_host('const __canvases=Object.create(null);function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return s.element||(s.element={state:s});}') or { panic(err) }
	runtime.evaluate_host(webgl_bootstrap()) or { panic(err) }
	return runtime
}

fn test_webgl_interfaces_build_on_the_first_global_read_as_ordinary_data_properties() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := lazy_webgl_runtime(mut host)
	defer { runtime.close() }
	// Before any use both globals are configurable, non-enumerable accessors.
	assert runtime.evaluate_host(r'(function(){for(const name of ["WebGLRenderingContext","WebGL2RenderingContext"]){const d=Object.getOwnPropertyDescriptor(globalThis,name);if(typeof d.get!=="function"||d.enumerable||!d.configurable)return false;}return Object.keys(globalThis).indexOf("WebGLRenderingContext")<0;})()')! == 'true'
	// Reading one global builds both interfaces with their constants and methods.
	assert runtime.evaluate_host(r'(function(){const C=WebGLRenderingContext,d=Object.getOwnPropertyDescriptor(globalThis,"WebGLRenderingContext"),d2=Object.getOwnPropertyDescriptor(globalThis,"WebGL2RenderingContext");return typeof C==="function"&&C.name==="WebGLRenderingContext"&&d.value===C&&d.writable&&!d.enumerable&&d.configurable&&d2.value===WebGL2RenderingContext&&C.COLOR_BUFFER_BIT===16384&&C.prototype.COLOR_BUFFER_BIT===16384&&typeof C.prototype.clearColor==="function"&&C.prototype.clearColor.length===4&&WebGL2RenderingContext.prototype.READ_BUFFER===3074&&typeof WebGL2RenderingContext.prototype.copyBufferSubData==="function"&&C.prototype.copyBufferSubData===undefined&&Object.prototype.toString.call(C.prototype)==="[object WebGLRenderingContext]";})()')! == 'true'
}

fn test_webgl_interfaces_keep_author_replacement_and_deletion_made_before_the_first_context() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := lazy_webgl_runtime(mut host)
	defer { runtime.close() }
	runtime.evaluate_host(r'globalThis.WebGLRenderingContext=5;delete globalThis.WebGL2RenderingContext;globalThis.lazyContext=__webglContext({bridgeKey:"__created_lazy_author",width:2,height:2},"webgl2",null);')!
	assert runtime.evaluate_host(r'(function(){const d=Object.getOwnPropertyDescriptor(globalThis,"WebGLRenderingContext");return d.value===5&&d.writable&&!("WebGL2RenderingContext" in globalThis)&&typeof lazyContext.clearColor==="function"&&lazyContext.COLOR_BUFFER_BIT===16384&&Object.prototype.toString.call(lazyContext)==="[object WebGL2RenderingContext]";})()')! == 'true'
}

fn test_webgl_interfaces_built_after_page_scripts_use_bootstrap_intrinsics() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := lazy_webgl_runtime(mut host)
	defer { runtime.close() }
	// A page replaces builtins the interface builders relied on before it first
	// uses WebGL. Calls still use their ordinary runtime paths, so only build
	// the interfaces here: through the global and through the extension factory.
	runtime.evaluate_host(r'const fail=function(){throw new Error("author intrinsic")};Object.keys=fail;Object.assign=fail;Array.prototype.filter=fail;Array.prototype.map=fail;Array.prototype.every=fail;String.prototype.startsWith=fail;Math.min=fail;Array.prototype[Symbol.iterator]=fail;')!
	assert runtime.evaluate_host(r'(function(){const P=WebGLRenderingContext.prototype,P2=WebGL2RenderingContext.prototype,extension=__webglCreateExtension("OES_vertex_array_object",{bridgeKey:"__created_lazy_extension"},false);return P.clearColor.length===4&&P.clearColor.name==="clearColor"&&P.COLOR_BUFFER_BIT===16384&&WebGLRenderingContext.COLOR_BUFFER_BIT===16384&&P2.READ_BUFFER===3074&&typeof P2.copyBufferSubData==="function"&&typeof extension.createVertexArrayOES==="function"&&Object.prototype.toString.call(extension)==="[object OESVertexArrayObject]";})()')! == 'true'
}
