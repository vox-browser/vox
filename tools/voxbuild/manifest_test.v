module main

import crypto.sha256
import json2
import os

fn manifest_fixture() !(string, string) {
	work := make_temp_directory(os.temp_dir(), 'vox-source-manifest-test-')!
	root := os.join_path(work, 'repo')
	make_directory(root)!
	supervisor_git(root, ['init', '-q', '-b', 'master'])!
	os.write_file(os.join_path(root, 'browser.v'), 'module main\n')!
	os.write_file(os.join_path(root, 'worker.v'), 'module main\n')!
	os.write_file(os.join_path(root, 'native.h'), 'int native;\n')!
	return work, root
}

fn manifest_fixture_component(work string, name string, paths []string) !string {
	directory := os.join_path(work, name)
	make_directory(directory)!
	mut digests := []string{}
	for path in paths {
		digests << hash_file(path)!
	}
	os.write_file(os.join_path(directory, 'v_sources'), paths.join('\x00'))!
	os.write_file(os.join_path(directory, 'v_source_digests'), digests.join('\x00'))!
	return directory
}

fn manifest_fixture_proof(directory string) ! {
	atomic_write_json_text(os.join_path(directory, 'parsed-verified.json'), json2.encode(ParsedBufferProof{
		protocol: 'verified-parsed-buffers-v1'
		sources:  v_inputs(component_inputs(directory)!)
	}))!
}

fn test_source_manifest_accepts_edits_before_each_component_parses() {
	work, root := manifest_fixture()!
	defer { os.rmdir_all(work) or {} }
	inventory := begin_source_inventory(root)!
	worker := manifest_fixture_component(work, 'worker', [os.join_path(root, 'worker.v')])!
	browser_path := os.join_path(root, 'browser.v')
	os.write_file(browser_path, 'module main\nfn latest() {}\n')!
	browser := manifest_fixture_component(work, 'browser', [browser_path])!
	combined := combine_source_inputs(root, inventory, [worker, browser], false)!
	assert combined[browser_path] == hash_file(browser_path)!
	assert os.join_path(root, 'native.h') in combined
}

fn test_source_manifest_rejects_conflicting_components_and_consumed_edits() {
	work, root := manifest_fixture()!
	defer { os.rmdir_all(work) or {} }
	inventory := begin_source_inventory(root)!
	source := os.join_path(root, 'worker.v')
	first := manifest_fixture_component(work, 'first', [source])!
	os.write_file(source, 'changed source')!
	if _ := combine_source_inputs(root, inventory, [first], false) {
		assert false, 'consumed source edit was accepted'
	} else {
		assert err.msg().contains('input changed')
	}
	second := manifest_fixture_component(work, 'second', [source])!
	if _ := combine_source_inputs(root, inventory, [first, second], false) {
		assert false, 'components with different source bytes were accepted'
	} else {
		assert err.msg().contains('different source bytes')
	}
}

fn test_source_manifest_keeps_native_bytes_pinned_after_v_parse() {
	work, root := manifest_fixture()!
	defer { os.rmdir_all(work) or {} }
	inventory := begin_source_inventory(root)!
	source := os.join_path(root, 'browser.v')
	component := manifest_fixture_component(work, 'browser', [source])!
	manifest_fixture_proof(component)!
	os.write_file(source, 'edit after parsing')!
	os.write_file(os.join_path(root, 'new.v'), 'new package member after parsing')!
	combined := combine_source_inputs(root, inventory, [component], true)!
	assert combined[source] != hash_file(source)!
	os.write_file(os.join_path(root, 'native.h'), 'changed native input')!
	if _ := combine_source_inputs(root, inventory, [component], true) {
		assert false, 'native input edit was accepted'
	}
}

fn test_source_manifest_build_tool_sources_stay_pinned_and_python_tools_are_excluded() {
	work, root := manifest_fixture()!
	defer { os.rmdir_all(work) or {} }
	tools := os.join_path(root, 'tools')
	make_directory(os.join_path(tools, 'voxbuild'))!
	helper := os.join_path(tools, 'voxbuild/common.v')
	os.write_file(helper, 'module main\n')!
	os.write_file(os.join_path(tools, 'legacy.py'), 'obsolete build helper')!
	inventory := begin_source_inventory(root)!
	assert helper in inventory.early_inputs
	assert 'tools/legacy.py' !in inventory.names
	os.write_file(os.join_path(tools, 'new.py'), 'unrelated Python tool')!
	validate_source_inventory(root, inventory, true)!
	os.write_file(helper, 'modified build helper')!
	if _ := validate_source_inventory(root, inventory, true) {
		assert false, 'changed build-tool V source was accepted after parsing'
	}
	os.write_file(helper, 'module main\n')!
	os.write_file(os.join_path(tools, 'voxbuild/new.v'), 'module main\n')!
	if _ := validate_source_inventory(root, inventory, true) {
		assert false, 'changed build-tool membership was accepted after parsing'
	}
}

fn test_source_manifest_pins_the_active_build_tool_executable() {
	work, root := manifest_fixture()!
	defer { os.rmdir_all(work) or {} }
	old := os.getenv_opt('VOX_BUILD_TOOL')
	defer {
		if value := old {
			os.setenv('VOX_BUILD_TOOL', value, true)
		} else {
			os.unsetenv('VOX_BUILD_TOOL')
		}
	}
	tool := os.join_path(work, 'vox-build')
	os.write_file(tool, 'running tool bytes')!
	os.setenv('VOX_BUILD_TOOL', tool, true)
	inventory := begin_source_inventory(root)!
	assert inventory.early_inputs[tool] == hash_file(tool)!
	os.write_file(tool, 'replacement tool bytes')!
	if _ := validate_source_inventory(root, inventory, true) {
		assert false, 'replaced build tool was accepted'
	}
}

