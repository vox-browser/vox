module platform

import os

#include <sys/mman.h>

// Arenas for -prealloc builds.
//
// V's -prealloc allocator bumps a thread-local block pointer and never frees
// individual allocations. Space comes back only when a whole arena is reset or
// released. An Arena wraps one of V's scoped arenas: entering it routes every
// allocation on this thread into it until the matching leave; reset makes its
// space reusable at once; release returns it to the system. Outside -prealloc
// every operation does nothing and allocations stay with the collector.
//
// Nothing that outlives an arena's reset may point into it. Code that runs
// inside an arena and updates longer-lived state (a cache, a retained map, a
// persistent object) must allocate that state through enter_persistent().
// VOX_ARENA_POISON=1 replaces reset and release with write-protecting the old
// blocks and never reusing them, so any later access to them faults.

// Mirrors of V's VMemoryBlock and VPreallocScope (vlib/builtin/prealloc.c.v).
// verify_prealloc_layout() compares their sizes with V's own types.
struct PreallocBlockView {
mut:
	current        &u8                = unsafe { nil }
	stop           &u8                = unsafe { nil }
	start          &u8                = unsafe { nil }
	previous       &PreallocBlockView = unsafe { nil }
	next           &PreallocBlockView = unsafe { nil }
	scope          voidptr
	min_block_size isize
	is_scope       bool
	mmap_allocated bool
	id             int
	mallocs        int
}

struct PreallocScopeView {
mut:
	previous       &PreallocBlockView = unsafe { nil }
	first          &PreallocBlockView = unsafe { nil }
	refs           int
	free_requested int
	abandoned      int
	finalized      int
}

// ArenaUsage describes a chain of arena blocks: bytes handed out by the bump
// allocator and the capacity of the blocks behind them.
pub struct ArenaUsage {
pub:
	used     i64
	capacity i64
	blocks   int
}

struct ArenaThreadState {
mut:
	initialized bool
	poison      bool
	// The main thread's own arena tail while an Arena is entered; nil when the
	// thread allocates from its base arena.
	base_tail voidptr
	depth     int
	owner     u64
}

__global arena_thread_state ArenaThreadState

fn arena_state() &ArenaThreadState {
	mut state := unsafe { &arena_thread_state }
	if !state.initialized {
		state.initialized = true
		state.poison = os.getenv('VOX_ARENA_POISON') == '1'
		state.owner = u64(C.pthread_self())
		verify_prealloc_layout()
	}
	$if prealloc {
		if u64(C.pthread_self()) != state.owner {
			panic('platform arenas are used by one thread')
		}
	}
	return state
}

fn verify_prealloc_layout() {
	$if prealloc {
		if sizeof(PreallocBlockView) != sizeof(VMemoryBlock)
			|| sizeof(PreallocScopeView) != sizeof(VPreallocScope) {
			panic('platform arena mirrors do not match V prealloc blocks')
		}
	}
}

// arenas_poisoned reports whether VOX_ARENA_POISON=1 is in effect.
pub fn arenas_poisoned() bool {
	return arena_state().poison
}

fn current_block() voidptr {
	$if prealloc {
		return unsafe { voidptr(g_memory_block) }
	}
	return unsafe { nil }
}

fn set_current_block(block voidptr) {
	$if prealloc {
		unsafe {
			g_memory_block = block
		}
	}
}

// thread_arena_usage walks the calling thread's arena chain, from the current
// block back through enclosing scopes to the thread's base arena. It reports
// zero without -prealloc.
pub fn thread_arena_usage() ArenaUsage {
	return chain_usage(&PreallocBlockView(current_block()), false)
}

fn chain_usage(start &PreallocBlockView, forward bool) ArenaUsage {
	mut used := i64(0)
	mut capacity := i64(0)
	mut blocks := 0
	mut block := unsafe { start }
	for block != unsafe { nil } {
		used += i64(block.current) - i64(block.start)
		capacity += i64(block.stop) - i64(block.start)
		blocks++
		block = if forward { block.next } else { block.previous }
	}
	return ArenaUsage{
		used:     used
		capacity: capacity
		blocks:   blocks
	}
}

// ArenaEntry restores the allocation target that was current before an
// enter call.
pub struct ArenaEntry {
	previous voidptr
	base     bool
}

@[heap]
pub struct Arena {
mut:
	scope   &PreallocScopeView = unsafe { nil }
	tail    &PreallocBlockView = unsafe { nil }
	entered bool
	resets  u64
	label   string
}

// new_arena creates an empty arena. Its first block is mapped lazily by the
// system, so an unused arena costs address space rather than memory.
pub fn new_arena(label string) &Arena {
	mut arena := &Arena{
		label: label
	}
	$if prealloc {
		arena.begin_scope()
	}
	return arena
}

fn (mut arena Arena) begin_scope() {
	$if prealloc {
		// A scope links its first block after the current one; create it from
		// the thread's base arena so no other arena's chain is extended.
		entry := enter_persistent()
		scope := unsafe { prealloc_scope_begin() }
		unsafe { prealloc_scope_leave(scope) }
		leave_persistent(entry)
		arena.scope = unsafe { &PreallocScopeView(scope) }
		arena.tail = arena.scope.first
		// The first block is not chained to the arena that was current when it
		// was created.
		arena.tail.previous = unsafe { nil }
	}
}

// enter routes this thread's allocations into the arena until leave.
pub fn (mut arena Arena) enter() ArenaEntry {
	$if prealloc {
		mut state := arena_state()
		if arena.entered {
			panic('arena ${arena.label} is already entered')
		}
		previous := current_block()
		if state.depth == 0 {
			state.base_tail = previous
		}
		state.depth++
		arena.entered = true
		set_current_block(arena.tail)
		return ArenaEntry{
			previous: previous
		}
	}
	return ArenaEntry{}
}

