module adblock

import os
import platform
import sync

// The default bundled filter set is immutable. URL and surveyed tokens fully
// determine its cosmetic rules and scriptlet source; procedural selectors still
// execute against the live document. Custom Engine contexts never use this memo.
// Keep encoded results so each caller owns independently decoded arrays.
const document_filter_memo_limit = 16
const document_filter_memo_byte_limit = 2 * 1024 * 1024

__global (
	document_filter_memo_       = map[string]string{}
	document_filter_memo_bytes_ int
	document_filter_memo_mutex_ = sync.new_mutex()
)

fn retained_document_filters(source string) ?string {
	document_filter_memo_mutex_.@lock()
	defer { document_filter_memo_mutex_.unlock() }
	return document_filter_memo_[source] or { return none }
}

fn retain_document_filters(source string, result string) {
	bytes := source.len + result.len
	if bytes > document_filter_memo_byte_limit { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	document_filter_memo_mutex_.@lock()
	defer { document_filter_memo_mutex_.unlock() }
	if source in document_filter_memo_ { return }
	if document_filter_memo_.len >= document_filter_memo_limit
		|| document_filter_memo_bytes_ + bytes > document_filter_memo_byte_limit {
		document_filter_memo_.clear()
		document_filter_memo_bytes_ = 0
	}
	document_filter_memo_[source.clone()] = result.clone()
	document_filter_memo_bytes_ += bytes
}

fn record_document_filter_memo(hit bool, source_bytes int, result_bytes int) {
	if os.getenv('VOX_DOCUMENT_FILTER_MEMO_DIAGNOSTICS') != '1' { return }
	eprintln('Vox document filter memo: hit=${hit} source_bytes=${source_bytes} result_bytes=${result_bytes}')
}
