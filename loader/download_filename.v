// Copyright (c) 2026, Tim Ledbetter <tim.ledbetter@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Loader/DownloadFilename.{h,cpp}.
module loader

pub const maximum_filename_byte_length = 255

pub fn truncate_filename_to_byte_length(filename string, maximum_byte_length uint) string {
	if uint(filename.len) <= maximum_byte_length {
		return filename
	}
	mut length := maximum_byte_length
	for _ in 0 .. 3 {
		if length == 0 || filename[int(length)] & 0xc0 != 0x80 {
			break
		}
		length--
	}
	return filename[..int(length)]
}

pub fn sanitize_suggested_download_filename(filename string) string {
	basename := filename.all_after_last('/')
	mut bytes := []u8{cap: basename.len}
	for byte in basename.bytes() {
		bytes << if byte in [u8(0), `/`, `\\`] { `_` } else { byte }
	}
	sanitized := bytes.bytestr()
	if sanitized in ['', '.', '..'] {
		return 'download'
	}
	if sanitized.len <= maximum_filename_byte_length {
		return sanitized
	}

	last_dot := sanitized.last_index('.') or { -1 }
	if last_dot > 0 && last_dot < sanitized.len - 1 {
		extension := sanitized[last_dot + 1..]
		if extension.len + 1 < maximum_filename_byte_length {
			title := sanitized[..last_dot]
			maximum_title_length := maximum_filename_byte_length - extension.len - 1
			return '${truncate_filename_to_byte_length(title, uint(maximum_title_length))}.${extension}'
		}
	}
	return truncate_filename_to_byte_length(sanitized, maximum_filename_byte_length)
}
