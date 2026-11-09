// Copyright (c) 2023, Kenneth Myhra <kennethmyhra@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the serialization algorithms in
// Libraries/LibWeb/HTML/FormControlInfrastructure.cpp.
module html

import rand
import fileapi
import infra
import encoding

pub struct FormDataFile {
pub:
	name      string
	mime_type string
	bytes     []u8
	// Source entries retain File objects; byte fields remain the serialization
	// and legacy typed boundary used by callers without a platform object.
	file ?&fileapi.File
}

pub type FormDataEntryValue = FormDataFile | string

pub struct FormDataEntry {
pub:
	name  string
	value FormDataEntryValue
}

pub struct SerializedFormData {
pub:
	boundary        string
	serialized_data []u8
}

pub fn create_form_data_string_entry(name string, value string) FormDataEntry {
	return FormDataEntry{infra.convert_to_scalar_value_string(name), FormDataEntryValue(infra.convert_to_scalar_value_string(value))}
}

pub fn create_form_data_native_file_entry(name string, file &fileapi.File) FormDataEntry {
	return FormDataEntry{
		name:  infra.convert_to_scalar_value_string(name)
		value: FormDataFile{
			name:      file.name()
			mime_type: file.type_()
			bytes:     file.raw_bytes()
			file:      file
		}
	}
}

pub fn create_form_data_file_entry(name string, file FormDataFile, filename ?string) FormDataEntry {
	if native_file := file.file {
		if replacement := filename {
			return create_form_data_native_file_entry(name, fileapi.File.create(native_file.raw_bytes(),
				replacement, native_file.type_(), native_file.last_modified()))
		}
		return create_form_data_native_file_entry(name, native_file)
	}
	entry_file := if replacement_name := filename {
		FormDataFile{
			name:      replacement_name
			mime_type: file.mime_type
			bytes:     file.bytes
		}
	} else {
		file
	}
	return FormDataEntry{infra.convert_to_scalar_value_string(name), FormDataEntryValue(entry_file)}
}

pub fn normalize_line_breaks(value string) string {
	mut output := []u8{}
	mut position := 0
	for position < value.len {
		start := position
		for position < value.len && value[position] != `\r` && value[position] != `\n` {
			position++
		}
		output << value[start..position].bytes()
		if position >= value.len {
			break
		}
		if (value[position] == `\r` && (position + 1 >= value.len || value[position + 1] != `\n`))
			|| value[position] == `\n` {
			output << '\r\n'.bytes()
			position++
		} else {
			output << '\r\n'.bytes()
			position += 2
		}
	}
	return output.bytestr()
}

fn escape_form_data_header_value(value string) string {
	mut output := []u8{}
	for character in value.bytes() {
		match character {
			`\r` { output << '%0D'.bytes() }
			`\n` { output << '%0A'.bytes() }
			`"` { output << '%22'.bytes() }
			else { output << character }
		}
	}
	return output.bytestr()
}

fn append_form_data_string(mut output []u8, value string) {
	output << value.bytes()
}

// https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#multipart/form-data-encoding-algorithm
pub fn serialize_to_multipart_form_data(entry_list []FormDataEntry) SerializedFormData {
	return serialize_to_multipart_form_data_with_encoding(entry_list, 'UTF-8') or { panic(err) }
}

pub fn serialize_to_multipart_form_data_with_encoding(entry_list []FormDataEntry, label string) !SerializedFormData {
	encoder := encoding.HTMLCharsetEncoder.create(label)!
	boundary := '---------------------------${rand.u64()}'
	mut output := []u8{}
	for entry in entry_list {
		append_form_data_string(mut output, '--${boundary}\r\n')
		normalized_name := normalize_line_breaks(entry.name)
		escaped_name := escape_form_data_header_value(encoder.encode(normalized_name)!.bytestr())
		match entry.value {
			FormDataFile {
				escaped_filename := escape_form_data_header_value(encoder.encode(entry.value.name)!.bytestr())
				append_form_data_string(mut output,
					'Content-Disposition: form-data; name="${escaped_name}"; filename="${escaped_filename}"\r\n')
				if entry.value.mime_type != '' {
					append_form_data_string(mut output,
						'Content-Type: ${entry.value.mime_type}\r\n\r\n')
				} else {
					append_form_data_string(mut output,
						'Content-Type: application/octet-stream\r\n\r\n')
				}
				output << entry.value.bytes
				append_form_data_string(mut output, '\r\n')
			}
			string {
				normalized_value := normalize_line_breaks(entry.value)
				append_form_data_string(mut output,
					'Content-Disposition: form-data; name="${escaped_name}"\r\n\r\n')
				output << encoder.encode(normalized_value)!
				append_form_data_string(mut output, '\r\n')
			}
		}
	}
	append_form_data_string(mut output, '--${boundary}--\r\n')
	return SerializedFormData{boundary, output}
}
