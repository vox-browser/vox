// Module browserwindow performs the operating-system side of the browser's
// host window: its title-bar-less UI2 host, saved geometry, process-tab
// visibility, detached tab windows, history swipe gestures and the native
// event pump used during long document work. Placement, persistence and
// gesture policy stay in browserui and module main.
module browserwindow

// Frame is a window or screen rectangle in AppKit screen coordinates, whose
// origin is the bottom left of the primary screen.
pub struct Frame {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

// Snapshot is a window's frame, minimum size and presentation state.
pub struct Snapshot {
pub:
	frame        Frame
	min_width    f64
	min_height   f64
	zoomed       bool
	fullscreen   bool
	miniaturized bool
}

// The window events delivered to observers, in the numbering that
// browserui.WindowState.update expects.
pub const event_changed = 0
pub const event_will_enter_fullscreen = 1
pub const event_did_enter_fullscreen = 2
pub const event_will_exit_fullscreen = 3
pub const event_did_exit_fullscreen = 4
pub const event_closing = 5

// WindowEventFn receives each observed window event with a fresh snapshot.
pub type WindowEventFn = fn (owner voidptr, kind int, snapshot Snapshot)

// The history swipe callbacks keep C-compatible arguments: AppKit invokes
// them from its event monitor and gesture-tracking handlers.
pub type SwipeBeginFn = fn (owner voidptr, delta i32, x f64, y f64, wheel_x f64, wheel_y f64, document &voidptr) i32

pub type SwipeFilterFn = fn (owner voidptr, phase i32, momentum i32, precise i32, enabled i32, modifiers u32, x f64, y f64) i32

pub type SwipeCaptureFn = fn (owner voidptr, expected u64) u64

pub type SwipeProgressFn = fn (owner voidptr, document voidptr, generation u64, amount f64, phase i32, complete i32, delta i32) i32
