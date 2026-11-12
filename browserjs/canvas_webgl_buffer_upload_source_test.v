// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_actual_buffer_uploads_reach_driver_bindings_without_source_slots() {
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
		key := '__created_source_upload_${kind}'
		runtime.evaluate_host('globalThis.uploadGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);')!
		mut context := host.contexts[key] or { panic('native upload context') }
		context.native.make_current()
		native_buffer := C.vox_gl_gen_object(0)
		C.vox_gl_bind_buffer(0x8892, native_buffer)
		result := runtime.evaluate_host(r'
 (function(){const gl=uploadGL;
 gl.bufferData(gl.ARRAY_BUFFER,new Uint8Array([1,2,3,4]),gl.STATIC_DRAW);
 if(gl.getBufferParameter(gl.ARRAY_BUFFER,gl.BUFFER_SIZE)!==4||gl.getError()!==gl.NO_ERROR)return "upload size";
 gl.bufferSubData(gl.ARRAY_BUFFER,1,new Uint8Array([9,8]));if(gl.getError()!==gl.NO_ERROR)return "sub upload";
 if(gl instanceof WebGL2RenderingContext){const bytes=new Uint8Array(4);gl.getBufferSubData(gl.ARRAY_BUFFER,0,bytes);if(bytes.join(",")!=="1,9,8,4"||gl.getError()!==gl.NO_ERROR)return "readback";}
 gl.bufferData(gl.ARRAY_BUFFER,7,gl.DYNAMIC_DRAW);if(gl.getBufferParameter(gl.ARRAY_BUFFER,gl.BUFFER_SIZE)!==7||gl.getError()!==gl.NO_ERROR)return "allocation";
 gl.bufferData(0xbad,new Uint8Array([1]),gl.STATIC_DRAW);if(gl.getError()!==gl.INVALID_ENUM)return "target";
 for(const call of [()=>gl.bufferData(0xbad,-4096,gl.STATIC_DRAW),()=>gl.bufferSubData(0xbad,-4096,new Uint8Array([1]))]){call();const error=gl.getError();if(error!==gl.INVALID_VALUE)return "negative:"+error;}
 // The pinned double-based 64-bit IDL conversion maps -1 to 0.
 gl.bufferData(0xbad,-1,gl.STATIC_DRAW);if(gl.getError()!==gl.INVALID_ENUM)return "source long long";
 return true})()
 ')!
		assert result == 'true'
		context.viewport(1, 2, 3, 4)
		mut other := webgl.WebGLRenderingContext.new(context.version, webgl.WebGLContextAttributes{}, [])
		other.viewport(9, 10, 11, 12)
		for call in ['uploadGL.bufferData(0xbad,null,uploadGL.STATIC_DRAW)',
			'uploadGL.bufferSubData(0xbad,-1,new Uint8Array(1),2)'] {
			if kind == 'webgl' && call.contains('bufferSubData') { continue }
			other.native.make_current()
			runtime.evaluate_host(call)!
			mut actual_viewport := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(0x0ba2, &actual_viewport[0])
			assert actual_viewport == [i32(1), 2, 3, 4]!
			assert runtime.evaluate_host('uploadGL.getError()')! == '1281'
		}
		context.native.make_current()
		C.vox_gl_delete_object(0, native_buffer)
	}
}
