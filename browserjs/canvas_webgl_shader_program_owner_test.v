// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_shader_program_mutations_select_source_owner_and_native_error_order() {
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
		key := '__created_shader_owner_${kind}'
		other_key := '__created_shader_other_${kind}'
		runtime.evaluate_host('globalThis.shaderOwner=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.shaderOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);shaderOwner.viewport(1,2,3,4);shaderOther.viewport(9,10,11,12);globalThis.ownedShader=shaderOwner.createShader(shaderOwner.VERTEX_SHADER);globalThis.ownedProgram=shaderOwner.createProgram();globalThis.foreignShader=shaderOther.createShader(shaderOther.VERTEX_SHADER);globalThis.foreignProgram=shaderOther.createProgram();')!
		mut context := host.contexts[key] or { panic('shader owner context') }
		mut other := host.contexts[other_key] or { panic('other shader context') }
		calls := ['shaderOwner.createShader(0xbad);',
			'shaderOwner.shaderSource(foreignShader,"void main(){}");',
			'shaderOwner.compileShader(foreignShader);', 'shaderOwner.linkProgram(foreignProgram);',
			'shaderOwner.validateProgram(foreignProgram);',
			'shaderOwner.attachShader(ownedProgram,foreignShader);',
			'shaderOwner.bindAttribLocation(foreignProgram,0xffffffff,"gl_reserved");',
			'shaderOwner.deleteShader(foreignShader);', 'shaderOwner.deleteProgram(foreignProgram);',
			'shaderOwner.deleteShader(null);', 'shaderOwner.deleteProgram(null);']
		expected := ['1280', '1282', '1282', '1282', '1282', '1282', '1282', '1282', '1282', '0',
			'0']
		for index, call in calls {
			other.native.make_current()
			runtime.evaluate_host(call)!
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(0x0ba2, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert runtime.evaluate_host('shaderOwner.getError()')! == expected[index]
		}
		context.native.make_current()
		native_program := C.vox_gl_create_program()
		name := 'gl_reserved'
		C.vox_gl_bind_attrib_location(native_program, 0xffffffff, name.str)
		expected_binding_error := C.vox_gl_get_error()
		C.vox_gl_delete_program(native_program)
		other.native.make_current()
		runtime.evaluate_host('shaderOwner.bindAttribLocation(ownedProgram,0xffffffff,"gl_reserved");')!
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('shaderOwner.getError()')! == expected_binding_error.str()
		other.native.make_current()
		runtime.evaluate_host('shaderOwner.attachShader(ownedProgram,ownedShader);')!
		assert runtime.evaluate_host('shaderOwner.getError()')! == '0'
		other.native.make_current()
		runtime.evaluate_host('shaderOwner.attachShader(ownedProgram,ownedShader);')!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('shaderOwner.getError()')! == '1282'
	}
}
