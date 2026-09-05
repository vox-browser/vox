// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CookieStore/CookieStore.{h,cpp,idl}.
module cookiestore

import dom
import html
import url

pub struct CookieListItem {
pub:
	name  ?string
	value ?string
}

pub struct CookieStoreGetOptions {
pub:
	name ?string
	url  ?string
}

pub struct CookieInit {
pub:
	name        string
	value       string
	expires     ?f64
	domain      ?string
	path        string = '/'
	same_site   CookieSameSite = .strict
	partitioned bool
}

pub struct CookieStoreDeleteOptions {
pub:
	name        string
	domain      ?string
	path        string = '/'
	partitioned bool
}

pub enum CookiePromiseState {
	pending
	fulfilled
	rejected
}

@[heap]
pub struct CookieItemPromise {
mut:
	state_  CookiePromiseState
	item_   ?CookieListItem
	reason_ string
}

fn CookieItemPromise.pending() &CookieItemPromise {
	return &CookieItemPromise{}
}

pub fn (promise &CookieItemPromise) state() CookiePromiseState {
	return promise.state_
}

pub fn (promise &CookieItemPromise) item() ?CookieListItem {
	return promise.item_
}

pub fn (promise &CookieItemPromise) reason() string {
	return promise.reason_
}

fn (mut promise CookieItemPromise) resolve(item ?CookieListItem) {
	if promise.state_ == .pending {
		promise.item_ = item
		promise.state_ = .fulfilled
	}
}

fn (mut promise CookieItemPromise) reject(reason string) {
	if promise.state_ == .pending {
		promise.reason_ = reason
		promise.state_ = .rejected
	}
}

@[heap]
pub struct CookieListPromise {
mut:
	state_  CookiePromiseState
	items_  []CookieListItem
	reason_ string
}

fn CookieListPromise.pending() &CookieListPromise {
	return &CookieListPromise{}
}

pub fn (promise &CookieListPromise) state() CookiePromiseState {
	return promise.state_
}

pub fn (promise &CookieListPromise) items() []CookieListItem {
	return promise.items_.clone()
}

pub fn (promise &CookieListPromise) reason() string {
	return promise.reason_
}

fn (mut promise CookieListPromise) resolve(items []CookieListItem) {
	if promise.state_ == .pending {
		promise.items_ = items.clone()
		promise.state_ = .fulfilled
	}
}

fn (mut promise CookieListPromise) reject(reason string) {
	if promise.state_ == .pending {
		promise.reason_ = reason
		promise.state_ = .rejected
	}
}

@[heap]
pub struct CookieVoidPromise {
mut:
	state_  CookiePromiseState
	reason_ string
}

fn CookieVoidPromise.pending() &CookieVoidPromise {
	return &CookieVoidPromise{}
}

pub fn (promise &CookieVoidPromise) state() CookiePromiseState {
	return promise.state_
}

pub fn (promise &CookieVoidPromise) reason() string {
	return promise.reason_
}

fn (mut promise CookieVoidPromise) resolve() {
	if promise.state_ == .pending {
		promise.state_ = .fulfilled
	}
}

fn (mut promise CookieVoidPromise) reject(reason string) {
	if promise.state_ == .pending {
		promise.reason_ = reason
		promise.state_ = .rejected
	}
}

pub struct CookieStoreEnvironment {
pub:
	creation_url     url.URL
	api_base_url     url.URL
	origin_is_opaque bool
	is_window        bool = true
	document         ?&dom.Document
}

// CookieStore.cpp parses the option with URL::Parser::basic_parse and the
// environment's API base URL. Keep that exact subsystem boundary here rather
// than maintaining a second CookieStore-specific URL grammar.
pub fn parse_cookie_store_url(input string, base &url.URL) ?url.URL {
	return url.basic_parse(input, base)
}

fn urls_have_same_origin(a &url.URL, b &url.URL) bool {
	return a.origin().is_same_origin(b.origin())
}

// https://cookiestore.spec.whatwg.org/#create-a-cookielistitem
pub fn create_a_cookie_list_item(cookie Cookie) CookieListItem {
	return CookieListItem{
		name: cookie.name
		value: cookie.value
	}
}

// The binding creates a fresh JavaScript array. Cloning gives typed callers
// the same isolation from the internal query result.
pub fn cookie_list_to_value(cookie_list []CookieListItem) []CookieListItem {
	return cookie_list.clone()
}

// https://cookiestore.spec.whatwg.org/#normalize-a-cookie-name-or-value
pub fn normalize_cookie_name_or_value(input string) string {
	return input.trim('\t ')
}

