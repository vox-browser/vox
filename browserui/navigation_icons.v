module browserui

import crypto.sha256
import os
import ui2
import gg

pub enum NavigationAction {
	back
	forward
	reload
}

// Embedded assets travel with the executable, including standalone Linux and
// Vinix packages. UI2's native image views read the content-addressed cache.
const navigation_icon_data = {
	'back':             $embed_file('icons/navigation/back.png').to_string()
	'back-disabled':    $embed_file('icons/navigation/back-disabled.png').to_string()
	'forward':          $embed_file('icons/navigation/forward.png').to_string()
	'forward-disabled': $embed_file('icons/navigation/forward-disabled.png').to_string()
	'reload':           $embed_file('icons/navigation/reload.png').to_string()
	'reload-disabled':  $embed_file('icons/navigation/reload-disabled.png').to_string()
}
const navigation_icon_files = cache_navigation_icons()

fn cache_navigation_icons() map[string]string {
	mut paths := map[string]string{}
	for name, data in navigation_icon_data {
		bytes := data.bytes()
		defer { unsafe { bytes.free() } }
		digest := sha256.sum(bytes).hex()
		for directory in [os.join_path(os.cache_dir(), 'vox', 'navigation-icons'),
			os.join_path(os.temp_dir(), 'vox-navigation-icons-${os.getuid()}')] {
			os.mkdir_all(directory) or { continue }
			path := os.join_path(directory, '${name}-${digest}.png')
			if !os.is_file(path) {
				temporary := path + '.${os.getpid()}.tmp'
				os.write_file_array(temporary, bytes) or { continue }
				os.mv(temporary, path) or {
					os.rm(temporary) or {}
					continue
				}
			}
			paths[name] = path
			break
		}
	}
	return paths
}

fn navigation_icon_key(action NavigationAction, enabled bool) string {
	return match action {
		.back {
			if enabled { 'back' } else { 'back-disabled' }
		}
		.forward {
			if enabled { 'forward' } else { 'forward-disabled' }
		}
		.reload {
			if enabled { 'reload' } else { 'reload-disabled' }
		}
	}
}

pub fn navigation_icon_path(action NavigationAction, enabled bool) string {
	return navigation_icon_files[navigation_icon_key(action, enabled)] or { '' }
}

pub fn navigation_icon_png(action NavigationAction, enabled bool) []u8 {
	return navigation_icon_data[navigation_icon_key(action, enabled)].bytes()
}

// Call before beginning a custom-renderer pass. The context owns the textures;
// the caller and UI2 retain only their IDs, including across history changes.
pub fn prepare_navigation_images(mut context gg.Context, mut images map[string]int) {
	for action in [NavigationAction.back, .forward, .reload] {
		for enabled in [true, false] {
			path := navigation_icon_path(action, enabled)
			if path == '' || path in images { continue }
			bytes := navigation_icon_png(action, enabled)
			defer { unsafe { bytes.free() } }
			bitmap := context.create_image_from_byte_array(bytes) or { continue }
			images[path] = bitmap.id
		}
	}
}

pub fn navigation_button(action NavigationAction, frame ui2.Rect, enabled bool) ui2.Element {
	id := action.str()
	label := match action {
		.back { 'Back' }
		.forward { 'Forward' }
		.reload { 'Reload' }
	}
	$if windows && !ui2_custom_rendering ? {
		// The native Win32 UI2 image backend currently accepts BMP only.
		return ui2.Element{
			...ui2.button(id, match action {
				.back { '‹' }
				.forward { '›' }
				.reload { '↻' }
			},
				frame, ui2.BoxStyle{ transparent: true }, ui2.TextStyle{ size: 17, color: 0x7d7d7d })
			action_id:           id
			enabled:             enabled
			tooltip:             label
			accessibility_label: label
		}
	}
	path := navigation_icon_path(action, enabled)
	return ui2.Element{
		...ui2.button(id, if path == '' { label } else { '' }, frame,
			ui2.BoxStyle{ transparent: true }, ui2.TextStyle{})
		action_id:           id
		enabled:             enabled
		tooltip:             label
		accessibility_label: label
		children:            if path == '' {
			[]ui2.Element{}
		} else {
			[ui2.image(id + '-icon', path, ui2.rect((frame.width - 18) / 2, (frame.height - 18) / 2, 18, 18))]
		}
	}
}
