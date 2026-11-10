// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of DOMURL/DOMURL.{h,cpp,idl} and Origin.{h,cpp,idl}.
module domurl

import fileapi
import url as liburl

// DOMURL::parse() is a thin binding-facing wrapper around LibURL's basic URL
// parser. Keeping the typed URL record here preserves empty query/fragment
// components, opaque paths, host variants, IDNA and state-override setters.
fn parse_api_url(input string, base ?string) ?liburl.URL {
	if base_value := base {
		parsed_base := liburl.parse(base_value) or { return none }
		return liburl.parse_with_base(input, &parsed_base)
	}
	return liburl.parse(input)
}

@[heap]
pub struct DOMURL {
mut:
	record liburl.URL
pub mut:
	query_object ?&URLSearchParams
}

pub fn DOMURL.create(record liburl.URL) &DOMURL {
	return &DOMURL{
		// Source takes a URL value whose copy-on-write data protects its caller.
		record: record.copy()
	}
}

pub fn DOMURL.initialize_a_url(record liburl.URL) &DOMURL {
	// Upstream defers allocating and parsing searchParams until its getter is
	// first used. This matters when href/search are changed without observing it.
	return DOMURL.create(record)
}

fn initialize_a_url(record liburl.URL) &DOMURL {
	return DOMURL.initialize_a_url(record)
}

pub fn DOMURL.construct_impl(input string, base ?string) !&DOMURL {
	return DOMURL.create_from_url(input, base)
}

pub fn DOMURL.create_from_url(input string, base ?string) !&DOMURL {
	record := parse_api_url(input, base) or { return error('TypeError: Invalid URL') }
	return initialize_a_url(record)
}

pub fn DOMURL.parse_for_bindings(input string, base ?string) ?&DOMURL {
	record := parse_api_url(input, base) or { return none }
	return initialize_a_url(record)
}

pub fn DOMURL.can_parse(input string, base ?string) bool {
	return parse_api_url(input, base) != none
}

pub fn (url &DOMURL) href() string {
	return url.record.serialize(false)
}

