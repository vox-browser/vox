// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_attrib_location_preserves_source_program_gate_and_domstring_conversion() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_attrib_location",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_attrib_location_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.program=gl.createProgram();globalThis.foreign=other.createProgram();')!
		mut other := host.contexts['__created_attrib_location_other'] or { panic('attribute location other') }
		other.native.make_current()
		assert runtime.evaluate_host('(function(){let converted=0;const value=gl.getAttribLocation(foreign,{toString(){converted++;return "position"}});return converted===1&&value===-1})()')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.getAttribLocation(foreign,{toString(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		vertex_source := if kind == 'webgl' {
			'attribute vec2 position;void main(){gl_Position=vec4(position,0,1);}'
		} else {
			'#version 300 es\\nin vec2 position;void main(){gl_Position=vec4(position,0,1);}'
		}
		fragment_source := if kind == 'webgl' {
			'precision mediump float;void main(){gl_FragColor=vec4(1);}'
		} else {
			'#version 300 es\\nprecision mediump float;out vec4 color;void main(){color=vec4(1);}'
		}
		assert runtime.evaluate_host('const vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(vertex,"${vertex_source}");gl.shaderSource(fragment,"${fragment_source}");gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);gl.getProgramParameter(program,gl.LINK_STATUS)')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('gl.getAttribLocation(program,"position")>=0')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('gl.getAttribLocation(program,"position\\u0000ignored")===gl.getAttribLocation(program,"position")&&gl.getAttribLocation(program,"absent")===-1&&gl.getError()===gl.NO_ERROR')! == 'true'
		runtime.evaluate_host('gl.deleteProgram(program);')!
		other.native.make_current()
		assert runtime.evaluate_host('gl.getAttribLocation(program,"position")===-1')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
	}
}
