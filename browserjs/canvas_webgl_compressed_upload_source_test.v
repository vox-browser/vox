// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_compressed_uploads_select_owner_before_format_and_span_errors() {
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
		key := '__created_compressed_upload_${kind}'
		other_key := '__created_compressed_upload_other_${kind}'
		runtime.evaluate_host('globalThis.compressedGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.compressedOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);compressedGL.viewport(1,2,3,4);compressedOther.viewport(9,10,11,12);globalThis.compressedExtension=compressedGL.getExtension("WEBGL_compressed_texture_s3tc");')!
		assert runtime.evaluate_host('compressedExtension!==null')! == 'true'
		mut context := host.contexts[key] or { panic('native compressed upload context') }
		mut other := host.contexts[other_key] or { panic('other compressed upload context') }
		pixels := [u8(0), 248, 224, 7, 0, 0, 0, 0]
		context.native.make_current()
		C.vox_gl_compressed_tex_image2d(0xbad, 0, 0x83f0, -4, 4, 1, pixels.len, pixels.data)
		expected_image := C.vox_gl_get_error()
		other.native.make_current()
		runtime.evaluate_host('compressedGL.compressedTexImage2D(0xbad,0,0x83f0,-4,4,1,new Uint8Array([0,248,224,7,0,0,0,0]));')!
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('compressedGL.getError()')! == expected_image.str()
		C.vox_gl_compressed_tex_sub_image2d(0xbad, 0, 0, 0, -4, 4, 0x83f0, pixels.len, pixels.data)
		expected_sub_image := C.vox_gl_get_error()
		other.native.make_current()
		runtime.evaluate_host('compressedGL.compressedTexSubImage2D(0xbad,0,0,0,-4,4,0x83f0,new Uint8Array([0,248,224,7,0,0,0,0]));')!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('compressedGL.getError()')! == expected_sub_image.str()
		mut calls := [
			'compressedGL.compressedTexImage2D(0xbad,0,0xbad,-4,4,1,new Uint8Array(0));',
			'compressedGL.compressedTexSubImage2D(0xbad,0,0,0,-4,4,0xbad,new Uint8Array(0));',
		]
		mut expected := ['1280', '1280']
		if kind == 'webgl2' {
			calls << [
				'compressedGL.compressedTexImage2D(0xbad,0,0x83f0,4,4,0,new Uint8Array(0),1);',
				'compressedGL.compressedTexImage3D(0xbad,0,0xbad,4,4,1,0,new Uint8Array(0),1);',
				'compressedGL.compressedTexSubImage3D(0xbad,0,0,0,0,4,4,1,0x83f0,new Uint8Array(0),1);',
			]
			expected << ['1281', '1280', '1281']
		}
		for index, call in calls {
			other.native.make_current()
			runtime.evaluate_host(call)!
			C.vox_gl_int_parameter(0x0ba2, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert runtime.evaluate_host('compressedGL.getError()')! == expected[index]
		}
	}
}
