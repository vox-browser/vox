module platform

import os
import time

fn test_windows_document_font_prefers_the_installed_bold_face() {
	root := os.join_path(os.temp_dir(), 'vox-windows-font-${os.getpid()}-${time.sys_mono_now()}')
	fonts := os.join_path(root, 'Fonts')
	os.mkdir_all(fonts) or { panic(err) }
	defer { os.rmdir_all(root) or {} }

	assert windows_document_font_path('', 400) == none
	assert windows_document_font_path(root, 400) == none
	regular := os.join_path(fonts, 'arial.ttf')
	bold := os.join_path(fonts, 'arialbd.ttf')
	os.write_file(regular, '') or { panic(err) }
	assert (windows_document_font_path(root, 400) or { '' }) == regular
	assert (windows_document_font_path(root, 700) or { '' }) == regular
	os.write_file(bold, '') or { panic(err) }
	assert (windows_document_font_path(root, 400) or { '' }) == regular
	assert (windows_document_font_path(root, 700) or { '' }) == bold
}

fn test_windows_document_font_provides_a_glyph_outline() {
	root := os.getenv_opt('WINDIR') or { os.getenv('SystemRoot') }
	path := windows_document_font_path(root, 700) or { return }
	font := &Font{family: 'Arial', source_path: path, point_size: 50, weight: 700}
	_, glyph := font.glyph_advance_and_index(u32(`A`))
	assert glyph > 0
	outline := font.glyph_outline(glyph) or { panic('missing installed Arial outline') }
	assert outline.contours.len > 0
}
