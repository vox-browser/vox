module adblock

import os

$if !macos {
	pub fn current_executable_path() !string { return os.executable() }
	pub fn configure_default_self_worker() ! { return error('The default adblock worker backend is available only on macOS') }
	pub fn configure_default_worker(helper string) ! {
		if helper != '' { return error('The default adblock worker backend is available only on macOS') }
	}
	pub fn configure_default_worker_with_deadline(helper string, timeout_ms int) ! {
		if timeout_ms < 0 { return error('Invalid worker deadline') }
		configure_default_worker(helper)!
	}
	pub fn default_worker_pid() int { return 0 }
	pub fn default_worker_memory_bytes() !u64 { return 0 }
	pub fn run_default_worker_role(arguments []string) ?int { return none }
}
