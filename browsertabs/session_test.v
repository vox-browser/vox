module browsertabs

import os
import time

fn test_new_tabs_spawn_distinct_processes_and_inherit_only_session_identity() {
	mut session := create(Frame{ width: 800, height: 600 })!
	defer { session.leave() or {} }
	output := os.join_path(session.folder, 'child-environment')
	// Exercise the actual posix_spawn path, including arguments containing spaces.
	pid := session.open('/bin/sh', ['-c',
		'printf "%s\\n%s\\n%s" "$VOX_TAB_GROUP" "$VOX_TAB_ID" "$1" > "$2"; exec /bin/sleep 30',
		'vox-tab-test', 'argument with spaces', output], false, Frame{})!
	defer {
		C.vox_tabs_terminate(i32(pid))
		C.waitpid(i32(pid), unsafe { nil }, 0)
	}
	assert pid != os.getpid()
	assert session.state.tabs.len == 2
	assert session.visible() // Keep the old page visible until the child is ready.
	assert !session.state.tabs[1].ready
	assert session.state.tabs[1].activate
	for _ in 0 .. 200 {
		if os.exists(output) { break }
		time.sleep(10 * time.millisecond)
	}
	entries := os.read_file(output)!.split_into_lines()
	assert entries == [session.folder, session.state.tabs[1].id, 'argument with spaces']
	if _ := join(session.folder, session.state.tabs[1].id) {
		assert false
	}
	second := session.open('/bin/sleep', ['30'], true, Frame{})!
	defer {
		C.vox_tabs_terminate(i32(second))
		C.waitpid(i32(second), unsafe { nil }, 0)
	}
	assert second != pid && second != os.getpid()
	assert !session.state.tabs[2].activate
	assert session.visible()
	session.close(2, Frame{})!
	session.close(1, Frame{})!
	assert session.state.tabs.len == 1
}

fn test_process_selection_order_and_crash_removal_do_not_replace_document_owner() {
	mut session := create(Frame{ width: 800, height: 600 })!
	defer { session.leave() or {} }
	pid := session.open('/bin/sleep', ['30'], false, Frame{})!
	defer {
		C.vox_tabs_terminate(i32(pid))
		C.waitpid(i32(pid), unsafe { nil }, 0)
	}
	original := session.id
	child := session.state.tabs[1].id.clone()
	// Model the child's first published frame without giving it the parent's
	// document or native-window state.
	mut child_session := &Session{ folder: session.folder, id: child }
	child_session.poll('Child page', 'https://child.test', '', true)!
	assert child_session.visible()
	assert !child_session.state.tabs[1].activate
	session.select(1, Frame{ x: 12, y: 34, width: 900, height: 700 })!
	assert session.state.selected == child
	session.move(1, 0)!
	assert session.selected_index() == 0
	assert session.index() == 1
	assert session.state.tabs[1].id == original
	assert session.state.frame.x == 12
	session.detach(0)!
	assert session.state.tabs[0].detach
	C.vox_tabs_terminate(i32(pid))
	C.waitpid(i32(pid), unsafe { nil }, 0)
	session.poll('Still alive', 'https://example.test', '', true)!
	assert session.state.tabs.len == 1
	assert session.visible()
	assert session.state.tabs[0].title == 'Still alive'
	assert session.state.tabs[0].pid == os.getpid()
	revision := session.revision
	session.poll('Still alive', 'https://example.test', '', true)!
	assert session.revision == revision
	session.poll('Changed', 'https://example.test/next', '', true)!
	assert session.revision > revision
	assert session.state.tabs[0].title == 'Changed'
}

fn test_failed_spawn_and_invalid_indices_preserve_the_existing_session() {
	mut session := create(Frame{})!
	folder := session.folder
	if _ := session.open('/no-such-vox-executable', [], false, Frame{}) {
		assert false
	}
	assert session.state.tabs.len == 1
	for index in [-1, 9] {
		session.select(index, Frame{})!
		session.close(index, Frame{})!
		session.detach(index)!
		session.move(0, index)!
	}
	assert session.visible()
	session.leave()!
	assert !os.exists(folder)
}

fn C.waitpid(i32, &i32, i32) i32

fn test_failed_session_write_terminates_and_reaps_the_spawned_child() {
	mut session := create(Frame{})!
	defer { session.leave() or {} }
	temporary := os.join_path(session.folder, 'state.json.${os.getpid()}')
	os.mkdir(temporary)!
	// Keep the failure fixture intact when save() cleans up its temporary path.
	os.write_file(os.join_path(temporary, 'blocker'), '')!
	if _ := session.open('/bin/sleep', ['30'], false, Frame{}) {
		assert false
	}
	os.rmdir_all(temporary)!
	assert session.state.tabs.len == 1
	assert session.children.len == 1
	pid := session.children[0]
	defer {
		C.vox_tabs_terminate(i32(pid))
		C.waitpid(i32(pid), unsafe { nil }, 0)
	}
	for _ in 0 .. 200 {
		session.poll('Existing tab', '', '', true)!
		if session.children.len == 0 { break }
		time.sleep(10 * time.millisecond)
	}
	assert session.children.len == 0
	assert C.vox_tabs_alive(i32(pid)) == 0
	assert session.visible()
}

fn test_detach_preserves_the_process_and_child_reaping() {
	mut session := create(Frame{})!
	folder := session.folder
	pid := session.open('/bin/sleep', ['30'], true, Frame{})!
	defer {
		C.vox_tabs_terminate(i32(pid))
		C.waitpid(i32(pid), unsafe { nil }, 0)
		os.rmdir_all(folder) or {}
	}
	mut detached := session.detach_self(Frame{ x: 40, y: 80 })!
	defer { detached.leave() or {} }
	assert detached.folder != folder
	assert detached.state.tabs.len == 1
	assert detached.state.tabs[0].pid == os.getpid()
	assert detached.state.frame.x == 40
	assert detached.children == [pid]
	assert session.children.len == 0
	remaining := session.load()!
	assert remaining.tabs.len == 1
	assert remaining.tabs[0].pid == pid
}
