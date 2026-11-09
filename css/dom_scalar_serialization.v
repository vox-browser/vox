module css

import os

const disable_dom_scalar_serialization = os.getenv('VOX_DISABLE_DOM_SCALAR_SERIALIZATION') != ''

fn serialize_dom_exact_integer(raw f64, unit string) ?string {
	if raw != raw || raw < -2147483648.0 || raw > 2147483647.0 { return none }
	integer := i64(raw)
	if raw != f64(integer) { return none }
	mut buffer := [32]u8{}
	if unit.len > buffer.len - 11 { return none }
	mut start := buffer.len - unit.len
	for index in 0 .. unit.len { buffer[start + index] = unit[index] }
	mut magnitude := u64(if integer < 0 { -integer } else { integer })
	for {
		start--
		buffer[start] = u8(magnitude % 10) + `0`
		magnitude /= 10
		if magnitude == 0 { break }
	}
	if integer < 0 { start--; buffer[start] = `-` }
	return unsafe { tos(&buffer[start], buffer.len - start).clone() }
}

fn append_dom_color_channel(mut buffer [64]u8, start int, channel u8) int {
	mut at := start
	if channel >= 100 { buffer[at] = channel / 100 + `0`; at++ }
	if channel >= 10 { buffer[at] = (channel / 10) % 10 + `0`; at++ }
	buffer[at] = channel % 10 + `0`
	return at + 1
}

// Match Color.serialize(), including its modern syntax and exact numeric alpha.
// Channels write directly into one final buffer; only non-opaque alpha needs
// the ordinary number serializer, which defines its precision and rounding.
fn serialize_dom_color(color Color) string {
	mut buffer := [64]u8{}
	prefix := 'rgb('
	for index, byte in prefix { buffer[index] = byte }
	mut at := append_dom_color_channel(mut buffer, prefix.len, color.r)
	buffer[at] = ` `; at++
	at = append_dom_color_channel(mut buffer, at, color.g)
	buffer[at] = ` `; at++
	at = append_dom_color_channel(mut buffer, at, color.b)
	if color.a != 255 {
		buffer[at] = ` `; buffer[at + 1] = `/`; buffer[at + 2] = ` `; at += 3
		alpha := serialize_a_number(f64(color.a) / 255.0)
		for byte in alpha { buffer[at] = byte; at++ }
	}
	buffer[at] = `)`; at++
	return unsafe { tos(&buffer[0], at).clone() }
}
