// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of XHR/FormData, FormDataEntry and FormDataIterator.
module xhr

import fileapi
import html
import time

pub struct FormDataFile {
pub:
	file &fileapi.File
}

pub type FormDataEntryValue = FormDataFile | string

// Binding conversion is explicit upstream now that the internal entry value
// and the Web IDL union have independent representations.
pub fn form_data_entry_value_for_bindings(value FormDataEntryValue) FormDataEntryValue {
	return value
}

pub struct FormDataBlob {
pub:
	blob &fileapi.Blob
}

pub type FormDataAppendValue = FormDataBlob | string

pub struct FormDataEntry {
pub:
	name  string
	value FormDataEntryValue
}

@[heap]
pub struct FormData {
pub mut:
	entries []FormDataEntry
}

pub fn FormData.create() &FormData {
	return FormData.construct_impl(none)
}

pub fn FormData.construct_impl(entries ?[]FormDataEntry) &FormData {
	return &FormData{
		entries: (entries or { []FormDataEntry{} }).clone()
	}
}

// https://xhr.spec.whatwg.org/#dom-formdata
pub fn FormData.create_from_form(form &html.HTMLFormElementModel, submitter ?&html.FormAssociatedElement) !&FormData {
	if control := submitter {
		if !control.is_submit_button() {
			return error('TypeError: submitter is not a valid submit button')
		}
		if owner := control.form() {
			if voidptr(owner) != voidptr(form.element) {
				return error('NotFoundError: submitter does not belong to the provided form')
			}
		} else {
			return error('NotFoundError: submitter does not belong to the provided form')
		}
	}
	entries := form.construct_entry_list_with_encoding(submitter, none) or {
		return error('InvalidStateError: form entry list construction is already in progress')
	}
	return FormData.from_html_entries(entries)
}

pub fn FormData.from_html_entries(entries []html.FormDataEntry) &FormData {
	return FormData.construct_impl(form_data_entries_from_html(entries))
}

fn form_data_entries_from_html(entries []html.FormDataEntry) []FormDataEntry {
	mut converted := []FormDataEntry{cap: entries.len}
	for entry in entries {
		value := match entry.value {
			html.FormDataFile {
				FormDataEntryValue(FormDataFile{
					file: entry.value.file or {
						fileapi.File.create(entry.value.bytes.clone(), entry.value.name,
							entry.value.mime_type, time.now().unix_milli())
					}
				})
			}
			string { FormDataEntryValue(entry.value) }
		}
		converted << FormDataEntry{
			name:  entry.name
			value: value
		}
	}
	return converted
}

pub fn (data &FormData) form_data_entries() []html.FormDataEntry {
	mut entries := []html.FormDataEntry{cap: data.entries.len}
	for entry in data.entries {
		entries << match entry.value {
			string { html.create_form_data_string_entry(entry.name, entry.value) }
			FormDataFile { html.create_form_data_native_file_entry(entry.name, entry.value.file) }
		}
	}
	return entries
}

pub fn (mut data FormData) replace_form_data_entries(entries []html.FormDataEntry) {
	data.entries = form_data_entries_from_html(entries)
}

pub fn FormData.from_query_entries(entries [][2]string) &FormData {
	mut result := &FormData{}
	for entry in entries {
		result.entries << FormDataEntry{
			name:  entry[0]
			value: entry[1]
		}
	}
	return result
}

pub fn (mut data FormData) append(name string, value string) {
	data.append_impl(name, FormDataAppendValue(value), none)
}

pub fn (mut data FormData) append_blob(name string, blob &fileapi.Blob, filename ?string) {
	data.append_impl(name, FormDataBlob{blob}, filename)
}

pub fn (mut data FormData) append_impl(name string, value FormDataAppendValue, filename ?string) {
	if value is string {
		string_value := value as string
		data.entries << FormDataEntry{
			name:  name
			value: FormDataEntryValue(string_value)
		}
		return
	}
	blob := (value as FormDataBlob).blob
	file := fileapi.File.create(blob.raw_bytes().clone(), filename or { 'blob' }, blob.type_(),
		time.now().unix_milli())
	data.entries << FormDataEntry{
		name:  name
		value: FormDataFile{file}
	}
}

pub fn (mut data FormData) append_file(name string, file &fileapi.File, filename ?string) {
	if replacement := filename {
		data.entries << FormDataEntry{
			name:  name
			value: FormDataFile{
				file: fileapi.File.create(file.raw_bytes().clone(), replacement, file.type_(),
					file.last_modified())
			}
		}
	} else {
		data.entries << FormDataEntry{
			name:  name
			value: FormDataFile{file}
		}
	}
}

