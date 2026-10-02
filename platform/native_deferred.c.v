// Core::ThreadEventQueue: retained deferred function and synchronized posting.
@[has_globals]
module platform

import sync

#flag darwin -framework CoreFoundation
#flag darwin -fblocks
#include "native_deferred_bridge.h"

fn C.vox_capture_origin_run_loop() voidptr
fn C.vox_defer_on_origin_run_loop(loop voidptr, context voidptr, callback fn (voidptr))
fn C.vox_deferred_thread_identity() u64

@[heap]
struct NativeDeferredCall {
	callback fn ()
}

__global (
	native_deferred_calls_      = map[u64]&NativeDeferredCall{}
	native_deferred_call_mutex_ = sync.new_mutex()
)

pub struct NativeDeferredInvoker {
	loop_handle voidptr
}

// Each capture is consumed by one deferred invocation, matching the source's
// originating EventLoop handle retained for the pending worker completion.
pub fn capture_native_deferred_invoker() ?NativeDeferredInvoker {
	$if macos {
		return NativeDeferredInvoker{
			loop_handle: C.vox_capture_origin_run_loop()
		}
	} $else {
		return none
	}
}

pub fn (invoker NativeDeferredInvoker) deferred_invoke(callback fn ()) {
	$if macos {
		call := &NativeDeferredCall{
			callback: callback
		}
		native_deferred_call_mutex_.lock()
		native_deferred_calls_[u64(voidptr(call))] = call
		native_deferred_call_mutex_.unlock()
		C.vox_defer_on_origin_run_loop(invoker.loop_handle, voidptr(call),
			invoke_native_deferred_call)
	}
}

fn invoke_native_deferred_call(pointer voidptr) {
	native_deferred_call_mutex_.lock()
	call := native_deferred_calls_[u64(pointer)] or {
		native_deferred_call_mutex_.unlock()
		return
	}
	native_deferred_calls_.delete(u64(pointer))
	native_deferred_call_mutex_.unlock()
	call.callback()
}

pub fn native_thread_identity() u64 {
	$if macos {
		return C.vox_deferred_thread_identity()
	} $else {
		return 0
	}
}
