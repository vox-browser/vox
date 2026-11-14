module browsertabs

import os
import rand
import platform
import time

#include "@DIR/process.h"

fn C.vox_tabs_lock(&char) i32
fn C.vox_tabs_unlock(i32)
fn C.vox_tabs_spawn(&char, &&char, &&char) i32
fn C.vox_tabs_alive(i32) i32
fn C.vox_tabs_terminate(i32)
fn C.vox_tabs_reap(i32) i32
fn C.vox_tabs_create_directory(&char) i32
fn C.vox_tabs_watch(&char, fn (voidptr), voidptr) i32

// Only chrome metadata crosses this boundary. Documents, JSC realms, native
// renderers and their allocation arenas stay entirely in their owning process.
@[heap]
pub struct Session {
pub:
	folder string
	id     string
pub mut:
	state    State
	revision u64
mut:
	children    []int
	storage     &platform.RetainedArena = unsafe { nil }
	encoded     string
	reopen_seen u64
	last_poll_ns u64
	poll_invalidated bool
}

pub fn create(frame Frame) !&Session {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	initialize_session_codec()!
	folder := create_session_directory(os.temp_dir())!
	os.chmod(folder, 0o700)!
	id := rand.uuid_v4()
	mut session := &Session{ folder: folder.clone(), id: id.clone() }
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	state := State{ tabs: [Tab{ id: id, pid: os.getpid(), ready: true }], selected: id, shown: id, frame: frame }
	session.save(state)!
	session.remember(state)
	return session
}

// A stale process's directory must never be selected again when an application
// PRNG sequence repeats. The OS reserves the name and creates it atomically.
fn create_session_directory(root string) !string {
	mut pattern := os.join_path(root, 'vox-tabs-XXXXXX').bytes()
	pattern << u8(0)
	code := C.vox_tabs_create_directory(&char(pattern.data))
	if code != 0 {
		return error_with_code('could not create tab session directory in ${root}', int(code))
	}
	return unsafe { tos_clone(&pattern[0]) }
}

pub fn join(folder string, id string) !&Session {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	initialize_session_codec()!
	if !os.is_abs_path(folder) || id == '' { return error('invalid tab process session') }
	mut session := &Session{ folder: folder.clone(), id: id.clone() }
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	state := session.load()!
	if !state.tabs.any(it.id == id && it.pid == os.getpid()) {
		return error('tab process is no longer in its session')
	}
	session.remember(state)
	return session
}

fn initialize_session_codec() ! {
	// Both codecs cache field metadata for the lifetime of the process. Warm
	// every nested record in the caller's persistent allocation scope before
	// remember() can initialize the decoder in a replaceable metadata arena.
	_ = decode_session_state(encode_session_state(State{ tabs: [Tab{}] }))!
}

fn (session &Session) lock() !i32 {
	path := os.join_path(session.folder, 'lock')
	fd := C.vox_tabs_lock(&char(path.str))
	if fd < 0 { return error('could not lock tab session') }
	return fd
}

fn (session &Session) load() !State {
	state := decode_session_state(os.read_file(os.join_path(session.folder, 'state.json'))!)!
	if state.version != 1 { return error('unsupported tab session') }
	return state
}

fn (session &Session) save(state State) ! {
	path := os.join_path(session.folder, 'state.json')
	temporary := '${path}.${os.getpid()}'
	defer { os.rm(temporary) or {} }
	os.write_file(temporary, encode_session_state(state))!
	os.chmod(temporary, 0o600)!
	os.rename(temporary, path)!
}

fn (mut state State) remove(id string) {
	index := tab_index(state.tabs, id)
	if index < 0 { return }
	state.tabs.delete(index)
	if state.selected == id {
		state.selected = ''
		for i := index; i >= 0; i-- {
			if i < state.tabs.len && state.tabs[i].ready {
				state.selected = state.tabs[i].id
				break
			}
		}
		if state.selected == '' {
			for tab in state.tabs {
				if tab.ready {
					state.selected = tab.id
					break
				}
			}
		}
	}
}

fn tab_index(tabs []Tab, id string) int {
	for i, tab in tabs { if tab.id == id { return i } }
	return -1
}

pub fn (session &Session) find(id string) int { return tab_index(session.state.tabs, id) }

pub fn (session &Session) index() int {
	return tab_index(session.state.tabs, session.id)
}

pub fn (session &Session) selected_index() int {
	return tab_index(session.state.tabs, session.state.selected)
}

