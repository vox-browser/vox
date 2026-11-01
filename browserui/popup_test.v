module browserui

fn test_popup_retains_row_semantics_and_skips_unselectable_entries() {
	mut popup := Popup{
		token: 7
		x:     790
		y:     590
		rows:  [
			MenuRow{ text: 'Group', group: true },
			MenuRow{ id: 'off', text: 'Disabled', enabled: false },
			MenuRow{ id: '42', text: 'Chosen', indent: 1, checked: true },
			MenuRow{ separator: true },
			MenuRow{ id: '99', text: 'Other' },
		]
	}
	assert popup.action(0) == '' && popup.action(1) == '' && popup.action(3) == ''
	popup.key('down')
	assert popup.active == 2
	assert popup.key('enter') == 'browser-menu:7:42'
	popup.key('up')
	assert popup.active == 4
	assert popup.key('escape') == 'browser-menu:7:dismiss'
	list := popup.elements(800, 600)[0].children[1]
	assert list.frame.x + list.frame.width <= 796
	assert list.frame.y + list.frame.height <= 596
	assert list.children[0].text_style.bold
	assert !list.children[1].enabled
	assert list.children[2].accessibility_value == 'selected'
	assert list.children[3].frame.height == 1
}
