module browsertabs

import os

fn hibernation_test_background(mut session Session) ! {
	mut state := session.load()!
	state.tabs << Tab{
		id:    'background-tab'
		pid:   424242
		title: 'Background'
		url:   'https://background.test/'
		ready: true
	}
	session.save(state)!
	session.remember(state)
}

fn test_tab_hibernation_marks_wakes_and_survives_selection() {
	mut session := create(Frame{})!
	defer {
		session.leave() or {}
		os.rmdir_all(session.folder) or {}
	}
	hibernation_test_background(mut session)!
	assert session.state.tabs.len == 2
	assert !session.is_hibernated(1)

	session.hibernate(1)!
	assert session.is_hibernated(1)
	assert session.state.tabs[1].hibernated
	assert session.state.tabs[1].hibernated_at > 0
	assert !session.state.tabs[1].loading

	// Re-hibernating is a no-op that keeps the original timestamp.
	stamp := session.state.tabs[1].hibernated_at
	session.hibernate(1)!
	assert session.state.tabs[1].hibernated_at == stamp

	// Reloading from disk preserves the mark.
	assert session.load()!.tabs[1].hibernated

	// Explicit wake clears the mark without selecting.
	session.wake(1)!
	assert !session.is_hibernated(1)
	assert session.state.tabs[1].hibernated_at == 0

	// Waking a live tab is a no-op.
	session.wake(1)!

	// Selecting a hibernated tab wakes it as part of the switch.
	session.hibernate(1)!
	session.select(1, Frame{})!
	assert !session.is_hibernated(1)
	assert session.state.selected == 'background-tab'

	// The selected tab can never hibernate.
	if _ := session.hibernate(1) {
		assert false, 'hibernating the selected tab must fail'
	}
	assert !session.is_hibernated(1)
}

fn test_tab_hibernation_rejects_invalid_indices_and_old_sessions() {
	mut session := create(Frame{})!
	defer {
		session.leave() or {}
		os.rmdir_all(session.folder) or {}
	}
	hibernation_test_background(mut session)!
	// Out-of-range indices are ignored like the other session mutations.
	session.hibernate(-1)!
	session.hibernate(9)!
	session.wake(-1)!
	session.wake(9)!
	assert !session.is_hibernated(-1)
	assert !session.is_hibernated(9)
	assert session.state.tabs.len == 2

	// Sessions written before hibernation existed decode with a live tab.
	legacy := '{"version":1,"tabs":[{"id":"legacy","pid":7,"title":"Legacy"}],"selected":"legacy","shown":"legacy","frame":{"x":0,"y":0,"width":0,"height":0},"reopen":0}'
	decoded := decode_session_state(legacy)!
	assert !decoded.tabs[0].hibernated
	assert decoded.tabs[0].hibernated_at == 0
}
