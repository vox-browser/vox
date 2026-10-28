// Copyright (c) 2018-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the URL record and its serializer from LibURL/URL.cpp/URL.h.
// https://url.spec.whatwg.org/#url-representation
module url

@[heap]
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
mut:
	// An absent entry owns no Blob or environment-origin payload.
	blob_url_entry_ ?BlobURLEntry = ?BlobURLEntry(none)
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

// The number of path segments.
pub fn (record &URL) path_segment_count() int {
	return record.paths.len
}

// LibURL URL::path_segment_at_index — the percent-decoded path segment at index.
pub fn (record &URL) path_segment_at_index(index int) string {
	return percent_decode(record.paths[index]).bytestr()
}

// LibURL URL::basename — the percent-decoded last path segment, or the empty string.
pub fn (record &URL) basename() string {
	if record.paths.len == 0 {
		return ''
	}
	return percent_decode(record.paths[record.paths.len - 1]).bytestr()
}

// LibURL URL::equals — two URLs are equal when their serializations (with the given fragment handling)
// are identical.
pub fn (record &URL) equals(other &URL, exclude_fragment bool) bool {
	return record.serialize(exclude_fragment) == other.serialize(exclude_fragment)
}

// https://url.spec.whatwg.org/#concept-url-origin. Blob entry installation is a
// DOMURL/FileAPI concern; this record consumes the entry snapshot when present.
pub fn (record &URL) origin() Origin {
	if record.scheme == 'blob' {
		if entry := record.blob_url_entry_ {
			return entry.environment.origin
		}
		path_url := parse(record.serialize_path()) or { return Origin.create_opaque(.standard) }
		if path_url.scheme in ['http', 'https', 'file'] {
			return path_url.origin()
		}
		return Origin.create_opaque(.standard)
	}
	if record.scheme in ['ftp', 'http', 'https', 'ws', 'wss'] {
		host := record.host or { return Origin.create_opaque(.standard) }
		return Origin.tuple(record.scheme, host, record.port, none)
	}
	// URL.cpp:381–384 gives internal resources one shared empty-host tuple.
	if record.scheme == 'resource' {
		return Origin.tuple(record.scheme, Host.from_string(''), none, none)
	}
	if record.scheme == 'file' {
		if file_scheme_urls_have_tuple_origins() {
			return Origin.tuple(record.scheme, Host.from_string(''), none, none)
		}
		return Origin.create_opaque(.file)
	}
	return Origin.create_opaque(.standard)
}

// LibURL URL::serialize_for_display — like serialize but omitting credentials and always keeping the
// fragment; used for user-facing display.
pub fn (record &URL) serialize_for_display() string {
	mut output := record.scheme + ':'
	mut has_host := false
	if host := record.host {
		has_host = true
		output += '//' + host.serialize()
		if port := record.port {
			output += ':${port}'
		}
	}
	if !record.has_an_opaque_path && !has_host && record.paths.len > 1 && record.paths[0] == '' {
		output += '/.'
	}
	output += record.serialize_path()
	if query := record.query {
		output += '?' + query
	}
	if fragment := record.fragment {
		output += '#' + fragment
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
