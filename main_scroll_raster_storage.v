module main

import platform

// The diff reads the preceding frame while assembling the next one. Keep
// exactly those two workspaces, including the damage vectors used by replay.
// Returning from preparation leaves the current workspace readable until the
// following frame; the older workspace can then be reset and reused.
struct ScrollRasterFrameStorage {
mut:
	current &platform.Arena = unsafe { nil }
	previous &platform.Arena = unsafe { nil }
}

struct ScrollRasterFrameScope {
mut:
	arena &platform.Arena = unsafe { nil }
	entry platform.ArenaEntry
}

fn (mut storage ScrollRasterFrameStorage) begin_frame() ScrollRasterFrameScope {
	$if prealloc {
		spare := storage.previous
		storage.previous = storage.current
		storage.current = spare
		if storage.current == unsafe { nil } {
			persistent := platform.enter_persistent()
			storage.current = platform.new_arena('scroll raster frame')
			platform.leave_persistent(persistent)
		}
		storage.current.reset()
		return ScrollRasterFrameScope{
			arena: storage.current
			entry: storage.current.enter()
		}
	}
	return ScrollRasterFrameScope{}
}

fn (mut scope ScrollRasterFrameScope) finish() {
	if scope.arena == unsafe { nil } { return }
	// The returned keys and replay decisions still belong to this frame.
	scope.arena.leave(scope.entry)
	scope.arena = unsafe { nil }
}

fn (mut frame ScrollRasterKeyFrame) release() {
	frame.valid = false
	frame.keys = []ScrollRasterCommandKey{}
	if frame.storage.current != unsafe { nil } { frame.storage.current.release() }
	if frame.storage.previous != unsafe { nil } { frame.storage.previous.release() }
	frame.storage = ScrollRasterFrameStorage{}
}
