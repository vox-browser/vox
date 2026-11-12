module buildtools

import os
import time

fn scan(path string) !(i64, i64) {
	if !exists(path) { return i64(0), i64(0) }
	stat := os.lstat(path)!
	mut newest := stat.mtime
	mut size := stat.size
	if os.is_dir(path) && !os.is_link(path) {
		for entry in listing(path)! {
			mtime, bytes := scan(entry)!
			if mtime > newest { newest = mtime }
			size += bytes
		}
	}
	return newest, size
}

fn retire(path string, dry bool) ! {
	if dry {
		println('Would remove ${path}')
		return
	}
	remove(path) or {
		$if macos {
			execute(['chflags', '-R', 'nouchg,nouappnd', path])
		}
		execute(['chmod', '-R', 'u+w', path])
		remove(path)!
	}
	println('Removed ${path}')
}

fn prune_receipts(build string, dry bool) ! {
	state := join(build, 'production-build')
	receipts := (listing(join(state, 'receipts'))!).filter(os.is_dir(it))
	latest := read(join(state, 'latest.json')) or { '' }
	for i, receipt in receipts {
		if i == receipts.len - 1 || (latest.len > 0 && (read(join(receipt, 'result.json')) or { '' }) == latest) {
			continue
		}
		if i < receipts.len - 20 {
			retire(receipt, dry)!
			continue
		}
		for name in ['generated', 'frozen-compiler-inputs'] {
			path := join(receipt, name)
			if exists(path) { retire(path, dry)! }
		}
	}
}

fn prune_build(root string, idle_hours f64, dry bool) ! {
	build := join(root, 'Build')
	if !os.is_dir(build) { return }
	mut process := os.new_process('lsof')
	process.set_args(['-nP', '-Fn'])
	process.set_redirect_stdio()
	process.run()
	output := process.stdout_slurp()
	process.stderr_slurp()
	process.wait()
	process.close()
	if output.len == 0 {
		return error('lsof unavailable; cannot tell which Build/ entries are in use')
	}
	mut held := []string{}
	for line in output.split_into_lines() {
		if line.starts_with('n' + build + '/') { held << line[1..] }
	}
	mut candidates := (listing(build)!).filter(os.file_name(it) !in ['v', 'deps', 'libregex', 'linux',
		'production-build', 'pixel-tools', 'release.lock', '.DS_Store'])
	for path in listing(join(build, 'v'))! {
		if os.file_name(path).starts_with('compiler-output.') || os.file_name(path) in [
			'Vox-profile',
			'Vox-profile.c',
			'address-bar-tests',
			'settings-tests',
		] {
			candidates << path
		}
	}
	for path in candidates {
		newest, _ := scan(path)!
		if f64(time.now().unix() - newest) < idle_hours * 3600 || held.any(it == path || it.starts_with(path + '/')) {
			continue
		}
		retire(path, dry)!
	}
	prune_receipts(build, dry)!
	for cache in ['prealloc-runtime', 'font-runtime', 'native-gg-runtime'] {
		base := join(build, 'v', cache)
		mut digests := (listing(base)!).filter(os.is_dir(it))
		digests.sort_with_compare(fn (a &string, b &string) int {
			return int(os.file_last_mod_unix(*b) - os.file_last_mod_unix(*a))
		})
		for i, path in digests {
			if i < 2 || f64(time.now().unix() - os.file_last_mod_unix(path)) < idle_hours * 3600 || held.any(it == path || it.starts_with(path + '/') || it == path + '.lock') {
				continue
			}
			retire(path, dry)!
			if exists(path + '.lock') { retire(path + '.lock', dry)! }
		}
	}
}
