module css

import math
import platform
import dom

fn worker_font_cache_keys() bool {
	mut computer := FontComputer.create()
	key := ComputedFontCacheKey{ font_family: ['Worker', 'sans-serif'] }
	_, owned := computer.lookup_font_cache_key(key, .chromium, 15.25)
	cascade := FontCascadeList.create()
	computer.computed_font_cache[owned] = cascade
	found, unused := computer.lookup_font_cache_key(key, .chromium, 15.25)
	return voidptr(found) == voidptr(cascade) && unused == ''
		&& computer.font_key_scratch_ == unsafe { nil }
}

fn test_font_cache_keys_remain_usable_on_workers() {
	// Initialize UI ownership first, then exercise independent worker computers.
	mut owner := platform.new_arena('font key worker origin')
	mut workers := []thread bool{}
	for _ in 0 .. 4 { workers << spawn worker_font_cache_keys() }
	for worker in workers {
		assert worker.wait()
	}
	owner.release()
}

fn test_font_cache_key_scratch_preserves_policy_sizes_and_owned_miss_keys() {
	mut computer := FontComputer.create()
	key := ComputedFontCacheKey{
		font_family:             ['Example', 'sans-serif']
		font_size:               CSSPixels.nearest_value_for(15.25)
		font_weight:             450
		font_width:              Percentage{ value_: 100 }
		font_variation_settings: {
			'wght': 475.0
		}
	}
	for policy in [platform.FontRenderingPolicy.libweb, .chromium] {
		expected := key.id() + if policy == .libweb {
			''
		} else {
			'|rendering:${policy}|size:${math.f64_bits(15.25)}'
		}
		missing, owned := computer.lookup_font_cache_key(key, policy, 15.25)
		assert missing == unsafe { nil } && owned == expected
		// A later format/reset cannot invalidate the caller's miss result.
		_, other := computer.lookup_font_cache_key(key, policy, 16.0)
		assert owned == expected
		if policy == .chromium {
			assert owned != other
		}
		cascade := FontCascadeList.create()
		computer.computed_font_cache[owned] = cascade
		found, unused := computer.lookup_font_cache_key(key, policy, 15.25)
		assert voidptr(found) == voidptr(cascade) && unused == ''
		before := platform.thread_arena_usage().used
		for _ in 0 .. 256 {
			cached, _ := computer.lookup_font_cache_key(key, policy, 15.25)
			assert voidptr(cached) == voidptr(cascade)
		}
		$if prealloc {
			assert platform.thread_arena_usage().used - before < 4096
		}
	}
}

fn test_document_font_key_scratch_is_released_with_its_owner() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut computer := FontComputer.create_for_document(document)
	_, key := computer.lookup_font_cache_key(ComputedFontCacheKey{ font_family: ['sans-serif'] }, .libweb, 16)
	assert key != ''
	arena := computer.font_key_scratch_
	assert arena.usage().capacity > 0
	document.release_native_storage()
	assert arena.usage().capacity == 0
}
