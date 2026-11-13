module buildtools

import os
import json2 as json

fn test_repeated_large_compiler_manifest_reads_keep_identical_v_inputs() ! {
	root := temporary(os.temp_dir(), 'vox-manifest-stability-')!
	defer { remove(root) or {} }
	mut names := []string{}
	mut hashes := []string{}
	mut expected := map[string]string{}
	for i in 0 .. 400 {
		path := join(root, 'package${i / 20}', 'source${i}.v')
		value := hash('source ${i}')
		names << path
		hashes << value
		expected[path] = value
	}
	names << '@native-input-manifest:v1'
	hashes << hash('v3-native-input-manifest-v1')
	names << '@native-input:' + join(root, 'native.h')
	hashes << hash('native input')
	os.write_file(join(root, 'v_sources'), names.join('\x00') + '\x00')!
	os.write_file(join(root, 'v_source_digests'), hashes.join('\x00') + '\x00')!
	first := only_v(component_inputs(root)!)
	assert first == expected
	for _ in 0 .. 3 {
		assert first == only_v(component_inputs(root)!)
		check_parsed_manifest(root, first)!
	}
	write_json(join(root, 'parsed-verified.json'), json.Any(map[string]json.Any{
		'protocol': 'verified-parsed-buffers-v1'
		'sources':  record_strings(first)
	}))!
	assert only_v(verified_component(root)!) == expected
}

fn test_changed_compiler_manifest_retains_both_identities_and_rejects() ! {
	root := temporary(os.temp_dir(), 'vox-manifest-change-')!
	defer { remove(root) or {} }
	path := join(root, 'source.v')
	before, after := hash('first buffer'), hash('second buffer')
	os.write_file(join(root, 'v_sources'), path)!
	os.write_file(join(root, 'v_source_digests'), after)!
	mut rejected := false
	check_parsed_manifest(root, {
		path: before
	}) or {
		rejected = true
		assert err.msg().contains('manifest-changed.json')
	}
	assert rejected
	report := load(join(root, 'manifest-changed.json'))!
	assert string_map(report['expected'] or { json.Null{} }) == {
		path: before
	}
	assert string_map(report['actual'] or { json.Null{} }) == {
		path: after
	}
}
