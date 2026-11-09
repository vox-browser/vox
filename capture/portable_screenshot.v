module main

// The application owns a pending portable capture across tab switches.
// Keep scheduling separate from the frame's GPU readback and process exit.
struct PortableScreenshotState {
mut:
	pending ?PendingPortableScreenshot
}

struct PendingPortableScreenshot {
	path   string
	due_ns i64
}

fn (mut state PortableScreenshotState) schedule(path string, now_ns i64, delay_ns i64) {
	if path == '' {
		state.pending = none
		return
	}
	state.pending = PendingPortableScreenshot{
		path:   path.clone()
		due_ns: now_ns + delay_ns
	}
}

fn (state &PortableScreenshotState) ready_path(now_ns i64) ?string {
	pending := state.pending or { return none }
	if now_ns < pending.due_ns { return none }
	return pending.path
}
