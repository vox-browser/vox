// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IndexedDB/Inspection.cpp. Browser Document and JsonValue
// objects are represented by deterministic typed records at this standalone
// module boundary.
module indexeddb

import x.json2
import math

pub enum InspectionJSONKind {
	null_
	number
	string_
	array
}

pub struct InspectionJSONValue {
pub:
	kind   InspectionJSONKind
	number f64
	text   string
	items  []InspectionJSONValue
}

pub fn (value InspectionJSONValue) serialized() string {
	return match value.kind {
		.null_ { 'null' }
		.number { value.number.str() }
		.string_ { json2.encode(value.text) }
		.array {
			mut parts := []string{cap: value.items.len}
			for item in value.items {
				parts << item.serialized()
			}
			'[${parts.join(',')}]'
		}
	}
}

pub fn serialize_key_for_inspection(key Key) InspectionJSONValue {
	return match key.kind {
		.invalid {
			InspectionJSONValue{}
		}
		.number, .date {
			InspectionJSONValue{
				kind: .number
				number: key.number
			}
		}
		.string_ {
			InspectionJSONValue{
				kind: .string_
				text: key.text
			}
		}
		.binary {
			InspectionJSONValue{
				kind: .string_
				text: key.dump()
			}
		}
		.array {
			InspectionJSONValue{
				kind: .array
				items: key.items.map(serialize_key_for_inspection(it))
			}
		}
	}
}

pub fn serialize_key_path(key_path KeyPath) string {
	return match key_path {
		string { key_path }
		[]string { json2.encode(key_path) }
	}
}

fn serialize_value_to_json(value Value) !string {
	return match value.kind {
		.undefined { error('undefined is not JSON serializable') }
		.null_ { 'null' }
		.boolean { value.bool_.str() }
		.number, .date {
			if math.is_nan(value.number) || math.is_inf(value.number, 0) {
				'null'
			} else {
				value.number.str()
			}
		}
		.string_ { json2.encode(value.text) }
		.binary { json2.encode(value.bytes) }
		.array {
			mut items := []string{cap: value.items.len}
			for item in value.items {
				items << serialize_value_to_json(item) or { 'null' }
			}
			'[${items.join(',')}]'
		}
		.object {
			mut names := value.fields.keys()
			names.sort()
			mut fields := []string{cap: names.len}
			for name in names {
				serialized := serialize_value_to_json(value.fields[name]) or { continue }
				fields << '${json2.encode(name)}:${serialized}'
			}
			'{${fields.join(',')}}'
		}
	}
}

pub fn serialize_record_value(value Value) string {
	return serialize_value_to_json(value) or { '<unserializable>' }
}

pub struct IndexedDatabaseDocument {
pub:
	url                     string
	storage_key             ?string
	same_origin_with_parent bool = true
	children                []IndexedDatabaseDocument
}

pub fn indexed_database_documents_for_inspection(root IndexedDatabaseDocument) []IndexedDatabaseDocument {
	mut documents := []IndexedDatabaseDocument{}
	append_inspection_document(root, mut documents, true)
	return documents
}

fn append_inspection_document(document IndexedDatabaseDocument, mut documents []IndexedDatabaseDocument, include bool) {
	if !include {
		return
	}
	if document.storage_key != none {
		documents << document
	}
	for child in document.children {
		append_inspection_document(child, mut documents, child.same_origin_with_parent)
	}
}

pub type InspectionDocumentMatcher = fn (string) bool

pub fn matching_document(document IndexedDatabaseDocument, document_matches InspectionDocumentMatcher) ?IndexedDatabaseDocument {
	for entry in indexed_database_documents_for_inspection(document) {
		if document_matches(entry.url) {
			return entry
		}
	}
	return none
}

pub struct InspectionDatabase {
pub:
	name               string
	version            u64
	object_store_names []string
}

pub struct InspectionStorageHost {
pub:
	url       string
	databases []InspectionDatabase
}

pub struct InspectionIndex {
pub:
	name        string
	key_path    string
	unique      bool
	multi_entry bool
}

pub struct InspectionObjectStore {
pub:
	name           string
	key_path       ?string
	auto_increment bool
	indexes        []InspectionIndex
}

pub struct InspectionDatabaseRow {
pub:
	name               string
	version            u64
	object_store_count int
}

pub struct InspectionRecord {
pub:
	key   InspectionJSONValue
	value string
}

pub type InspectionObject = InspectionDatabaseRow | InspectionObjectStore | InspectionRecord

pub struct InspectionPath {
pub:
	database_name    string
	object_store_name ?string
	key              ?InspectionJSONValue
}

pub fn inspect_indexed_database_storage(document IndexedDatabaseDocument) []InspectionStorageHost {
	mut hosts := []InspectionStorageHost{}
	for entry in indexed_database_documents_for_inspection(document) {
		storage_key := entry.storage_key or { continue }
		mut databases := []InspectionDatabase{}
		for database in DatabaseData.for_key(storage_key) {
			if database.version == 0 {
				continue
			}
			mut names := database.stores.keys()
			sort_name_list(mut names)
			databases << InspectionDatabase{
				name: database.name
				version: database.version
				object_store_names: names
			}
		}
		databases.sort_with_compare(fn (a &InspectionDatabase, b &InspectionDatabase) int {
			return compare_utf16_code_units(a.name, b.name)
		})
		hosts << InspectionStorageHost{
			url: entry.url
			databases: databases
		}
	}
	return hosts
}