pub fn (session &Session) visible() bool { return session.state.selected == session.id }

// replaced reports that another tab's window has been shown since this tab's.
pub fn (session &Session) replaced() bool { return session.state.shown != session.id }

// mark_shown publishes that this tab's window now covers the group's window
// area, so the previously shown tab can hide its own.
pub fn (mut session Session) mark_shown() ! {
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	mut state := session.load()!
	if state.shown == session.id || tab_index(state.tabs, session.id) < 0 { return }
	state.shown = session.id
	session.save(state)!
	session.remember(state)
}

// watch calls `changed(context)` on the main thread soon after any process
// saves the session state, so a tab reacts to a switch without waiting for
// its next poll. A later call replaces the watched session. It is available
// on macOS only; elsewhere tabs rely on polling.
pub fn (session &Session) watch(changed fn (voidptr), context voidptr) bool {
	return C.vox_tabs_watch(&char(session.folder.str), changed, context) == 0
}

// LaunchServices can reopen the original, now hidden tab process. Publish the
// request to the group so its selected document keeps ownership of the window.
pub fn (mut session Session) request_reopen() ! {
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	mut state := session.load()!
	state.reopen++
	session.save(state)!
	session.remember(state)
}

pub fn (mut session Session) take_reopen_request() bool {
	pending := session.reopen_seen != session.state.reopen
	session.reopen_seen = session.state.reopen
	return pending && session.visible()
}

// A dead tab is removed without affecting its siblings. Each launcher reaps
// only its own children; closing the original process does not own their lives.
pub fn (mut session Session) poll(title string, address string, favicon string, ready bool) ! {
	session.poll_loading(title, address, favicon, ready, false)!
}

// Loading is independent of readiness to show the native window. A tab can
// present its first frame while its document and subresources are still loading.
pub fn (mut session Session) poll_loading(title string, address string, favicon string, ready bool, loading bool) ! {
	scratch := platform.begin_thread_scratch('tab session poll')
	defer { scratch.finish() }
	session.poll_invalidated = false
	session.poll_state(title, address, favicon, ready, loading) or {
		session.poll_invalidated = true
		scratch.leave()
		return error(err.msg().clone())
	}
	session.last_poll_ns = time.sys_mono_now()
}

// Frames can arrive much faster than the session's 100 ms housekeeping timer.
// Publish local metadata immediately; the directory watcher also bypasses the
// interval for remote changes. The timer remains the fallback on every OS,
// including for crashed children which cannot publish their own removal.
pub fn (mut session Session) poll_loading_if_due(title string, address string, favicon string, ready bool, loading bool) ! {
	index := session.index()
	if index >= 0 && !session.poll_invalidated && session.last_poll_ns > 0
		&& time.sys_mono_now() < session.last_poll_ns + 100_000_000 {
		tab := session.state.tabs[index]
		if tab.title == title && tab.url == address && tab.favicon == favicon
			&& tab.loading == loading && (tab.ready || !ready) { return }
	}
	session.poll_loading(title, address, favicon, ready, loading)!
}

pub fn (mut session Session) invalidate_poll() {
	session.poll_invalidated = true
}

fn (mut session Session) poll_state(title string, address string, favicon string, ready bool, loading bool) ! {
	for i := session.children.len - 1; i >= 0; i-- {
		if C.vox_tabs_reap(i32(session.children[i])) != 0 { session.children.delete(i) }
	}
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	mut state := session.load()!
	before := encode_session_state(state)
	for tab in state.tabs.clone() {
		if C.vox_tabs_alive(i32(tab.pid)) == 0 { state.remove(tab.id) }
	}
	index := tab_index(state.tabs, session.id)
	if index >= 0 {
		mut tab := state.tabs[index]
		tab.title = title
		tab.url = address
		tab.favicon = favicon
		tab.loading = loading
		if ready && !tab.ready {
			tab.ready = true
			if tab.activate { state.selected = tab.id }
			tab.activate = false
		}
		state.tabs[index] = tab
	}
	if encode_session_state(state) != before { session.save(state)! }
	session.remember(state)
}

