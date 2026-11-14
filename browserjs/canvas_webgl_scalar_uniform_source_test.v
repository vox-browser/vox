// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn public_scalar_uniform_source_driver(index int, zero bool) {
	floats := if zero { [f32(0), 0, 0, 0]! } else { [f32(0.25), 0.5, 0.75, 1]! }
	ints := if zero { [i32(0), 0, 0, 0]! } else { [i32(1), 2, 3, 4]! }
	uints := if zero {
		[u32(0), 0, 0, 0]!
	} else {
		[u32(0xffffffff), 0x80000000, 0x10000001, 0x7fffffff]!
	}
	match index {
		0 { C.vox_gl_uniform1f(0, floats[0]) }
		1 { C.vox_gl_uniform2f(0, floats[0], floats[1]) }
		2 { C.vox_gl_uniform3f(0, floats[0], floats[1], floats[2]) }
		3 { C.vox_gl_uniform4f(0, floats[0], floats[1], floats[2], floats[3]) }
		4 { C.vox_gl_uniform1i(0, ints[0]) }
		5 { C.vox_gl_uniform2i(0, ints[0], ints[1]) }
		6 { C.vox_gl_uniform3i(0, ints[0], ints[1], ints[2]) }
		7 { C.vox_gl_uniform4i(0, ints[0], ints[1], ints[2], ints[3]) }
		8 { C.vox_gl_uniform1ui(0, uints[0]) }
		9 { C.vox_gl_uniform2ui(0, uints[0], uints[1]) }
		10 { C.vox_gl_uniform3ui(0, uints[0], uints[1], uints[2]) }
		11 { C.vox_gl_uniform4ui(0, uints[0], uints[1], uints[2], uints[3]) }
		else { panic('scalar operation') }
	}
}

fn public_scalar_uniform_source_query(program u32, width int) []f32 {
	mut values := [f32(0), 0, 0, 0]!
	C.vox_gl_get_uniform_floats(program, 0, &values[0])
	return values[..width].clone()
}

fn public_scalar_uniform_source_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_public_source_scalar_uniforms_preserve_nullable_zero_owner_and_idl_order() {
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
	runtime.evaluate_host(r'function __scalarSourceProgram(gl,type,expression){const two=gl instanceof WebGL2RenderingContext,prefix=two?"#version 300 es\n":"",vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(vertex,prefix+"void main(){gl_Position=vec4(0,0,0,1);}");gl.shaderSource(fragment,prefix+"precision mediump float;uniform "+type+" value;"+(two?"out vec4 color;":"")+"void main(){"+(two?"color":"gl_FragColor")+"="+expression+";}");gl.compileShader(vertex);gl.compileShader(fragment);const program=gl.createProgram();gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw gl.getProgramInfoLog(program);return {program,location:gl.getUniformLocation(program,"value")};}')!
	types := ['float', 'vec2', 'vec3', 'vec4', 'int', 'ivec2', 'ivec3', 'ivec4', 'uint', 'uvec2',
		'uvec3', 'uvec4']
	expressions := ['vec4(value)', 'vec4(value,0.0,1.0)', 'vec4(value,1.0)', 'value',
		'vec4(float(value))', 'vec4(vec2(value),0.0,1.0)', 'vec4(vec3(value),1.0)', 'vec4(value)',
		'vec4(float(value))', 'vec4(vec2(value),0.0,1.0)', 'vec4(vec3(value),1.0)', 'vec4(value)']
	methods := ['uniform1f', 'uniform2f', 'uniform3f', 'uniform4f', 'uniform1i', 'uniform2i',
		'uniform3i', 'uniform4i', 'uniform1ui', 'uniform2ui', 'uniform3ui', 'uniform4ui']
	for kind in ['webgl', 'webgl2'] {
		key := '__created_scalar_source_${kind}'
		other_key := '__created_scalar_other_${kind}'
		runtime.evaluate_host('globalThis.scalarOwner=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.scalarOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);scalarOwner.viewport(1,2,3,4);scalarOther.viewport(9,10,11,12);')!
		mut context := host.contexts[key] or { panic('scalar owner context') }
		mut other := host.contexts[other_key] or { panic('other scalar context') }
		for index, method in methods {
			if kind == 'webgl' && index >= 8 { continue }
			width := index % 4 + 1
			values := if index < 4 {
				['0.25', '0.5', '0.75', '1']
			} else if index < 8 {
				['1', '2', '3', '4']
			} else {
				['4294967295', '2147483648', '268435457', '2147483647']
			}
			args := values[..width].join(',')
			runtime.evaluate_host('globalThis.scalarOwned=__scalarSourceProgram(scalarOwner,"${types[index]}","${expressions[index]}");globalThis.scalarForeign=__scalarSourceProgram(scalarOther,"${types[index]}","${expressions[index]}");scalarOwner.useProgram(scalarOwned.program);')!
			context.native.make_current()
			mut native_program := i32(0)
			C.vox_gl_int_parameter(0x8b8d, &native_program)
			name := 'value'
			native_location := C.vox_gl_uniform_location(u32(native_program), name.str)
			assert native_location == 0
			public_scalar_uniform_source_driver(index, false)
			expected_error := C.vox_gl_get_error()
			expected_values := public_scalar_uniform_source_query(u32(native_program), width)
			public_scalar_uniform_source_driver(index, true)
			assert public_scalar_uniform_source_query(u32(native_program), width) == []f32{len: width}
			other.native.make_current()
			runtime.evaluate_host('scalarOwner.${method}(null,${args});')!
			public_scalar_uniform_source_owner()
			assert runtime.evaluate_host('scalarOwner.getError()')! == expected_error.str()
			assert public_scalar_uniform_source_query(u32(native_program), width) == expected_values
			if index >= 8 {
				mut actual_uints := [u32(0), 0, 0, 0]!
				C.vox_gl_get_uniform_uints(u32(native_program), 0, &actual_uints[0])
				expected_uints := [u32(0xffffffff), 0x80000000, 0x10000001, 0x7fffffff]!
				assert actual_uints[..width] == expected_uints[..width]
			}
			other.native.make_current()
			runtime.evaluate_host('scalarOwner.${method}(scalarForeign.location,${args});')!
			public_scalar_uniform_source_owner()
			assert runtime.evaluate_host('scalarOwner.getError()')! == '1282'
			runtime.evaluate_host('scalarOwner.useProgram(null);')!
			public_scalar_uniform_source_driver(index, false)
			expected_unbound_error := C.vox_gl_get_error()
			other.native.make_current()
			runtime.evaluate_host('scalarOwner.${method}(null,${args});')!
			public_scalar_uniform_source_owner()
			assert runtime.evaluate_host('scalarOwner.getError()')! == expected_unbound_error.str()
		}
		other.native.make_current()
		wrong_brand := runtime.evaluate_host(r'(function(){let converted=0;try{scalarOwner.uniform1f({}, {valueOf(){converted++;return 1}});return false}catch(error){return error instanceof TypeError&&converted===0}})()')!
		assert wrong_brand == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		converted := runtime.evaluate_host(r'(function(){const order=[];scalarOwner.uniform4f(scalarForeign.location,...[1,2,3,4].map((value,index)=>({valueOf(){order.push(index);return value}})));return order.join(",")==="0,1,2,3"})()')!
		assert converted == 'true'
		public_scalar_uniform_source_owner()
		assert runtime.evaluate_host('scalarOwner.getError()')! == '1282'
	}
}
