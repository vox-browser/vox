module browsertabs

import os

fn test_loading_metadata_is_shared_without_changing_window_readiness_or_favicons() {
	mut owner := create(Frame{})!
	defer { owner.leave() or {} }
	mut observer := join(owner.folder, owner.id)!
	owner.poll_loading('Site', 'https://loading.test/', 'data:image/png;base64,icon', true, true)!
	observer.poll_loading('Site', 'https://loading.test/', 'data:image/png;base64,icon', true, true)!
	assert observer.state.tabs[0].loading && observer.state.tabs[0].ready
	assert observer.state.tabs[0].pid == os.getpid()
	assert observer.visible()
	revision := observer.revision
	observer.poll_loading('Site', 'https://loading.test/', 'data:image/png;base64,icon', true, true)!
	assert observer.revision == revision
	owner.poll_loading('Site', 'https://loading.test/', 'data:image/png;base64,icon', true, false)!
	finished := observer.load()!
	assert !finished.tabs[0].loading && finished.tabs[0].ready
	assert finished.tabs[0].favicon == 'data:image/png;base64,icon'
	assert finished.selected == owner.id
}

fn test_new_background_process_tab_is_loading_before_its_first_metadata_poll() {
	mut session := create(Frame{})!
	defer { session.leave() or {} }
	pid := session.open('/bin/sleep', ['30'], true, Frame{})!
	defer {
		C.vox_tabs_terminate(i32(pid))
		C.waitpid(i32(pid), unsafe { nil }, 0)
	}
	assert session.state.tabs[1].loading && !session.state.tabs[1].ready
	assert session.visible()
	session.move(1, 0)!
	assert session.state.tabs[0].loading && session.state.tabs[0].pid == pid
}
