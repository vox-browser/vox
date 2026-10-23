module platform

struct RetainedAllocationEntry {
mut:
	previous_block voidptr
	previous_arena &Arena = unsafe { nil }
	previous_depth int
}

// Keep the returned token scalar-sized. The saved allocator records live in a
// reused base-owned stack, including under V's current large-record ABI.
pub struct RetainedAllocationScope {
mut:
	index int = -1
}

// Record only a block belonging to this tracked arena. ThreadScratchScope also
// uses V scopes, whose blocks must never become an enclosing Arena's tail.
fn remember_current_arena_tail() {
	$if prealloc {
		mut state := unsafe { &arena_thread_state }
		if !state.initialized || state.owner != u64(C.pthread_self()) { return }
		mut arena := state.current_arena
		block := unsafe { &PreallocBlockView(current_block()) }
		if arena != unsafe { nil } && block != unsafe { nil }
			&& block.scope == voidptr(arena.scope) {
			arena.tail = block
		}
	}
}

fn latest_arena_block(previous voidptr) voidptr {
	$if prealloc {
		mut block := unsafe { &PreallocBlockView(previous) }
		if block != unsafe { nil } && !block.is_scope {
			// A persistent allocation can grow a raw thread scope's base parent.
			// Restore that tail on workers too, before consulting UI ownership.
			for block.next != unsafe { nil } && !block.next.is_scope {
				block = block.next
			}
			return block
		}
		state := unsafe { &arena_thread_state }
		if !state.initialized || state.owner != u64(C.pthread_self()) { return previous }
		arena := state.current_arena
		if arena != unsafe { nil } && block != unsafe { nil }
			&& block.scope == voidptr(arena.scope) {
			return arena.tail
		}
	}
	return previous
}

// Retained state created during temporary work belongs to its document. This
// redirect also supports a document arena already entered by an outer scope;
// ordinary enter() deliberately rejects that reentry.
pub fn enter_retained_allocations() RetainedAllocationScope {
	$if prealloc {
		owner := current_retained_arena()
		if owner == unsafe { nil } { return RetainedAllocationScope{} }
		mut state := arena_state()
		mut arena := owner.arena
		assert arena.entered
		assert state.depth != 0
		current := unsafe { &PreallocBlockView(current_block()) }
		if state.depth > 0 && current.scope == voidptr(arena.scope)
			&& voidptr(state.current_arena) == voidptr(arena) {
			return RetainedAllocationScope{}
		}
		// Grow bookkeeping outside both the temporary work and document payload.
		persistent := enter_persistent()
		// Initialize explicitly: a zero-initialized global record can otherwise
		// leave this array without the element size needed to save restore records.
		if state.retained_allocation_stack.cap == 0 {
			state.retained_allocation_stack = []RetainedAllocationEntry{cap: 8}
		}
		index := state.retained_allocation_depth
		if index == state.retained_allocation_stack.len {
			state.retained_allocation_stack << RetainedAllocationEntry{}
		}
		leave_persistent(persistent)
		remember_current_arena_tail()
		previous := current_block()
		state.retained_allocation_stack[index] = RetainedAllocationEntry{
			previous_block: previous
			previous_arena: state.current_arena
			previous_depth: state.depth
		}
		state.retained_allocation_depth++
		if state.depth <= 0 {
			block := unsafe { &PreallocBlockView(previous) }
			if !block.is_scope { state.base_tail = previous }
			state.depth = -state.depth
		}
		state.current_arena = arena
		set_current_block(arena.tail)
		return RetainedAllocationScope{ index: index }
	}
	return RetainedAllocationScope{}
}

pub fn (mut scope RetainedAllocationScope) finish() {
	$if prealloc {
		if scope.index < 0 { return }
		mut state := arena_state()
		assert state.retained_allocation_depth == scope.index + 1
		remember_current_arena_tail()
		mut entry := unsafe { &state.retained_allocation_stack[scope.index] }
		state.current_arena = entry.previous_arena
		state.depth = entry.previous_depth
		previous := unsafe { &PreallocBlockView(entry.previous_block) }
		set_current_block(if !previous.is_scope {
			state.base_tail
		} else {
			latest_arena_block(previous)
		})
		entry.previous_block = unsafe { nil }
		entry.previous_arena = unsafe { nil }
		state.retained_allocation_depth--
		scope.index = -1
	}
}
