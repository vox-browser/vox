module main

import browserhistory
import browserui
import platform
import time
import ui2
import url

// The address bar's search engine. resolve_url sends text that does not name
// an address to the same engine.
const browser_search_label = 'DuckDuckGo Search'

fn browser_search_url(query string) string {
	return 'https://duckduckgo.com/html/?q=${url.percent_encode(query.trim_space(), .application_x_www_form_urlencoded,
		true)}'
}

// One candidate per distinct history address, with its visit count and latest
// title, plus bookmarks. History lists the newest visit first.
fn (app &BrowserApp) browser_address_candidates() []browserui.AddressCandidate {
	mut candidates := []browserui.AddressCandidate{}
	mut indices := map[string]int{}
	if app.browsing_history != unsafe { nil } {
		for visit in app.browsing_history.visits {
			if index := indices[visit.url] {
				candidates[index] = browserui.AddressCandidate{
					...candidates[index]
					visits: candidates[index].visits + 1
				}
				continue
			}
			indices[visit.url] = candidates.len
			candidates << browserui.AddressCandidate{
				url:          visit.url
				title:        visit.title
				visits:       1
				last_visited: visit.visited_at
			}
		}
	}
	if app.bookmarks != unsafe { nil } {
		for item in app.bookmarks.items {
			if index := indices[item.url] {
				previous := candidates[index]
				candidates[index] = browserui.AddressCandidate{
					...previous
					title:      if previous.title.trim_space() == '' { item.title } else { previous.title }
					bookmarked: true
				}
				continue
			}
			indices[item.url] = candidates.len
			candidates << browserui.AddressCandidate{ url: item.url, title: item.title, bookmarked: true }
		}
	}
	return candidates
}

// The field changed through editing. Keep what was typed, refresh the rows and
// complete the text inline unless the edit removed text or an input method is
// composing it.
fn (mut app BrowserApp) update_address_suggestions(text string) {
	mut state := app.browser_ui()
	allow_inline := !state.address_inline_blocked && !app.address_field_composing()
	state.address_inline_blocked = false
	app.address = text
	scratch := platform.begin_thread_scratch('address suggestions')
	defer { scratch.finish() }
	// Ranking reads the whole history; only the few resulting rows are retained.
	built := browserui.address_dropdown(u64(time.sys_mono_now()), browserui.AddressQuery{
		text:         text
		allow_inline: allow_inline
		now:          browserhistory.now()
		search_label: browser_search_label
	}, app.browser_address_candidates())
	scratch.leave()
	if dropdown := built {
		owned := dropdown.owned()
		state.address_dropdown = owned
		if owned.inline {
			start, end := owned.field_selection()
			app.show_address_field_text(owned.field_text(), start, end)
		}
	} else {
		state.address_dropdown = none
	}
	state.version++
	app.refresh_browser_ui()
}

fn (app &BrowserApp) address_suggestions_open() bool {
	return app.browser_ui_ != unsafe { nil } && app.browser_ui_.address_dropdown != none
}

// Closing keeps the field's text; callers that restore an address sync it.
fn (app &BrowserApp) close_address_suggestions() {
	if !app.address_suggestions_open() { return }
	mut state := app.browser_ui()
	state.address_dropdown = none
	state.address_inline_blocked = false
	state.version++
}

fn (app &BrowserApp) address_field_composing() bool {
	$if vox_ui2 ? {
		if app.native_address_bar { return ui2.embedded_text_composing('address') }
	}
	return false
}

// Replace the field's text after a completion or a keyboard selection and
// select the given rune range. Native replacement sends no change event.
fn (mut app BrowserApp) show_address_field_text(text string, start int, end int) {
	app.address = text
	app.address_cursor = end
	app.address_select = false
	$if linux || ui2_custom_rendering ? {
		ui2.set_text('address', text)
		ui2.select_embedded_text_range('address', start, end)
	}
	$if vox_ui2 ? {
		if app.native_address_bar {
			ui2.set_text('address', text)
			ui2.select_embedded_text_range('address', start, end)
		}
	}
}

// Record whether the next edit of the focused address field may be completed
// inline. Deleting, cutting, pasting and undoing leave the text as edited.
fn (mut app BrowserApp) note_address_key(event ui2.KeyEvent) {
	if ui2.focused_id() != 'address' { return }
	$if vox_ui2 ? {
		if ui2.embedded_key_panel() != '' { return }
	}
	mut state := app.browser_ui()
	command := event.cmd || event.ctrl
	state.address_inline_blocked = event.code in [.backspace, .delete]
		|| (command && event.code in [.x, .v, .z, .y])
}

// Up and Down move through the rows, showing each in the field. Escape on a
// moved selection returns to the typed text; otherwise it keeps its ordinary
// meaning and restores the page's address.
fn (mut app BrowserApp) handle_address_suggestion_key(event ui2.KeyEvent) bool {
	if event.cmd || event.ctrl || event.alt || ui2.focused_id() != 'address' { return false }
	$if vox_ui2 ? {
		if ui2.embedded_key_panel() != '' { return false }
	}
	mut state := app.browser_ui()
	mut dropdown := state.address_dropdown or { return false }
	match event.code {
		.up, .down { dropdown.move(if event.code == .up { -1 } else { 1 }) }
		.escape {
			if dropdown.active == 0 { return false }
			dropdown.active = 0
		}
		else { return false }
	}
	state.address_dropdown = dropdown
	start, end := dropdown.field_selection()
	app.show_address_field_text(dropdown.field_text(), start, end)
	state.version++
	app.refresh_browser_ui()
	return true
}

fn address_suggestion_destination(row browserui.AddressSuggestion) string {
	return if row.kind == .search { browser_search_url(row.url) } else { row.url }
}

// Enter opens the selected row while the field still shows that row's text.
fn (app &BrowserApp) address_suggestion_target(text string) ?string {
	if app.browser_ui_ == unsafe { nil } { return none }
	dropdown := app.browser_ui_.address_dropdown or { return none }
	if text != dropdown.field_text() { return none }
	row := dropdown.selected() or { return none }
	return address_suggestion_destination(row)
}

fn (mut app BrowserApp) activate_address_suggestion(action string) {
	dropdown := app.browser_ui().address_dropdown or { return }
	index := dropdown.row_for_action(action) or { return }
	row := dropdown.suggestions[index]
	destination := address_suggestion_destination(row)
	app.address = row.fill
	app.sync_address_bar()
	app.blur_address_bar()
	app.navigate(destination, true)
	request_browser_frame()
}

fn (app &BrowserApp) address_suggestion_elements(chrome BrowserChromeState) []ui2.Element {
	if app.browser_ui_ == unsafe { nil } { return []ui2.Element{} }
	dropdown := app.browser_ui_.address_dropdown or { return []ui2.Element{} }
	top := tab_strip_height + address_field_top + address_field_height + 2
	return dropdown.elements(address_field_left, top, browser_address_field_width(chrome.width),
		f64(chrome.height) - status_bar_height - top - 4)
}
