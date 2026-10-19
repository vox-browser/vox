module css

import math.bits

// Keep the live flag table borrowed. Font/style updates may change later flags
// while the caller consumes earlier properties; iteration remains in ID order.
struct InheritedPropertyIterator {
	style &ComputedProperties
mut:
	index int
}

fn (style &ComputedProperties) inherited_property_iterator() InheritedPropertyIterator {
	return InheritedPropertyIterator{
		style: style
	}
}

fn (mut iterator InheritedPropertyIterator) next() ?PropertyID {
	for iterator.index < number_of_longhand_properties {
		byte_index := iterator.index / 8
		remaining := iterator.style.property_inherited_[byte_index] & (u8(255) << (iterator.index % 8))
		if remaining == 0 {
			iterator.index = (byte_index + 1) * 8
			continue
		}
		index := byte_index * 8 + bits.trailing_zeros_8(remaining)
		iterator.index = index + 1
		return property_id_from_longhand_index(index)
	}
	return none
}
