module css

import platform

// Only cascade bookkeeping lives here. Declarations, substituted values and
// computed properties stay in their existing owners and can outlive this lease.
@[heap]
struct CascadeScratchSlot {
mut:
	arena &platform.Arena
	properties &CascadedProperties = unsafe { nil }
}

@[heap]
struct CascadeScratchPool {
mut:
	slots []&CascadeScratchSlot
	depth int
}

struct CascadeScratchLease {
	properties &CascadedProperties
mut:
	pool &CascadeScratchPool = unsafe { nil }
}

fn (s &StyleComputer) acquire_cascade_scratch() CascadeScratchLease {
	mut computer := unsafe { &StyleComputer(s) }
	if computer.cascade_scratch_ == unsafe { nil } {
		persistent := platform.enter_persistent()
		pool := &CascadeScratchPool{}
		computer.cascade_scratch_ = pool
		if computer.document_ != unsafe { nil } {
			mut owner := computer.document_.native_storage()
			if owner != unsafe { nil } {
				owner.add_cleanup(fn [pool] () {
					for index in 0 .. pool.slots.len {
						mut slot := pool.slots[index]
						slot.arena.release()
						slot.properties = unsafe { nil }
					}
				})
			}
		}
		platform.leave_persistent(persistent)
	}
	mut pool := computer.cascade_scratch_
	if pool.depth == pool.slots.len {
		persistent := platform.enter_persistent()
		mut slot := &CascadeScratchSlot{arena: platform.new_arena('cascade bookkeeping')}
		entry := slot.arena.enter()
		slot.properties = CascadedProperties.new()
		slot.properties.scratch_arena_ = slot.arena
		slot.arena.leave(entry)
		pool.slots << slot
		platform.leave_persistent(persistent)
	}
	properties := pool.slots[pool.depth].properties
	pool.depth++
	return CascadeScratchLease{properties: properties, pool: pool}
}

fn (mut lease CascadeScratchLease) finish() {
	if lease.pool == unsafe { nil } { return }
	mut pool := lease.pool
	assert pool.depth > 0
	assert voidptr(pool.slots[pool.depth - 1].properties) == voidptr(lease.properties)
	mut properties := lease.properties
	for index in 0 .. properties.allocated_entry_count_ {
		mut node := properties.entry_node(index)
		node.entry = CascadedPropertiesEntry{}
		node.previous = -1
	}
	properties.entry_heads_.reset()
	// The presence bitmap is public and can have independently set stale bits;
	// clear the complete bitmap, not just the heads active in this lease.
	for index in 0 .. properties.contained_properties_cache_.len {
		properties.contained_properties_cache_[index] = 0
	}
	properties.allocated_entry_count_ = 0
	properties.free_entry_index_ = -1
	pool.depth--
	lease.pool = unsafe { nil }
}
