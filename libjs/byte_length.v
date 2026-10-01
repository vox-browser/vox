module libjs

// Runtime/ByteLength.h: tagged lengths used by buffer witness records. Keeping
// auto and detached distinct from numeric zero is necessary for empty views.
pub enum ByteLengthKind {
	length
	auto_
	detached
}

pub struct ByteLength {
	kind  ByteLengthKind
	value u32
}

pub fn ByteLength.from_u32(length u32) ByteLength {
	return ByteLength{value: length}
}

pub fn ByteLength.auto_length() ByteLength {
	return ByteLength{kind: .auto_}
}

pub fn ByteLength.detached() ByteLength {
	return ByteLength{kind: .detached}
}

pub fn (length ByteLength) is_auto() bool {
	return length.kind == .auto_
}

pub fn (length ByteLength) is_detached() bool {
	return length.kind == .detached
}

pub fn (length ByteLength) length() u32 {
	assert length.kind == .length
	return length.value
}
