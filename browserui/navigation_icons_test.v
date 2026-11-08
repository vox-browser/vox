module browserui

import image.png
import os
import ui2
import gg

$if macos && vox_ui2 ? {
	import macos
}

fn test_navigation_assets_have_transparency_antialiasing_and_disabled_variants() {
	for action in [NavigationAction.back, .forward, .reload] {
		for enabled in [true, false] {
			path := navigation_icon_path(action, enabled)
			assert path.ends_with('.png') && os.is_file(path)
			assert os.read_bytes(path)! == navigation_icon_png(action, enabled)
			mut file := os.open(path)!
			decoded := png.decode(file)!
			file.close()
			assert decoded.bounds().dx() == 48 && decoded.bounds().dy() == 48
			mut solid, mut partial, mut clear := 0, 0, 0
			for y in 0 .. 48 {
				for x in 0 .. 48 {
					r, _, _, a := decoded.at(x, y).rgba()
					if a == 0 {
						clear++
					} else if a == 65535 {
						solid++
						assert r == u32(if enabled { 0x5f5f } else { 0xbdbd })
					} else {
						partial++
					}
				}
			}
			assert solid > 50 && partial > 25 && clear > 1000
		}
		assert navigation_icon_path(action, true) != navigation_icon_path(action, false)
	}
}

fn test_navigation_controls_keep_hit_area_actions_and_accessibility_without_font_glyphs() {
	for action in [NavigationAction.back, .forward, .reload] {
		for enabled in [true, false] {
			button := navigation_button(action, ui2.rect(5, 33, 22, 22), enabled)
			assert button.id == action.str() && button.action_id == action.str()
			assert button.enabled == enabled
			$if windows && !ui2_custom_rendering ? {
				assert button.text != ''
				continue
			}
			assert button.text == ''
			assert button.frame == ui2.rect(5, 33, 22, 22)
			assert button.box.transparent && !button.native_style
			assert button.tooltip == button.accessibility_label && button.tooltip != ''
			assert button.children.len == 1 && button.children[0].kind == .image
			assert button.children[0].frame == ui2.rect(2, 2, 18, 18)
		}
	}
}

fn test_custom_navigation_images_are_decoded_once_and_keep_their_cache_ids() {
	mut context := gg.new_context(width: 200, height: 100)
	mut images := map[string]int{}
	prepare_navigation_images(mut context, mut images)
	assert images.len == 6
	initial := images.clone()
	for _ in 0 .. 8 {
		prepare_navigation_images(mut context, mut images)
		assert images == initial
	}
	for action in [NavigationAction.back, .forward, .reload] {
		for enabled in [true, false] {
			id := images[navigation_icon_path(action, enabled)] or { panic('missing icon') }
			bitmap := context.get_cached_image_by_idx(id)
			assert bitmap.width == 48 && bitmap.height == 48
		}
	}
}

$if macos && vox_ui2 ? {
	#include "@DIR/tab_visual_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(voidptr) voidptr
	fn C.native_test_address_close(voidptr)
	fn C.native_test_tabs_click(voidptr)
	fn C.ui2_test_tabs_pixel(voidptr, f64, f64) u32
	fn C.ui2_test_tabs_capture(voidptr, &u8) int
}

struct NavigationIconEvents {
mut:
	values []string
}

const navigation_icon_events = &NavigationIconEvents{}

fn record_navigation_icon_event(action string) {
	mut log := unsafe { navigation_icon_events }
	log.values << action
}

fn test_mounted_navigation_icons_display_and_disabled_controls_do_not_dispatch() {
	$if macos && vox_ui2 ? {
		window := C.native_test_address_window()
		defer {
			ui2.unmount_embedded_browser()
			C.native_test_address_close(window)
		}
		mut log := unsafe { navigation_icon_events }
		log.values.clear()
		mut children := [
			ui2.label('enabled-label', 'Available', ui2.rect(12, 14, 76, 22), ui2.TextStyle{ size: 12, color: 0x5f6368 }),
			ui2.label('disabled-label', 'Unavailable', ui2.rect(12, 48, 76, 22), ui2.TextStyle{ size: 12, color: 0x5f6368 }),
		]
		for index, action in [NavigationAction.back, .forward, .reload] {
			children << navigation_button(action, ui2.rect(94 + index * 30, 14, 22, 22), true)
			disabled := navigation_button(action, ui2.rect(94 + index * 30, 48, 22, 22), false)
			children << ui2.Element{
				...disabled
				id:       'disabled-' + action.str()
				children: [ui2.Element{ ...disabled.children[0], id: 'disabled-' + action.str() + '-icon' }]
			}
		}
		ui2.mount_embedded_browser(C.native_test_address_parent(window), [
			ui2.view('navigation-preview', ui2.rect(0, 0, 210, 84), ui2.BoxStyle{ bg: 0xf7f7f7 }, children),
		], record_navigation_icon_event)!
		for action in [NavigationAction.back, .forward, .reload] {
			image := macos.msg_id(ui2.embedded_browser_control(action.str()), 'image')
			assert image != unsafe { nil }
			assert macos.msg_point(image, 'size').x == 18
			C.native_test_tabs_click(ui2.embedded_browser_control(action.str()))
			assert log.values.last() == action.str()
			before := log.values.len
			C.native_test_tabs_click(ui2.embedded_browser_control('disabled-' + action.str()))
			assert log.values.len == before
		}
		if path := os.getenv_opt('VOX_NAV_ICON_CAPTURE') {
			assert C.ui2_test_tabs_capture(ui2.embedded_browser_control('navigation-preview'), path.str) == 1
		}
		// Reconciliation must swap the bitmap without shrinking it or losing
		// the enabled state as navigation history changes.
		for enabled in [false, true] {
			children[2] = navigation_button(.back, ui2.rect(94, 14, 22, 22), enabled)
			ui2.update_embedded_browser([ui2.view('navigation-preview', ui2.rect(0, 0, 210, 84), ui2.BoxStyle{ bg: 0xf7f7f7 }, children)])
			button := ui2.embedded_browser_control('back')
			assert macos.msg_bool(button, 'isEnabled') == enabled
			assert macos.msg_point(macos.msg_id(button, 'image'), 'size').x == 18
			before := log.values.len
			C.native_test_tabs_click(button)
			assert log.values.len == before + if enabled { 1 } else { 0 }
		}
	}
}
