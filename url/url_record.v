// Copyright (c) 2018-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the URL record and its serializer from LibURL/URL.cpp/URL.h — the scheme, credentials,
// host, port, path, query, and fragment components, and the URL/path serializers. The URL parser (which
// needs IDNA for domains) and the blob URL entry are out of scope; the serializers are self-contained.
// https://url.spec.whatwg.org/#url-representation
module url

pub struct URL {
pub mut:
	scheme   string
	username string
	password string
	host     ?Host
	port     ?u16
	// The path is either a list of segments, or (when has_an_opaque_path is true) a single opaque string
	// stored as paths[0].
	paths              []string
	query              ?string
	fragment           ?string
	has_an_opaque_path bool
}

// https://url.spec.whatwg.org/#special-scheme — the schemes with special parsing rules.
const special_schemes = ['ftp', 'file', 'http', 'https', 'ws', 'wss']

pub fn is_special_scheme(scheme string) bool {
	return scheme in special_schemes
}

// https://url.spec.whatwg.org/#default-port — the default port for a special scheme, or none.
pub fn default_port_for_scheme(scheme string) ?u16 {
	return match scheme {
		'ftp' { u16(21) }
		'http' { u16(80) }
		'https' { u16(443) }
		'ws' { u16(80) }
		'wss' { u16(443) }
		else { none }
	}
}

// https://url.spec.whatwg.org/#is-special
pub fn (record &URL) is_special() bool {
	return is_special_scheme(record.scheme)
}

// The port, or the scheme's default port, or 0.
pub fn (record &URL) port_or_default() u16 {
	if port := record.port {
		return port
	}
	return default_port_for_scheme(record.scheme) or { 0 }
}

// https://url.spec.whatwg.org/#cannot-have-a-username-password-port — true when the host is null or the
// empty host, or the scheme is "file".
pub fn (record &URL) cannot_have_a_username_or_password_or_port() bool {
	if host := record.host {
		return host.is_empty_host() || record.scheme == 'file'
	}
	return true
}

// https://url.spec.whatwg.org/#include-credentials — a non-empty username or password.
pub fn (record &URL) includes_credentials() bool {
	return record.username != '' || record.password != ''
}

// https://url.spec.whatwg.org/#url-path-serializer
pub fn (record &URL) serialize_path() string {
	// 1. An opaque path is its single path string.
	if record.has_an_opaque_path {
		return record.paths[0]
	}
	// 2-4. Otherwise each segment is joined with a leading "/".
	mut output := ''
	for segment in record.paths {
		output += '/' + segment
	}
	return output
}

// https://url.spec.whatwg.org/#concept-url-serializer
pub fn (record &URL) serialize(exclude_fragment bool) string {
	// 1. The scheme, followed by ":".
	mut output := record.scheme + ':'
	// 2. If the host is non-null: "//", optional credentials, the host, and an optional port.
	mut has_host := false
	if host := record.host {
		has_host = true
		output += '//'
		if record.includes_credentials() {
			output += record.username
			if record.password != '' {
				output += ':' + record.password
			}
			output += '@'
		}
		output += host.serialize()
		if port := record.port {
			output += ':${port}'
		}
	}
	// 3. Guard a hostless path whose first segment is empty (so it is not read as an authority).
	if !has_host && !record.has_an_opaque_path && record.paths.len > 1 && record.paths[0] == '' {
		output += '/.'
	}
	// 4. The serialized path.
	output += record.serialize_path()
	// 5. The query, if any.
	if query := record.query {
		output += '?' + query
	}
	// 6. The fragment, if any and not excluded.
	if !exclude_fragment {
		if fragment := record.fragment {
			output += '#' + fragment
		}
	}
	// 7. Return output.
	return output
}
