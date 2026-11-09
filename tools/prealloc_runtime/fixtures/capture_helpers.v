module main

import os

fn main() {
	shell := os.execute('printf shell-capture')
	assert shell.exit_code == 0
	assert shell.output == 'shell-capture'
	arguments := os.exec(['/bin/sh', '-c', 'printf argv-capture >&2; exit 7'])
	assert arguments.exit_code == 7
	assert arguments.output == 'argv-capture'
	println('capture helpers passed')
}
