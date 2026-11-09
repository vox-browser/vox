module main

import os
import time

fn test_pruning_retains_current_configured_recent_and_held_build_tools() ! {
	root := make_temp_directory(os.temp_dir(), 'vox-tool-cache-test-')!
	defer { os.rmdir_all(root) or {} }
	build := os.join_path(root, 'Build')
	cache := os.join_path(build, 'tools')
	os.mkdir_all(cache)!
	now := time.now().unix()
	names := ['vox-build-1-10', 'vox-build-2-20', 'vox-build-3-30', 'vox-build-4-40', 'vox-build-5-50',
		'vox-build-user-file']
	for name in names {
		path := os.join_path(cache, name)
		os.write_file(path, 'cached tool')!
		os.utime(path, now - 500, now - 500)!
	}
	os.utime(os.join_path(cache, 'vox-build-5-50'), now, now)!
	os.symlink('vox-build-1-10', os.join_path(cache, 'vox-build'))!
	prior := os.getenv_opt('VOX_BUILD_TOOL')
	os.setenv('VOX_BUILD_TOOL', os.join_path(cache, 'vox-build-2-20'), true)
	defer {
		if value := prior {
			os.setenv('VOX_BUILD_TOOL', value, true)
		} else {
			os.unsetenv('VOX_BUILD_TOOL')
		}
	}
	held := {
		os.real_path(os.join_path(cache, 'vox-build-3-30')): true
	}
	assert prune_build_tool_cache(build, held, now, 100, true, false)! == 1
	assert os.is_file(os.join_path(cache, 'vox-build-4-40'))
	assert prune_build_tool_cache(build, held, now, 100, false, false)! == 1
	assert !os.exists(os.join_path(cache, 'vox-build-4-40'))
	for name in names {
		if name != 'vox-build-4-40' {
			assert os.is_file(os.join_path(cache, name))
		}
	}
	assert os.read_file(os.join_path(cache, 'vox-build'))! == 'cached tool'
}

fn test_pruning_retains_cached_tools_when_lsof_is_unavailable() ! {
	root := make_temp_directory(os.temp_dir(), 'vox-tool-cache-lsof-test-')!
	defer { os.rmdir_all(root) or {} }
	cache := os.join_path(root, 'Build/tools')
	commands := os.join_path(root, 'commands')
	os.mkdir_all(cache)!
	os.mkdir_all(commands)!
	path := os.join_path(cache, 'vox-build-6-60')
	os.write_file(path, 'old cached tool')!
	os.write_file(os.join_path(commands, 'lsof'), '#!/bin/sh\nexit 127\n')!
	os.chmod(os.join_path(commands, 'lsof'), 0o755)!
	prior := os.getenv('PATH')
	os.setenv('PATH', commands + os.path_delimiter + prior, true)
	defer { os.setenv('PATH', prior, true) }
	mut refused := false
	prune_build_idle(root, 0, false, false) or {
		refused = true
		assert err.msg().contains('lsof is unavailable')
	}
	assert refused
	assert os.read_file(path)! == 'old cached tool'
}
