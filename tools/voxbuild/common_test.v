module main

import crypto.sha256
import crypto.sha512
import os

fn test_literal_command_arguments_and_streams() ! {
	args := ['one two', r'$(printf unwanted)', 'quote\'and"double', '', r'path\name']
	assert shell_split(command_line(args))! == args
	result := capture_result(['sh', '-c', r'printf "%s" "$1"; printf "%s" "$2" >&2; exit 19', 'probe',
		args[1], args[2]])!
	assert result.exit_code == 19
	assert result.stdout == args[1]
	assert result.stderr == args[2]
	assert capture_command(['printf', 'line\n'])! == 'line\n'
}

fn test_shell_flags_preserve_quotes_without_evaluation() ! {
	text := '-I"/SDK path/include" ' + "'literal " + r'$HOME' + "' " + r'"back\q" escaped\ space'
	assert shell_split(text)! ==
		['-I/SDK path/include', r'literal $HOME', r'back\q', 'escaped space']
	for invalid in ["'unfinished", 'last\\'] {
		shell_split(invalid) or { continue }
		assert false, 'Malformed flags must fail'
	}
}

fn test_probe_uses_compiler_reported_root_and_keeps_diagnostics() ! {
	root := make_temp_directory(os.temp_dir(), 'vox-probe-test-')!
	defer { os.rmdir_all(root) or {} }
	library := os.join_path(root, 'selected root/vlib')
	make_directory(library)!
	work := os.join_path(root, 'work')
	compiler := os.join_path(root, 'fake v')
	os.write_file(compiler, '#!/bin/sh\ncase " $* " in *" -gc none "*) ;; *) exit 91;; esac\ncase " $* " in *" -b c "*) ;; *) exit 92;; esac\nprintf "%s\\n" ' + shell_quote(os.dir(library)) + '\n')!
	os.chmod(compiler, 0o755)!
	assert compiler_vlib(compiler, work)! == library
	assert os.ls(work)!.len == 0
	os.write_file(compiler, '#!/bin/sh\nprintf "frontend error"\nprintf "linker error" >&2\nexit 17\n')!
	compiler_vlib(compiler, work) or {
		assert err.msg().contains('exit 17')
		assert err.msg().contains('frontend error')
		assert err.msg().contains('linker error')
		assert err.msg().contains(shell_quote(compiler))
		assert os.ls(work)!.len == 0
		return
	}
	assert false, 'Failed compiler must not select a library'
}

fn test_backend_requires_one_supported_setting() ! {
	root := make_temp_directory(os.temp_dir(), 'vox-backend-test-')!
	defer { os.rmdir_all(root) or {} }
	os.write_file(os.join_path(root, 'v.mod'), "Module {\n backend: 'fastc', // selected backend\n}\n")!
	assert browser_backend(root)! == 'fastc'
	for source in ['Module {}', "backend: 'other'", "backend: 'c'\nbackend: 'fastc'"] {
		os.write_file(os.join_path(root, 'v.mod'), source)!
		browser_backend(root) or { continue }
		assert false, 'Invalid backend declaration accepted'
	}
}

fn test_streamed_hashes_match_multichunk_and_empty_inputs() ! {
	root := make_temp_directory(os.temp_dir(), 'vox-file-hash-test-')!
	defer { os.rmdir_all(root) or {} }
	path := os.join_path(root, 'binary input')
	mut data := []u8{len: 2 * 1024 * 1024 + 137}
	defer { unsafe { data.free() } }
	for index in 0 .. data.len { data[index] = u8(index * 37 + 17) }
	mut file := os.create(path)!
	file.write(data)!
	file.close()
	assert hash_file(path)! == sha256.sum(data).hex()
	mut sha512_digest := sha512.new()
	assert file_digest(path, mut sha512_digest)! == sha512.sum512(data).hex()
	os.write_file(path, '')!
	assert hash_file(path)! == sha256.hexhash('')
	mut empty_sha512 := sha512.new()
	assert file_digest(path, mut empty_sha512)! == sha512.sum512([]u8{}).hex()
}

fn test_streamed_hash_reports_a_missing_input() ! {
	root := make_temp_directory(os.temp_dir(), 'vox-file-hash-missing-')!
	defer { os.rmdir_all(root) or {} }
	missing := os.join_path(root, 'missing input')
	hash_file(missing) or {
		assert err.msg().contains(missing)
		return
	}
	assert false, 'A missing file must not be hashed as empty content'
}
