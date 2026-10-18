module main
import adblock
import os
fn main() {
	if status := adblock.run_default_worker_role(os.args) { exit(status) }
	eprintln('This private helper requires the adblock worker role')
	exit(64)
}
