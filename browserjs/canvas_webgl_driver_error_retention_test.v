// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_get_error_queries_actual_driver_flags_without_eager_consumption() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_error_source",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_error_other",width:2,height:2},"${kind}",null);globalThis.program=gl.createProgram();globalThis.foreignBuffer=other.createBuffer();')!
		mut context := host.contexts['__created_error_source'] or { panic('error context') }
		mut other := host.contexts['__created_error_other'] or { panic('other context') }
		program := host.programs.values()[0]
		context.native.make_current()
		if kind == 'webgl' {
			C.vox_gl_active_texture(0xbad)
			C.vox_gl_bind_attrib_location(program.object.native_name(), u32(-1), c'position')
		} else {
			C.vox_gl_bind_sampler(u32(-1), 0)
			C.vox_gl_bind_transform_feedback(0xbad, 0)
		}
		mut expected := []u32{}
		for _ in 0 .. 3 { expected << C.vox_gl_get_error() }
		assert expected.filter(it != 0).len == 2
		assert webgl.invalid_enum in expected && webgl.invalid_value in expected
		command := if kind == 'webgl' {
			'gl.activeTexture(0xbad);gl.bindAttribLocation(program,4294967295,"position");'
		} else {
			'gl.bindSampler(4294967295,null);gl.bindTransformFeedback(0xbad,null);'
		}
		other.native.make_current()
		runtime.evaluate_host(command)!
		assert runtime.evaluate_host('gl.getParameter(gl.ACTIVE_TEXTURE)===gl.TEXTURE0')! == 'true'
		runtime.evaluate_host('gl.createBuffer();')!
		assert runtime.evaluate_host('[gl.getError(),gl.getError(),gl.getError()].join(",")')! == expected.map(it.str()).join(',')
		assert other.get_error() == webgl.no_error
		other.native.make_current()
		runtime.evaluate_host(command)!
		runtime.evaluate_host('gl.bindBuffer(gl.ARRAY_BUFFER,foreignBuffer);gl.bufferData(gl.ARRAY_BUFFER,null,gl.STATIC_DRAW);')!
		context.native.set_pending_local_error(webgl.out_of_memory)
		assert runtime.evaluate_host('[gl.getError(),gl.getError(),gl.getError(),gl.getError(),gl.getError()].join(",")')! == '${webgl.out_of_memory},${expected[0]},${expected[1]},${webgl.invalid_operation},0'
		assert other.get_error() == webgl.no_error
	}
}
