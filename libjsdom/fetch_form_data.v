// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import domurl
import encoding
import fetch
import fileapi
import html
import libjs
import mimesniff
import xhr

fn materialize_form_data_body(mut vm libjs.VM, form &xhr.FormData) !FetchBodyValue {
	entries := form.form_data_entries()
	mut upper_bound := u64(80)
	for entry in entries {
		vm.consume_execution_budget()!
		// Bound expansion for quoted headers and CRLF normalization before
		// allocating the multipart byte vector. The native serializer supplies
		// the actual boundary, escaping, line endings and file Content-Type.
		mut cost := u64(256) + 3 * u64(entry.name.len)
		match entry.value {
			string { cost += 2 * u64(entry.value.len) }
			html.FormDataFile { cost += u64(entry.value.bytes.len) + 3 * u64(entry.value.name.len) + u64(entry.value.mime_type.len) }
		}
		if cost > u64(0x7fffffff) - upper_bound { return vm.throw_error(.range_error, 'FormData body exceeds the native byte-vector limit') }
		upper_bound += cost
		charge_buffer_source_work(mut vm, cost)!
	}
	serialized := html.serialize_to_multipart_form_data(entries)
	return FetchBodyValue{value: fetch.BodyInit{kind: .form_data, bytes: serialized.serialized_data, type_: 'multipart/form-data; boundary=' + serialized.boundary}}
}

fn (mut host Host) fetch_form_data_result(mut vm libjs.VM, bytes []u8, content_type string) !libjs.Value {
	mime := mimesniff.MimeType.parse(content_type) or { return vm.throw_error(.type_error, 'Body MIME type is unavailable') }
	mut native := xhr.FormData.create()
	if mime.essence() == 'application/x-www-form-urlencoded' {
		// Use the byte parser directly: URLSearchParams(string) strips a
		// leading '?' which is part of a Fetch form field's name.
		for entry in domurl.url_decode(bytes.bytestr()) { vm.consume_execution_budget()!; native.append(entry.name, entry.value) }
	} else if mime.essence() == 'multipart/form-data' {
		// Decode text fields separately. Decoding the entire body first would
		// replace invalid UTF-8 bytes inside uploaded files.
		entries := fetch.parse_multipart_form_data(bytes.bytestr(), mime) or { return vm.throw_error(.type_error, err.msg()) }
		mut decoder := encoding.TextDecoder.construct('utf-8', encoding.TextDecoderOptions{ignore_bom: true})!
		for entry in entries {
			vm.consume_execution_budget()!
			name := decoder.decode(entry.name.bytes(), encoding.TextDecodeOptions{})!
			if filename := entry.filename {
				file := fileapi.File.construct_impl([fileapi.BlobPart.from_bytes(entry.value.bytes())], decoder.decode(filename.bytes(), encoding.TextDecodeOptions{})!, fileapi.FilePropertyBag{type_: entry.content_type or { 'text/plain' }})
				native.append_file(name, file, none)
			} else { native.append(name, decoder.decode(entry.value.bytes(), encoding.TextDecodeOptions{})!) }
		}
	} else { return vm.throw_error(.type_error, 'Unsupported form data MIME type') }
	return host.wrap_form_data(native, none)
}
