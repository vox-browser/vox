module indexeddb

fn range_test_store_record(key f64) ObjectStoreRecord {
	return ObjectStoreRecord{
		key: number_key(key)
		value: number_value(key)
	}
}

fn range_test_index_record(key f64, primary_key f64) IndexRecord {
	return IndexRecord{
		key: number_key(key)
		primary_key: number_key(primary_key)
	}
}

fn test_record_range_binary_search_honors_open_bounds() {
	records := [
		range_test_store_record(1),
		range_test_store_record(2),
		range_test_store_record(3),
		range_test_store_record(4),
	]
	closed := record_range_for_key_range(records,
		IDBKeyRange.bound(number_key(2), number_key(3), false, false)!)
	assert closed == RecordRange{
		start: 1
		end: 3
	}
	open := record_range_for_key_range(records,
		IDBKeyRange.bound(number_key(2), number_key(4), true, true)!)
	assert open == RecordRange{
		start: 2
		end: 3
	}
	empty := record_range_for_key_range(records,
		IDBKeyRange.bound(number_key(2), number_key(2), true, false)!)
	assert empty.start == empty.end
}

fn test_record_range_binary_search_includes_duplicate_index_keys() {
	records := [
		range_test_index_record(1, 1),
		range_test_index_record(2, 1),
		range_test_index_record(2, 2),
		range_test_index_record(2, 3),
		range_test_index_record(3, 1),
	]
	matching := record_range_for_key_range(records, IDBKeyRange.only(number_key(2))!)
	assert matching == RecordRange{
		start: 1
		end: 4
	}
	assert first_record_index_with_key_at_or_after(records, number_key(2), true) == 4
	assert first_record_index_with_key_after(records, number_key(2), true, 0) == 1
}

fn test_record_queries_use_contiguous_record_range() {
	mut store := ObjectStoreData.create('records', false, none)
	for key in [1.0, 2.0, 3.0, 4.0] {
		store.store_a_record(range_test_store_record(key))!
	}
	range := IDBKeyRange.bound(number_key(1), number_key(4), true, true)!
	assert store.count_records_in_range(range) == 2
	assert store.first_in_range(range)?.key.number == 2
	assert store.first_n_in_range(range, u32(1)).map(it.key.number) == [2.0]
	assert store.last_n_in_range(range, u32(1)).map(it.key.number) == [3.0]
	removed := store.remove_records_in_range(range)
	assert removed.map(it.key.number) == [2.0, 3.0]
	assert store.records.map(it.key.number) == [1.0, 4.0]
}
