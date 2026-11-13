module browsertabs

// Session metadata follows the tab owner through selection, reordering and detach.
pub enum TabColor {
	none
	red
	orange
	yellow
	green
	blue
	purple
	pink
}

pub struct Tab {
pub mut:
	id           string
	pid          int
	title        string = 'New Tab'
	custom_title string
	url          string
	favicon      string
	loading      bool
	color        TabColor
	ready        bool
	activate     bool
	detach       bool
	// hibernated marks a background tab whose live content was discarded to
	// reclaim memory. Only metadata (title, url, favicon) is retained until
	// the tab is selected again. The selected tab is never hibernated.
	hibernated   bool
	hibernated_at i64
}

pub struct Frame {
pub mut:
	x      f64
	y      f64
	width  f64
	height f64
}

pub struct State {
pub mut:
	version  int = 1
	tabs     []Tab
	selected string
	// The tab whose window is on screen. A newly selected tab orders its window
	// over the previous one before publishing itself here, and the previous
	// tab hides only afterwards, so a switch never leaves the screen without a
	// browser window.
	shown  string
	frame  Frame
	reopen u64
}
