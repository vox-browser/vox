module main

import os
import strconv
import time
import math

fn pre_commit_violations(repo string, max_bytes u64) ![]string {
	output := supervisor_git(repo, ['diff', '--cached', '--raw', '-z', '--no-renames', '--no-abbrev',
		'--diff-filter=ACM'])!
	fields := output.split('\x00')
	mut problems := []string{}
	for index := 0; index + 1 < fields.len; index += 2 {
		metadata := fields[index].fields()
		if metadata.len < 4 { continue }
		if metadata[1] == '160000' { continue }
		path := fields[index + 1]
		lower := path.to_lower()
		measurement := (path.starts_with('docs/performance/') || path.starts_with('docs/benchmark-results/'))
			&& os.file_ext(lower) in ['.json', '.jsonl', '.ndjson']
		archive := os.file_ext(lower) in ['.gz', '.tgz', '.zip', '.tar', '.xz', '.zst', '.7z',
			'.bz2', '.tbz2', '.txz', '.rar']
		allowed_archive := path.starts_with('adblock/') || path.starts_with('tools/adblock/fixtures/') || path.starts_with('Tests/Browser/Brave/candidates/')
		if path == 'Build' || path.starts_with('Build/') {
			problems << '${path}: Build/ is local scratch'
		} else if measurement {
			problems << '${path}: measurement dumps stay local; commit a Markdown summary instead'
		} else if archive && !allowed_archive {
			problems << '${path}: archives stay local; commit the report or manifest instead'
		} else {
			size_text := supervisor_git(repo, ['cat-file', '-s', metadata[3]])!.trim_space()
			size := u64(strconv.atoi(size_text)!)
			if size > max_bytes {
				problems << '${path}: ${f64(size) / 1048576:.1f} MiB exceeds the ${f64(max_bytes) / 1048576:.0f} MiB limit'
			}
		}
	}
	return problems
}

fn native_pre_commit(repo string, args []string) !int {
	if args.len != 0 { return error('Usage: vox-build pre-commit') }
	problems := pre_commit_violations(repo, 32 * 1024 * 1024)!
	if problems.len == 0 { return 0 }
	eprintln('Commit rejected by tools/voxbuild:')
	for problem in problems { eprintln('  ' + problem) }
	eprintln('Unstage these with `git restore --staged PATH` and keep them out of the repository.')
	return 1
}

fn held_build_paths(build string) !map[string]bool {
	result := capture_result(['lsof', '-nP', '-Fn'])!
	if result.stdout == '' {
		return error('lsof is unavailable; cannot tell which Build/ entries are in use')
	}
	resolved := os.real_path(build)
	prefix := resolved + os.path_separator
	mut held := map[string]bool{}
	for line in result.stdout.split_into_lines() {
		if line.starts_with('n' + prefix) {
			mut path := line[1..]
			for path != resolved && path !in held {
				held[path] = true
				parent := os.dir(path)
				if parent == path { break }
				path = parent
			}
		}
	}
	return held
}

fn newest_build_mtime(path string) i64 {
	mut newest := i64(0)
	mut pending := [path]
	for pending.len > 0 {
		current := pending.pop()
		info := os.lstat(current) or { continue }
		if info.mtime > newest { newest = info.mtime }
		if info.get_filetype() == .directory {
			for name in os.ls(current) or { []string{} } { pending << os.join_path(current, name) }
		}
	}
	return newest
}

fn remove_build_entry(path string) ! {
	if os.is_link(path) || !os.is_dir(path) {
		if os.exists(path) || os.is_link(path) { os.rm(path)! }
		return
	}
	// Frozen receipt directories may be read-only. Change only directory modes
	// inside the exact scratch entry selected for deletion; never follow links.
	mut pending := [path]
	for pending.len > 0 {
		current := pending.pop()
		if os.is_link(current) { continue }
		os.chmod(current, 0o755)!
		for name in os.ls(current)! {
			child := os.join_path(current, name)
			if !os.is_link(child) && os.is_dir(child) { pending << child }
		}
	}
	os.rmdir_all(path) or {
		if os.user_os() != 'macos' { return err }
		capture_result(['chflags', '-R', 'nouchg,nouappnd', path])!
		os.rmdir_all(path)!
	}
}

fn immutable_build_tool_name(name string) bool {
	if !name.starts_with('vox-build-') { return false }
	parts := name['vox-build-'.len..].split('-')
	if parts.len != 2 { return false }
	for part in parts {
		if part == '' { return false }
		for ch in part { if ch < `0` || ch > `9` { return false } }
	}
	return true
}

