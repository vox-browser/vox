module adblock

import time

fn test_idle_engine_release_waits_for_filter_activity_and_never_waits_for_a_busy_engine() {
	_ = release_unused_engine()
	assert evaluate_engine('"retained λ "+(6*7)')! == 'retained λ 42'
	assert !release_default_engine_if_idle(5000)
	C.vox_adblock_lock()
	default_engine_last_used_ns = time.sys_mono_now() - 6_000_000_000
	// Trying maintenance while an evaluation owns the lock must return now.
	assert !release_default_engine_if_idle(5000)
	C.vox_adblock_unlock()
	assert release_default_engine_if_idle(5000)
	assert !release_default_engine_if_idle(5000)
	assert C.vox_adblock_get_context() == unsafe { nil }
	assert evaluate_engine('"retained λ "+(6*7)')! == 'retained λ 42'
	assert !release_default_engine_if_idle(5000)
	assert release_unused_engine()
}