pub fn (mut session Session) open(executable string, arguments []string, background bool, frame Frame) !int {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	mut state := session.load()!
	id := rand.uuid_v4()
	mut environment := os.environ()
	environment['VOX_TAB_GROUP'] = session.folder
	environment['VOX_TAB_ID'] = id
	mut entries := []string{}
	for key, value in environment { entries << '${key}=${value}' }
	mut argv := []&char{}
	argv << &char(executable.str)
	for argument in arguments { argv << &char(argument.str) }
	argv << unsafe { &char(nil) }
	mut envp := []&char{}
	for entry in entries { envp << &char(entry.str) }
	envp << unsafe { &char(nil) }
	pid := int(C.vox_tabs_spawn(&char(executable.str), argv.data, envp.data))
	if pid <= 0 { return error('could not start tab process') }
	if !background {
		for mut tab in state.tabs { tab.activate = false }
	}
	state.tabs << Tab{ id: id, pid: pid, activate: !background, loading: true }
	state.frame = frame
	// Retain ownership even if publishing the new tab fails: the terminated
	// child still needs to be reaped by the next poll.
	session.children << pid
	session.save(state) or {
		C.vox_tabs_terminate(i32(pid))
		return err
	}
	session.remember(state)
	return pid
}

pub fn (mut session Session) select(index int, frame Frame) ! {
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	mut state := session.load()!
	if index < 0 || index >= state.tabs.len { return }
	// Selecting a starting tab transfers focus when its first frame is ready.
	for mut tab in state.tabs { tab.activate = false }
	if state.tabs[index].ready {
		state.selected = state.tabs[index].id
	} else {
		state.tabs[index].activate = true
	}
	state.frame = frame
	session.save(state)!
	session.remember(state)
}

pub fn (mut session Session) move(from int, to int) ! {
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	mut state := session.load()!
	if from < 0 || to < 0 || from >= state.tabs.len || to >= state.tabs.len { return }
	tab := state.tabs[from]
	state.tabs.delete(from)
	state.tabs.insert(to, tab)
	session.save(state)!
	session.remember(state)
}

pub fn (mut session Session) detach(index int) ! {
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	mut state := session.load()!
	if index < 0 || index >= state.tabs.len { return }
	state.tabs[index].detach = true
	session.save(state)!
	session.remember(state)
}

// The same live document moves to a new window group. Keep reaping children
// launched before detaching, even though their tab metadata stays in that group.
pub fn (mut session Session) detach_self(frame Frame) !&Session {
	mut detached := create(frame)!
	index := session.index()
	if index >= 0 {
		detached.set_color(detached.id, session.state.tabs[index].color) or {
			detached.leave() or {}
			return err
		}
		detached.set_custom_title(detached.id, session.state.tabs[index].custom_title) or {
			detached.leave() or {}
			return err
		}
	}
	session.leave() or {
		detached.leave() or {}
		return err
	}
	detached.children = session.children
	session.children = []int{}
	return detached
}

pub fn (mut session Session) close(index int, frame Frame) ! {
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	mut state := session.load()!
	if index < 0 || index >= state.tabs.len { return }
	tab := state.tabs[index]
	state.remove(tab.id)
	state.frame = frame
	session.save(state)!
	session.remember(state)
	// A hung page must also be closable from another tab's responsive chrome.
	if tab.id != session.id { C.vox_tabs_terminate(i32(tab.pid)) }
}

pub fn (mut session Session) leave() ! {
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	mut state := session.load()!
	state.remove(session.id)
	session.save(state)!
	session.remember(state)
	if state.tabs.len == 0 { os.rmdir_all(session.folder)! }
}

// Replace the metadata arena only when chrome changes. Idle polling allocates
// entirely in scratch storage, including JSON decoding under -prealloc.
fn (mut session Session) remember(state State) {
	encoded := encode_session_state(state)
	if encoded == session.encoded { return }
	mut storage := platform.new_retained_arena('tab session metadata')
	mut scope := storage.enter_nested()
	session.encoded = encoded.clone()
	session.state = decode_session_state(session.encoded) or { panic(err) }
	session.revision++
	scope.finish()
	if session.storage != unsafe { nil } { session.storage.release() }
	session.storage = storage
}

pub fn (session &Session) encoded_state() string { return session.encoded }

// Native window close / application quit closes the complete visible group.
// A tab close removes only that tab and exits through leave() instead.
pub fn (mut session Session) shutdown() ! {
	fd := session.lock()!
	defer { C.vox_tabs_unlock(fd) }
	state := session.load()!
	session.save(State{})!
	for tab in state.tabs {
		if tab.id != session.id { C.vox_tabs_terminate(i32(tab.pid)) }
	}
	os.rmdir_all(session.folder)!
}
