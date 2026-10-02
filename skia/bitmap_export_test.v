module skia

fn test_bitmap_export_uses_source_skia_premultiplication_flip_and_nearest_scaling() {
	bitmap:=BitmapSource{width:2,height:2,pixels:[u8(200),100,50,128,0,255,0,255,0,0,255,255,255,255,0,255]}
	premultiplied:=export_bitmap_to_byte_buffer(bitmap,.rgba8888,false,true,none,none)!
	assert premultiplied.pixels[..4]==[u8(100),50,25,128]
	flipped:=export_bitmap_to_byte_buffer(bitmap,.rgba8888,true,false,none,none)!
	assert flipped.pixels[..8]==bitmap.pixels[8..]
	scaled:=export_bitmap_to_byte_buffer(bitmap,.rgba8888,false,false,4,4)!
	assert scaled.width==4 && scaled.height==4
	assert scaled.pixels[..4]==[u8(200),100,50,128]
	assert scaled.pixels[60..]==[u8(255),255,0,255]
	alpha:=export_bitmap_to_byte_buffer(bitmap,.alpha8,false,false,none,none)!
	assert alpha.pixels==[u8(128),255,255,255]
	rgb:=export_bitmap_to_byte_buffer(bitmap,.rgb888,true,true,8,8)!
	assert rgb.width==2 && rgb.height==2
	assert rgb.pixels==[u8(0),0,255,255,255,0,200,100,50,0,255,0]
}

fn test_bitmap_export_preserves_native_alpha_layout_and_source_unsupported_format() {
	bitmap:=BitmapSource{width:1,height:1,layout:1,alpha_type:2,pixels:[u8(25),50,100,128]}
	straight:=export_bitmap_to_byte_buffer(bitmap,.rgba8888,false,false,none,none)!
	assert straight.pixels==[u8(199),100,50,128]
	if _:=export_bitmap_to_byte_buffer(bitmap,.rgba5551,false,false,none,none) {assert false}
	assert (export_bitmap_to_byte_buffer(bitmap,.rgba8888,false,false,0,0)!).pixels.len==0
	negative:=export_bitmap_to_byte_buffer(bitmap,.rgba8888,false,false,-1,1)!
	assert negative.width==-1 && negative.pixels.len==0
}
