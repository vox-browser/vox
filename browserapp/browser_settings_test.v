module main

import browserextensions
import browsersettings
import gg
import os
import time

$if vox_ui2 ? {
	import ui2
	#include "@VMODROOT/native/include/native_browser_settings_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_address_insert(field voidptr, bytes &u8, length int)
	fn C.native_test_address_submit(field voidptr)
	fn C.native_test_chrome_click(control voidptr)
	fn C.native_test_address_shortcut(field voidptr, owner voidptr, callback fn (voidptr, int), key u16, shift int) int
	fn C.native_test_chrome_enabled(control voidptr) int
	fn C.native_test_settings_select_tab(control voidptr) int
	fn C.native_test_settings_close_panel(control voidptr)
	fn C.native_test_settings_cycle_tab(control voidptr, reverse int) int

	fn click_settings_section(section BrowserSettingsSection) {
		tab := ui2.embedded_browser_control(ui2.tab_bar_tab_action(browser_settings_sidebar_id, section.str()))
		assert tab != unsafe { nil }
		assert C.native_test_settings_select_tab(tab) != 0
		assert ui2.text('settings-heading') == section.title()
	}
}

fn test_settings_shortcut_uses_the_platform_command_modifier() {
	command := $if macos { gg.Modifier.super } $else { gg.Modifier.ctrl }
	assert is_browser_settings_shortcut(.comma, command)
	assert !is_browser_settings_shortcut(.comma, command | .shift)
	assert !is_browser_settings_shortcut(.period, command)
}

fn test_ui2_settings_save_automatically_and_keep_the_last_valid_proxy() {
	$if vox_ui2 ? {
		directory := os.join_path(os.temp_dir(), 'vox-ui2-settings-${os.getpid()}-${time.sys_mono_now()}')
		path := os.join_path(directory, 'settings.json')
		browsersettings.initialize(path)!
		window := C.native_test_address_window()
		mut app := &BrowserApp{}
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
			os.rmdir_all(directory) or {}
		}
		show_browser_settings()
		assert browser_settings_visible()
		assert ui2.text('settings-heading') == 'Tabs'
		assert ui2.embedded_browser_control('settings-allow-any-site') == unsafe { nil }
		assert ui2.embedded_browser_control('settings-host') == unsafe { nil }
		assert ui2.embedded_browser_control('settings-gpu-canvas') == unsafe { nil }
		assert ui2.embedded_browser_control('settings-apply') == unsafe { nil }
		assert ui2.embedded_browser_control('settings-cancel') == unsafe { nil }
		C.native_test_settings_close_panel(ui2.embedded_browser_control('settings-heading'))
		assert !browser_settings_visible()
		assert !os.exists(path)
		show_browser_settings()

		app.snapshot_cached = true
		app.snapshot_hold = true
		C.native_test_chrome_click(ui2.embedded_browser_control('settings-tab-coloring'))
		assert browsersettings.current().enable_tab_coloring
		assert !app.snapshot_cached && !app.snapshot_hold
		C.native_test_chrome_click(ui2.embedded_browser_control('settings-custom-tab-titles'))
		assert browsersettings.current().enable_custom_tab_titles
		assert C.native_test_settings_cycle_tab(ui2.embedded_browser_control('settings-heading'), 1) != 0
		assert ui2.text('settings-heading') == 'Advanced'
		assert ui2.control_checked('settings-gpu-canvas')
		assert !ui2.control_checked('settings-libjs')
		C.native_test_chrome_click(ui2.embedded_browser_control('settings-gpu-canvas'))
		assert browsersettings.current().disable_gpu_canvas
		C.native_test_chrome_click(ui2.embedded_browser_control('settings-libjs'))
		assert browsersettings.current().javascript_engine == 'libjs'
		assert C.native_test_settings_cycle_tab(ui2.embedded_browser_control('settings-heading'), 0) != 0
		assert ui2.text('settings-heading') == 'Tabs'

		click_settings_section(.proxy)
		host := ui2.embedded_browser_control('settings-host')
		assert C.native_test_chrome_enabled(host) == 0
		C.native_test_chrome_click(ui2.embedded_browser_control('settings-enabled'))
		assert C.native_test_chrome_enabled(host) != 0
		assert browsersettings.current().enabled
		ui2.set_text('settings-host', 'localhost')
		ui2.set_text('settings-port', '9050')
		app.update_browser_chrome(900, 600)
		assert ui2.embedded_browser_control('settings-host') == host
		assert browsersettings.current().port == '1080'
		click_settings_section(.tabs)
		assert browsersettings.current().host == 'localhost'
		assert browsersettings.current().port == '9050'

		click_settings_section(.proxy)
		ui2.select_embedded_textbox('settings-sites')
		bad_site := 'https://example.com'
		C.native_test_address_insert(ui2.embedded_browser_control('settings-sites'), bad_site.str, bad_site.len)
		assert ui2.text('settings-error').contains('hostnames')
		click_settings_section(.advanced)
		C.native_test_chrome_click(ui2.embedded_browser_control('settings-libjs'))
		assert browsersettings.current().javascript_engine == 'javascriptcore'
		assert browsersettings.current().sites == ''
		click_settings_section(.proxy)
		assert ui2.text('settings-sites') == bad_site
		assert ui2.text('settings-error').contains('hostnames')
		ui2.set_text('settings-sites', 'Example.com, another.org')
		C.native_test_settings_close_panel(ui2.embedded_browser_control('settings-heading'))
		assert !browser_settings_visible()
		assert browsersettings.current().sites == 'example.com, another.org'
		assert browsersettings.current().javascript_engine == 'javascriptcore'
		assert browsersettings.current().enable_custom_tab_titles
		assert browsersettings.current().disable_gpu_canvas

		show_browser_settings()
		click_settings_section(.proxy)
		assert ui2.text('settings-sites') == 'example.com, another.org'
		assert ui2.text('settings-error') == ''
		port := ui2.embedded_browser_control('settings-port')
		ui2.select_embedded_textbox('settings-port')
		new_port := '9150'
		C.native_test_address_insert(port, new_port.str, new_port.len)
		C.native_test_address_submit(port)
		assert browsersettings.current().port == new_port
		assert browser_settings_visible()
		ui2.set_text('settings-port', 'bad')
		assert C.native_test_address_shortcut(port, app, address_bar_shortcut, 53, 0) != 0
		assert !browser_settings_visible()
		assert browsersettings.current().port == new_port
	}
}

