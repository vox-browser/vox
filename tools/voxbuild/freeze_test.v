module main

import json2 as json
import os

fn test_frozen_flags_keep_operands_and_source_languages_distinct() ! {
	root := make_temp_directory(os.temp_dir(), 'vox-freeze-flags-')!
	defer { os.rmdir_all(root) or {} }
	for file in ['native.cpp', 'helper.c', 'link.a'] {
		os.write_file(os.join_path(root, file), 'input')!
	}
	parts := parse_frozen_flags(['-include', 'header.cpp', '-I', 'includes.c', '-x', 'objective-c++',
		'native.cpp', '-x', 'none', 'helper.c', 'link.a', '-framework', 'Foundation',
		'-Wl,-rpath,/private/lib'], root)!
	assert parts[0].kind == 'option'
	assert parts[0].value == ['-include', 'header.cpp']
	assert parts[1].kind == 'option'
	assert parts[3].kind == 'source'
	assert parts[3].value == [os.join_path(root, 'native.cpp'), 'objective-c++']
	assert parts[5].value == [os.join_path(root, 'helper.c'), 'c']
	assert parts[6].kind == 'object'
	assert flags_from_json(flag_parts_json(parts))! == parts
}

fn test_unsealed_compiler_flags_are_rejected() ! {
	for flags in [['-o', 'bad'], ['-I'], ['-x'], ['@response'], ['-fplugin=plugin.so'], ['-Xclang'],
		['-Wl,-force_load,lib.a'], ['-include-pch', 'cache'], ['-B/alternate'], ['missing.c'],
		['-Wl,-rpath,/safe,-plugin,/unsafe']] {
		parse_frozen_flags(flags, os.getwd()) or { continue }
		assert false, 'Unsealed compiler flag accepted: ${flags}'
	}
}

fn test_link_library_resolution_is_pinned() ! {
	root := make_temp_directory(os.temp_dir(), 'vox-freeze-library-')!
	defer { os.rmdir_all(root) or {} }
	first := os.join_path(root, 'first')
	second := os.join_path(root, 'second')
	make_directory(first)!
	make_directory(second)!
	library := os.join_path(second, 'libfixture.a')
	os.write_file(library, 'archive')!
	parts := parse_frozen_flags(['-L', first, '-L' + second, '-lfixture', '-lc'], root)!
	original := resolved_libraries(parts, root)!
	assert original['library:fixture'] == library
	identity := fingerprint(original.values())!
	os.write_file(os.join_path(first, 'libfixture.dylib'), 'earlier search result')!
	assert !string_maps_equal(resolved_libraries(parts, root)!, original)
	os.write_file(library, 'changed archive')!
	check_fingerprints(identity) or { return }
	assert false, 'Modified live library was not rejected'
}

fn test_frozen_receipt_rejects_incomplete_and_modified_inputs() ! {
	root := make_temp_directory(os.temp_dir(), 'vox-freeze-receipt-')!
	defer { os.rmdir_all(root) or {} }
	sealed := os.join_path(root, 'browser.i')
	live := os.join_path(root, 'live')
	os.write_file(sealed, 'sealed bytes')!
	os.write_file(live, 'live bytes')!
	expected := RepositoryState{ head: 'commit', build_inputs_sha256: 'source-hash' }
	mut data := FrozenCompile{
		protocol:         frozen_protocol
		source_inputs:    expected
		cwd:              root
		compiler_command: ['cc', sealed]
		sealed_inputs:    fingerprint([sealed])!
		live_inputs:      fingerprint([live])!
	}
	receipt := os.join_path(root, 'frozen-compile.json')
	os.write_file(receipt, json.encode(data))!
	validate_frozen_compile(root, root, expected, false)!
	mut rejected := false
	validate_frozen_compile(root, root, expected, true) or { rejected = true }
	assert rejected
	data.complete = true
	data.compiler_exit = 0
	os.write_file(receipt, json.encode(data))!
	validate_frozen_compile(root, root, expected, true)!
	os.write_file(sealed, 'modified bytes')!
	validate_frozen_compile(root, root, expected, true) or { return }
	assert false, 'Modified preprocessed source accepted'
}

fn test_canonical_manifest_digest_uses_sorted_paths() {
	assert canonical_source_json({
		'z': 'second'
		'a': 'first'
	}) == '{"a": "first", "z": "second"}'
}

fn test_frozen_symlink_inputs_keep_the_spelled_source_language() ! {
	root := make_temp_directory(os.temp_dir(), 'vox-freeze-links-')!
	defer { os.rmdir_all(root) or {} }
	content := os.join_path(root, 'content-without-extension')
	os.write_file(content, 'input')!
	os.symlink(content, os.join_path(root, 'source.c'))!
	os.symlink(content, os.join_path(root, 'object.a'))!
	parts := parse_frozen_flags(['source.c', 'object.a'], root)!
	assert parts[0] == FlagPart{'source', [content, 'c']}
	assert parts[1] == FlagPart{'object', [content]}
}