fn prune_build_tool_cache(build string, held map[string]bool, now i64, idle f64,
	dry_run bool, verbose bool) !int {
	root := os.join_path(build, 'tools')
	if !os.is_dir(root) { return 0 }
	mut protected := {
		os.real_path(os.join_path(root, 'vox-build')): true
		os.real_path(os.executable()):                 true
	}
	configured := os.getenv('VOX_BUILD_TOOL')
	if configured != '' { protected[os.real_path(configured)] = true }
	mut removed := 0
	for name in os.ls(root)! {
		path := os.join_path(root, name)
		if !immutable_build_tool_name(name) || os.is_link(path) || !os.is_file(path) { continue }
		resolved := os.real_path(path)
		if resolved in protected || resolved in held || f64(now - os.file_last_mod_unix(path)) < idle {
			continue
		}
		if !dry_run {
			os.rm(path) or {
				eprintln('Build/ pruning retained ${path}: ${err}')
				continue
			}
		}
		removed++
		if verbose { println('Unused build tool: ${path}') }
	}
	return removed
}

fn prune_build_idle(repo string, idle f64, dry_run bool, verbose bool) !int {
	build := os.join_path(repo, 'Build')
	if !os.is_dir(build) { return 0 }
	held := held_build_paths(build)!
	now := time.now().unix()
	mut removed := prune_build_tool_cache(build, held, now, idle, dry_run, verbose)!
	mut candidates := []string{}
	for name in os.ls(build)! {
		if name !in ['v', 'deps', 'libregex', 'linux', 'tools', 'production-build', 'pixel-tools',
			'release.lock', '.DS_Store'] {
			candidates << os.join_path(build, name)
		}
	}
	shared := os.join_path(build, 'v')
	if os.is_dir(shared) {
		for name in os.ls(shared)! {
			if name.starts_with('compiler-output.') || name in ['Vox-profile', 'Vox-profile.c',
				'address-bar-tests', 'settings-tests'] {
				candidates << os.join_path(shared, name)
			}
		}
	}
	for path in candidates {
		if f64(now - newest_build_mtime(path)) < idle || os.real_path(path) in held { continue }
		if !dry_run {
			remove_build_entry(path) or {
				eprintln('Build/ pruning retained ${path}: ${err}')
				continue
			}
		}
		removed++
		if verbose { println('Idle build output: ${path}') }
	}
	for cache in ['prealloc-runtime', 'font-runtime', 'native-gg-runtime'] {
		root := os.join_path(shared, cache)
		if !os.is_dir(root) { continue }
		mut digests := []string{}
		for name in os.ls(root)! {
			path := os.join_path(root, name)
			if os.is_dir(path) && !os.is_link(path) { digests << path }
		}
		digests.sort()
		// Most-recently-used runtime directories are protected independently of
		// their digest names. The remaining entries still require age and lsof.
		digests.sort_with_compare(fn (a &string, b &string) int {
			first := os.file_last_mod_unix(*a)
			second := os.file_last_mod_unix(*b)
			return if first > second {
				-1
			} else if first < second {
				1
			} else {
				0
			}
		})
		for index, path in digests {
			lock_path := path + '.lock'
			if index < 2 || f64(now - os.file_last_mod_unix(path)) < idle || os.real_path(path) in held || os.real_path(lock_path) in held {
				continue
			}
			if !dry_run {
				remove_build_entry(path) or {
					eprintln('Build/ pruning retained ${path}: ${err}')
					continue
				}
				if os.exists(lock_path) { os.rm(lock_path)! }
			}
			removed++
			if verbose { println('Unused staged runtime: ${path}') }
		}
	}
	if !dry_run {
		prune_production_receipts(os.join_path(build, 'production-build'))!
		prune_production_receipts(os.join_path(build, 'linux', 'production-build'))!
	}
	return removed
}

fn prune_build(repo string, args []string) !int {
	mut idle_hours := 12.0
	mut dry_run := false
	mut verbose := false
	mut index := 0
	for index < args.len {
		match args[index] {
			'--idle-hours' {
				index++
				if index >= args.len { return error('--idle-hours requires a number') }
				idle_hours = strconv.atof64(args[index])!
				if idle_hours < 0 || math.is_nan(idle_hours) || math.is_inf(idle_hours, 0) {
					return error('--idle-hours must be finite and nonnegative')
				}
			}
			'--dry-run' { dry_run = true }
			'--verbose' { verbose = true }
			else { return error('Unknown prune option: ${args[index]}') }
		}
		index++
	}
	count := prune_build_idle(repo, idle_hours * 3600, dry_run, verbose)!
	println('${if dry_run { 'Would remove' } else { 'Removed' }} ${count} Build/ entries')
	return 0
}
