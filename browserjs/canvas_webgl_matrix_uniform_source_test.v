// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn public_matrix_source_query(program u32, location int, size int) []f32 {
	mut values := []f32{len: size}
	C.vox_gl_get_uniform_floats(program, location, values.data)
	return values
}

fn public_matrix_source_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_public_source_matrix_uniforms_preserve_transpose_native_values_and_source_order() {
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
	runtime.evaluate_host(r'function __matrixSourceProgram(gl,type,expression){const two=gl instanceof WebGL2RenderingContext,prefix=two?"#version 300 es\n":"",vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(vertex,prefix+"void main(){gl_Position=vec4(0,0,0,1);}");gl.shaderSource(fragment,prefix+"precision mediump float;uniform "+type+" data;"+(two?"out vec4 color;":"")+"void main(){"+(two?"color":"gl_FragColor")+"="+expression+";}");gl.compileShader(vertex);gl.compileShader(fragment);const program=gl.createProgram();gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw gl.getProgramInfoLog(program);return {program,location:gl.getUniformLocation(program,"data")};}')!
	methods := ['uniformMatrix2fv', 'uniformMatrix3fv', 'uniformMatrix4fv', 'uniformMatrix3x2fv',
		'uniformMatrix4x2fv', 'uniformMatrix2x3fv', 'uniformMatrix4x3fv', 'uniformMatrix2x4fv',
		'uniformMatrix3x4fv']
	columns := [2, 3, 4, 3, 4, 2, 4, 2, 3]
	rows := [2, 3, 4, 2, 2, 3, 3, 4, 4]
	for kind in ['webgl', 'webgl2'] {
		key := '__created_matrix_source_${kind}'
		other_key := '__created_matrix_other_${kind}'
		runtime.evaluate_host('globalThis.matrixOwner=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.matrixOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);matrixOwner.viewport(1,2,3,4);matrixOther.viewport(9,10,11,12);')!
		mut context := host.contexts[key] or { panic('matrix owner context') }
		mut other := host.contexts[other_key] or { panic('other matrix context') }
		for index, method in methods {
			if kind == 'webgl' && index >= 3 { continue }
			column_count, row_count := columns[index], rows[index]
			size := column_count * row_count
			type_ := if column_count == row_count {
				'mat${column_count}'
			} else {
				'mat${column_count}x${row_count}'
			}
			padding := if row_count == 2 {
				',0.0,0.0'
			} else if row_count == 3 {
				',0.0'
			} else {
				''
			}
			mut terms := []string{}
			for column in 0 .. column_count { terms << 'vec4(data[${column}]${padding})' }
			runtime.evaluate_host('globalThis.matrixOwned=__matrixSourceProgram(matrixOwner,"${type_}","${terms.join('+')}");globalThis.matrixForeign=__matrixSourceProgram(matrixOther,"${type_}","${terms.join('+')}");matrixOwner.useProgram(matrixOwned.program);globalThis.matrixValues=new Float32Array(${size});for(let i=0;i<matrixValues.length;i++)matrixValues[i]=i+1;')!
			context.native.make_current()
			mut native_program := i32(0)
			C.vox_gl_int_parameter(0x8b8d, &native_program)
			name := 'data'
			native_location := C.vox_gl_uniform_location(u32(native_program), name.str)
			values := []f32{len: size, init: f32(index + 1)}
			zero := []f32{len: size}
			offset := if kind == 'webgl2' { ',99,0' } else { '' }
			other.native.make_current()
			runtime.evaluate_host('matrixOwner.${method}(null,true,new Float32Array(${size + 1})${offset});')!
			public_matrix_source_owner()
			assert runtime.evaluate_host('matrixOwner.getError()')! == '0'
			other.native.make_current()
			runtime.evaluate_host('matrixOwner.${method}(matrixForeign.location,true,new Float32Array(${size + 1})${offset});')!
			public_matrix_source_owner()
			assert runtime.evaluate_host('matrixOwner.getError()')! == '1282'
			other.native.make_current()
			runtime.evaluate_host('matrixOwner.${method}(matrixOwned.location,true,new Float32Array(${size + 1}));')!
			public_matrix_source_owner()
			assert runtime.evaluate_host('matrixOwner.getError()')! == '1281'
			runtime.evaluate_host('matrixOwner.${method}(matrixOwned.location,false,matrixValues);')!
			assert runtime.evaluate_host('matrixOwner.getError()')! == '0'
			assert public_matrix_source_query(u32(native_program), native_location, size) == values
			C.vox_gl_uniform_matrix(native_location, column_count, row_count, 1, 0, zero.data)
			C.vox_gl_uniform_matrix(native_location, column_count, row_count, 1, 1, values.data)
			expected_error := C.vox_gl_get_error()
			expected_values := public_matrix_source_query(u32(native_program), native_location, size)
			C.vox_gl_uniform_matrix(native_location, column_count, row_count, 1, 0, zero.data)
			assert public_matrix_source_query(u32(native_program), native_location, size) == zero
			other.native.make_current()
			runtime.evaluate_host('matrixOwner.${method}(matrixOwned.location,true,matrixValues);')!
			public_matrix_source_owner()
			assert runtime.evaluate_host('matrixOwner.getError()')! == expected_error.str()
			assert public_matrix_source_query(u32(native_program), native_location, size) == expected_values
			C.vox_gl_use_program(0)
			C.vox_gl_uniform_matrix(native_location, column_count, row_count, 1, 1, values.data)
			expected_unbound_error := C.vox_gl_get_error()
			other.native.make_current()
			runtime.evaluate_host('matrixOwner.${method}(matrixOwned.location,true,matrixValues);')!
			public_matrix_source_owner()
			assert runtime.evaluate_host('matrixOwner.getError()')! == expected_unbound_error.str()
		}
	}
}
