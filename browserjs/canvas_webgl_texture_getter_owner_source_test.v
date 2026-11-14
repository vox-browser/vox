// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_texture_getter_preserves_source_early_gates_and_lod_return_shape() {
	$if !darwin {
		return
	}
	for kind in ['webgl', 'webgl2'] {
		mut document := html.parse_document('<canvas></canvas>')
		mut host := CanvasWebGLHost.create(document)
		mut runtime := Runtime.create()
		defer { runtime.close() }
		host.install(mut runtime)!
		runtime.evaluate_host('const __canvases=Object.create(null);function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {state:s};}')!
		runtime.evaluate_host(webgl_bootstrap())!
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_texture_getter",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_texture_getter_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut context := host.contexts['__created_texture_getter'] or { panic('texture getter owner') }
		mut other := host.contexts['__created_texture_getter_other'] or { panic('texture getter other') }
		mut early_names := [u32(0xffff), u32(0x84fe)]
		mut names := [u32(webgl.texture_mag_filter), u32(webgl.texture_min_filter),
			u32(webgl.texture_wrap_s), u32(webgl.texture_wrap_t)]
		webgl2_names := [u32(0x813c), 0x884d, 0x884c, 0x82df, 0x813d, 0x8072, 0x912f, 0x813b, 0x813a]
		if kind == 'webgl' {
			early_names << webgl2_names
		} else {
			names << webgl2_names
		}
		for pname in early_names {
			other.native.make_current()
			assert runtime.evaluate_host('gl.getTexParameter(0xffff,${pname})===null')! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR')! == 'true'
		}
		context.native.make_current()
		native_texture := C.vox_gl_gen_object(3)
		C.vox_gl_bind_texture(webgl.texture_2d, native_texture)
		if kind == 'webgl2' {
			C.vox_gl_tex_storage2d(webgl.texture_2d, 1, 0x8058, 2, 2)
			C.vox_gl_tex_parameterf(webgl.texture_2d, 0x813b, 9.5)
			C.vox_gl_tex_parameterf(webgl.texture_2d, 0x813a, -2.5)
		}
		if runtime.evaluate_host('gl.getExtension("EXT_texture_filter_anisotropic")!==null')! == 'true' {
			println('actual public ANGLE anisotropy extension enabled')
			names << u32(0x84fe)
		}
		for target in [u32(webgl.texture_2d), u32(0xffff)] {
			for pname in names {
				context.native.make_current()
				is_lod := pname in [u32(0x813b), u32(0x813a)]
				query_name := if is_lod { u32(0x912f) } else { pname }
				expected := if is_lod {
					f64(C.vox_gl_tex_float_parameter(target, query_name))
				} else {
					f64(C.vox_gl_tex_parameter(target, query_name))
				}
				expected_error := C.vox_gl_get_error()
				other.native.make_current()
				expected_reply := if is_lod || pname == u32(0x912f) {
					(expected == 1).str()
				} else {
					i64(expected).str()
				}
				assert runtime.evaluate_host('gl.getTexParameter(${target},${pname})')! == expected_reply
				mut selected := [i32(0), 0, 0, 0]!
				C.vox_gl_int_parameter(webgl.viewport, &selected[0])
				assert selected == [i32(1), 2, 3, 4]!
				assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
			}
		}
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.getTexParameter(gl.TEXTURE_2D,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		context.native.make_current()
		C.vox_gl_delete_object(3, native_texture)
	}
}
