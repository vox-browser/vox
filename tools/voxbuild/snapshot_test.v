module main

import os

fn test_snapshot_source_refresh_rejects_drift_and_keeps_missing_file_modes() {
	root := make_temp_directory(os.temp_dir(), 'vox-snapshot-test-')!
	defer { os.rmdir_all(root) or {} }
	extracted := os.join_path(root, 'archive')
	target := os.join_path(root, 'live')
	prefix := 'libdeflate-1.24'
	source := os.join_path(extracted, prefix, 'nested', 'source.c')
	make_directory(os.dir(source))!
	os.write_file(source, 'pinned source\n')!
	os.chmod(source, 0o751)!
	first := snapshot_stage_source_tree(extracted, target, prefix)!
	assert first.len == 1
	assert first[prefix + '/nested/source.c'] == hash_file(source)!
	live := os.join_path(target, prefix, 'nested', 'source.c')
	assert os.read_file(live)! == 'pinned source\n'
	assert (os.stat(live)!).mode & 0o777 == 0o751
	assert snapshot_stage_source_tree(extracted, target, prefix)! == first
	os.write_file(live, 'local change\n')!
	if _ := snapshot_stage_source_tree(extracted, target, prefix) {
		assert false, 'modified dependency source was accepted'
	} else {
		assert err.msg().contains('Modified dependency source:')
	}
	assert os.read_file(live)! == 'local change\n'
}

fn test_snapshot_source_tree_rejects_links() {
	root := make_temp_directory(os.temp_dir(), 'vox-snapshot-link-test-')!
	defer { os.rmdir_all(root) or {} }
	prefix := 'libdeflate-1.24'
	make_directory(os.join_path(root, prefix))!
	outside := os.join_path(root, 'outside')
	os.write_file(outside, 'external bytes')!
	os.symlink(outside, os.join_path(root, prefix, 'source.c'))!
	if _ := snapshot_stage_source_tree(root, os.join_path(root, 'live'), prefix) {
		assert false, 'archive symlink was accepted'
	}
	assert os.read_file(outside)! == 'external bytes'
}

fn test_snapshot_build_identity_invalidates_changed_sources_and_toolchains() {
	identity := SnapshotBuildIdentity{
		version:          '1.24'
		url:              snapshot_deflate_url
		archive_sha256:   snapshot_deflate_sha256
		inputs:           {
			'libdeflate-1.24/source.c': 'original'
		}
		builder_sha256:   'builder'
		compiler:         '/tools/clang'
		compiler_version: 'clang version\n'
		cmake_version:    'cmake version\n'
	}
	assert snapshot_same_identity(identity, identity)
	assert !snapshot_same_identity(identity, SnapshotBuildIdentity{ ...identity, compiler_version: 'other version\n' })
	assert !snapshot_same_identity(identity, SnapshotBuildIdentity{ ...identity, cmake_version: 'other version\n' })
	assert !snapshot_same_identity(identity, SnapshotBuildIdentity{ ...identity, builder_sha256: 'other builder' })
	assert !snapshot_same_identity(identity, SnapshotBuildIdentity{
		...identity
		inputs: {
			'libdeflate-1.24/source.c': 'changed'
		}
	})
}
