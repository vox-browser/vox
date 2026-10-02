module highresolutiontime

import math

fn near(a f64, b f64) bool {
	return math.abs(a - b) < 1e-9
}

fn test_coarsen_time_default_resolution() {
	// Default resolution is 0.1 ms: values floor to a multiple of 0.1.
	assert coarsen_time(1.0, false) == 1.0
	assert near(coarsen_time(0.15, false), 0.1)
	assert coarsen_time(0.05, false) == 0.0 // below the 0.1 ms resolution
	assert near(coarsen_time(2.34, false), 2.3)
}

fn test_coarsen_time_cross_origin_isolated_is_finer() {
	// The cross-origin isolated resolution is 0.005 ms, so more precision survives.
	assert near(coarsen_time(0.13, true), 0.13)
	assert near(coarsen_time(0.13, false), 0.1)
	// A value below 0.1 but above 0.005 survives only with the finer resolution.
	assert near(coarsen_time(0.007, true), 0.005)
	assert coarsen_time(0.007, false) == 0.0
}

fn test_coarsen_time_zero_and_exact_multiples() {
	assert coarsen_time(0.0, false) == 0.0
	assert coarsen_time(0.0, true) == 0.0
	// An exact multiple of the resolution is unchanged.
	assert near(coarsen_time(0.5, false), 0.5)
	assert near(coarsen_time(0.025, true), 0.025)
}

fn test_coarsening_preserves_the_selected_bucket_after_inexact_division() {
	for timestamp in [0.146, -40.949] {
		bucket := math.floor(timestamp * 200)
		coarse := coarsen_time(timestamp, true)
		assert math.floor(coarse * 200) == bucket
		assert coarsen_time(coarse, true) == coarse
	}
}

fn test_repeated_coarsening_does_not_drift_across_buckets() {
	for isolated in [false, true] {
		for tick in -10000 .. 10000 {
			coarse := coarsen_time(f64(tick) / 173, isolated)
			assert coarsen_time(coarse, isolated) == coarse
		}
	}
}

fn test_time_sources_are_positive() {
	// The wall and monotonic clocks return positive millisecond counts.
	assert wall_clock_unsafe_current_time() > 0.0
	assert unsafe_shared_current_time() > 0.0
}

fn test_coarsened_shared_current_time_is_coarsened() {
	// The coarsened shared current time is the unsafe shared time coarsened to the resolution, so it is
	// no greater than the raw time and within one resolution step of it.
	raw := unsafe_shared_current_time()
	coarse := coarsened_shared_current_time(false)
	assert coarse <= raw + 0.1 // sampled slightly later, but coarsening only rounds down
	assert coarse >= 0.0
}

fn test_estimated_monotonic_time_of_unix_epoch_is_finite() {
	value := estimated_monotonic_time_of_the_unix_epoch()
	assert !math.is_nan(value)
	assert !math.is_inf(value, 0)
}

fn test_relative_high_resolution_time_uses_settings_origin_and_coarsening() {
	context := TimeOriginContext{
		time_origin:                      100
		cross_origin_isolated_capability: false
	}
	assert near(relative_high_resolution_coarsen_time(125.5, context), 25.5)
	assert near(relative_high_resolution_time(125.59, context), 25.5)
}

fn test_epoch_timestamp_is_unsigned_milliseconds() {
	timestamp := EpochTimeStamp(1_700_000_000_000)
	assert timestamp == u64(1_700_000_000_000)
}
