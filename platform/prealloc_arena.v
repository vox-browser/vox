module platform

import os

#include <sys/mman.h>
#include "@DIR/arena_poison_report.h"
#include "@DIR/arena_page_retirement.h"

fn C.vox_note_poisoned_range(start voidptr, end voidptr, label &char)
fn C.vox_install_poison_fault_handler()
fn C.vox_retire_unused_arena_pages(start voidptr, bytes usize) int

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
// VOX_ARENA_NO_REUSE=label,... does the same for the named arenas only.

// Mirrors of V's VMemoryBlock and VPreallocScope (vlib/builtin/prealloc.c.v),
// read to walk an arena's blocks. verify_prealloc_layout() compares their
// sizes with V's own types. Allocation/free use V's scope API; ThreadScratchScope
// also preserves a newly grown parent's saved link before V detaches a scope.
struct PreallocBlockView {
mut:
	current        &u8                = unsafe { nil }
	stop           &u8                = unsafe { nil }
	start          &u8                = unsafe { nil }
	previous       &PreallocBlockView = unsafe { nil }
	next           &PreallocBlockView = unsafe { nil }
	scope          voidptr
	recycle_cache  voidptr
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
	saved_next     &PreallocBlockView = unsafe { nil }
	min_address    usize
	max_address    usize
	ranges         voidptr
	ranges_len     int
	ranges_cap     int
	refs           i32
	free_requested i32
	abandoned      i32
	finalized      i32
}

// V keeps detached, dead scope blocks in a per-thread recycle cache. Its
// metadata stays warm while the payload pages can be returned at idle.
struct PreallocRecycleCacheView {
	count  int
	bytes  isize
	starts [8]voidptr
	sizes  [8]isize
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
	// Labels of arenas poisoned like VOX_ARENA_POISON while others are reused.
	no_reuse []string
	// The main thread's own arena tail while an Arena is entered; nil when the
	// thread allocates from its base arena.
	base_tail                 voidptr
	depth                     int
	owner                     u64
	retained                  &RetainedArena = unsafe { nil }
	current_arena             &Arena         = unsafe { nil }
	retained_allocation_stack []RetainedAllocationEntry
	retained_allocation_depth int
}

__global arena_thread_state ArenaThreadState

// Reusable UI arenas belong to their origin thread. Check without initializing
// that ownership from a background font or resource operation.
pub fn arena_thread_is_current() bool {
	if arena_thread_state.initialized {
		return arena_thread_state.owner == u64(C.pthread_self())
	}
	$if macos || linux {
		return C.libweb_v_is_main_thread()
	}
	return false
}

