// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of DOMURL/DOMURL.{h,cpp,idl} and Origin.{h,cpp,idl}.
module domurl

import net.urllib
import rand
import fileapi

const url_hex_upper = '0123456789ABCDEF'

fn percent_encode_url_component(input string, should_encode fn (u8) bool) string {
	mut output := ''
	for byte in input.bytes() {
		if should_encode(byte) {
			output += '%${url_hex_upper[byte >> 4].ascii_str()}${url_hex_upper[byte & 0x0f].ascii_str()}'
		} else {
			output += byte.ascii_str()
		}
	}
	return output
}

fn encode_url_query(input string, special bool) string {
	return percent_encode_url_component(input, fn [special] (byte u8) bool {
		should_encode := byte <= 0x20 || byte > 0x7e || byte in [`"`, `#`, `<`, `>`]
			|| (special && byte == `'`)
		return should_encode
	})
}

fn encode_url_userinfo(input string) string {
	return percent_encode_url_component(input, fn (byte u8) bool {
		if byte <= 0x20 || byte > 0x7e {
			return true
		}
		return byte in [`"`, `#`, `<`, `>`, `?`, `/`, `:`, `;`, `=`, `@`, `[`, `\\`, `]`, `^`,
			`|`]
	})
}

fn encode_url_fragment(input string) string {
	return percent_encode_url_component(input, fn (byte u8) bool {
		return byte <= 0x20 || byte > 0x7e || byte in [`"`, `<`, `>`] || byte == 0x60
	})
}

fn serialized_hostname(record urllib.URL) string {
	if record.host.starts_with('[') {
		closing_bracket := record.host.index_u8(`]`)
		if closing_bracket >= 0 {
			return record.host[..closing_bracket + 1].to_lower()
		}
	}
	return record.hostname().to_lower()
}

fn serialize_url_record(record urllib.URL, fragment_present bool) string {
	mut without_components := record
	without_components.user = none
	without_components.fragment = ''
	mut serialized := without_components.str()
	if user := record.user {
		userinfo := encode_url_userinfo(user.username) + if user.password_set {
			':${encode_url_userinfo(user.password)}'
		} else {
			''
		}
		if userinfo != '' {
			authority_start := serialized.index('://') or { -1 }
			if authority_start >= 0 {
				insert_at := authority_start + 3
				serialized = '${serialized[..insert_at]}${userinfo}@${serialized[insert_at..]}'
			}
		}
	}
	if fragment_present {
		serialized += '#${encode_url_fragment(record.fragment)}'
	}
	return serialized
}

fn default_port_for_scheme(scheme string) string {
	return match scheme {
		'ftp' { '21' }
		'http', 'ws' { '80' }
		'https', 'wss' { '443' }
		else { '' }
	}
}

fn normalize_url_record(record urllib.URL) urllib.URL {
	mut normalized := record
	if normalized.host != '' {
		hostname := serialized_hostname(normalized)
		port := normalized.port()
		normalized.host = if port == '' { hostname } else { '${hostname}:${port}' }
	}
	if normalized.port() == default_port_for_scheme(normalized.scheme) {
		normalized.host = serialized_hostname(normalized)
	}
	if normalized.raw_query != '' {
		normalized.raw_query = encode_url_query(normalized.raw_query, normalized.scheme in [
			'ftp',
			'file',
			'http',
			'https',
			'ws',
			'wss',
		])
	}
	return normalized
}

fn parse_api_url(input string, base ?string) ?urllib.URL {
	reference := urllib.parse(input) or { return none }
	if reference.is_abs() {
		return normalize_url_record(reference)
	}
	base_value := base or { return none }
	parsed_base := urllib.parse(base_value) or { return none }
	if !parsed_base.is_abs() {
		return none
	}
	resolved := parsed_base.resolve_reference(reference) or { return none }
	return normalize_url_record(resolved)
}

@[heap]
pub struct DOMURL {
mut:
	record           urllib.URL
	fragment_present bool
pub mut:
	query_object &URLSearchParams
}

fn initialize_a_url(record urllib.URL, fragment_present bool) &DOMURL {
	mut query := URLSearchParams.from_string(record.raw_query)
	url := &DOMURL{
		record:           record
		fragment_present: fragment_present
		query_object:     query
	}
	query.bind_url(url)
	return url
}

pub fn DOMURL.construct_impl(input string, base ?string) !&DOMURL {
	record := parse_api_url(input, base) or { return error('TypeError: Invalid URL') }
	return initialize_a_url(record, record.fragment != '' || input.contains('#'))
}

pub fn DOMURL.parse_for_bindings(input string, base ?string) ?&DOMURL {
	record := parse_api_url(input, base) or { return none }
	return initialize_a_url(record, record.fragment != '' || input.contains('#'))
}

pub fn DOMURL.can_parse(input string, base ?string) bool {
	return parse_api_url(input, base) != none
}

pub fn (url &DOMURL) href() string {
	return serialize_url_record(url.record, url.fragment_present)
}

