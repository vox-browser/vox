module adblock

import json2

fn C.vox_adblock_json_lock()
fn C.vox_adblock_json_unlock()

// Concurrent cold requests can otherwise observe partially initialized static
// JSON field tables. Keep this lock confined to conversion, outside the engine
// lock and before any engine call, including independent filter contexts.
fn encode_transport_json[T](value T) string {
	C.vox_adblock_json_lock()
	defer { C.vox_adblock_json_unlock() }
	return json2.encode(value, escape_unicode: true)
}

fn decode_transport_json[T](source string) !T {
	C.vox_adblock_json_lock()
	defer { C.vox_adblock_json_unlock() }
	return json2.decode[T](source)
}
