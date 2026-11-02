module bookmarkui

import ui2

fn test_shared_bookmark_declaration_preserves_actions_icons_and_accessibility() {
	state := State{
		width:   800
		height:  600
		top:     60
		visible: true
		items:   [
			Item{ title: 'Saved café', url: 'https://example.com/', icon: '/cache/icon.png' },
		]
	}
	bar := elements(state)[0]
	assert bar.id == 'bookmarks-bar'
	assert bar.frame == ui2.rect(0, 60, 800, 28)
	assert bar.accessibility_label == 'Bookmarks bar'
	button := bar.children[0]
	assert button.kind == .button
	assert button.native_style && button.box.transparent
	assert button.id == 'bookmark-open:0'
	assert button.image_path == '/cache/icon.png'
	assert button.button_image_size == 16
	assert ui2.embedded_button_image_frame(button) == ui2.rect(5, 3.5, 16, 16)
	assert button.tooltip == 'Saved café\nhttps://example.com/'
	assert button.accessibility_label == 'Saved café'
	assert button.menu[0].id == 'bookmark-remove:0'
}

fn test_overflow_is_a_scrollable_ui2_tree_with_open_remove_and_dismiss_actions() {
	items := []Item{len: 20, init: Item{ title: 'Bookmark ${index}', url: 'https://example.com/${index}' }}
	state := State{ width: 320, height: 240, top: 92, visible: true, overflow: true, items: items }
	count := visible_count(state)
	assert count > 0 && count < items.len
	views := elements(state)
	bar := views[0]
	assert bar.children.last().id == 'bookmarks-more'
	overlay := views[1]
	assert overlay.frame.y == 120
	assert overlay.children[0].id == 'bookmarks-dismiss'
	assert overlay.children[0].box.transparent
	list := overlay.children[1]
	assert list.kind == .scroll
	assert list.frame.height <= 96
	assert list.children.len == (items.len - count) * 2
	assert list.children[0].id == 'bookmark-open:${count}'
	assert list.children[0].button_image_size == 16
	assert ui2.embedded_button_image_frame(list.children[0]) == ui2.rect(5, 4, 16, 16)
	assert list.children[1].id == 'bookmark-remove:${count}'
	assert list.children[list.children.len - 2].id == 'bookmark-open:19'
	assert list.children.last().id == 'bookmark-remove:19'
	assert elements(State{ ...state, overflow: false }).len == 1
}

fn test_hidden_empty_error_and_narrow_bars_have_stable_ui2_layout() {
	assert elements(State{}).len == 0
	empty := elements(State{ width: 800, visible: true })[0]
	assert empty.children[0].id == 'bookmarks-hint'
	assert empty.children[0].text.contains('Save your favorite pages')
	failed := elements(State{ width: 800, visible: true, error: 'Cannot save', items: [Item{ title: 'Saved' }] })[0]
	assert failed.children.len == 1
	assert failed.children[0].text == 'Cannot save'
	narrow := State{ width: 32, height: 600, visible: true, overflow: true, items: [Item{ title: 'Very long title' }] }
	assert visible_count(narrow) == 0
	assert elements(narrow)[0].children[0].id == 'bookmarks-more'
	assert elements(narrow)[1].children[1].frame.width >= 0
}
