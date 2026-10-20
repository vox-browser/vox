module platform

import os

// Short-lived synchronous work on the calling thread. No V allocation made
// inside this scope may escape it; native APIs must copy the inputs they keep.
// Unlike the reusable UI arenas this scope is also usable by fetch workers.
@[heap]
pub struct ThreadScratchScope {
mut:
	scope   voidptr
	entered bool
	poison  bool
	label   string
}

pub fn begin_thread_scratch(label string) &ThreadScratchScope {
	// Allocate the descriptor before entering its temporary payload scope.
	mut scratch := &ThreadScratchScope{ label: label }
	$if prealloc {
		verify_prealloc_layout()
		scratch.poison = os.getenv('VOX_ARENA_POISON') == '1'
			|| label in os.getenv('VOX_ARENA_NO_REUSE').split(',')
		if scratch.poison { C.vox_install_poison_fault_handler() }
		remember_current_arena_tail()
		scratch.scope = unsafe { prealloc_scope_begin() }
		scratch.entered = true
	}
	return scratch
}

// Restore the caller's allocation target while keeping temporary bytes alive,
// allowing an error message to be copied out before finish() frees them.
pub fn (mut scratch ThreadScratchScope) leave() {
	$if prealloc {
		if scratch.entered {
			// A retained allocation can grow this scope's parent while the
			// temporary scope is active. V's unlink restores saved_next from
			// begin(), which would discard that new parent chain. Preserve the
			// current sibling when it belongs to the parent rather than us.
			mut scope := unsafe { &PreallocScopeView(scratch.scope) }
			parent := scope.previous
			if parent != unsafe { nil } {
				next := parent.next
				if next != unsafe { nil } && next.is_scope == parent.is_scope
					&& next.scope == parent.scope {
					scope.saved_next = next
				}
			}
			unsafe { prealloc_scope_leave(scratch.scope) }
			set_current_block(latest_arena_block(current_block()))
			scratch.entered = false
		}
	}
}

pub fn (mut scratch ThreadScratchScope) finish() {
	$if prealloc {
		if scratch.scope == unsafe { nil } { return }
		scratch.leave()
		if scratch.poison {
			poison_prealloc_scope(&PreallocScopeView(scratch.scope), scratch.label)
		} else {
			unsafe { prealloc_scope_free_after(scratch.scope) }
		}
		scratch.scope = unsafe { nil }
	}
}
