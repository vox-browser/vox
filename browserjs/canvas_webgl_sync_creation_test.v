// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_source_sync_creation_exposes_records_after_actual_driver_rejection() {
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
	runtime.evaluate_host(r'globalThis.syncOwner=__webglContext({bridgeKey:"__created_sync_zero",width:2,height:2},"webgl2",null);globalThis.syncOther=__webglContext({bridgeKey:"__created_sync_other",width:2,height:2},"webgl2",null);syncOwner.viewport(1,2,3,4);syncOther.viewport(9,10,11,12);')!
	mut context := host.contexts['__created_sync_zero'] or { panic('sync creation context') }
	mut other := host.contexts['__created_sync_other'] or { panic('other sync context') }
	conditions := [u32(0), 0x9117, 0]
	flags := [u32(0), 1, 1]
	for index, condition in conditions {
		context.native.make_current()
		expected_handle := C.vox_gl_fence_sync(condition, flags[index])
		expected_error := C.vox_gl_get_error()
		assert expected_handle == unsafe { nil }
		assert expected_error != 0
		other.native.make_current()
		actual := runtime.evaluate_host('globalThis.zeroSync=syncOwner.fenceSync(${condition},${flags[index]});zeroSync!==null&&zeroSync instanceof WebGLSync&&zeroSync instanceof WebGLObject&&syncOwner.getError()===${expected_error};')!
		assert actual == 'true'
		mut selected := [0, 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [1, 2, 3, 4]!
		expected_value := C.vox_gl_get_sync_parameter(expected_handle, 0x9113)
		expected_query_error := C.vox_gl_get_error()
		actual_query := runtime.evaluate_host('syncOwner.getSyncParameter(zeroSync,syncOwner.SYNC_CONDITION)===${expected_value}&&syncOwner.getError()===${expected_query_error};')!
		assert actual_query == 'true'
		runtime.evaluate_host('zeroSync.label="null-sync-${index}";')!
		assert host.syncs.values().any(it.object.label() == 'null-sync-${index}')
		for _, sync in host.syncs {
			if sync.object.label() != 'null-sync-${index}' { continue }
			assert sync.native_pointer() == unsafe { nil }
			assert uint(sync.sync_handle(context.identity(), context.context_generation())!) == uint(index + 1)
		}
		C.vox_gl_delete_sync(expected_handle)
		expected_delete_error := C.vox_gl_get_error()
		actual_delete := runtime.evaluate_host('syncOwner.deleteSync(zeroSync);syncOwner.getError()===${expected_delete_error}&&syncOwner.getSyncParameter(zeroSync,syncOwner.SYNC_CONDITION)===null&&syncOwner.getError()===syncOwner.INVALID_OPERATION;')!
		assert actual_delete == 'true'
	}
	assert runtime.evaluate_host('globalThis.realSync=syncOwner.fenceSync(syncOwner.SYNC_GPU_COMMANDS_COMPLETE,0);realSync.label="mapped-real-sync";syncOwner.getSyncParameter(realSync,syncOwner.SYNC_CONDITION)===syncOwner.SYNC_GPU_COMMANDS_COMPLETE&&syncOwner.getError()===syncOwner.NO_ERROR')! == 'true'
	for _, sync in host.syncs {
		if sync.object.label() != 'mapped-real-sync' { continue }
		assert uint(sync.sync_handle(context.identity(), context.context_generation())!) == 4
		assert sync.native_pointer() != unsafe { nil }
		assert sync.sync_handle(context.identity(), context.context_generation())! != sync.native_pointer()
	}
	assert runtime.evaluate_host('(function(){const result=syncOwner.clientWaitSync(realSync,0,0);if(result!==syncOwner.TIMEOUT_EXPIRED&&result!==syncOwner.CONDITION_SATISFIED&&result!==syncOwner.ALREADY_SIGNALED)return false;syncOwner.deleteSync(realSync);return syncOwner.getError()===syncOwner.NO_ERROR&&syncOwner.getSyncParameter(realSync,syncOwner.SYNC_CONDITION)===null&&syncOwner.getError()===syncOwner.INVALID_OPERATION})()')! == 'true'
}
