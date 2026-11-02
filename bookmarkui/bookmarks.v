module bookmarkui

import math
import ui2

// This declaration is shared by the native and custom-rendered UI2 backends.
pub struct Item {
pub:
	title string
	url   string
	icon  string
}

pub struct State {
pub:
	width    f64
	height   f64
	top      f64
	visible  bool
	overflow bool
	error    string
	items    []Item
}

pub fn item_width(title string) f64 {
	return math.min(180.0, math.max(66.0, f64(title.runes().len) * 7 + 40))
}

pub fn visible_count(state State) int {
	mut x := 8.0
	for index, item in state.items {
		width := item_width(item.title)
		if x + width > state.width - 34 { return index }
		x += width + 4
	}
	return state.items.len
}

fn bookmark_button(index int, item Item, frame ui2.Rect) ui2.Element {
	return ui2.Element{
		...ui2.button_with_image('bookmark-open:${index}', if item.icon == '' {
			'◎ ${item.title}'
		} else {
			item.title
		}, item.icon, frame,
			ui2.BoxStyle{ bg: 0xe6e6e6, radius: 8, transparent: true }, ui2.TextStyle{ size: 12, align: .left })
		native_style:        true
		button_image_size:   16
		key:                 'bookmark-${index}'
		tooltip:             '${item.title}\n${item.url}'
		accessibility_label: item.title
		menu:                [ui2.MenuEntry{ id: 'bookmark-remove:${index}', title: 'Remove bookmark' }]
	}
}

pub fn elements(state State) []ui2.Element {
	if !state.visible { return []ui2.Element{} }
	mut children := []ui2.Element{}
	count := visible_count(state)
	if state.error != '' || state.items.len == 0 {
		shortcut := $if macos { '⌘D' } $else { 'Ctrl+D' }
		children << ui2.label('bookmarks-hint', if state.error != '' {
			state.error
		} else {
			'Save your favorite pages here with ${shortcut}'
		}, ui2.rect(12, 5, math.max(0.0, state.width - 24), 18), ui2.TextStyle{ size: 12, color: 0x555555 })
	} else {
		mut x := 8.0
		for index in 0 .. count {
			width := item_width(state.items[index].title)
			children << bookmark_button(index, state.items[index], ui2.rect(x, 2, width, 23))
			x += width + 4
		}
		if count < state.items.len {
			children << ui2.Element{
				...ui2.button('bookmarks-more', '»', ui2.rect(math.max(0.0, state.width - 30), 2, 24, 23),
					ui2.BoxStyle{ bg: 0xe6e6e6, radius: 8, transparent: true }, ui2.TextStyle{ size: 15 })
				native_style:        true
				tooltip:             'More bookmarks'
				accessibility_label: 'More bookmarks'
			}
		}
	}
	mut result := [ui2.Element{
		...ui2.view('bookmarks-bar', ui2.rect(0, state.top, math.max(0.0, state.width), 28),
			ui2.BoxStyle{ bg: 0xf7f7f7, border_color: 0xd6d6d6, border_bottom: 1 }, children)
		accessibility_label: 'Bookmarks bar'
	}]
	if !state.overflow || count == state.items.len || state.error != '' { return result }
	// Use ordinary UI2 controls for the overflow too. Removal stays available
	// without relying on platform context-menu support.
	top := state.top + 28
	height := math.max(0.0, state.height - top - 24)
	width := math.min(320.0, math.max(0.0, state.width - 8))
	mut rows := []ui2.Element{}
	for index in count .. state.items.len {
		y := f64(index - count) * 28
		rows << bookmark_button(index, state.items[index], ui2.rect(4, y + 2, math.max(0.0, width - 36), 24))
		rows << ui2.Element{
			...ui2.button('bookmark-remove:${index}', '×', ui2.rect(math.max(0.0, width - 30), y + 2, 24, 24),
				ui2.BoxStyle{ bg: 0xe6e6e6, radius: 8, transparent: true }, ui2.TextStyle{ size: 15 })
			native_style:        true
			tooltip:             'Remove bookmark'
			accessibility_label: 'Remove ${state.items[index].title}'
		}
	}
	result << ui2.view('bookmarks-overlay', ui2.rect(0, top, state.width, height), ui2.BoxStyle{ transparent: true }, [
		ui2.button('bookmarks-dismiss', '', ui2.rect(0, 0, state.width, height), ui2.BoxStyle{ transparent: true }, ui2.TextStyle{}),
		ui2.scroll('bookmarks-overflow', ui2.rect(state.width - width - 4, 0, width,
			math.min(height, f64(state.items.len - count) * 28 + 4)), 0xf7f7f7, rows),
	])
	return result
}
