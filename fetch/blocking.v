// Copyright (c) 2022-2023, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Fetch/Infrastructure/HTTP/MIME.cpp (extract_mime_type), NoSniffBlocking.cpp, and
// MimeTypeBlocking.cpp — extracting a MIME type from a header list and the response-blocking
// decisions based on the request's destination and the response's MIME type. Composes the http
// header list, the mimesniff MimeType record, and the request/response records.
module fetch

import http
import mimesniff

// https://fetch.spec.whatwg.org/#concept-header-extract-mime-type
pub fn extract_mime_type(headers &http.HeaderList) ?mimesniff.MimeType {
	mut charset := ?string(none)
	mut essence := ?string(none)
	mut mime_type := ?mimesniff.MimeType(none)
	// 4-5. Get, decode, and split `Content-Type`; failure if null.
	values := headers.get_decode_and_split('Content-Type') or { return none }
	// 6. For each value:
	for value in values {
		// 1. Parse value.
		temporary_mime_type := mimesniff.MimeType.parse(value) or { continue }
		// 2. Skip failures and "*/*".
		if temporary_mime_type.essence() == '*/*' {
			continue
		}
		// 3. Set mimeType.
		mut current := temporary_mime_type
		// 4. If mimeType's essence is not essence:
		mut essence_matches := false
		if e := essence {
			essence_matches = current.essence() == e
		}
		if !essence_matches {
			// 1-2. Reset charset from this MIME type's charset parameter.
			charset = none
			if cs := current.parameters()['charset'] {
				charset = cs
			}
			// 3. Set essence.
			essence = current.essence()
		} else {
			// 5. Otherwise carry the charset forward if this value lacks one.
			if 'charset' !in current.parameters() {
				if cs := charset {
					current.set_parameter('charset', cs)
				}
			}
		}
		mime_type = current
	}
	// 7-8. Return mimeType (none if never set).
	return mime_type
}

// https://fetch.spec.whatwg.org/#determine-nosniff
pub fn determine_nosniff(headers &http.HeaderList) bool {
	// 1. Get, decode, and split `X-Content-Type-Options`.
	values := headers.get_decode_and_split('X-Content-Type-Options') or { return false }
	// 3. Return true if values[0] is an ASCII case-insensitive match for "nosniff".
	if values.len != 0 && values[0].to_lower() == 'nosniff' {
		return true
	}
	// 4. Return false.
	return false
}

// https://fetch.spec.whatwg.org/#should-response-to-request-be-blocked-due-to-nosniff?
pub fn should_response_to_request_be_blocked_due_to_nosniff(response &Response, request &Request) RequestOrResponseBlocking {
	// 1. If determine nosniff is false, return allowed.
	if !determine_nosniff(response.header_list) {
		return .allowed
	}
	// 2. Extract the MIME type from the response's header list.
	mime_type := extract_mime_type(response.header_list)
	// 4. Script-like destination + failure/non-JavaScript MIME type → blocked.
	if request.destination_is_script_like() {
		if mime := mime_type {
			if !mime.is_javascript() {
				return .blocked
			}
		} else {
			return .blocked
		}
	}
	// 5. "style" destination + failure/non-"text/css" → blocked.
	if destination := request.destination {
		if destination == .style {
			if mime := mime_type {
				if mime.essence() != 'text/css' {
					return .blocked
				}
			} else {
				return .blocked
			}
		}
	}
	// 6. Return allowed.
	return .allowed
}

// https://fetch.spec.whatwg.org/#should-response-to-request-be-blocked-due-to-mime-type?
pub fn should_response_to_request_be_blocked_due_to_its_mime_type(response &Response, request &Request) RequestOrResponseBlocking {
	// 1. Extract the MIME type; 2. failure → allowed.
	mime_type := extract_mime_type(response.header_list) or { return .allowed }
	// 4. Script-like destination + a bad essence → blocked.
	if request.destination_is_script_like() {
		essence := mime_type.essence()
		if essence.starts_with('audio/') || essence.starts_with('image/')
			|| essence.starts_with('video/') || essence == 'text/csv' {
			return .blocked
		}
	}
	// 5. Return allowed.
	return .allowed
}
