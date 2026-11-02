module browsertabs

pub fn normalize_custom_title(title string) string {
	return title.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ').trim_space()
}

// Keep the page's live title separate: polling/navigation must not erase a rename.
pub fn (mut session Session) set_custom_title(id string, title string) ! {
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	mut state := session.load()!
	index := tab_index(state.tabs, id)
	if index < 0 { return }
	state.tabs[index].custom_title = normalize_custom_title(title)
	session.save(state)!
	session.remember(state)
}
