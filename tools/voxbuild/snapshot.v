module main

import crypto.sha256
import json2
import os

const snapshot_deflate_version = '1.24'
const snapshot_deflate_sha256 = 'ad8d3723d0065c4723ab738be9723f2ff1cb0f1571e8bfcf0301ff9661f475e8'
const snapshot_deflate_url = 'https://codeload.github.com/ebiggers/libdeflate/tar.gz/refs/tags/v1.24'

struct SnapshotBuildIdentity {
	version          string
	url              string
	archive_sha256   string
	inputs           map[string]string
	builder_sha256   string
	compiler         string
	compiler_version string
	cmake_version    string
}

struct SnapshotBuildReceipt {
	inputs            SnapshotBuildIdentity
	library_sha256    string
	configure_command []string
}

fn snapshot_builder_hash(repo string) !string {
	mut identity := ''
	for name in ['snapshot.v', 'common.v', 'native.v', 'memory.v', 'supervisor.v', 'supervisor_native.h'] {
		identity += name + '\x00' + hash_file(os.join_path(repo, 'tools/voxbuild', name))! + '\x00'
	}
	return sha256.hexhash(identity)
}

// Compare authenticated archive files with the live source tree before making
// any missing file available. An existing edited dependency is never reset.
fn snapshot_stage_source_tree(extracted string, destination string, relative string) !map[string]string {
	reference := os.join_path(extracted, relative)
	if os.is_link(reference) || !os.is_dir(reference) {
		return error('Unsupported libdeflate archive entry: ${relative}')
	}
	mut names := os.ls(reference)!
	names.sort()
	mut inputs := map[string]string{}
	for name in names {
		path := relative + '/' + name
		source := os.join_path(extracted, path)
		if os.is_link(source) {
			return error('Unsupported libdeflate archive entry: ${path}')
		}
		if os.is_dir(source) {
			for child, digest in snapshot_stage_source_tree(extracted, destination, path)! {
				inputs[child] = digest
			}
			continue
		}
		if !os.is_file(source) || (os.stat(source)!).nlink != 1 {
			return error('Unsupported libdeflate archive entry: ${path}')
		}
		digest := hash_file(source)!
		target := os.join_path(destination, path)
		if os.exists(target) || os.is_link(target) {
			if !os.is_file(target) || hash_file(target)! != digest {
				return error('Modified dependency source: ${target}')
			}
		} else {
			make_directory(os.dir(target))!
			os.cp(source, target, fail_if_exists: true)!
			os.chmod(target, int((os.stat(source)!).mode & 0o777))!
		}
		inputs[path] = digest
	}
	return inputs
}

fn snapshot_extract_sources(archive string, root string, prefix string) !map[string]string {
	// The shared extractor checks paths. Reject links and special entries before
	// invoking tar as well; this compressor consists only of directories/files.
	listing := capture_command(['tar', '-tvzf', archive])!
	for line in listing.split_into_lines() {
		if line.len == 0 || line[0] !in [`-`, `d`] {
			return error('Unsupported libdeflate archive entry: ${line}')
		}
	}
	work := make_temp_directory(root, '.snapshot-source-')!
	defer { os.rmdir_all(work) or {} }
	extract_pinned_archive(archive, work, prefix)!
	return snapshot_stage_source_tree(work, root, prefix)
}

fn snapshot_same_identity(previous SnapshotBuildIdentity, current SnapshotBuildIdentity) bool {
	if previous.version != current.version || previous.url != current.url
		|| previous.archive_sha256 != current.archive_sha256
		|| previous.builder_sha256 != current.builder_sha256 || previous.compiler != current.compiler
		|| previous.compiler_version != current.compiler_version
		|| previous.cmake_version != current.cmake_version || previous.inputs.len != current.inputs.len {
		return false
	}
	for path, digest in current.inputs {
		if path !in previous.inputs || previous.inputs[path] != digest {
			return false
		}
	}
	return true
}

fn build_snapshot_deflate(repo string) !string {
	prefix := 'libdeflate-' + snapshot_deflate_version
	root := os.join_path(repo, 'Build/deps', prefix)
	make_directory(root)!
	mut held := acquire_file_lock(os.join_path(root, 'snapshot-build.lock'), true)!
	if !held.acquired {
		return error('Snapshot compression build is already running: ${root}')
	}
	defer { held.release() }
	archive := os.join_path(root, 'source.tar.gz')
	verified_download(snapshot_deflate_url, archive, snapshot_deflate_sha256, 'sha256')!
	inputs := snapshot_extract_sources(archive, root, prefix)!
	source := os.join_path(root, prefix)
	output := os.join_path(root, 'snapshot-build')
	library := os.join_path(output, 'libdeflate.a')
	receipt := os.join_path(root, 'snapshot-build.json')
	cmake := os.find_abs_path_of_executable('cmake') or {
		return error('Snapshot compression requires CMake and Clang')
	}
	compiler := os.find_abs_path_of_executable('clang') or {
		return error('Snapshot compression requires CMake and Clang')
	}
	identity := SnapshotBuildIdentity{
		version:          snapshot_deflate_version
		url:              snapshot_deflate_url
		archive_sha256:   snapshot_deflate_sha256
		inputs:           inputs
		builder_sha256:   snapshot_builder_hash(repo)!
		compiler:         compiler
		compiler_version: capture_command([compiler, '--version'])!
		cmake_version:    capture_command([cmake, '--version'])!
	}
	if os.is_file(receipt) && os.is_file(library) {
		previous := json2.decode[SnapshotBuildReceipt](os.read_file(receipt)!)!
		if snapshot_same_identity(previous.inputs, identity) && previous.library_sha256 == hash_file(library)! {
			return root
		}
	}
	command := [cmake, '-S', source, '-B', output, '-DCMAKE_BUILD_TYPE=Release',
		'-DCMAKE_C_COMPILER=${compiler}', '-DCMAKE_C_FLAGS=-fvisibility=hidden',
		'-DCMAKE_POSITION_INDEPENDENT_CODE=ON', '-DLIBDEFLATE_BUILD_STATIC_LIB=ON',
		'-DLIBDEFLATE_BUILD_SHARED_LIB=OFF', '-DLIBDEFLATE_BUILD_GZIP=OFF',
		'-DLIBDEFLATE_BUILD_TESTS=OFF', '-DLIBDEFLATE_DECOMPRESSION_SUPPORT=OFF',
		'-DLIBDEFLATE_GZIP_SUPPORT=OFF']
	run_to_stderr(command)!
	run_to_stderr([cmake, '--build', output, '--parallel', '2'])!
	atomic_write_json_text(receipt, json2.encode(SnapshotBuildReceipt{
		inputs:            identity
		library_sha256:    hash_file(library)!
		configure_command: command
	}, prettify: true, indent_string: '  '))!
	return root
}
