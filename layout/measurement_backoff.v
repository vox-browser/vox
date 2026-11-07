module layout

import platform

// Flex, grid and inline measurement caches live for one layout pass. An entry
// recorded on a probe miss is useful only if the same question is asked again
// before the pass ends; otherwise collecting its inputs and copying its
// geometry into the document is wasted. Containers whose recordings went
// unused in consecutive passes skip recording for a growing number of passes
// (retained_block_layout.v); the layout itself is unchanged.

const measurement_backoff_key_offset = i64(1) << 48

fn retained_measurement_backoff_key(root &Node, inline bool) ?i64 {
	id := retained_block_backoff_key(root) or { return none }
	return id + if inline { 2 * measurement_backoff_key_offset } else { measurement_backoff_key_offset }
}

fn (mut pool MeasurementUsedValuesChunkPool) allows_measurement_recording(root &Node, inline bool) bool {
	if pool.backoff_ == unsafe { nil } { return true }
	key := retained_measurement_backoff_key(root, inline) or { return true }
	mut backoff := pool.backoff_
	return backoff.allows_collecting(key)
}

fn (mut pool MeasurementUsedValuesChunkPool) note_measurement(root &Node, inline bool, reused bool) {
	if pool.backoff_ == unsafe { nil } { return }
	key := retained_measurement_backoff_key(root, inline) or { return }
	if !reused && key in pool.measurement_usage_ { return }
	if reused && pool.measurement_usage_[key] { return }
	// Like the caches themselves, the usage map outlives each probe's scratch.
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	pool.measurement_usage_[key] = reused
}

fn (mut pool MeasurementUsedValuesChunkPool) settle_measurement_backoff() {
	if pool.backoff_ == unsafe { nil } || pool.measurement_usage_.len == 0 { return }
	mut backoff := pool.backoff_
	for key, reused in pool.measurement_usage_ {
		if reused { backoff.note_reuse(key) } else { backoff.escalate(key) }
	}
}
