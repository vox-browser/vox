// Copyright (c) 2022-2023, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained pieces of Libraries/LibWeb/Fetch/Infrastructure:
// - URL scheme predicates and process_data_url (URL.cpp)
// - HTTP status classification (HTTP/Statuses.cpp)
// - bad-port blocking (PortBlocking.cpp)
// These depend only on dom.URL, the mimesniff MimeType record, base64, and the Request record
// (requests.v). block_bad_port takes a Request and reads its current URL, per the spec.
module fetch

import dom
import mimesniff
import encoding.base64

// --- URL schemes (Fetch/Infrastructure/URL) ---

// https://fetch.spec.whatwg.org/#local-scheme
const local_schemes = ['about', 'blob', 'data']

// https://fetch.spec.whatwg.org/#http-scheme
const http_schemes = ['http', 'https']

// https://fetch.spec.whatwg.org/#fetch-scheme (plus the ad-hoc internal "resource" scheme)
const fetch_schemes = ['about', 'blob', 'data', 'file', 'http', 'https', 'resource']

// https://fetch.spec.whatwg.org/#is-local
pub fn is_local_url(url dom.URL) bool {
	return url.scheme() in local_schemes
}

// https://fetch.spec.whatwg.org/#fetch-scheme
pub fn is_fetch_scheme(scheme string) bool {
	return scheme in fetch_schemes
}

// https://fetch.spec.whatwg.org/#http-scheme
pub fn is_http_or_https_scheme(scheme string) bool {
	return scheme in http_schemes
}

// --- HTTP statuses (Fetch/Infrastructure/HTTP/Statuses) ---

// https://fetch.spec.whatwg.org/#null-body-status
pub fn is_null_body_status(status u16) bool {
	// 101, 103, 204, 205, or 304.
	return status in [u16(101), 103, 204, 205, 304]
}

// https://fetch.spec.whatwg.org/#ok-status
pub fn is_ok_status(status u16) bool {
	// A status in the range 200 to 299, inclusive.
	return status >= 200 && status <= 299
}

// https://fetch.spec.whatwg.org/#redirect-status
pub fn is_redirect_status(status u16) bool {
	// 301, 302, 303, 307, or 308.
	return status in [u16(301), 302, 303, 307, 308]
}

// --- Port blocking (Fetch/Infrastructure/PortBlocking) ---

pub enum RequestOrResponseBlocking {
	blocked
	allowed
}

// https://fetch.spec.whatwg.org/#bad-port
const bad_ports = [u16(1), 7, 9, 11, 13, 15, 17, 19, 20, 21, 22, 23, 25, 37, 42, 43, 53, 69, 77,
	79, 87, 95, 101, 102, 103, 104, 109, 110, 111, 113, 115, 117, 119, 123, 135, 137, 139, 143,
	161, 179, 389, 427, 465, 512, 513, 514, 515, 526, 530, 531, 532, 540, 548, 554, 556, 563, 587,
	601, 636, 989, 990, 993, 995, 1719, 1720, 1723, 2049, 3659, 4045, 4190, 5060, 5061, 6000, 6566,
	6665, 6666, 6667, 6668, 6669, 6679, 6697, 10080]

// https://fetch.spec.whatwg.org/#bad-port
pub fn is_bad_port(port u16) bool {
	return port in bad_ports
}

// https://fetch.spec.whatwg.org/#block-bad-port
pub fn block_bad_port(request &Request) RequestOrResponseBlocking {
	// 1. Let url be request's current URL.
	url := request.current_url()
	// 2. If url's scheme is HTTP(S) and url's port is a bad port, return blocked.
	if is_http_or_https_scheme(url.scheme()) {
		if port := url.port() {
			if is_bad_port(port) {
				return .blocked
			}
		}
	}
	// 3. Return allowed.
	return .allowed
}

// --- data: URL processing (Fetch/Infrastructure/URL) ---

// https://fetch.spec.whatwg.org/#data-url-struct
pub struct DataURL {
pub:
	mime_type mimesniff.MimeType
	body      []u8
}

