module main

import crypto.sha256
import json2
import os
import time

struct PreallocIdentity {
	compiler        string
	compiler_sha256 string
	vlib            string
	sha256          string
	owned_files     map[string]string
}

fn patch_allocator(repo string, allocation_source string, prealloc_source string) !(string, string) {
	used := allocation_source.contains('prealloc_realloc_copy_size(')
	defined := prealloc_source.contains('fn prealloc_realloc_copy_size(')
	if used && defined {
		return allocation_source, prealloc_source
	}
	unsupported := 'Unsupported V allocator: bounded v_realloc cannot be staged. Set V_BIN to a compatible current V compiler.'
	signature := 'pub fn v_realloc(b &u8, n int) &u8'
	start, _, closing := staging_function_range(allocation_source, signature) or {
		return error(unsupported)
	}
	old := 'new_ptr = malloc(n)\n\t\t\tC.memcpy(new_ptr, b, n)'
	function := allocation_source[start..closing + 1]
	if used || defined || function.count(old) != 1 || !prealloc_source.contains('fn prealloc_realloc(') {
		return error(unsupported)
	}
	replacement := 'copy_size := prealloc_realloc_copy_size(b, n)\n\t\t\tnew_ptr = malloc(n)\n\t\t\tif copy_size > 0 { C.memcpy(new_ptr, b, copy_size) }'
	allocation := allocation_source[..start] + function.replace(old, replacement) + allocation_source[closing + 1..]
	helper := os.read_file(os.join_path(repo, 'tools/prealloc_runtime/bounded_realloc.c.v'))!
	if !helper.contains('module builtin\n') {
		return error('The bounded realloc helper has no builtin module declaration')
	}
	return allocation, prealloc_source + '\n' + helper.all_after('module builtin\n')
}

fn validate_allocator(builtin string) ! {
	allocation := os.read_file(os.join_path(builtin, 'allocation.c.v'))!
	prealloc := os.read_file(os.join_path(builtin, 'prealloc.c.v'))!
	if !allocation.contains('prealloc_realloc_copy_size(') || !prealloc.contains('fn prealloc_realloc_copy_size(') {
		return error("Prealloc requires V's bounded v_realloc copy, including realloc(nil, n). Set V_BIN to a compatible current V compiler.")
	}
}

fn staging_wrap_function(source string, signature string, before string, after string) !string {
	start, opening, closing := staging_function_range(source, signature) or {
		return error('Unsupported V closure runtime: expected one ${signature}')
	}
	return source[..start] + signature + ' {\n' + before + source[opening + 1..closing] + after + '}\n' + source[closing + 1..]
}

fn declare_capture_helpers(source string, header string) string {
	resolved := json2.encode(os.real_path(header))
	mut result := ''
	mut offset := 0
	mut search := 0
	for search < source.len {
		start := source.index_after('#include', search) or { break }
		mut value := start + '#include'.len
		search = value
		for value < source.len && source[value].is_space() {
			value++
		}
		if value == search {
			continue
		}
		for token in ['@VMODROOT', '@VEXEROOT'] {
			old := '"' + token + '/vlib/os/execute_capture_legacy.h"'
			if source[value..].starts_with(old) {
				result += source[offset..value] + resolved
				offset = value + old.len
				search = offset
				break
			}
		}
	}
	result += source[offset..]
	footer := '// Staged by tools/voxbuild/prealloc.v: os sources resolve outside\n' +
		'// this compiler root, so V does not declare their native capture helpers.\n#include ' + resolved + '\n'
	if result.contains(footer) {
		return result
	}
	return result.trim_right('\n') + '\n\n' + footer
}

fn staging_same_hashes(first map[string]string, second map[string]string) bool {
	if first.len != second.len {
		return false
	}
	for name, hash in first {
		if name !in second || second[name] != hash {
			return false
		}
	}
	return true
}

fn staging_reusable_runtime(root string, identity PreallocIdentity) !bool {
	manifest := os.join_path(root, 'manifest.json')
	if !os.is_file(manifest) {
		return false
	}
	recorded := json2.decode[PreallocIdentity](os.read_file(manifest)!)!
	if recorded.compiler_sha256 != identity.compiler_sha256 || recorded.vlib != identity.vlib || recorded.sha256 != identity.sha256 || !staging_same_hashes(recorded.owned_files, identity.owned_files) {
		return false
	}
	compiler := os.join_path(root, 'compiler/v')
	if !os.is_file(compiler) || os.real_path(os.join_path(root, 'compiler/vlib/builtin')) != os.join_path(root, 'builtin') || hash_file(compiler)! != identity.compiler_sha256 {
		return false
	}
	for name, hash in identity.owned_files {
		path := os.join_path(root, name)
		if !os.is_file(path) || hash_file(path)! != hash {
			return false
		}
	}
	return true
}

