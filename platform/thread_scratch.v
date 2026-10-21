module platform

#include "@DIR/thread_scratch_leases.h"

@[typedef]
struct C.VoxThreadScratchLease {
mut:
	scope voidptr
	label &u8
	label_len i64
	generation u64
	active i32
	entered i32
	poison i32
}

fn C.vox_thread_scratch_acquire() &C.VoxThreadScratchLease
fn C.vox_thread_scratch_poison_enabled(&u8, i64) i32

// Short-lived synchronous work on the calling thread. No V allocation made
// inside this scope may escape it; native APIs must copy the inputs they keep.
// Unlike the reusable UI arenas this scope is also usable by fetch workers.
pub struct ThreadScratchScope {
	lease &C.VoxThreadScratchLease = unsafe { nil }
	generation u64
}

pub fn begin_thread_scratch(label string) ThreadScratchScope {
	$if prealloc {
		verify_prealloc_layout()
		mut lease := C.vox_thread_scratch_acquire()
		lease.label = label.str
		lease.label_len = label.len
		lease.poison = C.vox_thread_scratch_poison_enabled(label.str, label.len)
		if lease.poison != 0 { C.vox_install_poison_fault_handler() }
		remember_current_arena_tail()
		lease.scope = unsafe { prealloc_scope_begin() }
		lease.entered = 1
		return ThreadScratchScope{lease:lease, generation:lease.generation}
	}
	return ThreadScratchScope{}
}

// Restore the caller's allocation target while keeping temporary bytes alive,
// allowing an error message to be copied out before finish() frees them.
pub fn (scratch ThreadScratchScope) leave() {
	$if prealloc {
		mut lease := scratch.lease
		if lease == unsafe { nil } || lease.active == 0 || lease.generation != scratch.generation { return }
		if lease.entered != 0 {
			// A retained allocation can grow this scope's parent while the
			// temporary scope is active. V's unlink restores saved_next from
			// begin(), which would discard that new parent chain. Preserve the
			// current sibling when it belongs to the parent rather than us.
			mut scope := unsafe { &PreallocScopeView(lease.scope) }
			parent := scope.previous
			if parent != unsafe { nil } {
				next := parent.next
				if next != unsafe { nil } && next.is_scope == parent.is_scope
					&& next.scope == parent.scope {
					scope.saved_next = next
				}
			}
			unsafe { prealloc_scope_leave(lease.scope) }
			set_current_block(latest_arena_block(current_block()))
			lease.entered = 0
		}
	}
}

pub fn (scratch ThreadScratchScope) finish() {
	$if prealloc {
		mut lease := scratch.lease
		if lease == unsafe { nil } || lease.active == 0 || lease.generation != scratch.generation { return }
		scratch.leave()
		if lease.poison != 0 {
			label := unsafe { tos(lease.label, int(lease.label_len)) }
			poison_prealloc_scope(&PreallocScopeView(lease.scope), label)
		} else {
			unsafe { prealloc_scope_free_after(lease.scope) }
		}
		lease.scope = unsafe { nil }
		lease.label = unsafe { nil }
		lease.label_len = 0
		lease.active = 0
	}
}
