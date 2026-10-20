module css

import platform

// Family lists, feature maps and parsed bridge values are synchronous inputs,
// including on a cache miss. Each nested call gets its own reusable arena;
// materialized font cascades allocate outside it before being published.
@[heap]
struct FontInputScratchPool {
mut:
	arenas []&platform.Arena
	depth int
}

struct FontInputScratchLease {
mut:
	pool &FontInputScratchPool = unsafe { nil }
	arena &platform.Arena = unsafe { nil }
	entry platform.ArenaEntry
}

fn (mut computer FontComputer) acquire_font_input_scratch() FontInputScratchLease {
	$if prealloc {
		if platform.arena_thread_is_current() {
			if computer.font_input_scratch_ == unsafe { nil } {
				persistent := platform.enter_persistent()
				pool := &FontInputScratchPool{}
				computer.font_input_scratch_ = pool
				if document := computer.document_ {
					mut owner := document.native_storage()
					if owner != unsafe { nil } {
						owner.add_cleanup(fn [pool] () {
							for index in 0 .. pool.arenas.len {
								mut arena := pool.arenas[index]
								arena.release()
							}
						})
					}
				}
				platform.leave_persistent(persistent)
			}
			mut pool := computer.font_input_scratch_
			if pool.depth == pool.arenas.len {
				persistent := platform.enter_persistent()
				pool.arenas << platform.new_arena('font computation inputs')
				platform.leave_persistent(persistent)
			}
			mut arena := pool.arenas[pool.depth]
			pool.depth++
			return FontInputScratchLease{pool:pool, arena:arena, entry:arena.enter()}
		}
	}
	return FontInputScratchLease{}
}

fn (mut lease FontInputScratchLease) finish() {
	if lease.pool == unsafe { nil } { return }
	assert lease.pool.depth > 0
	assert voidptr(lease.pool.arenas[lease.pool.depth - 1]) == voidptr(lease.arena)
	lease.arena.leave(lease.entry)
	lease.arena.reset()
	lease.pool.depth--
	lease.pool = unsafe { nil }
}
