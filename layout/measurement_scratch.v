module layout

import platform

@[heap]
struct MeasurementScratchSlot {
mut:
	arena &platform.Arena
}

struct MeasurementScratchScope {
mut:
	pool &MeasurementUsedValuesChunkPool = unsafe { nil }
	slot &MeasurementScratchSlot = unsafe { nil }
	entry platform.ArenaEntry
}

fn (mut pool MeasurementUsedValuesChunkPool) enter_scratch() MeasurementScratchScope {
	$if prealloc {
		assert !pool.closed
		if pool.scratch_metadata_ == unsafe { nil } {
			pool.scratch_metadata_ = platform.new_arena('intrinsic scratch metadata')
		}
		metadata := pool.scratch_metadata_.enter()
		if pool.scratch_depth_ == pool.scratch_slots_.len {
			pool.scratch_slots_ << &MeasurementScratchSlot{
				arena: platform.new_arena('intrinsic layout probe')
			}
		}
		mut slot := pool.scratch_slots_[pool.scratch_depth_]
		pool.scratch_depth_++
		pool.scratch_metadata_.leave(metadata)
		return MeasurementScratchScope{pool: pool, slot: slot, entry: slot.arena.enter()}
	}
	return MeasurementScratchScope{}
}

fn (mut scope MeasurementScratchScope) finish() {
	if scope.slot == unsafe { nil } { return }
	mut pool := scope.pool
	mut slot := scope.slot
	assert pool.scratch_depth_ > 0
	assert voidptr(pool.scratch_slots_[pool.scratch_depth_ - 1]) == voidptr(slot)
	slot.arena.leave(scope.entry)
	slot.arena.reset()
	pool.scratch_depth_--
	scope.slot = unsafe { nil }
}

fn (mut pool MeasurementUsedValuesChunkPool) release_scratch() {
	assert pool.scratch_depth_ == 0
	for index in 0 .. pool.scratch_slots_.len {
		mut slot := pool.scratch_slots_[index]
		slot.arena.release()
	}
	pool.scratch_slots_ = []&MeasurementScratchSlot{}
	if pool.scratch_metadata_ != unsafe { nil } {
		pool.scratch_metadata_.release()
		pool.scratch_metadata_ = unsafe { nil }
	}
}
