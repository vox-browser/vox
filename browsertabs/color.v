module browsertabs

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
