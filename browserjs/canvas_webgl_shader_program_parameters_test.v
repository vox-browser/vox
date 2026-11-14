// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html


fn test_actual_shader_program_parameters_use_driver_deletion_status_and_source_errors() {
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
	initial := runtime.evaluate_host(r'
 const gl=__webglContext({bridgeKey:"__created_driver_status",width:2,height:2},"webgl",null),vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER),program=gl.createProgram();
 gl.shaderSource(vertex,"void main(){gl_Position=vec4(0);}");gl.shaderSource(fragment,"precision mediump float;void main(){gl_FragColor=vec4(1);}");gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);gl.useProgram(program);
 gl.getShaderParameter(vertex,gl.COMPILE_STATUS)===true&&gl.getProgramParameter(program,gl.LINK_STATUS)===true&&gl.getShaderParameter(vertex,gl.DELETE_STATUS)===false&&gl.getShaderParameter(fragment,gl.DELETE_STATUS)===false&&gl.getProgramParameter(program,gl.DELETE_STATUS)===false&&gl.getError()===gl.NO_ERROR;
 ')!
	assert initial == 'true'
	mut context := host.contexts['__created_driver_status'] or { panic('native status context') }
	context.native.make_current()
	mut native_program := i32(0)
	C.vox_gl_int_parameter(0x8b8d, &native_program)
	mut count := 0
	mut shaders := [u32(0), 0]!
	C.vox_gl_attached_shaders(u32(native_program), 2, &count, &shaders[0])
	assert count == 2
	C.vox_gl_delete_shader(shaders[0])
	C.vox_gl_delete_program(u32(native_program))
	actual := runtime.evaluate_host(r'const flags=[gl.getShaderParameter(vertex,gl.DELETE_STATUS),gl.getShaderParameter(fragment,gl.DELETE_STATUS)];flags.every(flag=>typeof flag==="boolean")&&flags.filter(Boolean).length===1&&gl.getProgramParameter(program,gl.DELETE_STATUS)===true&&gl.getError()===gl.NO_ERROR')!
	assert actual == 'true'
	errors := runtime.evaluate_host(r'
 const shaderInvalid=gl.getShaderParameter(vertex,0xbad),shaderErrors=[gl.getError(),gl.getError(),gl.getError()],programInvalid=gl.getProgramParameter(program,0xbad),programErrors=[gl.getError(),gl.getError(),gl.getError()];
 shaderInvalid===null&&programInvalid===null&&shaderErrors.join(",")===[gl.INVALID_ENUM,gl.INVALID_ENUM,gl.NO_ERROR].join(",")&&programErrors.join(",")===[gl.INVALID_ENUM,gl.INVALID_ENUM,gl.NO_ERROR].join(",");
 ')!
	assert errors == 'true'
}
