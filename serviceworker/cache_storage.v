// Copyright (c) 2025-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ServiceWorker/Cache.{h,cpp,idl}, CacheStorage.{h,cpp,idl},
// and NameToCacheMap.h. The browser binding queues these operations as tasks;
// this typed engine boundary returns their already-settled promise projection.
module serviceworker

import fetch

pub struct CacheQueryOptions {
pub:
	ignore_search bool
	ignore_method bool
	ignore_vary   bool
}

pub struct MultiCacheQueryOptions {
pub:
	ignore_search bool
	ignore_method bool
	ignore_vary   bool
	cache_name    ?string
}

fn (options MultiCacheQueryOptions) cache_query_options() CacheQueryOptions {
	return CacheQueryOptions{
		ignore_search: options.ignore_search
		ignore_method: options.ignore_method
		ignore_vary:   options.ignore_vary
	}
}

@[heap]
pub struct RequestResponse {
pub:
	request  &fetch.Request
	response &fetch.Response
}

@[heap]
pub struct RequestResponseList {
pub mut:
	elements []&RequestResponse
}

pub enum CacheBatchOperationType {
	delete
	put
}

@[heap]
pub struct CacheBatchOperation {
pub:
	operation_type CacheBatchOperationType
	request        &fetch.Request
	response       ?&fetch.Response
	options        CacheQueryOptions
}

pub fn (operation &CacheBatchOperation) type_() CacheBatchOperationType {
	return operation.operation_type
}

pub struct CacheResult {
pub:
	state      WorkerPromiseState
	error      string
	response   ?&fetch.Response
	responses  []&fetch.Response
	requests   []&fetch.Request
	bool_value ?bool
}

pub type CacheFetchHook = fn (&fetch.Request) !&fetch.Response

@[heap]
pub struct Cache {
mut:
	request_response_list &RequestResponseList
	fetch_hook            ?CacheFetchHook
}

pub fn Cache.create(request_response_list &RequestResponseList) &Cache {
	return &Cache{
		request_response_list: request_response_list
	}
}

pub fn (mut cache Cache) set_fetch_hook(hook CacheFetchHook) {
	cache.fetch_hook = hook
}

// The binding layer creates immutable Response wrappers around this list.
pub fn resolve_cache_response_list(responses []&fetch.Response) CacheResult {
	mut copies := []&fetch.Response{cap: responses.len}
	for response in responses {
		copies << response.clone()
	}
	return CacheResult{
		state:     .fulfilled
		responses: copies
	}
}

// The binding layer creates immutable Request wrappers around this list.
pub fn resolve_cache_request_list(requests []&fetch.Request) CacheResult {
	mut copies := []&fetch.Request{cap: requests.len}
	for request in requests {
		copies << request.clone()
	}
	return CacheResult{
		state:    .fulfilled
		requests: copies
	}
}

fn cache_rejected(message string) CacheResult {
	return CacheResult{
		state: .rejected
		error: message
	}
}

fn vary_field_values(response &fetch.Response) []string {
	values := response.fetch_response_header_list().get_decode_and_split('Vary') or {
		return []string{}
	}
	mut fields := []string{cap: values.len}
	for value in values {
		fields << value.trim_space()
	}
	return fields
}

fn request_matches_cached_item(request_query &fetch.Request, request &fetch.Request, response ?&fetch.Response, options CacheQueryOptions) bool {
	if !options.ignore_method && request.fetch_request_method() != 'GET' {
		return false
	}
	mut query_url := request_query.url()
	mut cached_url := request.url()
	if options.ignore_search {
		query_url = query_url.with_query(none)
		cached_url = cached_url.with_query(none)
	}
	query_url.set_fragment(none)
	cached_url.set_fragment(none)
	if query_url != cached_url {
		return false
	}
	cached_response := response or { return true }
	if options.ignore_vary || !cached_response.fetch_response_header_list().contains('Vary') {
		return true
	}
	for field_value in vary_field_values(cached_response) {
		if field_value == '*' {
			return false
		}
		cached_header := request.fetch_request_header_list().get(field_value)
		query_header := request_query.fetch_request_header_list().get(field_value)
		cached_value := cached_header or {
			if query_header == none {
				continue
			}
			return false
		}
		query_value := query_header or { return false }
		if cached_value != query_value {
			return false
		}
	}
	return true
}

fn clone_request_response(entry &RequestResponse) &RequestResponse {
	return &RequestResponse{
		request:  entry.request.clone()
		response: entry.response.clone()
	}
}

fn query_cache_entries(request_response_list &RequestResponseList, request_query &fetch.Request, options CacheQueryOptions, clone_cache bool) []&RequestResponse {
	mut result := []&RequestResponse{}
	for entry in request_response_list.elements {
		if request_matches_cached_item(request_query, entry.request, entry.response, options) {
			result << if clone_cache { clone_request_response(entry) } else { entry }
		}
	}
	return result
}

pub fn (cache &Cache) query_cache(request_query &fetch.Request, options CacheQueryOptions) []&RequestResponse {
	return query_cache_entries(cache.request_response_list, request_query, options, true)
}