pub fn (mut url DOMURL) set_href(value string) ! {
	record := parse_api_url(value, none) or { return error('TypeError: Invalid URL') }
	url.record = record
	url.fragment_present = record.fragment != '' || value.contains('#')
	url.query_object.list = url_decode(record.raw_query)
}

pub fn (url &DOMURL) to_json() string {
	return url.href()
}

pub fn (url &DOMURL) origin() string {
	return url.extract_an_origin().serialize()
}

pub fn (url &DOMURL) protocol() string {
	return '${url.record.scheme}:'
}

fn valid_scheme(value string) bool {
	if value.len == 0 || !value[0].is_letter() {
		return false
	}
	for byte in value.bytes()[1..] {
		if !byte.is_alnum() && byte !in [`+`, `-`, `.`] {
			return false
		}
	}
	return true
}

pub fn (mut url DOMURL) set_protocol(value string) {
	scheme := value.trim_right(':').to_lower()
	if !valid_scheme(scheme) {
		return
	}
	old_is_special := url.record.scheme in ['ftp', 'file', 'http', 'https', 'ws', 'wss']
	new_is_special := scheme in ['ftp', 'file', 'http', 'https', 'ws', 'wss']
	if old_is_special != new_is_special {
		return
	}
	userinfo := url.record.user
	has_credentials := userinfo != none && (url.username() != '' || url.password() != '')
	if scheme == 'file' && (has_credentials || url.port() != '') {
		return
	}
	if url.record.scheme == 'file' && url.record.host == '' {
		return
	}
	url.record.scheme = scheme
	if url.port() == default_port_for_scheme(scheme) {
		url.record.host = serialized_hostname(url.record)
	}
}

pub fn (url &DOMURL) username() string {
	return if user := url.record.user { encode_url_userinfo(user.username) } else { '' }
}

pub fn (mut url DOMURL) set_username(value string) {
	if url.cannot_have_credentials() {
		return
	}
	password := if user := url.record.user { user.password } else { '' }
	password_set := if user := url.record.user { user.password_set } else { false }
	url.record.user = urllib.Userinfo{
		username:     value
		password:     password
		password_set: password_set
	}
}

pub fn (url &DOMURL) password() string {
	return if user := url.record.user { encode_url_userinfo(user.password) } else { '' }
}

pub fn (mut url DOMURL) set_password(value string) {
	if url.cannot_have_credentials() {
		return
	}
	url.record.user = urllib.Userinfo{
		username:     if user := url.record.user { user.username } else { '' }
		password:     value
		password_set: true
	}
}

fn (url &DOMURL) cannot_have_credentials() bool {
	return url.record.hostname() == '' || url.record.scheme == 'file'
}

pub fn (url &DOMURL) host() string {
	return url.record.host
}

pub fn (mut url DOMURL) set_host(value string) {
	if url.record.opaque != '' {
		return
	}
	parsed := urllib.parse('${url.record.scheme}://${value}/') or { return }
	if parsed.hostname() == '' || parsed.user != none {
		return
	}
	url.record.host = if parsed.port() == default_port_for_scheme(url.record.scheme) {
		serialized_hostname(parsed)
	} else {
		parsed.host.to_lower()
	}
}

pub fn (url &DOMURL) hostname() string {
	return serialized_hostname(url.record)
}

pub fn (mut url DOMURL) set_hostname(value string) {
	if url.record.opaque != '' {
		return
	}
	parsed := urllib.parse('${url.record.scheme}://${value}/') or { return }
	if parsed.hostname() == '' || parsed.port() != '' || parsed.user != none {
		return
	}
	port := url.record.port()
	hostname := serialized_hostname(parsed)
	url.record.host = if port == '' { hostname } else { '${hostname}:${port}' }
}

pub fn (url &DOMURL) port() string {
	return url.record.port()
}

pub fn (mut url DOMURL) set_port(value string) {
	if url.cannot_have_credentials() {
		return
	}
	for byte in value.bytes() {
		if byte < `0` || byte > `9` {
			return
		}
	}
	if value != '' && value.u64() > 65535 {
		return
	}
	hostname := url.record.hostname()
	normalized := if value == '' { '' } else { value.u64().str() }
	url.record.host = if normalized == ''
		|| normalized == default_port_for_scheme(url.record.scheme) {
		hostname
	} else {
		'${hostname}:${normalized}'
	}
}

pub fn (url &DOMURL) pathname() string {
	return if url.record.opaque != '' { url.record.opaque } else { url.record.escaped_path() }
}

pub fn (mut url DOMURL) set_pathname(value string) {
	if url.record.opaque == '' {
		url.record.path = if url.record.host != '' && !value.starts_with('/') {
			'/${value}'
		} else {
			value
		}
		url.record.raw_path = ''
	}
}

pub fn (url &DOMURL) search() string {
	return if url.record.raw_query == '' { '' } else { '?${url.record.raw_query}' }
}

