module css

import dom
import platform

__global css_arena_probe_bytes [64]i64

pub fn arena_probe_now() i64 {
	return platform.thread_arena_usage().used
}

pub fn arena_probe_add(slot int, start i64) i64 {
	now := platform.thread_arena_usage().used
	css_arena_probe_bytes[slot] += now - start
	return now
}

pub fn arena_probe_take() []i64 {
	mut values := []i64{}
	for index in 0 .. 64 {
		values << css_arena_probe_bytes[index]
		css_arena_probe_bytes[index] = 0
	}
	return values
}

pub fn computed_layout_cache_size() int {
	return int(sizeof(ComputedLayoutCache))
}

pub fn computed_properties_size() int {
	return int(sizeof(ComputedProperties))
}

pub fn animation_sample_stats(document &dom.Document) string {
	style_computer := css_style_computer_for(document)
	storage := style_computer.animation_samples_
	if storage == unsafe { nil } {
		return 'samples=none'
	}
	current := if storage.current != unsafe { nil } { storage.current.usage().used } else { i64(0) }
	return 'samples_current=${current} samples_retiring=${storage.retiring.len} samples_spare=${storage.spare.len} targets=${storage.current_targets.len}'
}
