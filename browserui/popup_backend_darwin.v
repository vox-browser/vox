module browserui

$if vox_ui2 ?&& !ui2_custom_rendering ? {
	import macos
	import ui2

	// UI2's dropdown owns its trigger and accepts only strings. The embedding
	// adapter can present the same menu rows from a trigger owned by the host.
	struct NativePopupTracking {
	mut:
		menu   macos.Id
		token  u64
		choice int
	}

	const native_popup_tracking = &NativePopupTracking{}

	type AppKitPopupMethod = fn (macos.Id, macos.Sel, macos.Id, macos.Point, macos.Id) bool

	// anchor is a top-level UI2 element in the embedding view. Popup coordinates
	// are top-left relative to that view, as they are for Popup.elements.
	pub fn native_popup_host(anchor string) voidptr {
		return voidptr(macos.msg_id(ui2.embedded_browser_control(anchor), 'superview'))
	}

	fn native_popup_choose(_ macos.Id, _ macos.Sel, item macos.Id) {
		mut tracking := unsafe { native_popup_tracking }
		if macos.msg_id(item, 'menu') == tracking.menu && macos.msg_bool(item, 'isEnabled') {
			tracking.choice = int(macos.msg_i64(item, 'tag'))
		}
	}

	fn native_popup_target() macos.Id {
		name := 'VoxUI2PopupTarget'
		mut cls := macos.get_class(name)
		if cls == unsafe { nil } {
			cls = macos.allocate_class_pair(macos.get_class('NSObject'), name)
			macos.add_method(cls, 'chooseItem:', voidptr(native_popup_choose), 'v@:@')
			macos.register_class_pair(cls)
		}
		return macos.msg_id(cls, 'new')
	}

	fn native_popup_menu(popup Popup, target macos.Id) macos.Id {
		menu := macos.new('NSMenu')
		macos.msg_void_bool(menu, 'setAutoenablesItems:', false)
		macos.msg_void_f64(menu, 'setMinimumWidth:', popup.width)
		for index, row in popup.rows {
			if row.separator {
				macos.msg_void1(menu, 'addItem:', macos.msg_id(macos.get_class('NSMenuItem'),
					'separatorItem'))
				continue
			}
			item := macos.msg_id3(macos.alloc('NSMenuItem'), 'initWithTitle:action:keyEquivalent:',
				macos.nsstring(row.text), macos.Id(macos.sel('chooseItem:')), macos.nsstring(''))
			macos.msg_void1(item, 'setTarget:', target)
			macos.msg_void_i64(item, 'setTag:', i64(index))
			macos.msg_void_i64(item, 'setIndentationLevel:', i64(row.indent))
			macos.msg_void_i64(item, 'setState:', i64(row.checked))
			macos.msg_void_bool(item, 'setEnabled:', row.enabled && !row.group)
			macos.msg_void1(menu, 'addItem:', item)
			macos.release(item)
		}
		return menu
	}

	pub fn show_native_popup(host voidptr, popup Popup) int {
		mut tracking := unsafe { native_popup_tracking }
		if tracking.menu != unsafe { nil } || popup.rows.len == 0 {
			return -1
		}
		// AppKit runs a nested tracking loop. Keep the host alive until it returns.
		view := macos.retain(host)
		target := native_popup_target()
		menu := native_popup_menu(popup, target)
		tracking.menu = menu
		tracking.token = popup.token
		tracking.choice = -1
		defer {
			tracking.menu = unsafe { nil }
			macos.release(menu)
			macos.release(target)
			macos.release(view)
		}
		bounds := macos.msg_rect(view, 'bounds')
		y := if macos.msg_bool(view, 'isFlipped') { popup.y } else { bounds.height - popup.y }
		location := macos.point(bounds.x + popup.x, bounds.y + y)
		selector := macos.sel('popUpMenuPositioningItem:atLocation:inView:')
		method := AppKitPopupMethod(macos.msg_id1(menu, 'methodForSelector:', macos.Id(selector)))
		chosen := method(menu, selector, unsafe { nil }, location, view)
		return if chosen { tracking.choice } else { -1 }
	}

	pub fn cancel_native_popup(token u64) {
		if native_popup_tracking.token == token {
			macos.msg_void(native_popup_tracking.menu, 'cancelTracking')
		}
	}
}
