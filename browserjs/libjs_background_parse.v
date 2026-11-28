@[has_globals]
module browserjs

import libjs
import os
import platform
import sync

// Module scripts are parsed on a few worker threads, as V8 compiles streamed
// scripts off the main thread. The fetch completion queues the decoded source
// and returns to the event loop; the worker's result is delivered back to the
// origin run loop, which resumes the ordinary module fetch with that syntax.
// Workers keep their allocations for the process, like resource workers, so
// the syntax records outlive the job. VOX_LIBJS_BACKGROUND_PARSE=0 parses on
// the main thread as before.
const libjs_parse_worker_count = 4
const libjs_background_parse_disabled = os.getenv('VOX_LIBJS_BACKGROUND_PARSE') == '0'

struct LibJSParseJob {
	source  string
	options libjs.ParseOptions
	invoker platform.NativeDeferredInvoker
	done    fn (&libjs.ParsedSource) = unsafe { nil }
}

@[heap]
struct LibJSParsePool {
mut:
	mutex   sync.Mutex
	jobs    chan LibJSParseJob
	started bool
}

__global libjs_parse_pool_ = &LibJSParsePool{}

fn libjs_background_parse_available() bool {
	$if macos || linux || windows {
		return !libjs_background_parse_disabled
	} $else {
		return false
	}
}

// Queue `source` (owned by the caller's persistent storage) for parsing as a
// module. `done` runs later on the calling thread's run loop. Returns false
// when no worker is available; the caller then parses synchronously.
fn submit_libjs_module_parse(source string, options libjs.ParseOptions, done fn (&libjs.ParsedSource)) bool {
	if !libjs_background_parse_available() { return false }
	invoker := platform.capture_native_deferred_invoker() or { return false }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut pool := libjs_parse_pool_
	pool.mutex.lock()
	if !pool.started {
		pool.jobs = chan LibJSParseJob{cap: 1024}
		for _ in 0 .. libjs_parse_worker_count {
			spawn libjs_parse_worker(pool.jobs)
		}
		pool.started = true
	}
	pool.mutex.unlock()
	pool.jobs <- LibJSParseJob{
		source:  source
		options: options
		invoker: invoker
		done:    done
	}
	return true
}

fn libjs_parse_worker(jobs chan LibJSParseJob) {
	platform.retain_thread_allocations()
	for {
		job := <-jobs or { return }
		parsed := libjs.parse_source_with_options(job.source, .module, job.options)
		done := job.done
		job.invoker.deferred_invoke(fn [done, parsed] () {
			done(parsed)
			platform.release_closure(voidptr(done))
		})
	}
}
