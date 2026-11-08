module main

import os

fn main() {
	result := os.execute('/bin/echo vox-prealloc-capture')
	assert result.exit_code == 0
	assert result.output.trim_space() == 'vox-prealloc-capture'
	failed := os.execute('/bin/sh -c "exit 7"')
	assert failed.exit_code == 7
	println('Staged prealloc process capture and exit status passed')
}