pub fn (mut url DOMURL) set_href(value string) ! {
	record := parse_api_url(value, none) or { return error('TypeError: Invalid URL') }
	url.record = record
	if mut query := url.query_object {
		query.list.clear()
		if record_query := record.query {
			query.list = url_decode(record_query)
		}
	}
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

pub fn (mut url DOMURL) set_protocol(value string) {
	url.record = url.record.with_scheme(value)
}

pub fn (url &DOMURL) username() string {
	return url.record.username
}

pub fn (mut url DOMURL) set_username(value string) {
	url.record = url.record.with_username(value)
}

pub fn (url &DOMURL) password() string {
	return url.record.password
}

pub fn (mut url DOMURL) set_password(value string) {
	url.record = url.record.with_password(value)
}

fn (url &DOMURL) cannot_have_credentials() bool {
	return url.record.cannot_have_a_username_or_password_or_port()
}

pub fn (url &DOMURL) host() string {
	host := url.record.host or { return '' }
	return host.serialize() + if port := url.record.port { ':${port}' } else { '' }
}

pub fn (mut url DOMURL) set_host(value string) {
	url.record = url.record.with_host(value, false)
}

pub fn (url &DOMURL) hostname() string {
	return if host := url.record.host { host.serialize() } else { '' }
}

pub fn (mut url DOMURL) set_hostname(value string) {
	url.record = url.record.with_host(value, true)
}

pub fn (url &DOMURL) port() string {
	return if port := url.record.port { port.str() } else { '' }
}

pub fn (mut url DOMURL) set_port(value string) {
	url.record = url.record.with_port(value)
}

pub fn (url &DOMURL) pathname() string {
	return url.record.serialize_path()
}

pub fn (url &DOMURL) fragment() ?string {
	return url.record.fragment
}

pub fn (mut url DOMURL) set_paths(paths []string) {
	if url.record.has_an_opaque_path {
		return
	}
	url.record = url.record.with_path(paths.join('/'))
}

pub fn (mut url DOMURL) set_pathname(value string) {
	url.record = url.record.with_path(value)
}

pub fn (url &DOMURL) search() string {
	query := url.record.query or { return '' }
	return if query == '' { '' } else { '?${query}' }
}

pub fn (mut url DOMURL) set_search(value string) {
	if value == '' {
		url.record = url.record.with_query(none)
		if mut query := url.query_object {
			query.list.clear()
		}
		return
	}
	// Basic URL parsing removes ASCII tabs/newlines even in query state.
	raw_input := if value.starts_with('?') { value[1..] } else { value }
	input := raw_input.replace('\t', '').replace('\r', '').replace('\n', '')
	url.record = url.record.with_query(input)
	// The query record holds the URL-encoded, normalized result. URLSearchParams
	// must reflect that result rather than the setter's unparsed input.
	if mut query := url.query_object {
		query.list = url_decode(url.record.query or { '' })
	}
}

fn (mut url DOMURL) set_query_from_params(query ?string) {
	// URLSearchParams serialization is already application/x-www-form-urlencoded
	// encoded, so install it directly rather than percent-encoding it again.
	url.record.query = query
}

pub fn (url &DOMURL) query() ?string {
	return url.record.query
}

pub fn (mut url DOMURL) set_query(query ?string) {
	url.set_query_from_params(query)
}

pub fn (url &DOMURL) search_params() &URLSearchParams {
	if query := url.query_object {
		return query
	}
	mut mutable_url := unsafe { &DOMURL(url) }
	// Source initializes from the URL record's query, not constructor input.
	// A leading '?' inside that query is a literal part of its first name.
	mut query := URLSearchParams.create(url_decode(url.record.query or { '' }))
	query.bind_url(mutable_url)
	mutable_url.query_object = query
	return query
}

pub fn (url &DOMURL) hash() string {
	fragment := url.record.fragment or { return '' }
	return if fragment == '' {
		''
	} else {
		'#${fragment}'
	}
}

pub fn (mut url DOMURL) set_hash(value string) {
	if value == '' {
		url.record = url.record.with_fragment(none)
		return
	}
	input := if value.starts_with('#') { value[1..] } else { value }
	url.record = url.record.with_fragment(input)
}

pub fn (url &DOMURL) has_an_opaque_path() bool {
	return url.record.has_an_opaque_path
}

pub fn (url &DOMURL) path_segment_at_index(index int) string {
	return url.record.path_segment_at_index(index)
}

pub type CreateObjectURLHook = fn (object_id string) !string

pub type RevokeObjectURLHook = fn (url string)

pub fn DOMURL.create_object_url_with_hook(object_id string, hook CreateObjectURLHook) !string {
	return hook(object_id)
}

pub fn DOMURL.revoke_object_url_with_hook(value string, hook RevokeObjectURLHook) {
	if value.starts_with('blob:') {
		hook(value)
	}
}

// HTML passes the actual current settings at this import-cycle boundary.
pub fn DOMURL.create_object_url(object fileapi.BlobURLObject, settings fileapi.BlobURLSettingsObject) !string {
	return fileapi.add_entry_to_blob_url_store(object, settings)
}

pub fn DOMURL.revoke_object_url(value string, environment fileapi.BlobURLUsageEnvironment) {
	record := parse(value, none, none) or { return }
	if record.scheme != 'blob' { return }
	entry := record.blob_url_entry() or { return }
	if !fileapi.check_for_same_partition_blob_url_usage(entry, environment) { return }
	fileapi.remove_entry_from_blob_url_store(record)
}

pub fn DOMURL.create_legacy_object_url_for_blob(blob &fileapi.Blob, environment fileapi.LegacyBlobURLEnvironment, mut store fileapi.LegacyBlobURLStore) !string {
	return store.add_entry(fileapi.BlobURLObject.from_blob(blob), environment)
}

pub fn DOMURL.revoke_legacy_object_url_from_store(value string, environment fileapi.LegacyBlobURLEnvironment, mut store fileapi.LegacyBlobURLStore) {
	entry := store.resolve(value) or { return }
	if !fileapi.check_for_same_partition_legacy_blob_url_usage(entry, environment) {
		return
	}
	store.remove_entry(value)
}

fn finish_parsing(parsed_url ?liburl.URL) ?liburl.URL {
	record := parsed_url or { return none }
	return finish_parsing_record(record)
}

// The DOM adapter receives this same finish step through HTML's setup hook,
// avoiding a DOM/FileAPI import cycle and retaining an owned record per URL.
pub fn finish_parsing_record(parsed_url liburl.URL) liburl.URL {
	mut record := parsed_url.copy()
	if record.scheme != 'blob' { return record }
	if entry := fileapi.resolve_a_blob_url(record) {
		record.set_blob_url_entry(entry.snapshot())
	}
	return record
}

pub fn parse_from_byte_string(input string, base_url ?liburl.URL, encoding ?string) ?liburl.URL {
	_ = encoding
	if base := base_url {
		return finish_parsing(liburl.parse_with_base(input, &base))
	}
	return finish_parsing(liburl.parse(input))
}

pub fn parse(input string, base_url ?liburl.URL, encoding ?string) ?liburl.URL {
	return parse_from_byte_string(input, base_url, encoding)
}

@[heap]
pub struct Origin {
mut:
	record liburl.Origin
}

pub struct OriginDOMURLSource {
pub:
	value &DOMURL
}

pub struct OriginObjectSource {
pub:
	value &Origin
}

pub type OriginInput = OriginDOMURLSource | OriginObjectSource | string

pub fn Origin.create(record liburl.Origin) &Origin {
	return &Origin{
		record: record
	}
}

pub fn Origin.create_opaque() &Origin {
	return Origin.create(liburl.Origin.create_opaque(.standard))
}

pub fn Origin.construct_impl() &Origin {
	return Origin.create_opaque()
}

pub fn Origin.from_string(value string) !&Origin {
	return Origin.from(value)
}

pub fn Origin.from(value OriginInput) !&Origin {
	if record := extract_origin_from_platform_object(value) {
		return Origin.create(record)
	}
	match value {
		string {
			parsed_url := liburl.parse(value) or { return error('TypeError: Value is not a valid Origin') }
			return Origin.create(parsed_url.origin())
		}
		OriginDOMURLSource {
			return error('TypeError: Value is not a valid Origin')
		}
		OriginObjectSource {
			return error('TypeError: Value is not a valid Origin')
		}
	}
}

fn extract_origin_from_platform_object(value OriginInput) ?liburl.Origin {
	return match value {
		OriginDOMURLSource { value.value.record.origin() }
		OriginObjectSource { value.value.record }
		string { none }
	}
}

pub fn (url &DOMURL) extract_an_origin() &Origin {
	return Origin.create(url.record.origin())
}

pub fn (origin &Origin) extract_an_origin() &Origin {
	return Origin.create(origin.record)
}

pub fn (origin &Origin) opaque() bool {
	return origin.record.is_opaque()
}

pub fn (origin &Origin) is_same_origin(other &Origin) bool {
	return origin.record.is_same_origin(other.record)
}

pub fn (origin &Origin) is_same_site(other &Origin) bool {
	return origin.record.is_same_site(other.record)
}

pub fn (origin &Origin) serialize() string {
	return origin.record.serialize()
}