pub fn (cache &Cache) match_all(request ?&fetch.Request, options CacheQueryOptions) CacheResult {
	if query := request {
		if query.fetch_request_method() != 'GET' && !options.ignore_method {
			return CacheResult{
				state: .fulfilled
			}
		}
		matches := cache.query_cache(query, options)
		mut responses := []&fetch.Response{cap: matches.len}
		for entry in matches {
			responses << entry.response
		}
		return CacheResult{
			state:     .fulfilled
			responses: responses
		}
	}
	mut responses := []&fetch.Response{cap: cache.request_response_list.elements.len}
	for entry in cache.request_response_list.elements {
		responses << entry.response.clone()
	}
	return CacheResult{
		state:     .fulfilled
		responses: responses
	}
}

pub fn (cache &Cache) match_(request &fetch.Request, options CacheQueryOptions) CacheResult {
	result := cache.match_all(request, options)
	if result.state == .rejected {
		return result
	}
	if result.responses.len == 0 {
		return CacheResult{
			state: .fulfilled
		}
	}
	return CacheResult{
		state:    .fulfilled
		response: result.responses[0]
	}
}

fn cache_request_is_http_get(request &fetch.Request) bool {
	return request.fetch_request_method() == 'GET' && request.url().scheme() in ['http', 'https']
}

pub fn (cache &Cache) add(request &fetch.Request) CacheResult {
	return cache.add_all([request])
}

pub fn (cache &Cache) add_all(requests []&fetch.Request) CacheResult {
	for request in requests {
		if !cache_request_is_http_get(request) {
			return cache_rejected('TypeError: Request must be a GET request with an HTTP(S) URL')
		}
	}
	fetch_hook := cache.fetch_hook or {
		return cache_rejected('NetworkError: Cache.addAll() has no fetch host')
	}
	mut operations := []&CacheBatchOperation{cap: requests.len}
	for original in requests {
		request := original.clone()
		response := fetch_hook(request) or { return cache_rejected(err.msg()) }
		status := response.fetch_response_status()
		if response.fetch_response_type() == .error || !fetch.is_ok_status(status) || status == 206 {
			return cache_rejected('TypeError: Fetch request failed')
		}
		if '*' in vary_field_values(response) {
			return cache_rejected("TypeError: Vary '*' is not supported")
		}
		if response.fetch_response_aborted() {
			return cache_rejected('AbortError: Fetch request was aborted')
		}
		operations << &CacheBatchOperation{
			operation_type: .put
			request:        request
			response:       response
		}
	}
	cache.batch_cache_operations(operations) or { return cache_rejected(err.msg()) }
	return CacheResult{
		state: .fulfilled
	}
}

pub fn (cache &Cache) put(request &fetch.Request, response &fetch.Response) CacheResult {
	if !cache_request_is_http_get(request) {
		return cache_rejected('TypeError: Request must be a GET request with an HTTP(S) URL')
	}
	if response.fetch_response_status() == 206 {
		return cache_rejected('TypeError: Partial responses are not supported')
	}
	if '*' in vary_field_values(response) {
		return cache_rejected("TypeError: Vary '*' is not supported")
	}
	if body := response.fetch_response_body() {
		if body.disturbed() || body.stream_locked() {
			return cache_rejected("TypeError: Response's body stream is disturbed or locked")
		}
	}
	operation := &CacheBatchOperation{
		operation_type: .put
		request:        request
		response:       response.clone()
	}
	cache.batch_cache_operations([operation]) or { return cache_rejected(err.msg()) }
	return CacheResult{
		state: .fulfilled
	}
}

pub fn (cache &Cache) delete_(request &fetch.Request, options CacheQueryOptions) CacheResult {
	if request.fetch_request_method() != 'GET' && !options.ignore_method {
		return CacheResult{
			state:      .fulfilled
			bool_value: false
		}
	}
	operation := &CacheBatchOperation{
		operation_type: .delete
		request:        request
		options:        options
	}
	removed := cache.batch_cache_operations([operation]) or { return cache_rejected(err.msg()) }
	return CacheResult{
		state:      .fulfilled
		bool_value: removed
	}
}

pub fn (cache &Cache) keys(request ?&fetch.Request, options CacheQueryOptions) CacheResult {
	if query := request {
		if query.fetch_request_method() != 'GET' && !options.ignore_method {
			return CacheResult{
				state: .fulfilled
			}
		}
		// Only requests are exposed. Cloning responses would tee every matched
		// cached body and grow a chain of streams on each keys() call.
		matches := query_cache_entries(cache.request_response_list, query, options, false)
		mut requests := []&fetch.Request{cap: matches.len}
		for entry in matches {
			requests << entry.request.clone()
		}
		return CacheResult{
			state:    .fulfilled
			requests: requests
		}
	}
	mut requests := []&fetch.Request{cap: cache.request_response_list.elements.len}
	for entry in cache.request_response_list.elements {
		requests << entry.request.clone()
	}
	return CacheResult{
		state:    .fulfilled
		requests: requests
	}
}

