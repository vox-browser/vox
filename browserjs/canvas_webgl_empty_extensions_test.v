// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_native_empty_webgl_extensions_are_plain_cached_objects() {
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
	assert runtime.evaluate_host(r'(function(){let enabled=0;for(const kind of ["webgl","webgl2"]){const a=__webglContext({bridgeKey:"__created_empty_a_"+kind,width:2,height:2},kind),b=__webglContext({bridgeKey:"__created_empty_b_"+kind,width:2,height:2},kind);for(const name of ["OES_texture_float_linear","EXT_float_blend"]){const extension=a.getExtension(name);if(!a.getSupportedExtensions().includes(name)){if(extension!==null)return false;continue}enabled++;if(extension===null||Object.getPrototypeOf(extension)!==Object.prototype||Reflect.ownKeys(extension).length!==0||Object.prototype.toString.call(extension)!=="[object Object]"||a.getExtension(name.toUpperCase())!==extension||b.getExtension(name)===extension)return false;extension.author=5;if(a.getExtension(name).author!==5)return false}if(a.getExtension("OES_texture_float_linear\u00e9")!==null||a.getError()!==a.NO_ERROR||b.getError()!==b.NO_ERROR)return false}return enabled>0})()')! == 'true'
}
