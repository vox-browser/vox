module platform

import os

fn test_atomic_replacement_creates_then_replaces_a_unicode_profile_file() {
	root := os.join_path(os.temp_dir(), 'vox-profile-Ж ${os.getpid()}')
	os.mkdir_all(root)!
	defer { os.rmdir_all(root) or {} }
	destination := os.join_path(root, 'profile.json')
	source := destination + '.replacement'
	for contents in ['first profile', 'replacement profile'] {
		os.write_file(source, contents)!
		atomic_replace_file(source, destination)!
		assert os.read_file(destination)! == contents
		assert !os.exists(source)
	}
}

fn test_atomic_replacement_does_not_treat_a_directory_as_a_container() {
	root := os.join_path(os.temp_dir(), 'vox-profile-directory-${os.getpid()}')
	os.mkdir_all(root)!
	defer { os.rmdir_all(root) or {} }
	source := os.join_path(root, 'profile.replacement')
	destination := os.join_path(root, 'existing-directory')
	os.mkdir(destination)!
	os.write_file(source, 'keep the source on failure')!
	mut failed := false
	atomic_replace_file(source, destination) or { failed = true }
	assert failed
	assert os.read_file(source)! == 'keep the source on failure'
	assert os.is_dir(destination)
}
