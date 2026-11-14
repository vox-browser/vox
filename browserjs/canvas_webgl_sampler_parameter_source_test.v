// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn public_sampler_parameter_source_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == expected
}

fn test_public_sampler_parameter_owner_and_source_name_gates_follow_idl_conversion() {
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
	runtime.evaluate_host('globalThis.samplerParamGL=__webglContext({bridgeKey:"__created_sampler_parameter_source",width:2,height:2},"webgl2",null);globalThis.samplerParamOther=__webglContext({bridgeKey:"__created_sampler_parameter_other",width:2,height:2},"webgl2",null);globalThis.ownedParamSampler=samplerParamGL.createSampler(),foreignParamSampler=samplerParamOther.createSampler();samplerParamGL.viewport(1,2,3,4);samplerParamOther.viewport(9,10,11,12);')!
	mut context := host.contexts['__created_sampler_parameter_source'] or { panic('sampler parameter context') }
	mut other := host.contexts['__created_sampler_parameter_other'] or { panic('other sampler parameter context') }
	for method in ['samplerParameteri', 'samplerParameterf'] {
		for pair in [
			['foreignParamSampler,0xbad,1', '1282'],
			['ownedParamSampler,0xbad,1', '1280'],
			['ownedParamSampler,34046,1', '1280'],
			['ownedParamSampler,10240,9984', '1280'],
		] {
			other.native.make_current()
			runtime.evaluate_host('samplerParamGL.${method}(${pair[0]})')!
			public_sampler_parameter_source_owner([i32(1), 2, 3, 4]!)
			assert runtime.evaluate_host('samplerParamGL.getError()')! == pair[1]
		}
		for receiver in ['null', '{}'] {
			other.native.make_current()
			assert runtime.evaluate_host('(function(){try{samplerParamGL.${method}(${receiver},0xbad,1);return false}catch(error){return error instanceof TypeError}})()')! == 'true'
			public_sampler_parameter_source_owner([i32(9), 10, 11, 12]!)
		}
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{samplerParamGL.${method}(foreignParamSampler,0xbad,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		public_sampler_parameter_source_owner([i32(9), 10, 11, 12]!)
	}
	runtime.evaluate_host('samplerParamGL.samplerParameterf(ownedParamSampler,samplerParamGL.TEXTURE_MIN_LOD,-2.75);samplerParamGL.samplerParameterf(ownedParamSampler,samplerParamGL.TEXTURE_MAX_LOD,4.5)')!
	for _, sampler in host.samplers {
		if sampler.object.context_id != context.identity() { continue }
		name := sampler.object.native_name()
		assert C.vox_gl_sampler_parameter(name, webgl.texture_min_lod) == -2.75
		assert C.vox_gl_sampler_parameter(name, webgl.texture_max_lod) == 4.5
	}
	assert context.get_error() == webgl.no_error
	runtime.evaluate_host('samplerParamGL.deleteSampler(ownedParamSampler)')!
	for method in ['samplerParameteri', 'samplerParameterf'] {
		other.native.make_current()
		runtime.evaluate_host('samplerParamGL.${method}(ownedParamSampler,0xbad,1)')!
		public_sampler_parameter_source_owner([i32(1), 2, 3, 4]!)
		assert context.get_error() == webgl.invalid_operation
	}
}
