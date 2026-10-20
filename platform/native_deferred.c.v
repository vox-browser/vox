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
	storage &RetainedArena = unsafe { nil }
	thread_scope voidptr
}

__global (
	native_deferred_calls_      = map[u64]&NativeDeferredCall{}
	native_deferred_call_mutex_ = sync.new_mutex()
)

pub struct NativeDeferredInvoker {
	loop_handle voidptr
	storage &RetainedArena = unsafe { nil }
}

// Each capture is consumed by one deferred invocation, matching the source's
// originating EventLoop handle retained for the pending worker completion.
pub fn capture_native_deferred_invoker() ?NativeDeferredInvoker {
	return capture_native_deferred_invoker_for_storage(current_retained_arena())
}

// An async resource completion can run with another document's allocation
// scope entered by a cooperative UI checkpoint. Its receiver is the owner.
pub fn capture_native_deferred_invoker_for_storage(owner &RetainedArena) ?NativeDeferredInvoker {
	$if macos || linux {
		mut storage := unsafe { &RetainedArena(owner) }
		if storage != unsafe { nil } { storage.retain() }
		return NativeDeferredInvoker{
			loop_handle: C.vox_capture_origin_run_loop()
			storage: storage
		}
	} $else {
		return none
	}
}

pub fn (invoker NativeDeferredInvoker) deferred_invoke(callback fn ()) {
	$if macos || linux {
		$if prealloc {
			// Neither the call record nor a shared map may live in a worker
			// scope that ends before the native origin loop consumes it.
			call := unsafe { &NativeDeferredCall(C.malloc(sizeof(NativeDeferredCall))) }
			if call == unsafe { nil } { panic('native deferred call allocation failed') }
			unsafe {
				*call = NativeDeferredCall{
					callback: callback
					storage: invoker.storage
					thread_scope: prealloc_scope_retain_current()
				}
			}
			C.vox_defer_on_origin_run_loop(invoker.loop_handle, voidptr(call),
				invoke_native_deferred_call)
			return
		}
		call := &NativeDeferredCall{
			callback: callback
			storage: invoker.storage
		}
		native_deferred_call_mutex_.lock()
		native_deferred_calls_[u64(voidptr(call))] = call
		native_deferred_call_mutex_.unlock()
		C.vox_defer_on_origin_run_loop(invoker.loop_handle, voidptr(call),
			invoke_native_deferred_call)
	}
}

fn invoke_native_deferred_call(pointer voidptr) {
	// A UI checkpoint can pump the native loop from a temporary layout/paint
	// arena. Worker completions follow the same run-to-completion rule as timers.
	if defer_native_call_during_cooperative_work(pointer) { return }
	$if prealloc {
		call := unsafe { &NativeDeferredCall(pointer) }
		defer {
			mut storage := call.storage
			if storage != unsafe { nil } { storage.release() }
			unsafe {
				prealloc_scope_release(call.thread_scope)
				C.free(call)
			}
		}
		call.callback()
		return
	}
	native_deferred_call_mutex_.lock()
	call := native_deferred_calls_[u64(pointer)] or {
		native_deferred_call_mutex_.unlock()
		return
	}
	native_deferred_calls_.delete(u64(pointer))
	native_deferred_call_mutex_.unlock()
	defer {
		mut storage := call.storage
		if storage != unsafe { nil } { storage.release() }
	}
	call.callback()
}

pub fn native_thread_identity() u64 {
	$if macos || linux {
		return C.vox_deferred_thread_identity()
	} $else {
		return 0
	}
}
