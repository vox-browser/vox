// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

const max_input_bytes = 64 * 1024 * 1024

struct CodestreamPart {
	data []u8
	last bool
}

fn container_be32(data []u8) u32 {
	return (u32(data[0]) << 24) | (u32(data[1]) << 16) | (u32(data[2]) << 8) | u32(data[3])
}

fn container_be64(data []u8) u64 {
	return (u64(container_be32(data[..4])) << 32) | u64(container_be32(data[4..8]))
}

// Extracts one complete codestream from a bounded, complete input file. Auxiliary
// boxes are validated/skipped; streaming checkpoints and metadata extraction are separate work.
pub fn extract_codestream(input []u8) ![]u8 {
	if input.len > max_input_bytes { return error('JPEG XL input exceeds 64 MiB') }
	signature := check_signature(input)
	if signature.status == .codestream { return input }
	if signature.status != .container { return error('Invalid or truncated JPEG XL signature') }
	mut position := 12
	mut version := -1
	mut whole_start := 0
	mut whole_end := 0
	mut has_whole := false
	mut parts := map[u32]CodestreamPart{}
	mut wanted := u32(0)
	mut last_index := u32(0)
	mut has_last := false
	mut codestream_complete := false
	for position < input.len {
		if input.len - position < 8 { return error('Truncated JPEG XL box header') }
		start := position
		mut length := u64(container_be32(input[position..position + 4]))
		kind := input[position + 4..position + 8].bytestr()
		position += 8
		if length == 1 {
			if input.len - position < 8 { return error('Truncated JPEG XL extended box size') }
			length = container_be64(input[position..position + 8])
			position += 8
			if length < 16 { return error('Invalid JPEG XL extended box size') }
		} else if length == 0 {
			length = u64(input.len - start)
		}
		if length < u64(position - start) || length > u64(input.len - start) {
			return error('Invalid or truncated JPEG XL box size')
		}
		end := start + int(length)
		body := input[position..end]
		position = end
		if kind != 'ftyp' && version < 0 { return error('JPEG XL file type box must be first') }
		match kind {
			'ftyp' {
				if version >= 0 || body.len < 8 || body[..4].bytestr() != 'jxl ' {
					return error('Invalid JPEG XL file type box')
				}
				encoded_version := container_be32(body[4..8])
				if encoded_version > 1 { return error('Unsupported JPEG XL container version') }
				version = int(encoded_version)
			}
			'jxlc' {
				if has_whole || parts.len > 0 {
					return error('Mixed or duplicate JPEG XL codestream boxes')
				}
				whole_start = end - body.len
				whole_end = end
				has_whole = true
				codestream_complete = true
			}
			'jxlp' {
				if has_whole || codestream_complete || body.len < 4 {
					return error('Invalid JPEG XL partial codestream box')
				}
				header := container_be32(body[..4])
				index := header & 0x7fffffff
				last := header & 0x80000000 != 0
				if index in parts || index < wanted || (index > wanted && version != 1) {
					return error('Duplicate or unordered JPEG XL codestream part')
				}
				if has_last && (last || index > last_index) {
					return error('JPEG XL codestream part follows last part')
				}
				if last {
					has_last = true
					last_index = index
				}
				parts[index] = CodestreamPart{ data: body[4..], last: last }
				for {
					if wanted !in parts { break }
					part := parts[wanted]
					wanted++
					if part.last {
						codestream_complete = true
						break
					}
				}
			}
			'brob' {
				if body.len < 4 { return error('Truncated JPEG XL compressed metadata box') }
				inner := body[..4].bytestr()
				if inner == 'brob' || inner == 'jbrd' || inner.starts_with('jxl') {
					return error('Invalid JPEG XL compressed metadata type')
				}
			}
			else {}
		}
	}
	if has_whole {
		whole := input[whole_start..whole_end]
		if check_signature(whole).status != .codestream {
			return error('Invalid JPEG XL codestream signature')
		}
		return whole
	}
	if !has_last || !codestream_complete || u64(last_index) + 1 != u64(parts.len) {
		return error('Missing JPEG XL codestream parts')
	}
	mut size := 0
	for _, part in parts { size += part.data.len }
	mut stream := []u8{cap: size}
	for i in 0 .. parts.len {
		stream << parts[u32(i)].data
	}
	if check_signature(stream).status != .codestream {
		return error('Invalid JPEG XL codestream signature')
	}
	return stream
}
