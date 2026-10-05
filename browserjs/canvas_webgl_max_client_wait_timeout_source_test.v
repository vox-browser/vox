// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_max_client_wait_timeout_preserves_source_zero_and_conversion_order() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_timeout_${kind}",width:2,height:2},"${kind}",null)')!
		if kind == 'webgl2' {
			assert runtime.evaluate_host('(function(){let calls=0;const value=gl.getParameter({valueOf(){calls++;return gl.MAX_CLIENT_WAIT_TIMEOUT_WEBGL}});return calls===1&&typeof value==="number"&&value===0&&gl.getError()===gl.NO_ERROR})()')! == 'true'
		} else {
			assert runtime.evaluate_host('gl.getParameter(0x9247)===null&&gl.getError()===gl.INVALID_ENUM')! == 'true'
		}
		assert runtime.evaluate_host('(function(){try{gl.getParameter(Symbol());return false}catch(error){return error instanceof TypeError&&gl.getError()===gl.NO_ERROR}})()')! == 'true'
	}
}
