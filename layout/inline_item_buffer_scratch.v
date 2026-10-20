module layout

import dom
import platform

// Item records are synchronous iterator input. Their node/glyph payloads keep
// their own owners; only the wide outer vectors use this reusable UI pool.
@[heap]
struct InlineItemBufferPool {
mut:
	arenas []&platform.Arena
	depth int
}

struct InlineItemBufferScope {
mut:
	pool &InlineItemBufferPool = unsafe { nil }
	arena &platform.Arena = unsafe { nil }
}

__global inline_item_buffer_pool_ &InlineItemBufferPool

fn acquire_inline_item_buffers(document &dom.Document) InlineItemBufferScope {
	$if prealloc {
		if document.native_storage() != unsafe { nil } && platform.arena_thread_is_current() {
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			if inline_item_buffer_pool_ == unsafe { nil } {
				inline_item_buffer_pool_ = &InlineItemBufferPool{}
			}
			mut pool := inline_item_buffer_pool_
			if pool.depth == pool.arenas.len { pool.arenas << platform.new_arena('inline iterator item records') }
			arena := pool.arenas[pool.depth]
			pool.depth++
			return InlineItemBufferScope{pool:pool,arena:arena}
		}
	}
	return InlineItemBufferScope{}
}

fn (mut scope InlineItemBufferScope) finish() {
	if scope.pool == unsafe { nil } { return }
	assert scope.pool.depth > 0
	assert voidptr(scope.pool.arenas[scope.pool.depth - 1]) == voidptr(scope.arena)
	scope.arena.reset()
	scope.pool.depth--
	scope.pool = unsafe { nil }
}
