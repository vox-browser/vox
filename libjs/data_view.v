module libjs

// Runtime/DataView.{h,cpp}. This completes the retained view and its buffer
// witness algorithms. Host-created records select their prototype explicitly;
// the translated constructor uses the realm's DataView prototype graph.
@[heap]
pub struct DataView {
pub:
	object &Object
	viewed_buffer ?&ArrayBufferObject
	byte_length ByteLength
	offset uint
}

pub fn DataView.create(realm &Realm, viewed_buffer ?&ArrayBufferObject, byte_length ByteLength, byte_offset uint, prototype &Object) &DataView {
	mut object := Object.create(realm, prototype)
	object.class_name = 'DataView'
	view := &DataView{object: object, viewed_buffer: viewed_buffer, byte_length: byte_length, offset: byte_offset}
	object.data_view = view
	return view
}

pub fn (view &DataView) byte_offset() u32 { return u32(view.offset) }

pub struct DataViewWithBufferWitness {
pub:
	object &DataView
	cached_buffer_byte_length ByteLength
}

pub fn make_data_view_with_buffer_witness_record(view &DataView, order BufferOrder) DataViewWithBufferWitness {
	buffer := view.viewed_buffer or { panic('DataView witness requires an installed buffer') }
	length := if buffer.is_detached() {
		ByteLength.detached()
	} else { ByteLength.from_u32(u32(array_buffer_byte_length(buffer, order))) }
	return DataViewWithBufferWitness{object: view, cached_buffer_byte_length: length}
}

pub fn is_view_out_of_bounds(record DataViewWithBufferWitness) bool {
	view := record.object
	buffer := view.viewed_buffer or { panic('DataView witness requires an installed buffer') }
	length := record.cached_buffer_byte_length
	assert buffer.is_detached() == length.is_detached()
	if length.is_detached() { return true }
	start := view.byte_offset()
	end := if view.byte_length.is_auto() { length.length() } else { start + view.byte_length.length() }
	return start > length.length() || end > length.length()
}

pub fn get_view_byte_length(record DataViewWithBufferWitness) u32 {
	assert !is_view_out_of_bounds(record)
	view := record.object
	if !view.byte_length.is_auto() { return view.byte_length.length() }
	buffer := view.viewed_buffer or { panic('DataView witness requires an installed buffer') }
	assert !buffer.is_fixed_length()
	assert !record.cached_buffer_byte_length.is_detached()
	return record.cached_buffer_byte_length.length() - view.byte_offset()
}
