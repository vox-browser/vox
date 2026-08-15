// Copyright (c) 2021-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained IPv6 parser of LibURL/Parser.cpp — the WHATWG URL IPv6 parser,
// including "::" compression and an embedded dotted-quad IPv4 tail. Pure string->address; the address is
// returned as eight u16 pieces (or none on failure). Validation-error reporting (a debug side effect) is
// dropped. Walks the input by code point with an EOF sentinel, mirroring the spec's pointer.
// https://url.spec.whatwg.org/#concept-ipv6-parser
module url

const ipv6_eof = rune(-1)

fn ipv6_code_point_at(code_points []rune, pointer int) rune {
	if pointer >= code_points.len {
		return ipv6_eof
	}
	return code_points[pointer]
}

fn ipv6_is_hex_digit(cp rune) bool {
	return cp >= 0 && cp <= 0x7F && is_ascii_hex_digit(u8(cp))
}

fn ipv6_hex_value(cp rune) u32 {
	return parse_ascii_hex_digit(u8(cp))
}

fn ipv6_is_digit(cp rune) bool {
	return cp >= `0` && cp <= `9`
}

fn ipv6_digit_value(cp rune) u32 {
	return u32(cp - `0`)
}

// https://url.spec.whatwg.org/#concept-ipv6-parser
pub fn parse_ipv6_address(input string) ?[]u16 {
	// 1. address: eight zero pieces.
	mut address := []u16{len: 8}
	// 2. pieceIndex = 0.
	mut piece_index := 0
	// 3. compress = null.
	mut compress := ?int(none)
	code_points := input.runes()
	// 4. pointer over input.
	mut pointer := 0

	// 5. A leading "::".
	if ipv6_code_point_at(code_points, pointer) == `:` {
		// 1. It must be followed by another ":".
		if ipv6_code_point_at(code_points, pointer + 1) != `:` {
			return none
		}
		// 2-3. Skip both colons and open a compression.
		pointer += 2
		piece_index++
		compress = piece_index
	}

	// 6. Consume pieces until the end.
	for ipv6_code_point_at(code_points, pointer) != ipv6_eof {
		// 1. No more than eight pieces.
		if piece_index == 8 {
			return none
		}
		// 2. A compression ":".
		if ipv6_code_point_at(code_points, pointer) == `:` {
			// 1. Only one compression is allowed.
			if compress != none {
				return none
			}
			// 2. Skip it and open the compression.
			pointer++
			piece_index++
			compress = piece_index
			continue
		}
		// 3-4. Read up to four hex digits.
		mut value := u32(0)
		mut length := 0
		for length < 4 && ipv6_is_hex_digit(ipv6_code_point_at(code_points, pointer)) {
			value = value * 0x10 + ipv6_hex_value(ipv6_code_point_at(code_points, pointer))
			pointer++
			length++
		}
		// 5. An embedded IPv4 dotted quad.
		if ipv6_code_point_at(code_points, pointer) == `.` {
			// 1. There must be a hex run before the dot.
			if length == 0 {
				return none
			}
			// 2. Rewind to the start of that run.
			pointer -= length
			// 3. The IPv4 tail needs two pieces.
			if piece_index > 6 {
				return none
			}
			// 4. numbersSeen = 0.
			mut numbers_seen := 0
			// 5. Parse the octets.
			for ipv6_code_point_at(code_points, pointer) != ipv6_eof {
				// 1. ipv4Piece = null.
				mut ipv4_piece := ?u32(none)
				// 2. A "." separates octets after the first.
				if numbers_seen > 0 {
					if ipv6_code_point_at(code_points, pointer) == `.` && numbers_seen < 4 {
						pointer++
					} else {
						return none
					}
				}
				// 3. Each octet must start with a digit.
				if !ipv6_is_digit(ipv6_code_point_at(code_points, pointer)) {
					return none
				}
				// 4. Read the octet.
				for ipv6_is_digit(ipv6_code_point_at(code_points, pointer)) {
					number := ipv6_digit_value(ipv6_code_point_at(code_points, pointer))
					if piece := ipv4_piece {
						// A leading zero (a previous 0) makes the octet invalid.
						if piece == 0 {
							return none
						}
						ipv4_piece = piece * 10 + number
					} else {
						ipv4_piece = number
					}
					if (ipv4_piece or { u32(0) }) > 255 {
						return none
					}
					pointer++
				}
				// 5. Fold the octet into the current piece.
				ipv4_piece_value := ipv4_piece or { return none }
				address[piece_index] = u16(u32(address[piece_index]) * 0x100 + ipv4_piece_value)
				// 6-7. Two octets fill one piece.
				numbers_seen++
				if numbers_seen == 2 || numbers_seen == 4 {
					piece_index++
				}
			}
			// 6. Exactly four octets are required.
			if numbers_seen != 4 {
				return none
			}
			// 7. The IPv4 tail ends the address.
			break
		} else if ipv6_code_point_at(code_points, pointer) == `:` {
			// 6. A piece separator.
			pointer++
			// 2. It must not be the last code point.
			if ipv6_code_point_at(code_points, pointer) == ipv6_eof {
				return none
			}
		} else if ipv6_code_point_at(code_points, pointer) != ipv6_eof {
			// 7. Anything else is invalid.
			return none
		}
		// 8-9. Store the piece.
		address[piece_index] = u16(value)
		piece_index++
	}

	// 7. Expand a compression by moving the trailing pieces to the end.
	if compress_index := compress {
		mut swaps := piece_index - compress_index
		piece_index = 7
		for piece_index != 0 && swaps > 0 {
			address[piece_index], address[compress_index + swaps - 1] = address[compress_index +
				swaps - 1], address[piece_index]
			piece_index--
			swaps--
		}
	} else if piece_index != 8 {
		// 8. Without a compression, all eight pieces are required.
		return none
	}

	// 9. Return the address.
	return address
}
