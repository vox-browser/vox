module html

import os

fn test_selected_file_from_path_keeps_only_basename() {
	directory := os.join_path(os.temp_dir(), 'libweb-v-selected-file-${os.getpid()}')
	os.mkdir_all(directory)!
	path := os.join_path(directory, 'upload.txt')
	os.write_file(path, 'contents')!
	mut selected := SelectedFile.from_file_path(path)!
	assert selected.name == 'upload.txt'
	assert selected.file_or_contents is os.File
	if selected.file_or_contents is os.File {
		mut open_file := selected.file_or_contents as os.File
		open_file.close()
	}
	os.rm(path)!
	os.rmdir(directory)!
}

fn test_selected_file_take_contents_moves_buffer() {
	mut selected := SelectedFile.from_contents('data.bin', [u8(1), 2, 3])
	assert selected.name == 'data.bin'
	assert selected.take_contents() == [u8(1), 2, 3]
	assert selected.take_contents().len == 0
}

fn test_selected_file_ipc_round_trips_contents_and_file_backing() {
	selected := SelectedFile.from_contents('bytes.bin', [u8(4), 5, 6])
	mut decoded := decode_selected_file(encode_selected_file(&selected)!)!
	assert decoded.name == 'bytes.bin'
	assert decoded.take_contents() == [u8(4), 5, 6]

	directory := os.join_path(os.temp_dir(), 'libweb-v-selected-file-ipc-${os.getpid()}')
	os.mkdir_all(directory)!
	path := os.join_path(directory, 'file.txt')
	os.write_file(path, 'file-backed')!
	mut file_backed := SelectedFile.from_file_path(path)!
	mut decoded_file := decode_selected_file(encode_selected_file(&file_backed)!)!
	assert decoded_file.name == 'file.txt'
	assert decoded_file.take_contents().bytestr() == 'file-backed'
	if file_backed.file_or_contents is os.File {
		mut open_file := file_backed.file_or_contents as os.File
		open_file.close()
	}
	os.rm(path)!
	os.rmdir(directory)!
}
