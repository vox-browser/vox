module browsertabs

import os

fn test_custom_titles_survive_navigation_polling_reorder_reload_and_detach() {
	mut session := create(Frame{})!
	defer { session.leave() or {} }
	id := session.id.clone()
	session.set_custom_title(id, '  Research — 資料\n2026\t ')!
	session.poll('Page title', 'https://example.test', '', true)!
	assert session.state.tabs[0].custom_title == 'Research — 資料 2026'
	assert session.state.tabs[0].title == 'Page title'
	pid := session.open('/bin/sleep', ['30'], true, Frame{})!
	defer {
		C.vox_tabs_terminate(i32(pid))
		C.waitpid(i32(pid), unsafe { nil }, 0)
	}
	session.move(0, 1)!
	session.set_custom_title(id, 'Renamed again')!
	assert session.state.tabs[1].id == id && session.state.tabs[1].custom_title == 'Renamed again'
	assert session.state.tabs[0].custom_title == ''
	session.poll('Navigated page', 'https://example.test/next', '', true)!
	reader := join(session.folder, id)!
	assert reader.state.tabs[1].custom_title == 'Renamed again'
	assert reader.state.tabs[1].title == 'Navigated page'
	session.set_custom_title('closed-tab', 'Ignore')!
	assert session.state.tabs[0].custom_title == ''
	mut detached := session.detach_self(Frame{})!
	defer { detached.leave() or {} }
	assert detached.state.tabs[0].custom_title == 'Renamed again'
	detached.set_custom_title(detached.id, ' \r\n\t ')!
	assert detached.state.tabs[0].custom_title == ''
	// The original group still owns the sleeping child.
	session.close(0, Frame{})!
	assert pid != os.getpid()
}

fn C.waitpid(i32, &i32, i32) i32
