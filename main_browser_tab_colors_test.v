module main

import browsersettings
import browsertabs
import gg
import os
import time

fn test_tab_coloring_targets_clicked_owner_and_revalidates_closed_disabled_and_stale_menus() {
	directory := os.join_path(os.temp_dir(), 'vox-tab-colors-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	browsersettings.initialize(os.join_path(directory, 'settings.json'))!
	mut app := &BrowserApp{ ctx: &gg.Context{} }
	app.initialize_browser_tabs()
	mut second := &BrowserApp{ ctx: app.ctx, tabs: app.tabs }
	app.tabs.pages << second
	first_id := app.browser_tab_identity(0)
	second_id := app.browser_tab_identity(1)
	app.show_tab_color_menu(second_id)
	assert app.browser_ui().popup == none
	browsersettings.save(browsersettings.Proxy{ enable_tab_coloring: true })!
	app.show_tab_color_menu(second_id)
	popup := app.browser_ui().popup or { panic('missing color menu') }
	assert app.browser_ui().tab_color_target == second_id
	// Reorder while the picker is open. Selection remains on the original owner.
	app.tabs.pages = [second, app]
	app.snapshot_cached = true
	app.snapshot_hold = true
	app.browser_popup_action('browser-menu:${popup.token}:tab-color-red')
	assert second.browser_ui().tab_color == .red
	assert app.browser_ui().tab_color == .none
	assert app.browser_ui().popup == none
	assert !app.snapshot_cached && !app.snapshot_hold
	assert app.browser_tab_colors() == [browsertabs.Color.red, .none]
	app.show_tab_color_menu(first_id)
	current := app.browser_ui().popup or { panic('missing current menu') }
	app.browser_popup_action('browser-menu:${popup.token}:tab-color-blue')
	assert app.browser_ui().tab_color == .none
	app.browser_popup_action('browser-menu:${current.token}:tab-color-blue')
	assert app.browser_ui().tab_color == .blue
	app.show_tab_color_menu(second_id)
	app.tabs.pages = [app]
	app.complete_tab_color_menu('green')
	assert app.browser_ui().tab_color == .blue
	app.dismiss_browser_popup()
	app.show_tab_color_menu(first_id)
	browsersettings.save(browsersettings.Proxy{})!
	app.complete_tab_color_menu('pink')
	assert app.browser_ui().tab_color == .blue
	strip := app.browser_tab_strip(app.browser_chrome_state(800, 600))
	assert strip.children[3].menu.len == 0
	assert strip.children[3].vector.fill == u32(0xf7f7f7)
	browsersettings.save(browsersettings.Proxy{ enable_tab_coloring: true })!
	colored := app.browser_tab_strip(app.browser_chrome_state(800, 600))
	assert colored.children[3].menu.len == 1
	assert colored.children[3].vector.fill != strip.children[3].vector.fill
}
