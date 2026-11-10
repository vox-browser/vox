module adblock

import json2
import platform

fn C.vox_adblock_json_lock()
fn C.vox_adblock_json_unlock()

fn init() {
	$if prealloc {
		// The encoder and decoder each publish a per-type field table in a
		// process-wide static on first use, in the caller's current arena.
		// Build every transport struct's tables in startup storage: the first
		// request check can run inside a document's native storage (the New
		// Tab page), and fetch workers keep reading the tables after that
		// document retires. No filter engine, assets or JavaScript context are
		// initialized here.
		_ = json2.decode[DocumentFilters]('{}') or { panic(err) }
		_ = json2.decode[Decision]('{}') or { panic(err) }
		_ = json2.encode(Request{}, escape_unicode: true)
		_ = json2.encode([ResponseHeader{}], escape_unicode: true)
		_ = json2.encode(RequestLog{}, escape_unicode: true)
	}
}

// Concurrent cold requests can otherwise observe partially initialized static
// JSON field tables. Keep this lock confined to conversion, outside the engine
// lock and before any engine call, including independent filter contexts.
fn encode_transport_json[T](value T) string {
	C.vox_adblock_json_lock()
	defer { C.vox_adblock_json_unlock() }
	// Cosmetic surveys contain many ID/class strings. Their JSON needs no
	// retained type metadata, so only the final encoded bytes must survive.
	// Struct encodes retain json2's lazily published field tables and keep
	// their ordinary lifetime, including cold requests on fetch workers.
	$if T is string || T is []string {
		mut work := platform.begin_thread_scratch('filter JSON encoding')
		encoded := json2.encode(value, escape_unicode: true)
		work.leave()
		owned := encoded.clone()
		work.finish()
		return owned
	} $else {
		return json2.encode(value, escape_unicode: true)
	}
}

fn decode_transport_json[T](source string) !T {
	C.vox_adblock_json_lock()
	defer { C.vox_adblock_json_unlock() }
	$if prealloc {
		$if T is DocumentFilters {
			// Memo hits decode the full cosmetic/scriptlet reply too. The token
			// index is parser storage, not part of the returned filter records.
			work := platform.begin_thread_scratch('document filter JSON decoding')
			value := json2.decode[T](source) or {
				work.finish()
				// Preserve the codec's actual error type, message and source
				// context in the caller's storage on this uncommon path.
				return json2.decode[T](source)
			}
			work.leave()
			owned := DocumentFilters{
				css: value.css.clone()
				scriptlets: value.scriptlets.clone()
				procedural: value.procedural.map(it.clone())
				filters: value.filters.map(it.clone())
			}
			work.finish()
			return owned
		}
	}
	return json2.decode[T](source)
}
