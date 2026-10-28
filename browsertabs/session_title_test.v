module browsertabs

import os
import platform

fn test_tab_titles_survive_replacing_and_reusing_session_metadata() {
	mut session := create(Frame{ width: 1024, height: 768 })!
	defer { session.leave() or {} }
	assert session.state.tabs[0].title == 'New Tab'
	for title in ['https://www.wikipedia.org/', 'Wikipedia', 'Wikipedia', 'Next title'] {
		session.poll(title, 'https://www.wikipedia.org/', '', true)!
		assert session.state.tabs.len == 1
		assert session.state.tabs[0].title == title
		assert session.state.tabs[0].url == 'https://www.wikipedia.org/'
		assert session.state.tabs[0].pid == os.getpid()
		// Recycle the same scratch allocator between timer callbacks. Decoder
		// metadata must outlive both this scratch work and the previous snapshot.
		scratch := platform.begin_thread_scratch('between tab title polls')
		bytes := []u8{len: 64 * 1024, init: u8(0xa5)}
		assert bytes[bytes.len - 1] == 0xa5
		scratch.finish()
	}
	assert session.revision == 4
}