pub fn (mut data FormData) delete(name string) {
	data.entries = data.entries.filter(it.name != name)
}

pub fn (mut data FormData) delete_(name string) {
	data.delete(name)
}

pub fn (data &FormData) entry_list() []FormDataEntry {
	return data.entries.clone()
}

pub fn (data &FormData) get(name string) ?FormDataEntryValue {
	for entry in data.entries {
		if entry.name == name {
			return form_data_entry_value_for_bindings(entry.value)
		}
	}
	return none
}

pub fn (data &FormData) get_all(name string) []FormDataEntryValue {
	mut result := []FormDataEntryValue{}
	for entry in data.entries {
		if entry.name == name {
			result << form_data_entry_value_for_bindings(entry.value)
		}
	}
	return result
}

pub fn (data &FormData) has(name string) bool {
	return data.entries.any(it.name == name)
}

pub fn (mut data FormData) set(name string, value string) {
	data.set_impl(name, FormDataAppendValue(value), none)
}

pub fn (mut data FormData) set_blob(name string, blob &fileapi.Blob, filename ?string) {
	data.set_impl(name, FormDataBlob{blob}, filename)
}

pub fn (mut data FormData) set_impl(name string, value FormDataAppendValue, filename ?string) {
	if value is string {
		string_value := value as string
		data.set_entry(FormDataEntry{ name: name, value: FormDataEntryValue(string_value) })
		return
	}
	blob := (value as FormDataBlob).blob
	file := fileapi.File.create(blob.raw_bytes().clone(), filename or { 'blob' }, blob.type_(),
		time.now().unix_milli())
	data.set_entry(FormDataEntry{ name: name, value: FormDataFile{file} })
}

pub fn (mut data FormData) set_file(name string, file &fileapi.File, filename ?string) {
	value := if replacement := filename {
		FormDataFile{
			file: fileapi.File.create(file.raw_bytes().clone(), replacement, file.type_(),
				file.last_modified())
		}
	} else {
		FormDataFile{file}
	}
	data.set_entry(FormDataEntry{ name: name, value: value })
}

// The callback receives (value, key), matching the iterable WebIDL forEach
// callback order. The loop observes entries appended by the callback.
pub enum IterationDecision {
	continue_
	break_
}

pub fn (data &FormData) for_each(callback fn (FormDataEntryValue, string) IterationDecision) {
	mut index := 0
	for index < data.entries.len {
		entry := data.entries[index]
		if callback(form_data_entry_value_for_bindings(entry.value), entry.name) == .break_ {
			break
		}
		index++
	}
}

fn (mut data FormData) set_entry(new_entry FormDataEntry) {
	mut first := -1
	mut filtered := []FormDataEntry{cap: data.entries.len}
	for entry in data.entries {
		if entry.name == new_entry.name {
			if first == -1 {
				first = filtered.len
				filtered << new_entry
			}
			continue
		}
		filtered << entry
	}
	if first == -1 {
		filtered << new_entry
	}
	data.entries = filtered
}

pub enum IteratorKind {
	key
	value
	key_value
}

pub struct FormDataIteratorResult {
pub:
	done      bool
	has_key   bool
	has_value bool
	key       string
	value     FormDataEntryValue
}

pub struct FormDataIterator {
	data &FormData
	kind IteratorKind
pub mut:
	prototype_initialized bool
mut:
	index int
}

pub fn (data &FormData) iterator(kind IteratorKind) FormDataIterator {
	return FormDataIterator.create(data, kind)
}

pub fn FormDataIterator.create(data &FormData, kind IteratorKind) FormDataIterator {
	mut iterator := FormDataIterator{
		data: data
		kind: kind
	}
	set_form_data_iterator_prototype(mut iterator)
	return iterator
}

fn set_form_data_iterator_prototype(mut iterator FormDataIterator) {
	iterator.prototype_initialized = true
}

fn form_data_entry_value(value FormDataEntryValue) FormDataEntryValue {
	return form_data_entry_value_for_bindings(value)
}

pub fn (mut iterator FormDataIterator) next() FormDataIteratorResult {
	if iterator.index >= iterator.data.entries.len {
		return FormDataIteratorResult{
			done: true
		}
	}
	entry := iterator.data.entries[iterator.index]
	value := form_data_entry_value(entry.value)
	iterator.index++
	return match iterator.kind {
		.key {
			FormDataIteratorResult{
				has_key: true
				key:     entry.name
			}
		}
		.value {
			FormDataIteratorResult{
				has_value: true
				value:     value
			}
		}
		.key_value {
			FormDataIteratorResult{
				has_key:   true
				has_value: true
				key:       entry.name
				value:     value
			}
		}
	}
}