fn is_hex_digit(ch u8) bool {
	return (ch >= `0` && ch <= `9`) || (ch >= `a` && ch <= `f`) || (ch >= `A` && ch <= `F`)
}

fn hex_value(ch u8) u8 {
	if ch >= `0` && ch <= `9` {
		return ch - `0`
	}
	if ch >= `a` && ch <= `f` {
		return ch - `a` + 10
	}
	return ch - `A` + 10
}

// URL percent-decoding of a string, returning the decoded bytes.
fn percent_decode(input string) []u8 {
	bytes := input.bytes()
	mut output := []u8{}
	mut i := 0
	for i < bytes.len {
		byte := bytes[i]
		if byte != `%` || i + 2 >= bytes.len || !is_hex_digit(bytes[i + 1])
			|| !is_hex_digit(bytes[i + 2]) {
			output << byte
			i++
		} else {
			output << hex_value(bytes[i + 1]) * 16 + hex_value(bytes[i + 2])
			i += 3
		}
	}
	return output
}

// https://fetch.spec.whatwg.org/#data-url-processor
pub fn process_data_url(data_url dom.URL) !DataURL {
	// 1. Assert: dataURL's scheme is "data".
	// 2. Let input be the URL serialization of dataURL with the fragment excluded.
	serialized := data_url.serialize()
	fragment_index := serialized.index_u8(`#`)
	without_fragment := if fragment_index >= 0 { serialized[..fragment_index] } else { serialized }
	// 3. Remove the leading "data:" from input.
	mut input := without_fragment
	if input.starts_with('data:') {
		input = input['data:'.len..]
	}
	// 4-5. Collect code points that are not "," as the MIME type.
	comma_index := input.index_u8(`,`)
	end := if comma_index >= 0 { comma_index } else { input.len }
	mut mime_type := input[..end]
	// 6. Strip leading and trailing ASCII whitespace from mimeType.
	mime_type = mime_type.trim(' \t\n\x0c\r')
	// 7. If there was no comma, return failure.
	if comma_index < 0 {
		return error('Missing a comma character')
	}
	// 8-9. The encoded body is the remainder after the comma.
	encoded_body := input[comma_index + 1..]
	// 10. Let body be the percent-decoding of encodedBody.
	mut body := percent_decode(encoded_body)
	// 11. If mimeType ends (case-insensitively) with ";base64" (with optional spaces), base64-decode.
	if mime_type.to_lower().ends_with('base64') {
		trimmed := mime_type[..mime_type.len - 6].trim_right(' ')
		if trimmed.ends_with(';') {
			// isomorphic decode of body (bytes → Latin-1 string); the body is ASCII base64.
			string_body := body.bytestr()
			// forgiving-base64 decode (whitespace stripped).
			body = forgiving_base64_decode(string_body)!
			// Remove the trailing ";base64" (and spaces) from mimeType.
			mime_type = trimmed[..trimmed.len - 1]
		}
	}
	// 12. If mimeType starts with ";", prepend "text/plain".
	if mime_type.starts_with(';') {
		mime_type = 'text/plain${mime_type}'
	}
	// 13-14. Parse mimeType; on failure fall back to text/plain;charset=US-ASCII.
	mut mime_type_record := mimesniff.MimeType.parse(mime_type) or {
		mut fallback := mimesniff.MimeType.create('text', 'plain')
		fallback.set_parameter('charset', 'US-ASCII')
		fallback
	}
	// 15. Return the data: URL struct.
	return DataURL{
		mime_type: mime_type_record
		body:      body
	}
}

// forgiving-base64 decode: strip ASCII whitespace, then base64-decode.
fn forgiving_base64_decode(input string) ![]u8 {
	// Embedded fonts and images can contain hundreds of kilobytes. Growing a
	// string for every byte retains quadratic temporary storage without GC.
	mut stripped := []u8{cap: input.len}
	for ch in input {
		if ch != ` ` && ch != `\t` && ch != `\n` && ch != `\x0c` && ch != `\r` {
			stripped << ch
		}
	}
	// A length of exactly one more than a multiple of 4 is invalid.
	if stripped.len % 4 == 1 {
		return error('Invalid base64')
	}
	return base64.decode(stripped.bytestr())
}
