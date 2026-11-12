// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_texture_storage_uses_source_owner_and_actual_driver_validation() {
	$if !darwin && !linux {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	runtime.evaluate_host('const __canvases=Object.create(null);function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	key := '__created_texture_storage'
	other_key := '__created_texture_storage_other'
	runtime.evaluate_host('globalThis.storageGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"webgl2",null);globalThis.storageOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"webgl2",null);storageGL.viewport(1,2,3,4);storageOther.viewport(9,10,11,12);')!
	mut context := host.contexts[key] or { panic('native texture storage context') }
	mut other := host.contexts[other_key] or { panic('other texture storage context') }
	context.native.make_current()
	C.vox_gl_tex_storage2d(0xbad, 0, 0x8058, -1, 0)
	expected_2d := C.vox_gl_get_error()
	other.native.make_current()
	runtime.evaluate_host('storageGL.texStorage2D(0xbad,0,storageGL.RGBA8,-1,0);')!
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
	assert runtime.evaluate_host('storageGL.getError()')! == expected_2d.str()
	C.vox_gl_tex_storage3d(0xbad, 0, 0x8058, -1, 0, -1)
	expected_3d := C.vox_gl_get_error()
	other.native.make_current()
	runtime.evaluate_host('storageGL.texStorage3D(0xbad,0,storageGL.RGBA8,-1,0,-1);')!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
	assert runtime.evaluate_host('storageGL.getError()')! == expected_3d.str()
	assert runtime.evaluate_host(r'(function(){const gl=storageGL;const texture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,texture);gl.texStorage2D(gl.TEXTURE_2D,1,gl.RGBA8,2,2);if(gl.getTexParameter(gl.TEXTURE_2D,gl.TEXTURE_IMMUTABLE_FORMAT)!==true||gl.getTexParameter(gl.TEXTURE_2D,gl.TEXTURE_IMMUTABLE_LEVELS)!==1)return false;const volume=gl.createTexture();gl.bindTexture(gl.TEXTURE_3D,volume);gl.texStorage3D(gl.TEXTURE_3D,1,gl.RGBA8,1,1,2);return gl.getTexParameter(gl.TEXTURE_3D,gl.TEXTURE_IMMUTABLE_FORMAT)===true&&gl.getTexParameter(gl.TEXTURE_3D,gl.TEXTURE_IMMUTABLE_LEVELS)===1&&gl.getError()===gl.NO_ERROR})()')! == 'true'
}