fn query_cookies(backend &CookieStoreBackend, record &url.URL, name ?string) []CookieListItem {
	mut list := []CookieListItem{}
	for cookie in backend.query(record) {
		if candidate_name := name {
			if cookie.name != normalize_cookie_name_or_value(candidate_name) {
				continue
			}
		}
		list << create_a_cookie_list_item(cookie)
	}
	return list
}

fn cookie_default_path(paths []string) []string {
	if paths.len == 0 {
		return ['']
	}
	mut result := paths.clone()
	if result.len > 1 {
		result.delete(result.len - 1)
	} else {
		result[0] = ''
	}
	return result
}

pub fn serialized_cookie_default_path(record &url.URL) string {
	mut clone := *record
	clone.paths = cookie_default_path(clone.paths)
	return clone.serialize_path()
}

const maximum_name_value_pair_size = 4096
const maximum_attribute_value_size = 1024
const maximum_cookie_age_ms = f64(400 * 24 * 60 * 60 * 1000)

fn contains_forbidden_cookie_byte(value string) bool {
	for byte in value.bytes() {
		if byte == `;` || byte == 0x7f || (byte <= 0x1f && byte != `\t`) {
			return true
		}
	}
	return false
}

// https://cookiestore.spec.whatwg.org/#set-a-cookie
pub fn set_a_cookie(mut backend CookieStoreBackend, record &url.URL, input CookieInit) bool {
	name := normalize_cookie_name_or_value(input.name)
	value := normalize_cookie_name_or_value(input.value)
	if contains_forbidden_cookie_byte(name) || contains_forbidden_cookie_byte(value) || name.contains('=') {
		return false
	}
	if name.len == 0 {
		if value.len == 0 || value.contains('=') {
			return false
		}
		lower_value := value.to_lower()
		if lower_value.starts_with('__host-') || lower_value.starts_with('__host-http-') || lower_value.starts_with('__http-') || lower_value.starts_with('__secure-') {
			return false
		}
	}
	lower_name := name.to_lower()
	if lower_name.starts_with('__host-http-') || lower_name.starts_with('__http-') {
		return false
	}
	if name.len + value.len > maximum_name_value_pair_size {
		return false
	}
	host := url_host_string(record)
	if host.len == 0 {
		return false
	}
	mut parsed_domain := ''
	mut host_only := true
	if domain := input.domain {
		if domain.starts_with('.') || lower_name.starts_with('__host-') {
			return false
		}
		lower_domain := domain.to_lower()
		if !dom.is_a_registrable_domain_suffix_of_or_is_equal_to(lower_domain, host) {
			return false
		}
		for code_point in lower_domain.runes() {
			if url.is_forbidden_domain_code_point(u32(code_point)) {
				return false
			}
		}
		if lower_domain.len > maximum_attribute_value_size {
			return false
		}
		parsed_domain = lower_domain
		host_only = false
	}
	mut expires := input.expires
	if requested_expiry := expires {
		age_limit := backend.now_ms() + maximum_cookie_age_ms
		if requested_expiry > age_limit {
			expires = age_limit
		}
	}
	mut path := input.path
	if path.len == 0 {
		path = serialized_cookie_default_path(record)
	}
	if !path.starts_with('/') || (path != '/' && lower_name.starts_with('__host-')) || path.len > maximum_attribute_value_size {
		return false
	}
	// Partitioned storage is also a FIXME in upstream CookieStore.cpp.
	_ = input.partitioned
	backend.store(record, Cookie{
		name: name
		value: value
		domain: parsed_domain
		path: path
		expires: expires
		secure: true
		same_site: input.same_site
		partitioned: false
		host_only: host_only
	})
	return true
}

// https://cookiestore.spec.whatwg.org/#delete-a-cookie
pub fn delete_a_cookie(mut backend CookieStoreBackend, record &url.URL, options CookieStoreDeleteOptions) bool {
	name := normalize_cookie_name_or_value(options.name)
	value := if name.len == 0 { 'ladybird' } else { '' }
	return set_a_cookie(mut backend, record, CookieInit{
		name: name
		value: value
		expires: f64(-8.64e15)
		domain: options.domain
		path: options.path
		same_site: .strict
		partitioned: options.partitioned
	})
}

@[heap]
pub struct CookieStore {
	dom.EventTarget
mut:
	backend_    &CookieStoreBackend = unsafe { nil }
	environment CookieStoreEnvironment
	event_loop_ &html.EventLoop = unsafe { nil }
}

