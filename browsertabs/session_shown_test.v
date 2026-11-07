module browsertabs

import os

fn test_previous_tab_hides_only_after_the_selected_tab_is_shown() {
	mut session := create(Frame{ width: 800, height: 600 })!
	defer { session.leave() or {} }
	// The creating tab's window is the one on screen.
	assert session.state.shown == session.id
	assert !session.replaced()
	pid := session.open('/bin/sleep', ['30'], false, Frame{})!
	defer {
		C.vox_tabs_terminate(i32(pid))
		C.waitpid(i32(pid), unsafe { nil }, 0)
	}
	mut child := &Session{ folder: session.folder, id: session.state.tabs[1].id.clone() }
	child.poll('Child', 'https://child.test', '', true)!
	assert child.visible()
	// Selected but not yet shown: the previous tab must keep its window up.
	session.poll('Parent', 'https://parent.test', '', true)!
	assert !session.visible()
	assert !session.replaced()
	assert child.replaced()
	child.mark_shown()!
	revision := child.revision
	child.mark_shown()!
	assert child.revision == revision
	assert !child.replaced()
	session.poll('Parent', 'https://parent.test', '', true)!
	assert session.replaced()
	// Switching back hands the window over the same way.
	session.select(0, Frame{ width: 800, height: 600 })!
	assert session.visible()
	assert session.replaced()
	child.poll('Child', 'https://child.test', '', true)!
	assert !child.replaced()
	session.mark_shown()!
	child.poll('Child', 'https://child.test', '', true)!
	assert child.replaced()
	assert !session.replaced()
	// A closed tab cannot claim the window any more.
	session.close(1, Frame{})!
	child.poll('Child', 'https://child.test', '', true)!
	child.mark_shown()!
	session.poll('Parent', 'https://parent.test', '', true)!
	assert session.state.shown == session.id
}

fn test_older_session_records_without_a_shown_tab_hide_immediately() {
	mut session := create(Frame{ width: 800, height: 600 })!
	defer { session.leave() or {} }
	os.write_file(os.join_path(session.folder, 'state.json'),
		'{"version":1,"tabs":[{"id":"${session.id}","pid":${os.getpid()},"ready":true}],"selected":"${session.id}"}')!
	session.poll('Parent', 'https://parent.test', '', true)!
	assert session.state.shown == ''
	assert session.replaced()
	session.mark_shown()!
	assert !session.replaced()
}