// leave restores the allocation target from before the matching enter.
pub fn (mut arena Arena) leave(entry ArenaEntry) {
	$if prealloc {
		mut state := arena_state()
		if !arena.entered {
			panic('arena ${arena.label} is not entered')
		}
		arena.tail = &PreallocBlockView(current_block())
		arena.entered = false
		state.depth--
		set_current_block(entry.previous)
		if state.depth == 0 {
			state.base_tail = unsafe { nil }
		}
	}
}

// arena_entered reports whether allocations currently go to an Arena rather
// than the thread's base arena.
pub fn arena_entered() bool {
	$if prealloc {
		return arena_state().depth > 0
	}
	return false
}

// enter_persistent routes allocations to the thread's base arena while an
// arena is entered: retained state such as caches must outlive the arena.
pub fn enter_persistent() ArenaEntry {
	$if prealloc {
		mut state := arena_state()
		if state.depth == 0 {
			return ArenaEntry{
				base: true
			}
		}
		previous := current_block()
		set_current_block(state.base_tail)
		state.depth = -state.depth
		return ArenaEntry{
			previous: previous
		}
	}
	return ArenaEntry{
		base: true
	}
}

pub fn leave_persistent(entry ArenaEntry) {
	$if prealloc {
		if entry.base {
			return
		}
		mut state := arena_state()
		// The base arena may have grown a new block meanwhile.
		state.base_tail = current_block()
		state.depth = -state.depth
		set_current_block(entry.previous)
	}
}

// usage reports the arena's current blocks.
pub fn (arena &Arena) usage() ArenaUsage {
	if arena.scope == unsafe { nil } {
		return ArenaUsage{}
	}
	return chain_usage(arena.scope.first, true)
}

pub fn (arena &Arena) reset_count() u64 {
	return arena.resets
}

// reset makes the arena's space reusable. Every pointer into it becomes
// invalid. An arena that grew past one block is remapped as a single block
// with a quarter more than its high-water mark, so steady reuse maps nothing.
pub fn (mut arena Arena) reset() {
	$if prealloc {
		if arena.entered {
			panic('arena ${arena.label} is reset while entered')
		}
		arena.resets++
		mut state := arena_state()
		if state.poison {
			arena.poison_blocks()
			arena.begin_scope()
			return
		}
		usage := arena.usage()
		mut first := arena.scope.first
		if usage.blocks > 1 {
			size := isize((usage.used + usage.used / 4 + arena_block_granularity - 1) / arena_block_granularity * arena_block_granularity)
			mut block := arena.scope.first
			for block != unsafe { nil } {
				mut next := block.next
				free_block(block)
				block = next
			}
			first = new_block(size, voidptr(arena.scope))
		}
		first.previous = unsafe { nil }
		first.next = unsafe { nil }
		first.current = first.start
		arena.scope.first = first
		arena.tail = first
	}
}

// release returns the arena's blocks to the system. The arena must not be
// entered or used afterwards.
pub fn (mut arena Arena) release() {
	$if prealloc {
		if arena.scope == unsafe { nil } {
			return
		}
		if arena.entered {
			panic('arena ${arena.label} is released while entered')
		}
		mut state := arena_state()
		if state.poison {
			arena.poison_blocks()
		} else {
			unsafe { prealloc_scope_free_after(voidptr(arena.scope)) }
		}
		arena.scope = unsafe { nil }
		arena.tail = unsafe { nil }
	}
}

const arena_block_granularity = i64(64 * 1024)

fn new_block(size isize, scope voidptr) &PreallocBlockView {
	mut block := unsafe { &PreallocBlockView(C.calloc(1, sizeof(PreallocBlockView))) }
	if block == unsafe { nil } {
		panic('could not allocate an arena block')
	}
	start := unsafe {
		C.mmap(nil, usize(size), C.PROT_READ | C.PROT_WRITE, C.MAP_ANONYMOUS | C.MAP_PRIVATE, -1, 0)
	}
	if start == C.MAP_FAILED {
		panic('could not map an arena block of ${size} bytes')
	}
	block.start = unsafe { &u8(start) }
	block.current = block.start
	block.stop = unsafe { block.start + size }
	block.scope = scope
	block.min_block_size = size
	block.is_scope = true
	block.mmap_allocated = true
	return block
}

fn free_block(block &PreallocBlockView) {
	size := usize(i64(block.stop) - i64(block.start))
	if block.mmap_allocated {
		unsafe { C.munmap(block.start, size) }
	} else {
		unsafe { C.free(block.start) }
	}
	unsafe { C.free(block) }
}

// Write-protect every block and abandon them with their scope.
fn (mut arena Arena) poison_blocks() {
	mut block := arena.scope.first
	for block != unsafe { nil } {
		size := usize(i64(block.stop) - i64(block.start))
		if block.mmap_allocated {
			unsafe { C.mprotect(block.start, size, C.PROT_NONE) }
		}
		block = block.next
	}
	arena.scope = unsafe { nil }
	arena.tail = unsafe { nil }
}

// contains reports whether `pointer` lies in one of the arena's blocks.
pub fn (arena &Arena) contains(pointer voidptr) bool {
	if arena.scope == unsafe { nil } {
		return false
	}
	mut block := arena.scope.first
	for block != unsafe { nil } {
		if u64(pointer) >= u64(block.start) && u64(pointer) < u64(block.stop) {
			return true
		}
		block = block.next
	}
	return false
}
