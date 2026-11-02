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

pub fn (mut session Session) set_color(id string, color TabColor) ! {
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	mut state := session.load()!
	index := tab_index(state.tabs, id)
	if index < 0 { return }
	state.tabs[index].color = color
	session.save(state)!
	session.remember(state)
}