fn staging_write_runtime(staged string, root string, vlib string, builtin string, owned map[string][]u8, compiler string, identity PreallocIdentity) ! {
	make_directory(os.join_path(staged, 'builtin/closure'))!
	for file_name in os.ls(builtin)! {
		name := 'builtin/' + file_name
		if file_name != 'closure' && name !in owned {
			stage_link(os.join_path(staged, name), os.join_path(builtin, file_name))!
		}
	}
	for name, data in owned {
		os.write_file(os.join_path(staged, name), data.bytestr())!
	}
	compiler_root := os.join_path(staged, 'compiler')
	make_directory(os.join_path(compiler_root, 'vlib'))!
	for name in os.ls(vlib)! {
		target := if name == 'builtin' {
			os.join_path(root, 'builtin')
		} else {
			os.join_path(vlib, name)
		}
		stage_link(os.join_path(compiler_root, 'vlib', name), target)!
	}
	for name in ['thirdparty', 'cmd', 'v.mod'] {
		original := os.join_path(os.dir(vlib), name)
		if os.exists(original) {
			stage_link(os.join_path(compiler_root, name), original)!
		}
	}
	compiler_copy := os.join_path(compiler_root, 'v')
	os.cp(compiler, compiler_copy)!
	metadata := os.stat(compiler)!
	os.utime(compiler_copy, metadata.atime, metadata.mtime)!
	validate_allocator(os.join_path(staged, 'builtin'))!
	atomic_write_json_text(os.join_path(staged, 'manifest.json'), json2.encode(identity,
		prettify: true
	) + '\n')!
}

fn prepare_prealloc(repo string, compiler_name string, output_root string) !string {
	compiler := os.real_path(os.find_abs_path_of_executable(compiler_name) or { compiler_name })
	probe_work := make_temp_directory(os.temp_dir(), 'vox-prealloc-root-')!
	defer { os.rmdir_all(probe_work) or {} }
	vlib := os.real_path(compiler_vlib(compiler, probe_work)!)
	builtin := os.join_path(vlib, 'builtin')
	allocation, prealloc := patch_allocator(repo, os.read_file(os.join_path(builtin, 'allocation.c.v'))!, os.read_file(os.join_path(builtin, 'prealloc.c.v'))!)!
	source := os.join_path(builtin, 'closure')
	if !os.is_file(os.join_path(source, 'closure.c.v')) {
		return error('Prealloc requires the current V closure runtime')
	}
	mut inputs := map[string][]u8{}
	for name in os.ls(builtin)! {
		path := os.join_path(builtin, name)
		if os.is_file(path) {
			inputs['builtin/' + name] = os.read_bytes(path)!
		}
	}
	for name in os.ls(source)! {
		path := os.join_path(source, name)
		if os.is_file(path) {
			inputs['builtin/closure/' + name] = os.read_bytes(path)!
		}
	}
	mut owned := {
		'builtin/allocation.c.v':                        allocation.bytes()
		'builtin/prealloc.c.v':                          prealloc.bytes()
		'builtin/closure/closure_prealloc_metadata.c.v': os.read_bytes(os.join_path(repo, 'tools/prealloc_runtime/closure_prealloc_metadata.c.v'))!
	}
	compat := os.join_path(builtin, 'c_headers_compat_nix.c.v')
	capture_header := os.join_path(vlib, 'os/execute_capture_legacy.h')
	if os.is_file(compat) && os.is_file(capture_header) {
		owned['builtin/c_headers_compat_nix.c.v'] = declare_capture_helpers(os.read_file(compat)!, capture_header).bytes()
		inputs['os/execute_capture_legacy.h'] = os.read_bytes(capture_header)!
	}
	for name, original in inputs {
		if name.starts_with('builtin/closure/') {
			mut data := original.clone()
			if name.ends_with('/closure.c.v') {
				data = staging_wrap_function(data.bytestr(), 'fn closure_init_body()', '\tclosure_metadata_enter()\n', '\tclosure_metadata_leave()\n')!.bytes()
			} else if os.file_name(name) in ['closure_nix.c.v', 'closure_windows.c.v'] {
				text := staging_wrap_function(data.bytestr(), 'fn closure_mtx_lock_platform()', '', '\tclosure_metadata_enter()\n')!
				data = staging_wrap_function(text, 'fn closure_mtx_unlock_platform()', '\tclosure_metadata_leave()\n', '')!.bytes()
			}
			owned[name] = data
		}
	}
	mut owned_hashes := map[string]string{}
	for name, data in owned {
		inputs[name] = data.clone()
		owned_hashes[name] = sha256.sum(data).hex()
	}
	compiler_hash := hash_file(compiler)!
	mut digest := sha256.new()
	digest.write(vlib.bytes())!
	digest.write(compiler_hash.bytes())!
	mut names := inputs.keys()
	names.sort()
	for name in names {
		digest.write(name.bytes())!
		digest.write([u8(0)])!
		digest.write(inputs[name])!
	}
	digest.write(os.read_bytes(os.join_path(repo, 'tools/voxbuild/prealloc.v'))!)!
	hash := digest.sum([]u8{}).hex()
	base := if output_root != '' {
		output_root
	} else {
		os.join_path(repo, 'Build/v/prealloc-runtime')
	}
	make_directory(base)!
	root := os.join_path(os.real_path(base), hash)
	identity := PreallocIdentity{ compiler: compiler, compiler_sha256: compiler_hash, vlib: vlib, sha256: hash, owned_files: owned_hashes }
	mut runtime_lock := acquire_file_lock(os.join_path(os.dir(root), hash + '.lock'), false)!
	defer { runtime_lock.release() }
	if staging_reusable_runtime(root, identity)! {
		now := time.now().unix()
		os.utime(root, now, now)!
		return root
	}
	if os.exists(root) {
		return error('Incomplete or modified staged V runtime: ${root}')
	}
	temporary := make_temp_directory(os.dir(root), hash + '.tmp-')!
	defer { os.rmdir_all(temporary) or {} }
	staged := os.join_path(temporary, 'runtime')
	staging_write_runtime(staged, root, vlib, builtin, owned, compiler, identity)!
	os.rename(staged, root)!
	return root
}
