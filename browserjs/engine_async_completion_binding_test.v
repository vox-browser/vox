module browserjs

import platform
import time

fn test_webassembly_settlement_marks_the_document_state_dirty() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_engine_async_completion_binding()!
	assert runtime.evaluate_host('WebAssembly.instantiate.name==="instantiate"&&WebAssembly.instantiate.length===1&&WebAssembly.compile.name==="compile"')! == 'true'
	runtime.evaluate_host(r'globalThis.settled=[];
 const empty=new Uint8Array([0,97,115,109,1,0,0,0]);
 globalThis.pending=WebAssembly.instantiate(empty);
 pending.then(result=>settled.push(result.instance instanceof WebAssembly.Instance));
 WebAssembly.compile(new Uint8Array([1,2,3])).catch(error=>settled.push(error instanceof WebAssembly.CompileError));')!
	runtime.take_document_state_dirty()
	deadline := time.sys_mono_now() + 5 * time.second
	for !runtime.has_pending_document_state() && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
	}
	assert runtime.take_document_state_dirty()
	for runtime.evaluate_host('settled.length')! != '2' && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
	}
	// The caller still receives the original promise and both results.
	assert runtime.evaluate_host('JSON.stringify(settled.sort())')! == '[true,true]'
}