pub fn CookieStore.create(backend &CookieStoreBackend, environment CookieStoreEnvironment, event_loop &html.EventLoop) &CookieStore {
	return &CookieStore{
		backend_: backend
		environment: environment
		event_loop_: event_loop
	}
}

pub fn (store &CookieStore) event_target() &dom.EventTarget {
	return unsafe { &dom.EventTarget(store) }
}

pub fn (store &CookieStore) backend() &CookieStoreBackend {
	return store.backend_
}

fn (store &CookieStore) resolved_options_url(options_url ?string) !url.URL {
	mut target := store.environment.creation_url
	if option := options_url {
		parsed := parse_cookie_store_url(option, &store.environment.api_base_url) or {
			return error('TypeError: url is invalid')
		}
		if store.environment.is_window && !parsed.equals(&store.environment.creation_url, true) {
			return error('TypeError: url does not match creation URL')
		}
		if !urls_have_same_origin(&parsed, &store.environment.creation_url) {
			return error("TypeError: url's origin does not match creation URL's origin")
		}
		target = parsed
	}
	return target
}

fn (store &CookieStore) queue_item_query(record url.URL, name ?string, promise &CookieItemPromise) {
	html.queue_a_task(.unspecified, store.event_loop_, store.environment.document, fn [store, record, name, promise] () {
		list := query_cookies(store.backend_, &record, name)
		html.queue_a_task(.unspecified, store.event_loop_, store.environment.document, fn [list, promise] () {
			mut mutable_promise := unsafe { &CookieItemPromise(promise) }
			if list.len == 0 {
				mutable_promise.resolve(none)
			} else {
				mutable_promise.resolve(list[0])
			}
		})
	})
}

fn (store &CookieStore) queue_list_query(record url.URL, name ?string, promise &CookieListPromise) {
	html.queue_a_task(.unspecified, store.event_loop_, store.environment.document, fn [store, record, name, promise] () {
		list := query_cookies(store.backend_, &record, name)
		html.queue_a_task(.unspecified, store.event_loop_, store.environment.document, fn [list, promise] () {
			mut mutable_promise := unsafe { &CookieListPromise(promise) }
			mutable_promise.resolve(cookie_list_to_value(list))
		})
	})
}

// https://cookiestore.spec.whatwg.org/#dom-cookiestore-get
pub fn (store &CookieStore) get(name string) &CookieItemPromise {
	mut promise := CookieItemPromise.pending()
	if store.environment.origin_is_opaque {
		promise.reject('SecurityError: Document origin is opaque')
		return promise
	}
	store.queue_item_query(store.environment.creation_url, name, promise)
	return promise
}

pub fn (store &CookieStore) get_with_options(options CookieStoreGetOptions) &CookieItemPromise {
	mut promise := CookieItemPromise.pending()
	if store.environment.origin_is_opaque {
		promise.reject('SecurityError: Document origin is opaque')
		return promise
	}
	if options.name == none && options.url == none {
		promise.reject('TypeError: CookieStoreGetOptions is empty')
		return promise
	}
	record := store.resolved_options_url(options.url) or {
		promise.reject(err.msg())
		return promise
	}
	store.queue_item_query(record, options.name, promise)
	return promise
}

// https://cookiestore.spec.whatwg.org/#dom-cookiestore-getall
pub fn (store &CookieStore) get_all(name string) &CookieListPromise {
	mut promise := CookieListPromise.pending()
	if store.environment.origin_is_opaque {
		promise.reject('SecurityError: Document origin is opaque')
		return promise
	}
	store.queue_list_query(store.environment.creation_url, name, promise)
	return promise
}

pub fn (store &CookieStore) get_all_with_options(options CookieStoreGetOptions) &CookieListPromise {
	mut promise := CookieListPromise.pending()
	if store.environment.origin_is_opaque {
		promise.reject('SecurityError: Document origin is opaque')
		return promise
	}
	record := store.resolved_options_url(options.url) or {
		promise.reject(err.msg())
		return promise
	}
	store.queue_list_query(record, options.name, promise)
	return promise
}

fn (store &CookieStore) queue_set(options CookieInit, promise &CookieVoidPromise, error_message string) {
	html.queue_a_task(.unspecified, store.event_loop_, store.environment.document, fn [store, options, promise, error_message] () {
		mut backend := store.backend_
		result := set_a_cookie(mut backend, &store.environment.creation_url, options)
		html.queue_a_task(.unspecified, store.event_loop_, store.environment.document, fn [result, error_message, promise] () {
			mut mutable_promise := unsafe { &CookieVoidPromise(promise) }
			if !result {
				mutable_promise.reject('TypeError: ${error_message}')
			} else {
				mutable_promise.resolve()
			}
		})
	})
}

