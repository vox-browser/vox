module indexeddb

// Typed storage retains the complete fixed backing buffer as well as the
// view's original constructor, offset and length. Key conversion uses only
// the viewed bytes; value retrieval reconstructs the original buffer shape.
pub fn array_buffer_view_value(name string, bytes []u8, offset u32, byte_length u32, array_length ?u32) !Value {
	width := match name {
		'DataView', 'Int8Array', 'Uint8Array', 'Uint8ClampedArray' { u32(1) }
		'Int16Array', 'Uint16Array', 'Float16Array' { u32(2) }
		'Int32Array', 'Uint32Array', 'Float32Array' { u32(4) }
		'Float64Array', 'BigInt64Array', 'BigUint64Array' { u32(8) }
		else { return error('DataCloneError: unknown stored buffer view') }
	}
	if u64(offset) > u64(bytes.len) || u64(byte_length) > u64(bytes.len) - u64(offset) {
		return error('DataCloneError: stored view is out of bounds')
	}
	if name == 'DataView' {
		if array_length != none { return error('DataCloneError: DataView has no element length') }
	} else {
		count := array_length or { return error('DataCloneError: typed array has no element length') }
		if offset % width != 0 || byte_length % width != 0 || u64(count) * u64(width) != u64(byte_length) {
			return error('DataCloneError: invalid typed array dimensions')
		}
	}
	return Value{
		kind:             .array_buffer_view
		bytes:            bytes.clone()
		view_name:        name
		view_offset:      offset
		view_byte_length: byte_length
		view_length:      array_length
	}
}
