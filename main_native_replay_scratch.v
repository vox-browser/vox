module main

import platform

struct NativeReplayScratchScope {
mut:
	arena &platform.Arena = unsafe { nil }
	entry platform.ArenaEntry
}

fn (mut app BrowserApp) begin_native_replay_scratch() NativeReplayScratchScope {
	$if prealloc {
		$if macos {
			if app.ctx != unsafe { nil } && app.ctx.native_rendering {
				if app.native_replay_scratch == unsafe { nil } {
					persistent := platform.enter_persistent()
					app.native_replay_scratch = platform.new_arena('native command replay')
					platform.leave_persistent(persistent)
				}
				return NativeReplayScratchScope{
					arena: app.native_replay_scratch
					entry: app.native_replay_scratch.enter()
				}
			}
		}
	}
	return NativeReplayScratchScope{}
}

fn (mut scope NativeReplayScratchScope) finish() {
	if scope.arena == unsafe { nil } { return }
	scope.arena.leave(scope.entry)
	scope.arena.reset()
	scope.arena = unsafe { nil }
}

fn (mut app BrowserApp) release_native_replay_scratch() {
	if app.native_replay_scratch == unsafe { nil } { return }
	app.native_replay_scratch.release()
	app.native_replay_scratch = unsafe { nil }
}
