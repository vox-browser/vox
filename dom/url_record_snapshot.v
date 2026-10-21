module dom

import platform
import url as liburl

// Value copies share immutable parsed metadata, while parsed() still returns
// an independent record. Serialized-only URL fields need no inline URL payload.
@[heap]
struct URLRecordSnapshot {
	source string
	record liburl.URL
}

fn (u URL) parsed_snapshot() ?&URLRecordSnapshot {
	if u.record_ != unsafe { nil } && u.record_.source == u.value { return u.record_ }
	if cached := dom_url_record_cache[u.value] { return cached }
	// A cache entry and every byte it references must outlive a temporary
	// caller. Instance snapshots, including Blob entries, stay instance-owned.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	owned := u.value.clone()
	parsed := liburl.parse(owned) or { return none }
	snapshot := &URLRecordSnapshot{
		source: url_snapshot_source(parsed, owned)
		record: parsed
	}
	dom_url_record_cache[owned] = snapshot
	return snapshot
}

fn url_snapshot_source(record &liburl.URL, reusable ?string) string {
	$if prealloc {
		mut scratch := platform.begin_thread_scratch('URL canonical source')
		serialized := record.serialize(false)
		scratch.leave()
		source := if existing := reusable {
			if existing == serialized { existing } else { serialized.clone() }
		} else {
			serialized.clone()
		}
		scratch.finish()
		return source
	}
	serialized := record.serialize(false)
	if existing := reusable {
		if existing == serialized { return existing }
	}
	return serialized
}
