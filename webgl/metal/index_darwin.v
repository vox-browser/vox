module metal

pub enum IndexFormat { u8 u16 u32 }

pub struct IndexBinding {
pub:
	buffer &GPUBuffer = unsafe { nil }
	offset int
	format IndexFormat = .u16
	restart bool
}

struct PreparedIndices {
	buffer &GPUBuffer = unsafe { nil }
	offset u64
	width u32
	maximum u64
	has_vertices bool
	owned bool
}

// Metal accepts 16/32-bit indices and always reserves the largest value for
// primitive restart. Expand byte indices and non-restarting 16-bit indices so
// legal WebGL1 index values retain their meaning.
fn prepare_indices(target &DrawingBuffer, binding IndexBinding, count int) !PreparedIndices {
	if binding.buffer == unsafe { nil } || binding.buffer.handle == unsafe { nil } || binding.buffer.owner.handle != target.handle || binding.offset < 0 { return error('Invalid Metal index buffer') }
	width := match binding.format { .u8 { 1 } .u16 { 2 } .u32 { 4 } }
	if binding.offset % width != 0 || binding.offset > binding.buffer.length || u64(count) * u64(width) > u64(binding.buffer.length - binding.offset) { return error('Metal index range outside allocation') }
	bytes := binding.buffer.read(binding.offset, count * width)!
	mut maximum := u64(0)
	mut has_vertices := false
	mut converted := []u8{}
	out_width := if width == 1 { 2 } else if width == 2 && !binding.restart { 4 } else { width }
	if out_width != width { converted = []u8{len: count * out_width} }
	restart := match width { 1 { u64(255) } 2 { u64(65535) } else { u64(0xffffffff) } }
	for i in 0 .. count {
		mut value := u64(0)
		for j in 0 .. width { value |= u64(bytes[i * width + j]) << (j * 8) }
		if !binding.restart && width == 4 && value == restart { return error('Metal cannot encode a non-restarting uint32 maximum index') }
		if !binding.restart || value != restart {
			has_vertices = true
			if value > maximum { maximum = value }
		} else if out_width != width { value = if out_width == 2 { u64(65535) } else { u64(0xffffffff) } }
		if out_width != width { for j in 0 .. out_width { converted[i * out_width + j] = u8(value >> (j * 8)) } }
	}
	if out_width == width { return PreparedIndices{buffer: binding.buffer, offset: u64(binding.offset), width: u32(width), maximum: maximum, has_vertices: has_vertices} }
	mut buffer := GPUBuffer.create(target, converted.len)!
	buffer.write(0, converted) or { buffer.close(); return err }
	return PreparedIndices{buffer: buffer, width: u32(out_width), maximum: maximum, has_vertices: has_vertices, owned: true}
}
