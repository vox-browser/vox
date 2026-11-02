module main

import adblock

// dyld image zero can be an injected library. Script workers must execute the
// actual browser image, as do browser tabs and the isolated filter worker.
fn browser_script_worker_executable() !string {
	return adblock.current_executable_path()
}
