module browserui

import ui2

fn test_tabs_share_controls_actions_and_accessibility() {
	strip := tab_strip(800, [Tab{ index: 2, title: 'Saved', x: 62, width: 184, selected: true, icon: '/icon.png' }], 258)
	assert strip.id == 'tab-strip'
	assert strip.children[0].id == 'window-close'
	tab := strip.children[3]
	assert tab.clickable && tab.draggable
	assert tab.action_id == 'tabdrag-2'
	assert tab.accessibility_value == 'selected'
	assert tab.children[0].image_path == '/icon.png'
	assert tab.children[2].id == 'tab-close:2'
	assert strip.children.last().id == 'tab-new'
}

fn test_shortcuts_share_platform_policy_and_preserve_editing_commands() {
	assert shortcut(ui2.KeyEvent{ code: .d, cmd: true }, true, true) == 'bookmark-add'
	assert shortcut(ui2.KeyEvent{ code: .d, ctrl: true }, true, false) == 'bookmark-add'
	assert shortcut(ui2.KeyEvent{ code: .d, cmd: true, shift: true }, false, true) == 'debug-toggle'
	assert shortcut(ui2.KeyEvent{ code: .tab, ctrl: true, shift: true }, false, true) == 'tab-previous'
	assert shortcut(ui2.KeyEvent{ code: ._8, cmd: true }, false, true) == 'tab-select:7'
	assert shortcut(ui2.KeyEvent{ code: .escape }, true, true) == 'address-cancel'
	assert shortcut(ui2.KeyEvent{ code: .left, cmd: true }, true, true) == ''
	assert shortcut(ui2.KeyEvent{ code: .kp_add, cmd: true }, true, true) == 'zoom-in'
	assert shortcut(ui2.KeyEvent{ code: .kp_subtract, cmd: true }, true, true) == 'zoom-out'
	assert shortcut(ui2.KeyEvent{ code: .kp_0, cmd: true }, true, true) == 'zoom-reset'
	assert shortcut(ui2.KeyEvent{ code: .c, cmd: true }, true, true) == ''
	assert shortcut(ui2.KeyEvent{ code: .comma, ctrl: true }, false, false) == 'settings-open'
	assert shortcut(ui2.KeyEvent{ code: .d, cmd: true, alt: true }, false, true) == ''
}
