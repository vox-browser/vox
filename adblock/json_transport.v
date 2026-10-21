module adblock

import json2
import platform

fn C.vox_adblock_json_lock()
fn C.vox_adblock_json_unlock()

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
	return json2.decode[T](source)
}
