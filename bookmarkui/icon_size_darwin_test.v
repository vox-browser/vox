module bookmarkui

$if vox_ui2 ? {
	import os
	import ui2

	#include "@DIR/mounted_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_chrome_click(control voidptr)
	fn C.native_test_bookmark_capture(control voidptr, path &char)
	fn C.bookmark_test_icon_size(control voidptr) int

	struct BookmarkEvents {
	mut:
		action string
	}
	const bookmark_events = &BookmarkEvents{}

	fn bookmark_event(action string) {
		mut log := unsafe { bookmark_events }
		log.action = action
	}
}

fn test_mounted_icons_stay_16px_in_the_bar_after_refresh_and_in_overflow() {
	$if vox_ui2 ? {
		window := C.native_test_address_window()
		defer {
			ui2.unmount_embedded_browser()
			C.native_test_address_close(window)
		}
		mut state := State{
			width:   800
			height:  600
			top:     60
			visible: true
			items:   [
				Item{ title: 'Wikipedia', url: 'https://en.wikipedia.org/wiki/Main_Page', icon: @DIR + '/../optimizedsites/assets/wikipedia.ico' },
				Item{ title: 'Old Reddit', url: 'https://old.reddit.com/r/programming/', icon: @DIR + '/../optimizedsites/assets/reddit.png' },
				Item{ title: 'vlang.io', url: 'https://vlang.io/', icon: @DIR + '/../optimizedsites/assets/vlang.png' },
				Item{ title: 'Hacker News', url: 'https://news.ycombinator.com/', icon: @DIR + '/../optimizedsites/assets/hacker-news.ico' },
			]
		}
		ui2.mount_embedded_browser(C.native_test_address_parent(window), elements(state), bookmark_event)!
		for index in 0 .. 4 {
			assert C.bookmark_test_icon_size(ui2.embedded_browser_control('bookmark-open:${index}')) == 1
		}
		if path := os.getenv_opt('VOX_BOOKMARK_CAPTURE') {
			C.native_test_bookmark_capture(ui2.embedded_browser_control('bookmarks-bar'), path.str)
		}
		button := ui2.embedded_browser_control('bookmark-open:3')
		state = State{
			...state
			items: [
				...state.items[..3],
				Item{ ...state.items[3], icon: @DIR + '/../optimizedsites/assets/vlang.png' },
			]
		}
		ui2.update_embedded_browser(elements(state))
		assert ui2.embedded_browser_control('bookmark-open:3') == button
		assert C.bookmark_test_icon_size(button) == 1
		C.native_test_chrome_click(button)
		assert bookmark_events.action == 'bookmark-open:3'
		state = State{ ...state, width: 140, overflow: true }
		ui2.update_embedded_browser(elements(state))
		for index in 0 .. 4 {
			assert C.bookmark_test_icon_size(ui2.embedded_browser_control('bookmark-open:${index}')) == 1
		}
		C.native_test_chrome_click(ui2.embedded_browser_control('bookmark-open:3'))
		assert bookmark_events.action == 'bookmark-open:3'
	}
}
