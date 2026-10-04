// Copyright (c) 2018-2024, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause
// Translation of LibURL/URL.cpp::create_with_data.
module url

pub fn create_with_data(mime_type string, payload string, is_base64 bool) &URL {
	mut record := &URL{}
	record.has_an_opaque_path = true
	record.scheme = 'data'
	mut path := mime_type
	if is_base64 {
		path += ';base64'
	}
	path += ','
	path += payload
	record.paths = [path]
	return record
}
