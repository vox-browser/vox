module browsertabs

fn test_tab_colors_follow_stable_process_owners_and_survive_poll_and_detach() {
	mut session := create(Frame{})!
	defer { session.leave() or {} }
	original := session.id.clone()
	session.set_color(original, .blue)!
	session.poll('Colored tab', 'https://example.test', '', true)!
	assert session.state.tabs[0].color == .blue
	// Another process's fresh disk read sees the color too.
	mut reader := join(session.folder, original)!
	assert reader.state.tabs[0].color == .blue
	session.set_color('closed-tab', .red)!
	assert session.state.tabs[0].color == .blue
	mut detached := session.detach_self(Frame{})!
	defer { detached.leave() or {} }
	assert detached.state.tabs[0].color == .blue
	detached.set_color(detached.id, .none)!
	assert detached.state.tabs[0].color == .none
}