fn arena_state() &ArenaThreadState {
	mut state := unsafe { &arena_thread_state }
	if !state.initialized {
		state.initialized = true
		state.poison = os.getenv('VOX_ARENA_POISON') == '1'
		no_reuse := os.getenv('VOX_ARENA_NO_REUSE')
		if no_reuse != '' {
			state.no_reuse = no_reuse.split(',')
		}
		$if prealloc {
			if state.poison || state.no_reuse.len > 0 {
				C.vox_install_poison_fault_handler()
			}
		}
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
			|| sizeof(PreallocScopeView) != sizeof(VPreallocScope)
			|| sizeof(PreallocRecycleCacheView) != sizeof(VPreallocBlockCache) {
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
	previous     voidptr
	base         bool
	thread_scope bool
	depth        i32
}

@[heap]
pub struct Arena {
mut:
	scope          &PreallocScopeView = unsafe { nil }
	tail           &PreallocBlockView = unsafe { nil }
	entered        bool
	resets         u64
	label          string
	previous_arena &Arena = unsafe { nil }
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
		// Begin the scope from the thread's base arena, then detach it: an
		// arena is only current between enter and leave.
		entry := enter_persistent()
		scope := unsafe { prealloc_scope_begin() }
		unsafe { prealloc_scope_leave(scope) }
		leave_persistent(entry)
		arena.scope = unsafe { &PreallocScopeView(scope) }
		arena.tail = arena.scope.first
		// The detached first block is not chained to the block it was begun
		// after, so walks of one arena never reach another.
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
		remember_current_arena_tail()
		arena.previous_arena = state.current_arena
		state.current_arena = arena
		depth := state.depth
		base := depth <= 0
		if base {
			state.base_tail = previous
		}
		state.depth = if base { 1 } else { depth + 1 }
		arena.entered = true
		set_current_block(arena.tail)
		return ArenaEntry{
			previous: previous
			base:     base
			depth:    i32(depth)
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
		state.current_arena = arena.previous_arena
		arena.previous_arena = unsafe { nil }
		state.depth = entry.depth
		// Persistent sections may have grown the base chain while this arena
		// was entered. Restore its latest tail, including when entered from a
		// persistent section nested inside another arena.
		set_current_block(if entry.base {
			state.base_tail
		} else {
			latest_arena_block(entry.previous)
		})
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

// A document arena is a durable owner for retained state, but still needs
// the same short-lived culling and paint-refresh scratch as base allocations.
pub fn transient_arena_entered() bool {
	$if prealloc {
		block := unsafe { &PreallocBlockView(current_block()) }
		if block == unsafe { nil } || !block.is_scope { return false }
		// ThreadScratchScope also enters V scopes without changing Arena.depth.
		if !arena_thread_is_current() { return true }
		state := arena_state()
		if state.retained != unsafe { nil } {
			if block.scope == voidptr(state.retained.arena.scope) { return false }
		}
		return true
	}
	return false
}

// enter_persistent routes allocations to the thread's base arena while an
// arena is entered: retained state such as caches must outlive the arena.
pub fn enter_persistent() ArenaEntry {
	$if prealloc {
		// Raw thread scratch scopes retain their parent links, including on
		// workers. Reach their own base without consulting UI arena ownership.
		previous := current_block()
		mut parent := unsafe { &PreallocBlockView(previous) }
		for parent != unsafe { nil } && parent.is_scope {
			parent = parent.previous
		}
		if parent != unsafe { nil } && voidptr(parent) != previous {
			for parent.next != unsafe { nil } && !parent.next.is_scope {
				parent = parent.next
			}
			set_current_block(parent)
			return ArenaEntry{ previous: previous, thread_scope: true }
		}
		// Workers already allocate in their own base scope. They must not
		// switch the origin thread's entered arena when filling shared caches.
		if arena_thread_state.initialized
			&& arena_thread_state.owner != u64(C.pthread_self()) {
			return ArenaEntry{ base: true }
		}
		mut state := arena_state()
		// Outside an arena, or already in a persistent section whose base tail
		// may have grown since it was saved, allocations already go to the base.
		if state.depth <= 0 {
			return ArenaEntry{
				base: true
			}
		}
		remember_current_arena_tail()
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
		if entry.thread_scope {
			set_current_block(latest_arena_block(entry.previous))
			return
		}
		if entry.base {
			return
		}
		mut state := arena_state()
		// The base arena may have grown a new block meanwhile.
		state.base_tail = current_block()
		state.depth = -state.depth
		set_current_block(latest_arena_block(entry.previous))
	}
}

pub fn enter_persistent_if(enabled bool) ArenaEntry {
	if enabled { return enter_persistent() }
	return ArenaEntry{ base: true }
}

// usage reports the arena's current blocks.
pub fn (arena &Arena) usage() ArenaUsage {
	if arena.scope == unsafe { nil } {
		return ArenaUsage{}
	}
	mut used := i64(0)
	mut blocks := 0
	mut block := arena.scope.first
	for block != unsafe { nil } && block.scope == voidptr(arena.scope) {
		used += i64(block.current) - i64(block.start)
		blocks++
		block = block.next
	}
	$if prealloc {
		return ArenaUsage{
			used:     used
			capacity: i64(unsafe { prealloc_scope_allocated_size(voidptr(arena.scope)) })
			blocks:   blocks
		}
	}
	return ArenaUsage{}
}

pub fn (arena &Arena) reset_count() u64 {
	return arena.resets
}

// Idle maintenance may discard the warm pages of an empty reusable arena.
// An entered arena or one with any live allocation keeps all of its payload.
// Reset/release remains the boundary that invalidates pointers, not this call.
pub fn (arena &Arena) trim_empty_pages() bool {
	$if prealloc {
		if arena.scope == unsafe { nil } || arena.entered || arena.usage().used != 0 {
			return false
		}
		mut block := arena.scope.first
		for block != unsafe { nil } && block.scope == voidptr(arena.scope) {
			if block.mmap_allocated && C.vox_retire_unused_arena_pages(block.start,
				usize(block.stop) - usize(block.start)) != 0 {
				panic('could not trim empty arena pages')
			}
			block = block.next
		}
		return true
	}
	return false
}

// Discard complete pages beyond each block's allocation cursor. Live payload,
// cursor positions, block links, and capacity remain valid for retained readers
// and future allocations. Call only on the owning thread between arena entries.
pub fn (arena &Arena) trim_unused_pages() bool {
	$if prealloc {
		if !arena_thread_is_current() || arena.scope == unsafe { nil } || arena.entered {
			return false
		}
		verify_prealloc_layout()
		mut block := arena.scope.first
		for block != unsafe { nil } && block.scope == voidptr(arena.scope) {
			if usize(block.current) < usize(block.start) || usize(block.current) > usize(block.stop) {
				panic('invalid arena allocation cursor')
			}
			if block.mmap_allocated && C.vox_retire_unused_arena_pages(block.current,
				usize(block.stop) - usize(block.current)) != 0 {
				panic('could not trim unused arena pages')
			}
			block = block.next
		}
		return true
	}
	return false
}

fn trim_thread_arena_recycle_pages() {
	$if prealloc {
		verify_prealloc_layout()
		block := unsafe { &PreallocBlockView(current_block()) }
		if block == unsafe { nil } || block.recycle_cache == unsafe { nil } { return }
		cache := unsafe { &PreallocRecycleCacheView(block.recycle_cache) }
		assert cache.count >= 0 && cache.count <= 8
		for index in 0 .. cache.count {
			if C.vox_retire_unused_arena_pages(cache.starts[index], usize(cache.sizes[index])) != 0 {
				panic('could not trim recycled arena pages')
			}
		}
	}
}

// reset makes the arena's space reusable. Every pointer into it becomes
// invalid. The arena keeps the blocks that cover a quarter more than its
// high-water mark, so steady reuse maps nothing new.
pub fn (mut arena Arena) reset() {
	$if prealloc {
		if arena.entered {
			panic('arena ${arena.label} is reset while entered')
		}
		arena.resets++
		mut state := arena_state()
		if state.poison || arena.label in state.no_reuse {
			arena.poison_blocks()
			arena.begin_scope()
			return
		}
		usage := arena.usage()
		scope := voidptr(arena.scope)
		// Reentering rewinds every kept block; leaving detaches the scope again.
		if !unsafe { prealloc_scope_reenter(scope, isize(usage.used + usage.used / 4)) } {
			panic('arena ${arena.label} could not be reset')
		}
		unsafe { prealloc_scope_leave(scope) }
		arena.tail = arena.scope.first
		arena.tail.previous = unsafe { nil }
		// Large high-water buffers can stay unused for the rest of a page.
		// Keep their virtual capacity for reuse without retaining dirty payload
		// pages. Small working arenas retain their warm backing pages.
		if arena.usage().capacity >= 1024 * 1024 {
			mut block := arena.scope.first
			for block != unsafe { nil } && block.scope == scope {
				if block.mmap_allocated && C.vox_retire_unused_arena_pages(block.start,
					usize(block.stop) - usize(block.start)) != 0 {
					panic('could not retire empty arena pages')
				}
				block = block.next
			}
		}
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
		if state.poison || arena.label in state.no_reuse {
			arena.poison_blocks()
		} else {
			unsafe { prealloc_scope_free_after(voidptr(arena.scope)) }
		}
		arena.scope = unsafe { nil }
		arena.tail = unsafe { nil }
	}
}

// Write-protect every block and abandon them with their scope.
fn (mut arena Arena) poison_blocks() {
	poison_prealloc_scope(arena.scope, arena.label)
	arena.scope = unsafe { nil }
	arena.tail = unsafe { nil }
}

fn poison_prealloc_scope(scope &PreallocScopeView, label string) {
	$if prealloc {
		mut block := scope.first
		for block != unsafe { nil } && block.scope == voidptr(scope) {
			size := usize(i64(block.stop) - i64(block.start))
			// Overwrite the old contents too: blocks that were not mapped on
			// their own cannot be protected, and stale readers then see garbage.
			unsafe { vmemset(block.start, 0xa5, isize(size)) }
			if block.mmap_allocated {
				unsafe { C.mprotect(block.start, size, C.PROT_NONE) }
				C.vox_note_poisoned_range(block.start, block.stop, label.str)
			}
			block = block.next
		}
		unsafe { prealloc_scope_abandon(voidptr(scope)) }
	}
}

// contains reports whether `pointer` lies in one of the arena's blocks.
pub fn (arena &Arena) contains(pointer voidptr) bool {
	if arena.scope == unsafe { nil } {
		return false
	}
	$if prealloc {
		return unsafe { prealloc_scope_owns(voidptr(arena.scope), pointer) }
	}
	return false
}
