module html

import dom

fn test_range_sanitization_uses_the_same_number_serialization_as_numeric_setters() {
	for row in [
		['value="11"', '11']!,
		['value="00011.00"', '11']!,
		['value="-0"', '0']!,
		['value="invalid"', '50']!,
		['min="2" max="10" value="20"', '10']!,
		['step="0.25" value="1.25"', '1.25']!,
		['step="any" max="1e21" value="1e20"', '100000000000000000000']!,
	] {
		mut document := parse_document('<input id="field" type="range" ${row[0]}>')
		defer { document.finalize() }
		element := document.get_element_by_id('field')?
		mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		assert model.value() == row[1]
		model.set_value(row[1])!
		assert model.value() == row[1]
	}
}

fn test_range_form_data_entries_use_the_sanitized_canonical_string() {
	mut document := parse_document('<form id="form"><input type="range" name="level" value="11"></form>')
	defer { document.finalize() }
	form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(document.get_element_by_id('form')?) })
	entries := form.construct_entry_list_with_encoding(none, none)?
	assert entries.len == 1
	assert entries[0].name == 'level' && entries[0].value == FormDataEntryValue('11')
}
