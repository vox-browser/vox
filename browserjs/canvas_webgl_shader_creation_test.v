// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

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
