// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LocalNavigable's hyperlink-download path. The DOM Element
// algorithm enters through the callback installed on its Navigable identity;
// fetch, Navigation, Loader, and Page remain owned by the HTML side.
module html

import dom
import fetch
import http
import loader
import page

struct ContentDispositionInfo {
	is_attachment bool
	filename      ?string
}

fn split_content_disposition_parameters(value string) []string {
	mut parameters := []string{}
	mut in_quoted_string := false
	mut escaped := false
	mut parameter_start := 0
	for index, character in value.bytes() {
		if escaped {
			escaped = false
			continue
		}
		if in_quoted_string && character == `\\` {
			escaped = true
			continue
		}
		if character == `"` {
			in_quoted_string = !in_quoted_string
			continue
		}
		if character != `;` || in_quoted_string {
			continue
		}
		parameters << value[parameter_start..index].trim('\t ')
		parameter_start = index + 1
	}
	parameters << value[parameter_start..].trim('\t ')
	return parameters
}

fn parse_content_disposition_parameter_value(input string) string {
	value := input.trim('\t ')
	if !value.starts_with('"') {
		return value
	}
	mut output := []u8{}
	mut escaped := false
	for index := 1; index < value.len; index++ {
		character := value[index]
		if escaped {
			output << character
			escaped = false
			continue
		}
		if character == `\\` {
			escaped = true
			continue
		}
		if character == `"` {
			break
		}
		output << character
	}
	return output.bytestr()
}

fn percent_decode_download_filename(value string) string {
	mut output := []u8{cap: value.len}
	mut index := 0
	for index < value.len {
		if value[index] == `%` && index + 2 < value.len {
			high := download_hex_digit_value(value[index + 1])
			low := download_hex_digit_value(value[index + 2])
			if high >= 0 && low >= 0 {
				output << u8(high * 16 + low)
				index += 3
				continue
			}
		}
		output << value[index]
		index++
	}
	return output.bytestr()
}

fn download_hex_digit_value(character u8) int {
	if character >= `0` && character <= `9` {
		return int(character - `0`)
	}
	if character >= `A` && character <= `F` {
		return int(character - `A`) + 10
	}
	if character >= `a` && character <= `f` {
		return int(character - `a`) + 10
	}
	return -1
}

fn parse_content_disposition_extended_filename(value string) ?string {
	decoded_value := parse_content_disposition_parameter_value(value)
	first_separator := decoded_value.index("'") or {
		return percent_decode_download_filename(decoded_value)
	}
	second_relative := decoded_value[first_separator + 1..].index("'") or { return none }
	second_separator := first_separator + 1 + second_relative
	return percent_decode_download_filename(decoded_value[second_separator + 1..])
}

fn parse_content_disposition(headers &http.HeaderList) ContentDispositionInfo {
	header := headers.get('Content-Disposition') or { return ContentDispositionInfo{} }
	parameters := split_content_disposition_parameters(header)
	if parameters.len == 0 {
		return ContentDispositionInfo{}
	}
	mut filename := ?string(none)
	mut extended_filename := ?string(none)
	for parameter in parameters[1..] {
		equals_index := parameter.index('=') or { continue }
		name := parameter[..equals_index].trim('\t ').to_lower()
		value := parameter[equals_index + 1..]
		if name == 'filename*' {
			extended_filename = parse_content_disposition_extended_filename(value)
		} else if name == 'filename' {
			filename = parse_content_disposition_parameter_value(value)
		}
	}
	resolved_filename := if extended := extended_filename {
		?string(extended)
	} else {
		filename
	}
	return ContentDispositionInfo{
		is_attachment: parameters[0].to_lower() == 'attachment'
		filename:      resolved_filename
	}
}

// https://html.spec.whatwg.org/multipage/links.html#getting-the-suggested-filename
fn suggested_download_filename(url dom.URL, headers &http.HeaderList, proposed_filename ?string,
	interface_origin ?dom.Origin) string {
	content_disposition := parse_content_disposition(headers)
	if content_disposition.is_attachment {
		if filename := content_disposition.filename {
			return loader.sanitize_suggested_download_filename(filename)
		}
	}

	trusted_operation := if origin := interface_origin {
		response_origin := if url.scheme() == 'data' { origin } else { url.origin() }
		response_origin.is_same_origin(origin)
	} else {
		true
	}
	if trusted_operation {
		if filename := content_disposition.filename {
			return loader.sanitize_suggested_download_filename(filename)
		}
	}
	if proposed := proposed_filename {
		if proposed != '' && (trusted_operation || content_disposition.is_attachment) {
			return loader.sanitize_suggested_download_filename(proposed)
		}
	}
	filename := if url.has_an_opaque_path() { '' } else { url.basename() }
	return loader.sanitize_suggested_download_filename(filename)
}