fn test_extensions_settings_loads_enables_disables_and_removes_an_extension() {
	$if vox_ui2 ? {
		profile := os.join_path(os.temp_dir(), 'vox-ui2-extensions-${os.getpid()}-${time.sys_mono_now()}')
		os.mkdir_all(profile)!
		previous := os.getenv_opt('VOX_PROFILE_DIR')
		os.setenv('VOX_PROFILE_DIR', profile, true)
		defer {
			if old_profile := previous {
				os.setenv('VOX_PROFILE_DIR', old_profile, true)
			} else {
				os.unsetenv('VOX_PROFILE_DIR')
			}
			os.rmdir_all(profile) or {}
		}
		os.write_file(os.join_path(profile, 'manifest.json'), '{"manifest_version":3,"name":"CSS fixture","version":"1","content_scripts":[{"matches":["https://extensions.test/*"],"css":["extension.css"]}]}')!
		os.write_file(os.join_path(profile, 'extension.css'), '#result { display:none }')!
		window := C.native_test_address_window()
		mut app := &BrowserApp{}
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		browser_ui_event('extensions-open')
		assert browser_settings_visible()
		assert ui2.text('settings-heading') == 'Extensions'
		ui2.set_text('extensions-path', profile)
		click_settings_section(.tabs)
		assert ui2.embedded_browser_control('extensions-path') == unsafe { nil }
		click_settings_section(.extensions)
		assert ui2.text('extensions-path') == profile
		C.native_test_chrome_click(ui2.embedded_browser_control('extensions-install'))
		assert ui2.text('extensions-path') == ''
		extensions := browserextensions.installed(browserextensions.profile_path())!
		assert extensions.len == 1
		id := extensions[0].id
		toggle := ui2.embedded_browser_control('extensions-toggle:${id}')
		assert toggle != unsafe { nil }
		C.native_test_chrome_click(toggle)
		assert !browserextensions.installed(browserextensions.profile_path())![0].enabled
		assert ui2.embedded_browser_control('extensions-toggle:${id}') == toggle
		C.native_test_chrome_click(toggle)
		assert browserextensions.installed(browserextensions.profile_path())![0].enabled
		C.native_test_chrome_click(ui2.embedded_browser_control('extensions-remove:${id}'))
		assert browserextensions.installed(browserextensions.profile_path())!.len == 0
	}
}
