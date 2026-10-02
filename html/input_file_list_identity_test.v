module html

import dom
import fileapi

fn test_input_file_list_retains_selected_objects_and_setter_identity() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	element.set_attribute_value('type', 'file')
	element.set_attribute_value('multiple', '')
	mut input := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	empty := input.file_list()?
	assert input.file_list()? == empty
	assert empty.length() == 0
	input.did_select_files([SelectedFile.from_contents('one.txt', 'hello'.bytes())], .replace)
	first := input.file_list()?
	assert first != empty
	file := first.item(0)?
	assert file.name() == 'one.txt'
	assert file.type_() == 'text/plain'
	assert file.raw_bytes().bytestr() == 'hello'
	assert input.value() == 'C:\\fakepath\\one.txt'
	input.did_select_files([SelectedFile.from_contents('two.png', '\x89PNG\r\n\x1a\n'.bytes())],
		.append)
	assert input.file_list()? == first
	assert first.item(0)? == file
	assert first.length() == 2
	assert first.item(1)?.type_() == 'image/png'
	mut replacement := fileapi.FileList.create()
	manual := fileapi.File.create([u8(9)], 'manual.bin', 'application/octet-stream', 123)
	replacement.add_file(manual)
	input.set_file_list(replacement)
	input.set_file_list(none)
	assert input.file_list()? == replacement
	assert input.file_list()?.item(0)? == manual
	input.reset()
	assert input.file_list()? != replacement
	assert input.file_list()?.length() == 0
	assert replacement.item(0)? == manual
	input.set_type('text')
	assert input.file_list() == none
}

fn test_file_input_cancel_preserves_file_list_without_input_events() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	element.set_attribute_value('type', 'file')
	mut input := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	input.did_select_files([SelectedFile.from_contents('one.txt', 'hello'.bytes())], .replace)
	files := input.file_list()?
	input.did_select_files([], .replace)
	assert input.file_list()? == files
	assert input.event_count('input') == 1
	assert input.event_count('change') == 1
	assert input.event_count('cancel') == 1
}
