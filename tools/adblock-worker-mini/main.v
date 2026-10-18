module main
import adblock
import os
fn main() {
	if status := adblock.run_default_worker_role(os.args) { exit(status) }
	if os.args.len == 2 && os.args[1] == '--test-self-worker' {
		path := adblock.current_executable_path() or { eprintln(err); exit(70) }
		println('self_path=' + path)
		adblock.configure_default_self_worker() or { eprintln(err); exit(71) }
		result := adblock.evaluate_engine('42') or { eprintln(err); exit(72) }
		assert result == '42'
		assert adblock.default_worker_pid() > 0
		assert adblock.default_worker_memory_bytes() or { u64(0) } > 0
		assert adblock.check(adblock.Request{url:'https://securepubads.g.doubleclick.net/tag/js/gpt.js',source_url:'https://www.theverge.com/',request_type:'script'}).blocked
		filters := adblock.document_filters('https://www.theverge.com/', ['.ad-banner']) or { eprintln(err); exit(73) }
		assert filters.scriptlets.contains('const scriptletGlobals =')
		assert adblock.release_unused_engine()
		assert adblock.default_worker_pid() == 0
		println('PASS self-worker full engine and idle release')
		return
	}
	eprintln('This private helper requires the adblock worker role')
	exit(64)
}
