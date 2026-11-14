// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn public_vector_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_public_source_vector_uniform_owner_precedes_null_parent_span_and_size_returns() {
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
	runtime.evaluate_host(r'function __vectorSourceProgram(gl){const two=gl instanceof WebGL2RenderingContext,prefix=two?"#version 300 es\n":"",vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(vertex,prefix+"void main(){gl_Position=vec4(0,0,0,1);}");gl.shaderSource(fragment,prefix+"precision mediump float;uniform vec4 tint;"+(two?"out vec4 color;void main(){color=tint;}":"void main(){gl_FragColor=tint;}"));gl.compileShader(vertex);gl.compileShader(fragment);const program=gl.createProgram();gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);return {program,location:gl.getUniformLocation(program,"tint")};}')!
	methods := ['uniform1fv', 'uniform2fv', 'uniform3fv', 'uniform4fv', 'uniform1iv', 'uniform2iv',
		'uniform3iv', 'uniform4iv', 'uniform1uiv', 'uniform2uiv', 'uniform3uiv', 'uniform4uiv']
	for kind in ['webgl', 'webgl2'] {
		key := '__created_vector_owner_${kind}'
		other_key := '__created_vector_other_${kind}'
		runtime.evaluate_host('globalThis.vectorOwner=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.vectorOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);globalThis.vectorOwned=__vectorSourceProgram(vectorOwner);globalThis.vectorForeign=__vectorSourceProgram(vectorOther);vectorOwner.useProgram(vectorOwned.program);vectorOwner.viewport(1,2,3,4);vectorOther.viewport(9,10,11,12);')!
		mut other := host.contexts[other_key] or { panic('other vector context') }
		for index, method in methods {
			if kind == 'webgl' && index >= 8 { continue }
			width := index % 4 + 1
			constructor := if index < 4 {
				'Float32Array'
			} else if index < 8 {
				'Int32Array'
			} else {
				'Uint32Array'
			}
			offset := if kind == 'webgl2' { ',99,0' } else { '' }
			other.native.make_current()
			runtime.evaluate_host('vectorOwner.${method}(null,new ${constructor}(${width + 1})${offset});')!
			public_vector_owner()
			assert runtime.evaluate_host('vectorOwner.getError()')! == '0'
			other.native.make_current()
			runtime.evaluate_host('vectorOwner.${method}(vectorForeign.location,new ${constructor}(${width + 1})${offset});')!
			public_vector_owner()
			assert runtime.evaluate_host('vectorOwner.getError()')! == '1282'
			if kind == 'webgl2' {
				other.native.make_current()
				runtime.evaluate_host('vectorOwner.${method}(vectorOwned.location,new ${constructor}(${width + 1})${offset});')!
				public_vector_owner()
				assert runtime.evaluate_host('vectorOwner.getError()')! == '1281'
			}
			if width > 1 {
				other.native.make_current()
				runtime.evaluate_host('vectorOwner.${method}(vectorOwned.location,new ${constructor}(${width + 1}));')!
				public_vector_owner()
				assert runtime.evaluate_host('vectorOwner.getError()')! == '1281'
			}
		}
		// List element conversion is an IDL step before the source body selects GL.
		other.native.make_current()
		converted := runtime.evaluate_host(r'(function(){const marker={},order=[];try{vectorOwner.uniform4fv(null,[{valueOf(){order.push("item");throw marker}}]);return false}catch(error){return error===marker&&order.join(",")==="item"}})()')!
		assert converted == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
	}
}
