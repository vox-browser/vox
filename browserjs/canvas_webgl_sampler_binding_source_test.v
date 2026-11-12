// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn public_sampler_binding_source_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_public_sampler_bind_delete_body_order_and_fresh_native_query_records() {
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
	runtime.evaluate_host('globalThis.samplerSourceGL=__webglContext({bridgeKey:"__created_sampler_binding_source",width:2,height:2},"webgl2",null);globalThis.samplerSourceOther=__webglContext({bridgeKey:"__created_sampler_binding_other",width:2,height:2},"webgl2",null);globalThis.ownedSampler=samplerSourceGL.createSampler(),foreignSampler=samplerSourceOther.createSampler();samplerSourceGL.viewport(1,2,3,4);samplerSourceOther.viewport(9,10,11,12);')!
	mut context := host.contexts['__created_sampler_binding_source'] or { panic('sampler context') }
	mut other := host.contexts['__created_sampler_binding_other'] or { panic('other sampler context') }
	other.native.make_current()
	assert runtime.evaluate_host(r'samplerSourceGL.bindSampler(0,ownedSampler);samplerSourceGL.bindSampler(1,ownedSampler);globalThis.queriedSampler=samplerSourceGL.getParameter(samplerSourceGL.SAMPLER_BINDING);queriedSampler instanceof WebGLSampler&&queriedSampler!==ownedSampler&&queriedSampler!==samplerSourceGL.getParameter(samplerSourceGL.SAMPLER_BINDING)&&samplerSourceGL.getError()===samplerSourceGL.NO_ERROR')! == 'true'
	public_sampler_binding_source_owner()
	mut initial := i32(0)
	C.vox_gl_int_parameter(webgl.sampler_binding, &initial)
	assert initial != 0
	for pair in [
		['bindSampler(4294967295,ownedSampler)', '1281'],
		['bindSampler(4294967295,foreignSampler)', '1282'],
		['deleteSampler(foreignSampler)', '1282'],
		['deleteSampler(null)', '0'],
	] {
		other.native.make_current()
		runtime.evaluate_host('samplerSourceGL.${pair[0]};')!
		public_sampler_binding_source_owner()
		assert runtime.evaluate_host('samplerSourceGL.getError()')! == pair[1]
		mut actual := i32(0)
		C.vox_gl_int_parameter(webgl.sampler_binding, &actual)
		assert actual == initial
	}
	other.native.make_current()
	runtime.evaluate_host('samplerSourceGL.deleteSampler(ownedSampler)')!
	public_sampler_binding_source_owner()
	for unit in [0, 1] {
		runtime.evaluate_host('samplerSourceGL.activeTexture(samplerSourceGL.TEXTURE0+${unit})')!
		mut actual := i32(-1)
		C.vox_gl_int_parameter(webgl.sampler_binding, &actual)
		assert actual == 0
		assert runtime.evaluate_host(r'globalThis.zeroSampler=samplerSourceGL.getParameter(samplerSourceGL.SAMPLER_BINDING);zeroSampler instanceof WebGLSampler&&zeroSampler!==samplerSourceGL.getParameter(samplerSourceGL.SAMPLER_BINDING)&&samplerSourceGL.getError()===samplerSourceGL.NO_ERROR')! == 'true'
	}
	other.native.make_current()
	runtime.evaluate_host('samplerSourceGL.deleteSampler(ownedSampler)')!
	public_sampler_binding_source_owner()
	assert context.get_error() == webgl.no_error
	other.native.make_current()
	runtime.evaluate_host('samplerSourceGL.bindSampler(4294967295,ownedSampler)')!
	public_sampler_binding_source_owner()
	assert context.get_error() == webgl.invalid_operation
	for expression in ['bindSampler(0,{})', 'deleteSampler({})'] {
		other.native.make_current()
		assert runtime.evaluate_host('(function(){try{samplerSourceGL.${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
	}
	other.native.make_current()
	assert runtime.evaluate_host(r'(function(){const marker={};try{samplerSourceGL.bindSampler({valueOf(){throw marker}},foreignSampler);return false}catch(error){return error===marker}})()')! == 'true'
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
}
