// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_source_wholly_fixme_webgl_operations_do_not_gain_fabricated_method_properties() {
	$if !darwin { return }
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	runtime.evaluate_host('const __canvases=Object.create(null);function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	result := runtime.evaluate_host(r'(function(){const gl=__webglContext({bridgeKey:"__created_fixme_properties",width:2,height:2},"webgl2");for(const name of ["copyTexSubImage3D","getFragDataLocation","isQuery","isSampler","getSamplerParameter","isSync","isTransformFeedback","getTransformFeedbackVarying","getIndexedParameter"])if(name in gl||gl[name]!==undefined||Object.getOwnPropertyDescriptor(WebGL2RenderingContext.prototype,name)!==undefined)return false;for(const name of ["texImage2D","texSubImage2D","compressedTexImage2D","compressedTexSubImage2D","texImage3D","texSubImage3D","compressedTexImage3D","compressedTexSubImage3D","readPixels"])if(typeof gl[name]!=="function"||!Number.isFinite(gl[name].length))return false;return gl.getError()===gl.NO_ERROR})()')!
	assert result == 'true'
}