// https://cookiestore.spec.whatwg.org/#dom-cookiestore-set
pub fn (store &CookieStore) set(name string, value string) &CookieVoidPromise {
	mut promise := CookieVoidPromise.pending()
	if store.environment.origin_is_opaque {
		promise.reject('SecurityError: Document origin is opaque')
		return promise
	}
	store.queue_set(CookieInit{
		name: name
		value: value
	}, promise, 'Name or value are malformed')
	return promise
}

pub fn (store &CookieStore) set_with_options(options CookieInit) &CookieVoidPromise {
	mut promise := CookieVoidPromise.pending()
	if store.environment.origin_is_opaque {
		promise.reject('SecurityError: Document origin is opaque')
		return promise
	}
	store.queue_set(options, promise, 'Name, value, domain or path are malformed')
	return promise
}

fn (store &CookieStore) queue_delete(options CookieStoreDeleteOptions, promise &CookieVoidPromise) {
	html.queue_a_task(.unspecified, store.event_loop_, store.environment.document, fn [store, options, promise] () {
		mut backend := store.backend_
		result := delete_a_cookie(mut backend, &store.environment.creation_url, options)
		html.queue_a_task(.unspecified, store.event_loop_, store.environment.document, fn [result, promise] () {
			mut mutable_promise := unsafe { &CookieVoidPromise(promise) }
			if !result {
				mutable_promise.reject('TypeError: Name is malformed')
			} else {
				mutable_promise.resolve()
			}
		})
	})
}

// https://cookiestore.spec.whatwg.org/#dom-cookiestore-delete
pub fn (store &CookieStore) delete_(name string) &CookieVoidPromise {
	mut promise := CookieVoidPromise.pending()
	if store.environment.origin_is_opaque {
		promise.reject('SecurityError: Document origin is opaque')
		return promise
	}
	store.queue_delete(CookieStoreDeleteOptions{
		name: name
	}, promise)
	return promise
}

pub fn (store &CookieStore) delete_with_options(options CookieStoreDeleteOptions) &CookieVoidPromise {
	mut promise := CookieVoidPromise.pending()
	if store.environment.origin_is_opaque {
		promise.reject('SecurityError: Document origin is opaque')
		return promise
	}
	store.queue_delete(options, promise)
	return promise
}

pub fn (store &CookieStore) set_onchange(handler ?&dom.CallbackType) {
	store.event_target().set_event_handler_attribute('change', handler)
}

pub fn (store &CookieStore) onchange() ?&dom.CallbackType {
	return store.event_target().event_handler_attribute('change')
}

pub enum CookieChangeType {
	changed
	deleted
}

pub struct CookieChange {
pub:
	cookie Cookie
	type_  CookieChangeType
}

// https://cookiestore.spec.whatwg.org/#observable-changes
pub fn observable_changes(changes []Cookie, now f64) []CookieChange {
	mut observable := []CookieChange{cap: changes.len}
	for cookie in changes {
		type_ := if expiry := cookie.expires {
			if expiry < now { CookieChangeType.deleted } else { CookieChangeType.changed }
		} else {
			CookieChangeType.changed
		}
		observable << CookieChange{
			cookie: cookie
			type_: type_
		}
	}
	return observable
}

pub struct PreparedLists {
pub:
	changed []CookieListItem
	deleted []CookieListItem
}

// https://cookiestore.spec.whatwg.org/#prepare-lists
pub fn prepare_lists(changes []CookieChange) PreparedLists {
	mut changed := []CookieListItem{}
	mut deleted := []CookieListItem{}
	for change in changes {
		item := create_a_cookie_list_item(change.cookie)
		if change.type_ == .changed {
			changed << item
		} else {
			deleted << CookieListItem{
				name: item.name
			}
		}
	}
	return PreparedLists{
		changed: changed
		deleted: deleted
	}
}

// https://cookiestore.spec.whatwg.org/#process-cookie-changes
pub fn (store &CookieStore) process_cookie_changes(changes []Cookie) {
	now := store.backend_.now_ms()
	html.queue_a_task(.dom_manipulation, store.event_loop_, store.environment.document, fn [store, changes, now] () {
		observable := observable_changes(changes, now)
		lists := prepare_lists(observable)
		mut event := CookieChangeEvent.create('change', CookieChangeEventInit{
			changed: lists.changed
			deleted: lists.deleted
		})
		event.set_bubbles(false)
		event.set_cancelable(false)
		store.event_target().dispatch_event(unsafe { &dom.Event(event) })
	})
}
