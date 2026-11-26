module buildtools

import os
import time

fn test_staged_browser_cleanup_waits_for_the_artifact_lease() ! {
	root := temporary(os.temp_dir(), 'vox-stage-lease-')!
	defer { remove(root) or {} }
	receipt := join(root, 'receipt')
	stage := join(root, 'stage')
	artifact := join(stage, 'browser')
	mkdir(stage)!
	os.write_file(artifact, 'staged browser')!
	mut lease := acquire(join(receipt, 'artifact.lock'), false)!
	started := chan bool{cap: 1}
	completed := chan bool{cap: 1}
	cleanup := spawn fn [stage, receipt, started, completed] () {
		started <- true
		remove_staged_browser(stage, receipt) or {
			completed <- false
			return
		}
		completed <- true
	}()
	_ = <-started
	mut removed_while_leased := false
	select {
		_ := <-completed { removed_while_leased = true }
		250 * time.millisecond {}
	}
	retained_contents := read(artifact) or { '' }
	lease.release()
	cleanup.wait()
	assert !removed_while_leased
	assert retained_contents == 'staged browser'
	assert <-completed
	assert !exists(stage)
}
