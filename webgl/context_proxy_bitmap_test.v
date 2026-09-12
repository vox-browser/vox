module webgl

import encoding.binary

fn test_context_proxy_records_bitmap_upload_commands_and_options() {
	mut proxy := WebGLContextProxyBase.new(.webgl2, []string{}, 1024)!
	proxy.tex_image2d_from_bitmap(texture_2d, 1, 0x1908, 0x1908, 0x1401, [u8(1), 2, 3, 4], WebGLIntSize{ width: 8, height: 6 }, true, false)!
	proxy.tex_sub_image2d_from_bitmap(texture_2d, 2, 3, 4, 0x1908, 0x1401, [u8(5), 6, 7, 8], none, false, true)!
	proxy.tex_image3d_from_bitmap(texture_3d, 3, 0x1908, 4, 0x1908, 0x1401, [u8(9), 10, 11, 12], WebGLIntSize{ width: 2, height: 3 }, true, true)!
	proxy.tex_sub_image3d_from_bitmap(texture_3d, 4, 5, 6, 7, 8, 0x1908, 0x1401, [
		u8(13),
		14,
		15,
		16,
	], none, false, false)!
	proxy.flush_commands()

	batches := proxy.transmitted_batches()
	assert batches.len == 1
	assert batches[0].bitmap_count == 4
	records := WebGLCommandList.for_each_command(batches[0].bytes)!
	assert records.map(it.type_) == [webgl_command_tex_image2d_from_bitmap,
		webgl_command_tex_sub_image2d_from_bitmap, webgl_command_tex_image3d_from_bitmap,
		webgl_command_tex_sub_image3d_from_bitmap]
	assert binary.little_endian_u32_at(records[0].payload, 20) == 0
	assert binary.little_endian_u32_at(records[0].payload, 24) == 1
	assert binary.little_endian_u32_at(records[0].payload, 28) == 8
	assert binary.little_endian_u32_at(records[0].payload, 32) == 6
	assert binary.little_endian_u32_at(records[0].payload, 36) == 1
	assert binary.little_endian_u32_at(records[0].payload, 40) == 0
	assert binary.little_endian_u32_at(records[1].payload, 24) == 1
	assert binary.little_endian_u32_at(records[1].payload, 28) == 0
}

fn test_context_proxy_keeps_bitmap_and_referring_command_in_same_batch() {
	mut proxy := WebGLContextProxyBase.new(.webgl1, []string{}, 2048)!
	for index in 0 .. webgl_max_bitmap_attachments_per_message + 1 {
		proxy.tex_image2d_from_bitmap(texture_2d, 0, 0x1908, 0x1908, 0x1401, [
			u8(index),
		], none, false, false)!
	}
	proxy.flush_commands()

	batches := proxy.transmitted_batches()
	assert batches.len == 2
	assert batches[0].bitmap_count == webgl_max_bitmap_attachments_per_message
	assert WebGLCommandList.for_each_command(batches[0].bytes)!.len == webgl_max_bitmap_attachments_per_message
	assert batches[1].bitmap_count == 1
	assert WebGLCommandList.for_each_command(batches[1].bytes)!.len == 1
}

fn test_context_proxy_drops_bitmap_uploads_after_loss() {
	mut proxy := WebGLContextProxyBase.new(.webgl2, []string{}, 512)!
	proxy.set_lost()
	proxy.tex_image2d_from_bitmap(texture_2d, 0, 0x1908, 0x1908, 0x1401, [u8(1), 2, 3, 4], none, false, false)!
	proxy.flush_commands()
	assert proxy.transmitted_batches().len == 0
	assert proxy.pending_bitmaps_.len == 0
}
