module html

import dom
import encoding.hex
import x.json2

struct FormCharsetUploadVector {
	input string
	encodings map[string]string
}

fn test_multipart_form_encodes_names_values_and_filenames_but_preserves_file_bytes() {
	vector := json2.decode[FormCharsetUploadVector]($embed_file('@VMODROOT/encoding/fixtures/html_form_first100_vectors.json').to_string())!
	file_bytes := vector.input.bytes()
	for label, expected_hex in vector.encodings {
		expected := hex.decode(expected_hex)!.bytestr()
		entries := [create_form_data_string_entry(vector.input, vector.input),
			create_form_data_file_entry('file', FormDataFile{name: vector.input, mime_type: 'text/plain', bytes: file_bytes}, none)]
		result := serialize_to_multipart_form_data_with_encoding(entries, label)!
		actual := result.serialized_data.bytestr()
		assert actual.contains('Content-Disposition: form-data; name="${expected}"\r\n\r\n${expected}\r\n'), label
		assert actual.contains('name="file"; filename="${expected}"\r\nContent-Type: text/plain\r\n\r\n${file_bytes.bytestr()}\r\n'), label
	}
}

fn test_form_output_encoding_maps_utf16_to_utf8_and_keeps_legacy_labels() {
	for label in ['UTF-16LE', 'UTF-16BE', 'UTF-8', 'windows-1252', 'ISO-2022-JP', 'x-user-defined'] {
		mut document := parse_document('<!doctype html><form id="form" accept-charset="${label}"></form>')
		defer { document.finalize() }
		element := document.get_element_by_id('form') or { panic('form') }
		form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
		assert form.pick_an_encoding() == if label.starts_with('UTF-16') { 'UTF-8' } else { label }
	}
}
