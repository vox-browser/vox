// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IndexedDB/TransactionChanges.h.
module indexeddb

pub struct TransactionChange {
pub:
	database_name     string
	object_store_name string
	key               ?InspectionJSONValue
}

pub struct TransactionChanges {
pub mut:
	added   []TransactionChange
	changed []TransactionChange
	deleted []TransactionChange
}

pub struct IndexedDBDevtoolsNotification {
pub:
	document_url string
	changes      TransactionChanges
}

pub fn (changes &TransactionChanges) is_empty() bool {
	return changes.added.len == 0 && changes.changed.len == 0 && changes.deleted.len == 0
}
