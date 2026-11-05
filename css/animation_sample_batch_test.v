module css

import dom

fn test_animation_sample_batch_preserves_the_original_floor_and_caps_only_expansion() {
	floor := i64(256 * 1024)
	for bytes in [i64(-1), 0, 1, 1024, 4096] {
		assert expanded_animation_sample_arena_limit(floor, bytes) == floor
	}
	assert expanded_animation_sample_arena_limit(floor, 16384) == 1024 * 1024
	assert expanded_animation_sample_arena_limit(1024 * 1024, 65536) == 4 * 1024 * 1024
	assert expanded_animation_sample_arena_limit(8 * 1024 * 1024, 512 * 1024) == 16 * 1024 * 1024
	assert expanded_animation_sample_arena_limit(32 * 1024 * 1024, 2 * 1024 * 1024) == 32 * 1024 * 1024
	assert expanded_animation_sample_arena_limit(floor, i64(0x7fffffffffffffff)) == 16 * 1024 * 1024
	assert expanded_animation_sample_arena_limit(floor, i64(-0x7fffffffffffffff) - 1) == floor
	for bytes in [i64(1), 4096, 16384, 65536, 262144, 1048576, 4194304] {
		original := if 16 * bytes > floor { 16 * bytes } else { floor }
		expanded := expanded_animation_sample_arena_limit(original, bytes)
		assert expanded >= original
		if original < animation_sample_expanded_threshold_cap {
			assert expanded <= animation_sample_expanded_threshold_cap
		} else {
			assert expanded == original
		}
	}
}

fn test_animation_sample_batch_defers_the_old_boundary_and_still_rotates() {
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.oldest_live_paint_scene_generation = 2
		mut storage := AnimationSampleStorage{}
		defer { storage.dispose() }
		assert !storage.begin_update(document)
		storage.enter()
		padding := []u8{len: 768 * 1024, init: 17}
		assert padding[padding.len - 1] == 17
		storage.leave()
		storage.update_start_used = storage.current.usage().used
		storage.update_bytes = 32768
		serial := storage.current_serial
		rotated := storage.begin_update(document)
		assert rotated == retain_short_animation_sample_batch
		assert storage.current_serial == serial + if rotated { u64(1) } else { u64(0) }
		storage.enter()
		large := []u8{len: 17 * 1024 * 1024, init: 23}
		assert large[large.len - 1] == 23
		storage.leave()
		storage.update_start_used = storage.current.usage().used
		storage.update_bytes = 0
		assert storage.begin_update(document)
		storage.retire_unreachable(document)
		assert storage.retiring.len == 0
	}
}

fn test_animation_sample_batch_reuses_bounded_storage_over_many_rotations() {
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.oldest_live_paint_scene_generation = 2
		mut storage := AnimationSampleStorage{}
		defer { storage.dispose() }
		mut rotations := 0
		for index in 0 .. 2048 {
			if storage.begin_update(document) { rotations++ }
			storage.enter()
			fill := u8(index % 251)
			bytes := []u8{len: 32768, init: fill}
			last := bytes[bytes.len - 1]
			storage.leave()
			assert last == fill
			assert storage.current.usage().used <= 3 * 1024 * 1024
			assert storage.retiring.len <= 1
			assert storage.spare.len <= 2 && storage.spare_target_lists.len <= 2
		}
		if retain_short_animation_sample_batch {
			assert rotations > 64
		} else {
			assert rotations > 16 && rotations < 64
		}
	}
}
