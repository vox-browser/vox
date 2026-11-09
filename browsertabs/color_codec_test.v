module browsertabs

import json2

struct Color {
	red int
}

fn test_tab_color_codec_does_not_collide_with_a_color_record() {
	// The browser also decodes CSS Color records. A distinct enum name avoids
	// generic type binding collisions in the current V JSON decoder.
	assert json2.decode[Color]('{"red":123}')!.red == 123
	state := State{ tabs: [Tab{ color: .blue, custom_title: 'Research' }] }
	restored := decode_session_state(encode_session_state(state))!
	assert restored.tabs[0].color == .blue
	assert restored.tabs[0].custom_title == 'Research'
}

fn test_session_metadata_round_trips_every_color_and_process_field() {
	colors := [TabColor.none, .red, .orange, .yellow, .green, .blue, .purple, .pink]
	names := ['none', 'red', 'orange', 'yellow', 'green', 'blue', 'purple', 'pink']
	mut tabs := []Tab{}
	for index, color in colors {
		tabs << Tab{
			id:           'tab-${index}'
			pid:          4_294_967_297 + index
			title:        'Page "${index}"\n資料'
			custom_title: 'Research \\ ${index}'
			url:          'https://example.test/${index}?a=1&b=2'
			favicon:      'data:image/svg+xml,<svg/>'
			loading:      index % 2 == 0
			color:        color
			ready:        index % 3 == 0
			activate:     index % 3 == 1
			detach:       index % 3 == 2
		}
	}
	state := State{
		tabs:     tabs
		selected: 'tab-5'
		shown:    'tab-2'
		frame:    Frame{ x: -12.5, y: 34.5, width: 900.25, height: 700.75 }
		reopen:   u64(18_446_744_073_709_551_615)
	}
	encoded := encode_session_state(state)
	for name in names {
		assert encoded.contains('"color":"${name}"')
	}
	restored := decode_session_state(encoded)!
	assert restored == state
	// Polling compares this representation before replacing retained metadata.
	assert encode_session_state(restored) == encoded
}

fn test_session_metadata_reads_version_one_color_names_and_older_defaults() {
	state := decode_session_state('{"version":1,"tabs":[{"id":"old","pid":123,"color":"purple"},{"id":"older"}],"selected":"old","frame":{}}')!
	assert state.tabs.len == 2
	assert state.tabs[0].color == .purple
	assert state.tabs[0].pid == 123
	assert state.tabs[1].color == .none
	assert state.tabs[1].title == 'New Tab'
	assert !state.tabs[1].ready && !state.tabs[1].loading
	assert state.selected == 'old'
	assert state.shown == ''
	assert state.reopen == 0
}

fn test_session_metadata_rejects_unknown_color_names() {
	for color in ['', 'Blue', 'ultraviolet'] {
		if _ := decode_session_state('{"tabs":[{"color":${json2.encode(color)}}]}') {
			assert false, 'invalid stored colors must not silently become the default'
		}
	}
}

fn test_session_metadata_rejects_malformed_records() {
	for source in ['{', '{"tabs":false}', '{"tabs":[{"color":{}}]}'] {
		if _ := decode_session_state(source) {
			assert false, 'malformed metadata must not replace a session'
		}
	}
}
