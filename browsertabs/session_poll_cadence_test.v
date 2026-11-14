module browsertabs

import os

fn test_frame_poll_skips_unchanged_session_io_but_publishes_local_changes() {
	mut session := create(Frame{})!
	defer { session.leave() or {} }
	session.poll_loading_if_due('Page', 'https://example.test/', '', true, false)!
	// Pin the clock inside the interval, independently of test host load.
	session.last_poll_ns += 1_000_000_000
	lock_path := os.join_path(session.folder, 'lock')
	os.rm(lock_path)!
	os.mkdir(lock_path)!
	// Locking this path fails. An unchanged frame must not touch it.
	session.poll_loading_if_due('Page', 'https://example.test/', '', true, false)!
	if _ := session.poll_loading_if_due('New title', 'https://example.test/', '', true, false) {
		assert false, 'title changes must publish immediately'
	}
	os.rmdir(lock_path)!
	session.poll_loading_if_due('New title', 'https://example.test/', '', true, true)!
	assert session.state.tabs[0].title == 'New title'
	assert session.state.tabs[0].loading
	session.poll_loading_if_due('New title', 'https://example.test/next', 'icon', true, false)!
	assert session.state.tabs[0].url == 'https://example.test/next'
	assert session.state.tabs[0].favicon == 'icon'
	assert !session.state.tabs[0].loading
}

fn test_frame_poll_watcher_and_housekeeping_bypass_the_interval() {
	mut session := create(Frame{})!
	defer { session.leave() or {} }
	session.poll_loading_if_due('Page', '', '', true, false)!
	mut remote := &Session{folder: session.folder, id: session.id}
	mut state := remote.load()!
	state.reopen++
	remote.save(state)!
	session.last_poll_ns += 1_000_000_000
	session.invalidate_poll()
	session.poll_loading_if_due('Page', '', '', true, false)!
	assert session.state.reopen == state.reopen
	assert !session.poll_invalidated
	state.reopen++
	remote.save(state)!
	session.last_poll_ns = 0
	session.poll_loading_if_due('Page', '', '', true, false)!
	assert session.state.reopen == state.reopen
}

fn test_frame_poll_publishes_first_ready_state_without_waiting() {
	mut session := create(Frame{})!
	defer { session.leave() or {} }
	mut state := session.load()!
	state.tabs[0].ready = false
	session.save(state)!
	session.poll_loading('Loading', '', '', false, true)!
	session.last_poll_ns += 1_000_000_000
	session.poll_loading_if_due('Loading', '', '', true, true)!
	assert session.state.tabs[0].ready
}
