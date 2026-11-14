// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_vertex_array_binding_wraps_first_exposed_actual_record_and_reuses_existing_wrapper() {
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
	for kind in ['webgl2', 'webgl'] {
		key := '__created_vertex_array_record_${kind}'
		other_key := '__created_vertex_array_record_other_${kind}'
		runtime.evaluate_host('globalThis.arrayRecordGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.arrayRecordOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);arrayRecordGL.viewport(1,2,3,4);arrayRecordOther.viewport(9,10,11,12);globalThis.arrayRecordOES=${if kind == 'webgl' {
			'arrayRecordGL.getExtension("OES_vertex_array_object")'
		} else {
			'null'
		}};')!
		mut context := host.contexts[key] or { panic('VAO context') }
		mut other := host.contexts[other_key] or { panic('other VAO context') }
		create := if kind == 'webgl2' {
			'arrayRecordGL.createVertexArray()'
		} else {
			'arrayRecordOES.createVertexArrayOES()'
		}
		bind := if kind == 'webgl2' {
			'arrayRecordGL.bindVertexArray'
		} else {
			'arrayRecordOES.bindVertexArrayOES'
		}
		delete := if kind == 'webgl2' {
			'arrayRecordGL.deleteVertexArray'
		} else {
			'arrayRecordOES.deleteVertexArrayOES'
		}
		is_array := if kind == 'webgl2' {
			'arrayRecordGL.isVertexArray'
		} else {
			'arrayRecordOES.isVertexArrayOES'
		}
		pname := if kind == 'webgl2' {
			'arrayRecordGL.VERTEX_ARRAY_BINDING'
		} else {
			'arrayRecordOES.VERTEX_ARRAY_BINDING_OES'
		}
		brand := if kind == 'webgl2' {
			'exposedArray instanceof WebGLVertexArrayObject'
		} else {
			'Object.prototype.toString.call(exposedArray)==="[object WebGLVertexArrayObjectOES]"&&typeof WebGLVertexArrayObjectOES==="undefined"'
		}
		assert runtime.evaluate_host('globalThis.existingArray=${create};${bind}(existingArray);arrayRecordGL.getParameter(${pname})===existingArray')! == 'true'
		runtime.evaluate_host('${delete}(existingArray)')!
		mut object := unsafe { &webgl.WebGLObject(nil) }
		if kind == 'webgl2' {
			mut array := context.create_vertex_array()
			array.object.set_label('typed retained VAO')
			context.bind_vertex_array(array)
			object = &array.object
		} else {
			mut array := context.create_vertex_array_oes()
			array.object.set_label('typed retained VAO')
			context.bind_vertex_array_oes(array)
			object = &array.object
		}
		assert voidptr(object) !in host.platform_objects
		name := object.native_name()
		context.native.make_current()
		assert C.vox_gl_is_vertex_array(name, if kind == 'webgl' { 1 } else { 0 }) == 1
		C.vox_gl_delete_object(if kind == 'webgl' { 7 } else { 6 }, name)
		mut actual := i32(-1)
		C.vox_gl_int_parameter(webgl.vertex_array_binding, &actual)
		assert actual == 0
		other.native.make_current()
		assert runtime.evaluate_host('globalThis.exposedArray=arrayRecordGL.getParameter(${pname});${brand}&&exposedArray===arrayRecordGL.getParameter(${pname})&&${is_array}(exposedArray)===false&&arrayRecordGL.getError()===arrayRecordGL.NO_ERROR')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		wrapper := host.platform_objects[voidptr(object)] or { panic('first exposed VAO') }
		if kind == 'webgl2' {
			registered := host.vertex_arrays[wrapper] or { panic('registered actual VAO') }
			assert &registered.object == object
		} else {
			registered := host.vertex_arrays_oes[wrapper] or { panic('registered actual OES VAO') }
			assert &registered.object == object
		}
		assert object.label() == 'typed retained VAO'
		assert runtime.evaluate_host('${delete}(exposedArray);arrayRecordGL.getParameter(${pname})===null')! == 'true'
		assert object.invalidated()
		assert runtime.evaluate_host('${bind}(exposedArray);arrayRecordGL.getError()===${if kind == 'webgl2' {
			'arrayRecordGL.INVALID_OPERATION'
		} else {
			'arrayRecordGL.NO_ERROR'
		}}')! == 'true'
	}
}