fn response_content_length(headers &http.HeaderList) ?u64 {
	length := headers.extract_length()
	if length is u64 {
		return length
	}
	return none
}

fn page_model_for_download(model &NavigableModel) ?&page.Page {
	dom_page := model.page() or { return none }
	if dom_page.target == unsafe { nil } {
		return none
	}
	return unsafe { &page.Page(dom_page.target) }
}

fn (mut model NavigableModel) start_download_for_response(response &fetch.Response,
	download_url dom.URL, suggested_filename string) {
	mut internal_response := unsafe { &fetch.Response(response.unsafe_response()) }
	mut body := internal_response.body or { return }
	page_model := page_model_for_download(&model) or {
		internal_response.release_request_transfer_lease()
		return
	}
	mut client := page_model.client()
	download_id := client.page_did_start_download(page.DownloadRequest{
		url:                download_url.serialize()
		suggested_filename: suggested_filename
		total_size:         response_content_length(internal_response.header_list)
	}) or {
		return
	}
	client.page_did_register_download_controller(download_id)
	reader := body.incrementally_read(fn [client, download_id] (data []u8) {
		if client.page_is_download_canceled(download_id) {
			return
		}
		mut mutable_client := unsafe { &page.PageClient(client) }
		mutable_client.page_did_receive_download_data(download_id, data)
	}, fn [client, download_id] () {
		if client.page_is_download_canceled(download_id) {
			return
		}
		mut mutable_client := unsafe { &page.PageClient(client) }
		mutable_client.page_did_finish_download(download_id)
	}, fn [client, download_id] (message string) {
		if client.page_is_download_canceled(download_id) {
			return
		}
		mut mutable_client := unsafe { &page.PageClient(client) }
		mutable_client.page_did_fail_download(download_id, message)
	})
	_ = reader
	client.page_did_register_download_reader(download_id)
	internal_response.resume_body_delivery()
}

// https://html.spec.whatwg.org/multipage/links.html#handle-as-a-download
fn (mut model NavigableModel) handle_as_a_download(response &fetch.Response,
	fallback_url dom.URL, proposed_filename ?string, interface_origin dom.Origin) {
	internal_response := response.unsafe_response()
	if internal_response.body == none {
		return
	}
	download_url := internal_response.url() or { fallback_url }
	suggested_filename := suggested_download_filename(download_url, internal_response.header_list,
		proposed_filename, interface_origin)
	model.start_download_for_response(internal_response, download_url, suggested_filename)
}

fn process_hyperlink_download_response(model &NavigableModel, response &fetch.Response,
	fallback_url dom.URL, proposed_filename ?string, interface_origin dom.Origin) {
	if response.is_network_error() {
		return
	}
	mut mutable_model := unsafe { &NavigableModel(model) }
	mutable_model.handle_as_a_download(response, fallback_url, proposed_filename, interface_origin)
}

// https://html.spec.whatwg.org/multipage/links.html#downloading-hyperlinks
fn (mut model NavigableModel) download_the_hyperlink(url dom.URL,
	user_involvement dom.UserNavigationInvolvement, source_element &dom.Element,
	proposed_filename ?string, interface_origin dom.Origin) {
	if user_involvement != .browser_ui {
		mut window := model.active_window() or { return }
		mut navigation := unsafe { &Navigation(window.navigation()) }
		html_user_involvement := match user_involvement {
			.browser_ui { UserNavigationInvolvement.browser_ui }
			.activation { UserNavigationInvolvement.activation }
			.none { UserNavigationInvolvement.none_ }
		}
		if !navigation.fire_a_download_request_navigate_event(url, html_user_involvement,
			source_element, proposed_filename or { '' }) {
			return
		}
		model.inform_the_navigation_api_about_aborting_navigation()
	}

	// The navigate event can detach the source document from this navigable.
	current_navigable := source_element.document().navigable() or { return }
	if voidptr(current_navigable) != voidptr(model.host_) {
		return
	}
	fetch_hook := model.navigation_fetch_hook_ or { return }
	mut request := fetch.Request.create()
	request.set_url(url)
	settings_pointer := source_element.document().relevant_settings_object()
	if settings_pointer != unsafe { nil } {
		request.set_client(unsafe { &EnvironmentSettingsObject(settings_pointer) })
	}
	request.initiator = .download
	request.use_url_credentials = true
	algorithms := fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{
		process_response: fn [model, url, proposed_filename, interface_origin] (response &fetch.Response) {
			process_hyperlink_download_response(model, response, url, proposed_filename, interface_origin)
		}
	})
	_ = fetch.fetch(request, algorithms, &fetch.FetchHost{
		perform: fetch_hook
	}, .no)
}
