@[has_globals]
module browserjs

#include "@DIR/../platform/closure_release_test.h"

$if gcboehm ? {
	fn C.vox_closure_release_watch(owner voidptr)
	fn C.vox_closure_release_run_worker(work fn ())
	fn C.vox_closure_release_owner_alive() u32
}

__global retained_closed_runtime = unsafe { &Runtime(nil) }

@[heap]
struct RuntimeOwnedCapture {
	bytes []u8
}

fn runtime_owned_capture_fixture(close bool) {
	capture := &RuntimeOwnedCapture{ bytes: []u8{len: 4096} }
	$if gcboehm ? {
		C.vox_closure_release_watch(voidptr(capture))
	}
	mut runtime := Runtime.create_with_engine(.libjs)
	retained_closed_runtime = runtime
	runtime.define_host_function('capture', fn [capture] (input string) !string {
		return '${input}:${capture.bytes.len}'
	}) or { panic(err) }
	result := runtime.evaluate('capture("owned")') or { panic(err) }
	assert result == 'owned:4096'
	if close {
		runtime.close()
		runtime.close()
		if _ := runtime.evaluate('capture("closed")') {
			assert false, 'a closed runtime must reject execution'
		} else {
			assert err.msg().contains('closed')
		}
	}
}

fn runtime_owned_capture_open() {
	runtime_owned_capture_fixture(false)
}

fn runtime_owned_capture_closed() {
	runtime_owned_capture_fixture(true)
}

fn test_runtime_close_releases_callback_capture_while_closed_runtime_remains_reachable() {
	$if gcboehm ? {
		C.vox_closure_release_run_worker(runtime_owned_capture_open)
		assert C.vox_closure_release_owner_alive() == 1
		mut runtime := retained_closed_runtime
		runtime.close()
		assert runtime.closed
		assert C.vox_closure_release_owner_alive() == 0
		C.vox_closure_release_run_worker(runtime_owned_capture_closed)
		assert retained_closed_runtime.closed
		assert C.vox_closure_release_owner_alive() == 0
	} $else {
		runtime_owned_capture_closed()
		assert retained_closed_runtime.closed
	}
	retained_closed_runtime = unsafe { nil }
}
