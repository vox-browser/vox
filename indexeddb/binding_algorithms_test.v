module indexeddb

fn test_new_key_path_binding_algorithms_preserve_empty_identifiers_and_typed_values() {
	assert strictly_split_key_path('') == ['']
	assert strictly_split_key_path('.profile..id.') == ['', 'profile', '', 'id', '']
	assert convert_a_key_path_to_a_value('profile.id').text == 'profile.id'
	compound := convert_a_key_path_to_a_value(['first', 'last'])
	assert compound.kind == .array
	assert compound.items.map(it.text) == ['first', 'last']
}

fn test_stored_record_deserialization_clones_and_reports_corruption() {
	mut original := object_value({
		'name': string_value('before')
	})
	serialized := StoredRecordSerialization.from_value(original)
	deserialized := deserialize_a_stored_record(serialized)!
	original.fields['name'] = string_value('after')
	assert deserialized.fields['name'].text == 'before'
	if _ := deserialize_a_stored_record(StoredRecordSerialization{
		corrupted: true
	}) {
		assert false
	} else {
		assert err.msg().contains('NotReadableError')
	}
}

fn test_blob_and_file_key_path_properties_participate_in_key_extraction() {
	blob := blob_value(123, 'image/png')
	assert key_path_value_for_blob_or_file(blob, 'size')?.number == 123
	assert key_path_value_for_blob_or_file(blob, 'type')?.text == 'image/png'
	assert evaluate_key_path(blob, 'size')?.number == 123

	file := file_value('image.png', 456, 'image/png', 789)
	assert evaluate_key_path(file, 'name')?.text == 'image.png'
	assert evaluate_key_path(file, 'lastModified')?.number == 789
	assert evaluate_key_path(file, 'missing') == none
}

fn test_request_database_info_record_cursor_and_key_range_binding_results() {
	mut data := DatabaseData.create('binding-database')
	data.version = 4
	mut connection := new_connection(data)
	mut request := IDBRequest.create('factory')
	set_idb_request_result(mut request, connection)
	assert request.result()! == .database
	assert request.database == connection

	zero_version := DatabaseData.create('hidden')
	infos := resolve_database_info_list_promise([data, zero_version])
	assert infos == [IDBDatabaseInfo{
		name: 'binding-database'
		version: 4
	}]

	mut records := []IDBRecord{}
	record := IDBRecord.create(number_key(1), number_key(2), string_value('value'))
	append_idb_record(mut records, 1, record)
	assert records.len == 2
	assert records[1].value.text == 'value'

	mut transaction := IDBTransaction.create(connection, .readonly, .default_, [])
	store := ObjectStoreData.create('store', false, none)
	cursor := IDBCursor.create(transaction, store, none, .next, IDBKeyRange.unbounded(),
		false, request)
	assert idb_cursor_result(cursor)? == cursor
	assert idb_cursor_result(none) == none

	range := IDBKeyRange.only(string_key('key'))!
	wrapped := IDBKeyRangeValue.from_range(range)
	assert key_range_from_value(wrapped)?.includes(string_key('key'))!
	assert idb_key_range_from_value(wrapped)?.includes(string_key('key'))!
	connection.close()
}
