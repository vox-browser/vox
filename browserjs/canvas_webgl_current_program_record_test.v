// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_current_program_first_exposure_wraps_actual_typed_source_record() {
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
		key := '__created_program_record_${kind}'
		other_key := '__created_program_record_other_${kind}'
		runtime.evaluate_host('globalThis.programRecordGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.programRecordOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);programRecordGL.viewport(1,2,3,4);programRecordOther.viewport(9,10,11,12);')!
		mut context := host.contexts[key] or { panic('program record context') }
		mut other := host.contexts[other_key] or { panic('other program record context') }
		mut program := context.create_program()
		program.object.set_label('typed retained program')
		context.use_program(program)
		assert context.get_error() == webgl.invalid_operation
		mut native_program := i32(-1)
		C.vox_gl_int_parameter(webgl.current_program, &native_program)
		assert native_program == 0
		assert voidptr(&program.object) !in host.platform_objects
		other.native.make_current()
		assert runtime.evaluate_host(r'globalThis.exposedProgram=programRecordGL.getParameter(programRecordGL.CURRENT_PROGRAM);exposedProgram instanceof WebGLProgram&&exposedProgram===programRecordGL.getParameter(programRecordGL.CURRENT_PROGRAM)')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		wrapper := host.platform_objects[voidptr(&program.object)] or { panic('program wrapper') }
		registered := host.programs[wrapper] or { panic('registered typed program') }
		assert registered == program
		assert registered.object.label() == 'typed retained program'
		assert runtime.evaluate_host(r'programRecordGL.getAttachedShaders(exposedProgram).length===0&&programRecordGL.getError()===programRecordGL.NO_ERROR')! == 'true'
		assert runtime.evaluate_host(r'(function(){programRecordGL.deleteProgram(exposedProgram);if(programRecordGL.getParameter(programRecordGL.CURRENT_PROGRAM)!==null)return false;programRecordGL.useProgram(exposedProgram);return programRecordGL.getError()===programRecordGL.INVALID_OPERATION})()')! == 'true'
	}
}
