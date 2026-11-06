module browserui

import ui2

fn test_find_shortcuts() {
	assert shortcut(ui2.KeyEvent{ code: .f, cmd: true }, false, true) == 'find-open'
	assert shortcut(ui2.KeyEvent{ code: .g, cmd: true }, false, true) == 'find-next'
	assert shortcut(ui2.KeyEvent{ code: .g, cmd: true, shift: true }, false, true) == 'find-previous'
}

fn test_find_bar_status_and_actions() {
	mut bar := FindBar{ token: 7, query: 'a' }
	assert bar.status() == ''
	bar.searched = true
	bar.total = 0
	assert bar.status() == 'Not found'
	bar.total = 5
	bar.current = 2
	assert bar.status() == '2 of 5'
	assert bar.action('next') == 'find-bar:7:next'
	assert bar.input_id() == 'find-input-7'
}

fn test_find_bar_elements() {
	elements := (FindBar{ token: 1 }).elements(800, 80)
	assert elements.len == 1
	assert elements[0].id == 'find-bar'
}