fn test_source_manifest_rejects_partial_digests_and_changed_verified_buffers() {
	work, root := manifest_fixture()!
	defer { os.rmdir_all(work) or {} }
	component := manifest_fixture_component(work, 'browser', [os.join_path(root, 'browser.v')])!
	manifest_fixture_proof(component)!
	for malformed in ['', 'bad', '0'.repeat(64) + '\x00' + '1'.repeat(64)] {
		os.write_file(os.join_path(component, 'v_source_digests'), malformed)!
		if _ := component_inputs(component) {
			assert false, 'partial manifest was accepted'
		}
	}
	os.write_file(os.join_path(component, 'v_source_digests'), '0'.repeat(64))!
	if _ := verified_component(component) {
		assert false, 'changed parsed buffer manifest was accepted'
	}
}

fn test_source_manifest_validates_native_marker_and_duplicate_paths() {
	work, root := manifest_fixture()!
	defer { os.rmdir_all(work) or {} }
	source := os.join_path(root, 'browser.v')
	native := os.join_path(root, 'native.h')
	component := manifest_fixture_component(work, 'browser', [source])!
	marker := sha256.hexhash('v3-native-input-manifest-v1')
	os.write_file(os.join_path(component, 'v_sources'), [source, '@native-input-manifest:v1',
		'@native-input:' + native].join('\x00'))!
	os.write_file(os.join_path(component, 'v_source_digests'), [hash_file(source)!, marker,
		hash_file(native)!].join('\x00'))!
	assert component_inputs(component)!.len == 2
	os.write_file(os.join_path(component, 'v_source_digests'), [hash_file(source)!, '0'.repeat(64),
		hash_file(native)!].join('\x00'))!
	if _ := component_inputs(component) {
		assert false, 'invalid native marker was accepted'
	}
	os.write_file(os.join_path(component, 'v_sources'), [source, source].join('\x00'))!
	os.write_file(os.join_path(component, 'v_source_digests'), [hash_file(source)!, '0'.repeat(64)].join('\x00'))!
	if _ := component_inputs(component) {
		assert false, 'conflicting duplicate path was accepted'
	}
}

fn manifest_fake_compiler(work string) !string {
	path := os.join_path(work, 'compiler.sh')
	os.write_file(path, '#!/bin/sh\nset -eu\n' + r'
component=$V_MACOS_V3_C_ERROR_DIR
mkdir -p "$component"
if [ "$3" = before ]; then printf changed >"$1"; fi
if [ "$3" = membership ]; then mkdir -p "$(dirname "$4")"; printf added >"$4"; fi
printf %s "$1" >"$component/v_sources"
printf %s "$2" >"$component/v_source_digests"
if [ "$3" = after ]; then
    count=0
    while [ ! -f "$component/parsed-verified.json" ]; do
        count=$((count+1))
        [ "$count" -lt 1000 ] || exit 3
        sleep .01
    done
    printf changed >"$1"
fi
')!
	os.chmod(path, 0o755)!
	return path
}

fn test_source_manifest_compiler_monitor_seals_before_later_edits() {
	work, root := manifest_fixture()!
	defer { os.rmdir_all(work) or {} }
	inventory := begin_source_inventory(root)!
	source := os.join_path(root, 'browser.v')
	component := os.join_path(work, 'browser')
	compiler := manifest_fake_compiler(work)!
	assert compile_component(root, inventory, component, [compiler, source, hash_file(source)!,
		'after'])! == 0
	assert os.read_file(source)! == 'changed'
	assert os.is_file(os.join_path(component, 'parsed-verified.json'))
	combine_source_inputs(root, inventory, [component], true)!
}

fn test_source_manifest_compiler_monitor_rejects_early_edits() {
	work, root := manifest_fixture()!
	defer { os.rmdir_all(work) or {} }
	inventory := begin_source_inventory(root)!
	source := os.join_path(root, 'browser.v')
	component := os.join_path(work, 'browser')
	compiler := manifest_fake_compiler(work)!
	if _ := compile_component(root, inventory, component, [compiler, source, hash_file(source)!,
		'before']) {
		assert false, 'edit before parsed-buffer verification was accepted'
	}
	assert os.is_file(os.join_path(component, 'verification-error.json'))
	assert !os.exists(os.join_path(component, 'parsed-verified.json'))
}

fn test_source_manifest_compiler_membership_is_scoped_to_consumed_packages() {
	for consumed in [false, true] {
		work, root := manifest_fixture()!
		defer { os.rmdir_all(work) or {} }
		inventory := begin_source_inventory(root)!
		source := os.join_path(root, 'worker.v')
		component := os.join_path(work, 'worker')
		compiler := manifest_fake_compiler(work)!
		added := os.join_path(root, if consumed { 'new.v' } else { 'css/new.v' })
		command := [compiler, source, hash_file(source)!, 'membership', added]
		if consumed {
			if _ := compile_component(root, inventory, component, command) {
				assert false, 'new consumed package member was accepted'
			}
		} else {
			assert compile_component(root, inventory, component, command)! == 0
			combine_source_inputs(root, inventory, [component], true)!
		}
	}
}
