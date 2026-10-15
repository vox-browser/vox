module main

import adblock
import css
import fetch
import http
import json
import requestserver
import strconv

fn install_browser_font_resource_cache() {
	requestserver.install_native_font_response_cache_provider(browser_cached_font_response)
}

fn browser_cached_font_response(request &fetch.Request) ?&fetch.Response {
	destination := request.destination or { return none }
	if request.method != 'GET' || destination != .font
		|| request.current_url().scheme() !in ['http', 'https'] { return none }
	address := request.current_url().serialize()
	path := browser_cache_entry_path(browser_cache_root(), 'resources', address)
	// Old entries lack status or redirect/header provenance. They remain cache
	// misses rather than manufacturing a successful font response.
	status := strconv.atoi(read_browser_cache_entry(path + '.status') or { return none }) or { return none }
	if status < 200 || status >= 300 { return none }
	if (read_browser_cache_entry(path + '.url') or { return none }) != address { return none }
	headers := json.decode([]adblock.ResponseHeader,
		read_browser_cache_entry(path + '.headers.json') or { return none }) or { return none }
	body := read_browser_cache_entry(path) or { return none }
	mut response := fetch.Response.create()
	response.status = u16(status)
	response.url_list = request.url_list.clone()
	for header in headers {
		response.header_list.append(http.Header{name:header.name,value:header.value})
	}
	response.set_body_bytes(body.bytes())
	return response
}

fn (app &BrowserApp) font_resources_ready_for_capture() bool {
	if app.document == unsafe { nil } { return false }
	owner := app.document.existing_font_face_set() or { return true }
	if owner.font_face_set_record() == unsafe { nil } { return true }
	fonts := unsafe { &css.FontFaceSet(owner.font_face_set_record()) }
	return fonts.status() == .loaded && fonts.ready_promise.state == .fulfilled
		&& !app.document.anything_is_delaying_the_load_event()
		&& app.document.layout_is_up_to_date() && !app.document.needs_style_update_after_layout()
}
