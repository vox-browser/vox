// SPDX-License-Identifier: BSD-2-Clause
module cachepolicy

import crypto.sha256
import json2
import os
import strconv
import time

// A verified snapshot of the response body and the metadata that describes it.
// An entry is readable only after its atomic commit record has been published.
pub struct DiskEntry {
pub:
	final_url string
	body      string
	response  Response
}

// Keep the version-one receipt's string fields and sorted JSON key order.
// Encoding this fixed schema avoids json2's map-key ownership cleanup; FastC
// with -gc none otherwise frees each cloned string key twice.
struct DiskTimingRecord {
	integrity     string
	request_time  string
	response_time string
	version       string = '1'
}

fn disk_integrity(final_url string, status string, encoded_headers string, body string) string {
	// Fixed-length digests make the field boundaries unambiguous without
	// constructing another complete copy of a potentially large image body.
	return sha256.hexhash(final_url) + sha256.hexhash(status) +
		sha256.hexhash(encoded_headers) + sha256.hexhash(body)
}

fn read_disk_part(path string, limit int) ?string {
	if !os.is_file(path) || os.file_size(path) > u64(limit) { return none }
	contents := os.read_file(path) or { return none }
	if contents.len == 0 || contents.len > limit { return none }
	return contents
}

fn write_disk_part(path string, contents string, limit int) bool {
	if contents.len == 0 || contents.len > limit { return false }
	os.mkdir_all(os.dir(path)) or { return false }
	temporary := '${path}.${os.getpid()}.${time.sys_mono_now()}.tmp'
	os.write_file(temporary, contents) or {
		os.rm(temporary) or {}
		return false
	}
	os.mv(temporary, path) or {
		os.rm(temporary) or {}
		return false
	}
	return true
}

// Invalidation removes the commit record first. Readers that already hold a
// record still verify its exact response bytes before using them.
pub fn discard_disk_entry(path string) {
	for suffix in ['.timing.json', '.status', '.url', '.headers.json', ''] {
		os.rm(path + suffix) or {}
	}
}

// Store one measured response. Timing is never synthesized while reading old
// entries. The historical companion names remain usable for diagnostics, but
// every cache adapter reads through read_disk_entry rather than raw files.
pub fn store_disk_response(path string, final_url string, body string, received_response Response, limit int) bool {
	response := Response{ ...received_response, headers: storage_headers(received_response.headers) }
	os.rm(path + '.timing.json') or {}
	os.rm(path + '.status') or {}
	if forbids_storage(response.headers) {
		discard_disk_entry(path)
		return false
	}
	encoded_headers := json2.encode(response.headers, escape_unicode: true)
	body_written := write_disk_part(path, body, limit)
	url_written := write_disk_part(path + '.url', final_url, limit)
	headers_written := write_disk_part(path + '.headers.json', encoded_headers, limit)
	if !body_written || !url_written || !headers_written || response.status < 100 || response.status > 599 {
		return false
	}
	timing := response.timing or { return false }
	status := response.status.str()
	if !write_disk_part(path + '.status', status, limit) { return false }
	// Decimal strings preserve exact millisecond timestamps in every JSON
	// decoder and avoid generic struct decoding's mutable field metadata.
	record := DiskTimingRecord{
		integrity:     disk_integrity(final_url, status, encoded_headers, body)
		request_time:  timing.request_time.str()
		response_time: timing.response_time.str()
	}
	return write_disk_part(path + '.timing.json', json2.encode(record), limit)
}

fn disk_record_fields(encoded string) ?map[string]string {
	value := json2.decode[json2.Any](encoded) or { return none }
	if value !is map[string]json2.Any { return none }
	fields := value as map[string]json2.Any
	mut strings := map[string]string{}
	for key in ['version', 'request_time', 'response_time', 'integrity'] {
		field := fields[key] or { return none }
		if field !is string { return none }
		strings[key] = field as string
	}
	return strings
}

fn disk_headers(encoded string) ?[]Header {
	value := json2.decode[json2.Any](encoded) or { return none }
	if value !is []json2.Any { return none }
	items := value as []json2.Any
	mut headers := []Header{cap: items.len}
	for item in items {
		if item !is map[string]json2.Any { return none }
		fields := item as map[string]json2.Any
		name := fields['name'] or { return none }
		field_value := fields['value'] or { return none }
		if name !is string || field_value !is string { return none }
		headers << Header{ name: name as string, value: field_value as string }
	}
	return headers
}

// A concurrent replacement may yield a cache miss. It must never pair a fresh
// header/timing record with another request's body, status or redirect target.
pub fn read_disk_entry(path string, limit int) ?DiskEntry {
	if limit <= 0 { return none }
	record := disk_record_fields(read_disk_part(path + '.timing.json', limit) or { return none }) or { return none }
	if record['version'] != '1' { return none }
	request_time := strconv.parse_int(record['request_time'], 10, 64) or { return none }
	response_time := strconv.parse_int(record['response_time'], 10, 64) or { return none }
	status := read_disk_part(path + '.status', limit) or { return none }
	code := strconv.parse_int(status, 10, 32) or { return none }
	if code < 100 || code > 599 { return none }
	final_url := read_disk_part(path + '.url', limit) or { return none }
	encoded_headers := read_disk_part(path + '.headers.json', limit) or { return none }
	body := read_disk_part(path, limit) or { return none }
	if record['integrity'] != disk_integrity(final_url, status, encoded_headers, body) {
		return none
	}
	// Validate the original receipt before filtering. Older entries may still
	// contain connection-specific fields, which must not be replayed either.
	headers := storage_headers(disk_headers(encoded_headers) or { return none })
	return DiskEntry{
		final_url: final_url
		body:      body
		response:  Response{
			status:  u32(code)
			headers: headers
			timing:  Timing{ request_time: request_time, response_time: response_time }
		}
	}
}
