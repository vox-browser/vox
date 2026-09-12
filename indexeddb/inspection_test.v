module indexeddb

fn match_all_inspection_documents(_ string) bool {
	return true
}

fn match_root_inspection_document(url string) bool {
	return url == 'https://root.example/'
}

fn inspection_document_tree(root_storage_key string, child_storage_key string) IndexedDatabaseDocument {
	return IndexedDatabaseDocument{
		url: 'https://root.example/'
		storage_key: root_storage_key
		children: [
			IndexedDatabaseDocument{
				url: 'https://root.example/frame'
				storage_key: child_storage_key
			},
			IndexedDatabaseDocument{
				url: 'https://cross.example/'
				storage_key: 'inspection-cross-origin'
				same_origin_with_parent: false
			},
		]
	}
}

fn test_inspection_serializes_keys_key_paths_and_record_values() {
	key := array_key([
		number_key(1),
		string_key('two'),
		binary_key([u8(3), 4]),
	])
	serialized := serialize_key_for_inspection(key)
	assert serialized.kind == .array
	assert serialized.items.len == 3
	assert serialized.items[0].serialized() == '1.0'
	assert serialized.items[1].serialized() == '"two"'
	assert serialize_key_path('profile.id') == 'profile.id'
	assert serialize_key_path(['first', 'last']) == '["first","last"]'
	assert serialize_record_value(object_value({
		'name': string_value('Ladybird')
		'live': bool_value(true)
	})) == '{"live":true,"name":"Ladybird"}'
	assert serialize_record_value(undefined_value()) == '<unserializable>'
}

fn test_inspection_lists_same_origin_documents_databases_stores_and_records() {
	root_key := 'inspection-list-root'
	child_key := 'inspection-list-child'
	mut root_database := DatabaseData.create_for_key_and_name(root_key, 'root-db')
	root_database.version = 2
	mut store := ObjectStoreData.create('people', true, 'id')
	mut index := IndexData.create('by_name', 'name', false, false)
	index.store_name = store.name
	store.indexes[index.name] = &index
	store.store_a_record(ObjectStoreRecord{
		key: number_key(1)
		value: object_value({
			'id': number_value(1)
			'name': string_value('Ada')
		})
	})!
	root_database.add_object_store(store)
	mut child_database := DatabaseData.create_for_key_and_name(child_key, 'child-db')
	child_database.version = 1
	document := inspection_document_tree(root_key, child_key)

	documents := indexed_database_documents_for_inspection(document)
	assert documents.len == 2
	hosts := inspect_indexed_database_storage(document)
	assert hosts.len == 2
	assert hosts[0].databases[0].name == 'root-db'
	assert hosts[0].databases[0].object_store_names == ['people']

	database_rows := inspect_indexed_database_objects(document, match_root_inspection_document,
		none)
	assert database_rows.len == 1
	assert database_rows[0] is InspectionDatabaseRow
	assert (database_rows[0] as InspectionDatabaseRow).object_store_count == 1

	store_rows := inspect_indexed_database_objects(document, match_root_inspection_document,
		[InspectionPath{
			database_name: 'root-db'
		}])
	assert store_rows.len == 1
	assert store_rows[0] is InspectionObjectStore
	inspected_store := store_rows[0] as InspectionObjectStore
	assert inspected_store.key_path? == 'id'
	assert inspected_store.indexes[0].name == 'by_name'

	record_rows := inspect_indexed_database_objects(document, match_root_inspection_document,
		[InspectionPath{
			database_name: 'root-db'
			object_store_name: 'people'
			key: serialize_key_for_inspection(number_key(1))
		}])
	assert record_rows.len == 1
	assert record_rows[0] is InspectionRecord
	assert (record_rows[0] as InspectionRecord).value == '{"id":1.0,"name":"Ada"}'
}

fn test_inspection_clear_delete_record_and_blocked_database_delete() {
	storage_key := 'inspection-mutations'
	mut database := DatabaseData.create_for_key_and_name(storage_key, 'db')
	database.version = 1
	mut store := ObjectStoreData.create('store', false, none)
	store.store_a_record(ObjectStoreRecord{
		key: string_key('one')
		value: string_value('first')
	})!
	store.store_a_record(ObjectStoreRecord{
		key: string_key('two')
		value: string_value('second')
	})!
	database.add_object_store(store)
	document := IndexedDatabaseDocument{
		url: 'https://root.example/'
		storage_key: storage_key
	}

	delete_indexed_database_record_for_inspection(document, match_all_inspection_documents,
		'db', 'store', serialize_key_for_inspection(string_key('one')))!
	assert store.records.len == 1
	assert store.records[0].key.text == 'two'
	clear_indexed_database_object_store_for_inspection(document, match_all_inspection_documents,
		'db', 'store')!
	assert store.records.len == 0

	mut connection := new_connection(database)
	assert delete_indexed_database_for_inspection(document, match_all_inspection_documents,
		'db')!
	connection.close()
	assert !delete_indexed_database_for_inspection(document, match_all_inspection_documents,
		'db')!
	assert DatabaseData.for_key_and_name(storage_key, 'db') == none
}
