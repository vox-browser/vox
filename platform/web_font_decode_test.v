module platform

import gfxfont
import os

fn test_web_font_preparation_retains_the_source_woff_conversion_verbatim() {
	data :=
		os.read_bytes(os.join_path(os.dir(@FILE), '..', 'gfxfont', 'testdata', 'HashSans.woff'))!
	prepared := prepare_font_data(data) or { panic('source WOFF preparation failed') }
	assert os.read_bytes(prepared)! == gfxfont.convert_woff_to_sfnt(data)!
	assert prepare_font_data(data)? == prepared
}

fn test_web_font_preparation_retains_the_source_woff2_conversion_verbatim() {
	data := os.read_bytes(os.join_path(os.dir(@FILE), '..', 'gfxfont', 'testdata',
		'incorrect_sfnt_size.woff2'))!
	prepared := prepare_font_data(data) or { panic('source WOFF2 preparation failed') }
	assert os.read_bytes(prepared)! == gfxfont.convert_woff2_to_sfnt(data)!
}
