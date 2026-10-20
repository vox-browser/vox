module css

import math
import platform

// Formatting a key is synchronous. Cache hits retain no temporary strings;
// misses copy the finished key before font matching can run callbacks/reenter.
fn (mut computer FontComputer) lookup_font_cache_key(key ComputedFontCacheKey,
	policy platform.FontRenderingPolicy, font_size_px f64) (&FontCascadeList, string) {
	mut scratch := unsafe { &platform.Arena(nil) }
	mut entry := platform.ArenaEntry{}
	$if prealloc {
		if platform.arena_thread_is_current() {
			if computer.font_key_scratch_ == unsafe { nil } {
				persistent := platform.enter_persistent()
				arena := platform.new_arena('font cache key')
				computer.font_key_scratch_ = arena
				if document := computer.document_ {
					mut owner := document.native_storage()
					if owner != unsafe { nil } {
						owner.add_cleanup(fn [arena] () {
							mut storage := unsafe { &platform.Arena(arena) }
							storage.release()
						})
					}
				}
				platform.leave_persistent(persistent)
			}
			scratch = computer.font_key_scratch_
			entry = scratch.enter()
		}
	}
	serialized := key.id() + if policy == .libweb {
		''
	} else {
		'|rendering:${policy}|size:${math.f64_bits(font_size_px)}'
	}
	if scratch != unsafe { nil } { scratch.leave(entry) }
	if cached := computer.computed_font_cache[serialized] {
		if scratch != unsafe { nil } { scratch.reset() }
		return cached, ''
	}
	owned := if scratch != unsafe { nil } { serialized.clone() } else { serialized }
	if scratch != unsafe { nil } { scratch.reset() }
	return unsafe { nil }, owned
}