pub fn (mut url DOMURL) set_search(value string) {
	if value == '' {
		url.record.raw_query = ''
		url.record.force_query = false
		url.query_object.list.clear()
		return
	}
	input := if value.starts_with('?') { value[1..] } else { value }
	url.record.raw_query = encode_url_query(input, url.record.scheme in ['ftp', 'file', 'http',
		'https', 'ws', 'wss'])
	url.record.force_query = true
	url.query_object.list = url_decode(input)
}

fn (mut url DOMURL) set_query_from_params(query ?string) {
	if value := query {
		url.record.raw_query = value
		url.record.force_query = true
	} else {
		url.record.raw_query = ''
		url.record.force_query = false
	}
}

pub fn (url &DOMURL) search_params() &URLSearchParams {
	return url.query_object
}

pub fn (url &DOMURL) hash() string {
	return if url.record.fragment == '' {
		''
	} else {
		'#${encode_url_fragment(url.record.fragment)}'
	}
}

pub fn (mut url DOMURL) set_hash(value string) {
	url.fragment_present = value != ''
	url.record.fragment = if value.starts_with('#') { value[1..] } else { value }
}

pub fn (url &DOMURL) has_an_opaque_path() bool {
	return url.record.opaque != ''
}

pub fn (url &DOMURL) path_segment_at_index(index int) string {
	segments := url.record.path.trim_left('/').split('/')
	return segments[index]
}

pub type CreateObjectURLHook = fn (object_id string) !string

pub type RevokeObjectURLHook = fn (url string)

pub fn DOMURL.create_object_url(object_id string, hook CreateObjectURLHook) !string {
	return hook(object_id)
}

pub fn DOMURL.revoke_object_url(value string, hook RevokeObjectURLHook) {
	if value.starts_with('blob:') {
		hook(value)
	}
}

pub fn DOMURL.create_object_url_for_blob(blob &fileapi.Blob, environment fileapi.BlobURLEnvironment, mut store fileapi.BlobURLStore) !string {
	return store.add_entry(fileapi.BlobURLObject.from_blob(blob), environment)
}

pub fn DOMURL.revoke_object_url_from_store(value string, environment fileapi.BlobURLEnvironment, mut store fileapi.BlobURLStore) {
	entry := store.resolve(value) or { return }
	if !fileapi.check_for_same_partition_blob_url_usage(entry, environment) {
		return
	}
	store.remove_entry(value)
}

@[heap]
pub struct Origin {
pub:
	scheme       string
	host         string
	port         string
	opaque_token u64
}

pub fn Origin.construct_impl() &Origin {
	return &Origin{
		opaque_token: rand.u64()
	}
}

pub fn Origin.from_string(value string) !&Origin {
	url := DOMURL.construct_impl(value, none)!
	return url.extract_an_origin()
}

pub fn (url &DOMURL) extract_an_origin() &Origin {
	if url.record.scheme == 'blob' {
		if inner := urllib.parse(url.record.opaque) {
			if inner.scheme in ['ftp', 'http', 'https', 'ws', 'wss'] && inner.hostname() != '' {
				mut port := inner.port()
				if port == default_port_for_scheme(inner.scheme) {
					port = ''
				}
				return &Origin{
					scheme: inner.scheme
					host:   inner.hostname().to_lower()
					port:   port
				}
			}
		}
		return Origin.construct_impl()
	}
	host := url.hostname()
	if host == '' || url.record.scheme !in ['ftp', 'http', 'https', 'ws', 'wss'] {
		return Origin.construct_impl()
	}
	mut port := url.port()
	if (url.protocol() == 'http:' && port == '80')
		|| (url.protocol() == 'https:' && port == '443')
		|| (url.protocol() == 'ws:' && port == '80')
		|| (url.protocol() == 'wss:' && port == '443')
		|| (url.protocol() == 'ftp:' && port == '21') {
		port = ''
	}
	return &Origin{
		scheme: url.record.scheme
		host:   host.to_lower()
		port:   port
	}
}

pub fn (origin &Origin) opaque() bool {
	return origin.opaque_token != 0
}

pub fn (origin &Origin) is_same_origin(other &Origin) bool {
	if origin.opaque() || other.opaque() {
		return origin.opaque() && other.opaque() && origin.opaque_token == other.opaque_token
	}
	return origin.scheme == other.scheme && origin.host == other.host && origin.port == other.port
}

pub fn (origin &Origin) is_same_site(other &Origin) bool {
	if origin.is_same_origin(other) {
		return true
	}
	if origin.opaque() || other.opaque() || origin.scheme != other.scheme {
		return false
	}
	// Public-suffix/registrable-domain lookup is a host service. Without it,
	// exact hosts are the conservative same-site result.
	return origin.host == other.host
}

pub fn (origin &Origin) serialize() string {
	if origin.opaque() {
		return 'null'
	}
	return '${origin.scheme}://${origin.host}${if origin.port == '' {
		''
	} else {
		':${origin.port}'
	}}'
}
