module indexeddb

pub enum IDBRetrievalKind {
	values
	keys
	records
}

pub fn (mut store IDBObjectStore) get_all_async(options IDBGetAllOptions, kind IDBRetrievalKind) !&IDBRequest {
	store.require_cursor_source()!
	return store.enqueue_operation(fn [options, kind] (mut handle IDBObjectStore) !&IDBRequest {
		return match kind {
			.values { handle.get_all(options)! }
			.keys { handle.get_all_keys(options)! }
			.records { handle.get_all_records(options)! }
		}
	})
}

pub fn (mut index IDBIndex) get_all_async(options IDBGetAllOptions, kind IDBRetrievalKind) !&IDBRequest {
	index.require_cursor_source()!
	return index.enqueue_operation(fn [options, kind] (mut handle IDBIndex) !&IDBRequest {
		return match kind {
			.values { handle.get_all(options)! }
			.keys { handle.get_all_keys(options)! }
			.records { handle.get_all_records(options)! }
		}
	})
}
