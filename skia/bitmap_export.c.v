// Translation of Gfx::export_bitmap_to_byte_buffer with a native Skia ABI.
module skia

$if linux {
	#flag @DIR/../Build/linux/native/skia.a
} $else {
	#flag @DIR/bitmap_export.o
}
#include "bitmap_export.h"

pub enum BitmapExportFormat {
	gray8
	alpha8
	rgb565
	rgba5551
	rgba4444
	rgb888
	rgba8888
}

pub struct BitmapSource {
pub:
	width int
	height int
	pitch int
	// V host layout: RGBA, BGRA, RGBx, BGRx.
	layout int
	alpha_type int = 1
	color_space int
	pixels []u8
}

pub struct BitmapExport {
pub:
	width int
	height int
	pixels []u8
}

fn C.vox_skia_bitmap_export(&u8,int,int,int,int,int,int,int,int,int,int,&u8) int

pub fn export_bitmap_to_byte_buffer(bitmap BitmapSource, format BitmapExportFormat, flip_y bool, premultiply_alpha bool, target_width ?int, target_height ?int) !BitmapExport {
	mut width:=target_width or {bitmap.width}
	mut height:=target_height or {bitmap.height}
	// HostWebGLContext::convert_bitmap_for_upload returns these sizes to GL.
	if width<0 || height<0 {return BitmapExport{width:width,height:height}}
	if format==.rgb888 && (width!=bitmap.width || height!=bitmap.height) {width=bitmap.width;height=bitmap.height}
	bytes_per_pixel:=match format {.gray8,.alpha8 {1} .rgb565,.rgba5551,.rgba4444 {2} .rgb888 {3} .rgba8888 {4}}
	length:=u64(width)*u64(height)*u64(bytes_per_pixel)
	if length>u64(max_int) {return error('Gfx::export_bitmap_to_byte_buffer size overflow')}
	mut output:=[]u8{len:int(length)}
	if length==0 {return BitmapExport{width:width,height:height,pixels:output}}
	pitch:=if bitmap.pitch==0 {bitmap.width*4} else {bitmap.pitch}
	if bitmap.width<=0 || bitmap.height<=0 || pitch<bitmap.width*4 || u64(pitch)*u64(bitmap.height)>u64(bitmap.pixels.len) {return error('Invalid bitmap storage')}
	flags:=int(premultiply_alpha)+2*int(flip_y)
	if C.vox_skia_bitmap_export(bitmap.pixels.data,bitmap.width,bitmap.height,pitch,bitmap.layout,bitmap.alpha_type,bitmap.color_space,int(format),flags,width,height,output.data)!=1 {return error('Failed to export bitmap through Skia')}
	return BitmapExport{width:width,height:height,pixels:output}
}