pub fn (cache &Cache) batch_cache_operations(operations []&CacheBatchOperation) !bool {
	// Operations add and remove entries without mutating them. Copy the list,
	// not its responses: cloning each response would tee its stored body.
	backup := cache.request_response_list.elements.clone()
	mut added_items := &RequestResponseList{}
	mut removed_any_items := false
	mut list := cache.request_response_list
	for operation in operations {
		if operation.operation_type == .delete && operation.response != none {
			list.elements = backup
			return error("TypeError: Batch operations of type 'delete' must not have a response")
		}
		if query_cache_entries(added_items, operation.request, operation.options, false).len > 0 {
			list.elements = backup
			return error('InvalidStateError: Batch operation requests must be unique')
		}
		if operation.operation_type == .delete {
			matches := query_cache_entries(list, operation.request, operation.options, false)
			if matches.len > 0 {
				removed_any_items = true
				mut retained := []&RequestResponse{cap: list.elements.len}
				for entry in list.elements {
					mut remove := false
					for matched in matches {
						if voidptr(entry) == voidptr(matched) {
							remove = true
							break
						}
					}
					if !remove {
						retained << entry
					}
				}
				list.elements = retained
			}
			continue
		}
		response := operation.response or {
			list.elements = backup
			return error("TypeError: Batch operations of type 'put' must have a response")
		}
		if !cache_request_is_http_get(operation.request) {
			list.elements = backup
			return error('TypeError: Request must be a GET request with an HTTP(S) URL')
		}
		matches := query_cache_entries(list, operation.request, CacheQueryOptions{}, false)
		mut retained := []&RequestResponse{cap: list.elements.len + 1}
		for entry in list.elements {
			mut replace := false
			for matched in matches {
				if voidptr(entry) == voidptr(matched) {
					replace = true
					break
				}
			}
			if !replace {
				retained << entry
			}
		}
		inserted := &RequestResponse{
			request:  operation.request
			response: response
		}
		retained << inserted
		list.elements = retained
		added_items.elements << inserted
	}
	return removed_any_items
}

pub struct CacheStorageResult {
pub:
	state    WorkerPromiseState
	error    string
	value    ?bool
	cache    ?&Cache
	response ?&fetch.Response
	keys     []string
}

@[heap]
pub struct CacheStorage {
mut:
	name_to_cache_map map[string]&RequestResponseList
	cache_order       []string
}

pub fn CacheStorage.create() &CacheStorage {
	return &CacheStorage{}
}

pub fn (mut storage CacheStorage) open(cache_name string) CacheStorageResult {
	list := storage.get_or_create_cache(cache_name)
	return CacheStorageResult{
		state: .fulfilled
		cache: Cache.create(list)
	}
}

pub fn (storage &CacheStorage) has(cache_name string) CacheStorageResult {
	return CacheStorageResult{
		state: .fulfilled
		value: storage.contains_cache(cache_name)
	}
}

pub fn (storage &CacheStorage) match_(request &fetch.Request, options MultiCacheQueryOptions) CacheStorageResult {
	query_options := options.cache_query_options()
	if cache_name := options.cache_name {
		list := storage.name_to_cache_map[cache_name] or {
			return CacheStorageResult{
				state: .fulfilled
			}
		}
		result := Cache.create(list).match_(request, query_options)
		return CacheStorageResult{
			state:    result.state
			error:    result.error
			response: result.response
		}
	}
	for cache_name in storage.cache_order {
		list := storage.name_to_cache_map[cache_name] or { continue }
		result := Cache.create(list).match_(request, query_options)
		if response := result.response {
			return CacheStorageResult{
				state:    .fulfilled
				response: response
			}
		}
	}
	return CacheStorageResult{
		state: .fulfilled
	}
}

pub fn (mut storage CacheStorage) delete_(cache_name string) CacheStorageResult {
	return CacheStorageResult{
		state: .fulfilled
		value: storage.delete_cache(cache_name)
	}
}

pub fn (storage &CacheStorage) keys() CacheStorageResult {
	return CacheStorageResult{
		state: .fulfilled
		keys:  storage.cache_keys()
	}
}

pub fn (storage &CacheStorage) contains_cache(cache_name string) bool {
	return cache_name in storage.name_to_cache_map
}

pub fn (mut storage CacheStorage) delete_cache(cache_name string) bool {
	if !storage.contains_cache(cache_name) {
		return false
	}
	storage.name_to_cache_map.delete(cache_name)
	storage.cache_order = storage.cache_order.filter(it != cache_name)
	return true
}

pub fn (mut storage CacheStorage) get_or_create_cache(cache_name string) &RequestResponseList {
	if cache := storage.name_to_cache_map[cache_name] {
		return cache
	}
	cache := &RequestResponseList{}
	storage.name_to_cache_map[cache_name] = cache
	storage.cache_order << cache_name
	return cache
}

pub fn (storage &CacheStorage) cache_keys() []string {
	return storage.cache_order.clone()
}

pub fn (storage &CacheStorage) relevant_name_to_cache_map() map[string]&RequestResponseList {
	return storage.name_to_cache_map.clone()
}