pub fn inspect_object_store(object_store &ObjectStoreData) InspectionObjectStore {
	mut indexes := []InspectionIndex{}
	for _, index in object_store.indexes {
		indexes << InspectionIndex{
			name: index.name
			key_path: serialize_key_path(index.key_path)
			unique: index.unique
			multi_entry: index.multi_entry
		}
	}
	indexes.sort_with_compare(fn (a &InspectionIndex, b &InspectionIndex) int {
		return compare_utf16_code_units(a.name, b.name)
	})
	key_path := if path := object_store.key_path {
		?string(serialize_key_path(path))
	} else {
		none
	}
	return InspectionObjectStore{
		name: object_store.name
		key_path: key_path
		auto_increment: object_store.auto_increment
		indexes: indexes
	}
}

pub fn append_database_rows(mut rows []InspectionObject, storage_key string) {
	for database in DatabaseData.for_key(storage_key) {
		if database.version == 0 {
			continue
		}
		rows << InspectionDatabaseRow{
			name: database.name
			version: database.version
			object_store_count: database.stores.len
		}
	}
}

pub fn append_object_store_rows(mut rows []InspectionObject, storage_key string, database_name string) {
	database := DatabaseData.for_key_and_name(storage_key, database_name) or { return }
	mut names := database.stores.keys()
	sort_name_list(mut names)
	for name in names {
		object_store := database.stores[name] or { continue }
		rows << inspect_object_store(object_store)
	}
}

pub fn append_record_rows(mut rows []InspectionObject, storage_key string, path InspectionPath) {
	object_store_name := path.object_store_name or { return }
	database := DatabaseData.for_key_and_name(storage_key, path.database_name) or { return }
	object_store := database.object_store_with_name(object_store_name) or { return }
	for record in object_store.records {
		serialized_key := serialize_key_for_inspection(record.key)
		if key := path.key {
			if serialized_key.serialized() != key.serialized() {
				continue
			}
		}
		rows << InspectionRecord{
			key: serialized_key
			value: serialize_record_value(record.value)
		}
	}
}

pub fn inspect_indexed_database_objects(document IndexedDatabaseDocument, document_matches InspectionDocumentMatcher, paths ?[]InspectionPath) []InspectionObject {
	mut rows := []InspectionObject{}
	for entry in indexed_database_documents_for_inspection(document) {
		if !document_matches(entry.url) {
			continue
		}
		storage_key := entry.storage_key or { continue }
		if requested_paths := paths {
			for path in requested_paths {
				if path.object_store_name == none {
					append_object_store_rows(mut rows, storage_key, path.database_name)
				} else {
					append_record_rows(mut rows, storage_key, path)
				}
			}
		} else {
			append_database_rows(mut rows, storage_key)
		}
	}
	return rows
}

pub fn delete_indexed_database_for_inspection(document IndexedDatabaseDocument, document_matches InspectionDocumentMatcher, database_name string) !bool {
	entry := matching_document(document, document_matches) or {
		return error('Unable to find IndexedDB host')
	}
	storage_key := entry.storage_key or { return error('Unable to find IndexedDB host') }
	if database := DatabaseData.for_key_and_name(storage_key, database_name) {
		if database.associated_connections.len > 0 {
			return true
		}
	}
	DatabaseData.delete_for_key_and_name(storage_key, database_name)
	return false
}

pub fn clear_indexed_database_object_store_for_inspection(document IndexedDatabaseDocument, document_matches InspectionDocumentMatcher, database_name string, object_store_name string) ! {
	entry := matching_document(document, document_matches) or {
		return error('Unable to find IndexedDB host')
	}
	storage_key := entry.storage_key or { return error('Unable to find IndexedDB host') }
	database := DatabaseData.for_key_and_name(storage_key, database_name) or {
		return error('Unable to find IndexedDB database')
	}
	mut object_store := database.object_store_with_name(object_store_name) or {
		return error('Unable to find IndexedDB object store')
	}
	clear_an_object_store(mut object_store)
}

pub fn delete_indexed_database_record_for_inspection(document IndexedDatabaseDocument, document_matches InspectionDocumentMatcher, database_name string, object_store_name string, key InspectionJSONValue) ! {
	entry := matching_document(document, document_matches) or {
		return error('Unable to find IndexedDB host')
	}
	storage_key := entry.storage_key or { return error('Unable to find IndexedDB host') }
	database := DatabaseData.for_key_and_name(storage_key, database_name) or {
		return error('Unable to find IndexedDB database')
	}
	mut object_store := database.object_store_with_name(object_store_name) or {
		return error('Unable to find IndexedDB object store')
	}
	for record in object_store.records {
		if serialize_key_for_inspection(record.key).serialized() != key.serialized() {
			continue
		}
		range := IDBKeyRange.create(record.key, record.key, false, false)!
		delete_records_from_an_object_store(mut object_store, range)
		return
	}
	return error('Unable to find IndexedDB record')
}
