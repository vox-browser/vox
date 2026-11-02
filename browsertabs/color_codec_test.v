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
	restored := json2.decode[State](json2.encode(state))!
	assert restored.tabs[0].color == .blue
	assert restored.tabs[0].custom_title == 'Research'
}
