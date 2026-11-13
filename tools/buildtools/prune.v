module buildtools

import os
import time

struct PruneReport {
mut:
	removed int
	failed  int
	dry     bool
	verbose bool
}

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

fn prune_remove(path string) ! {
	if os.is_dir(path) && !os.is_link(path) {
		// Sealed compiler inputs can contain read-only directories. Change only
		// directories being removed; never traverse a module or bundle symlink.
		os.chmod(path, 0o755) or {}
		for entry in listing(path)! { prune_remove(entry)! }
		os.rmdir(path)!
	} else if exists(path) {
		os.rm(path)!
	}
}

fn retire(path string, dry bool) ! {
	if dry { return }
	prune_remove(path) or {
		$if macos {
			// App Management can reject deletion even after immutable flags have
			// been cleared. Keep that failure local to this entry and quiet the
			// recursive utility, which otherwise emits one error per bundle file.
			execute(['sh', '-c', 'exec "$@" >/dev/null 2>&1', 'sh', 'chflags', '-R', 'nouchg,nouappnd',
				path])
		}
		prune_remove(path)!
	}
}

fn (mut report PruneReport) retire_entry(path string, reason string) {
	retire(path, report.dry) or {
		report.failed++
		eprintln('Not removed: ${path}: ${err}')
		return
	}
	report.removed++
	if report.verbose { println('${reason}: ${path}') }
}

fn prune_receipts_report(build string, mut report PruneReport) ! {
	state := join(build, 'production-build')
	receipts := (listing(join(state, 'receipts'))!).filter(os.is_dir(it))
	latest := read(join(state, 'latest.json')) or { '' }
	for i, receipt in receipts {
		if i == receipts.len - 1 || (latest.len > 0 && (read(join(receipt, 'result.json')) or { '' }) == latest) {
			continue
		}
		if i < receipts.len - 20 {
			report.retire_entry(receipt, 'old production receipt')
			continue
		}
		for name in ['generated', 'frozen-compiler-inputs'] {
			path := join(receipt, name)
			if exists(path) { report.retire_entry(path, 'receipt payload') }
		}
	}
}

fn prune_receipts(build string, dry bool) ! {
	mut report := PruneReport{ dry: dry }
	prune_receipts_report(build, mut report)!
}

fn prune_build(root string, idle_hours f64, dry bool, verbose bool) ! {
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
	mut report := PruneReport{ dry: dry, verbose: verbose }
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
		newest, _ := scan(path) or {
			eprintln('Cannot scan ${path}: ${err}')
			continue
		}
		if f64(time.now().unix() - newest) < idle_hours * 3600 || held.any(it == path || it.starts_with(path + '/')) {
			continue
		}
		report.retire_entry(path, 'idle job output')
	}
	prune_receipts_report(build, mut report)!
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
			report.retire_entry(path, 'unused runtime')
			if exists(path + '.lock') { report.retire_entry(path + '.lock', 'unused runtime lock') }
		}
	}
	println('${if dry { 'Would remove' } else { 'Removed' }} ${report.removed} Build/ entries')
	if report.failed > 0 { return error('${report.failed} Build/ entries could not be removed') }
}
