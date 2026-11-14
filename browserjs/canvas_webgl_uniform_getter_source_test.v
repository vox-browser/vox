// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_source_get_uniform_preserves_upstream_zero_body_and_idl_conversion() {
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
	runtime.evaluate_host(r'function __sourceUniformProgram(gl){const two=gl instanceof WebGL2RenderingContext,prefix=two?"#version 300 es\n":"",vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(vertex,prefix+"void main(){gl_Position=vec4(0,0,0,1);}");gl.shaderSource(fragment,prefix+"precision mediump float;uniform vec4 tint;"+(two?"out vec4 color;void main(){color=tint;}":"void main(){gl_FragColor=tint;}"));gl.compileShader(vertex);gl.compileShader(fragment);const program=gl.createProgram();gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);return {program,location:gl.getUniformLocation(program,"tint")};}')!
	for kind in ['webgl', 'webgl2'] {
		key := '__created_uniform_zero_${kind}'
		other_key := '__created_uniform_other_${kind}'
		runtime.evaluate_host('globalThis.uniformOwner=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.uniformOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);globalThis.uniformOwned=__sourceUniformProgram(uniformOwner);globalThis.uniformForeign=__sourceUniformProgram(uniformOther);uniformOwner.useProgram(uniformOwned.program);uniformOwner.uniform4f(uniformOwned.location,1,0.5,0.25,1);')!
		mut context := host.contexts[key] or { panic('uniform owner context') }
		mut other := host.contexts[other_key] or { panic('other uniform context') }
		context.native.make_current()
		mut native_program := i32(0)
		C.vox_gl_int_parameter(0x8b8d, &native_program)
		name := 'tint'
		native_location := C.vox_gl_uniform_location(u32(native_program), name.str)
		mut actual_uniform := [f32(0), 0, 0, 0]!
		C.vox_gl_get_uniform_floats(u32(native_program), native_location, &actual_uniform[0])
		assert actual_uniform == [f32(1), 0.5, 0.25, 1]!
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		actual := runtime.evaluate_host(r'[uniformOwner.getUniform(uniformOwned.program,uniformOwned.location),uniformOwner.getUniform(uniformForeign.program,uniformOwned.location),uniformOwner.getUniform(uniformOwned.program,uniformForeign.location)].every(value=>typeof value==="number"&&Object.is(value,0));')!
		assert actual == 'true'
		converted := runtime.evaluate_host(r'(function(){let converted=0;for(const args of [[uniformOwned.program],[null,uniformOwned.location],[uniformOwned.program,null],[Object.create(WebGLProgram.prototype),uniformOwned.location],[uniformOwned.program,{valueOf(){converted++;return 0}}]]){try{uniformOwner.getUniform(...args);return false}catch(error){if(!(error instanceof TypeError))return false}}return converted===0})()')!
		assert converted == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		C.vox_gl_enable(0xbad)
		pending_value := runtime.evaluate_host('uniformOwner.getUniform(uniformOwned.program,uniformOwned.location)')!
		pending_error := C.vox_gl_get_error()
		assert pending_value == '0'
		assert pending_error == 0x0500
		runtime.evaluate_host('uniformOwner.deleteProgram(uniformOwned.program);')!
		other.native.make_current()
		deleted_value := runtime.evaluate_host('uniformOwner.getUniform(uniformOwned.program,uniformOwned.location)')!
		assert deleted_value == '0'
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('uniformOwner.getError()')! == '0'
	}
}
