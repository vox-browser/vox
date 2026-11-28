module libjs

import dl
import platform

@[heap]
struct NativeCacheBackgroundBatch {
	storage   &platform.RetainedArena
	keys      []string
	directory string
	abi       string
	build     NativeLibraryBuild
mut:
	finished   bool
	compiled   ?NativeCompiledLibrary
	failure    string
	abandoned  bool
}

// One batch per VM. The worker owns the compiler and disk publication. It
// never reads a VM or its bytecode. Only the origin thread installs entries
// in the VM, and disk publication can finish after its document closes.
pub fn (mut vm VM) start_background_native_cache_batch() ! {
	if !vm.native_code_cache_is_idle() {
		return error('Native disk cache compilation requires an idle VM')
	}
	mut tier := vm.native_tier or { return }
	mut cache := tier.persistent or { return }
	if cache.pending.len == 0 || cache.background_batch != none { return }

	mut storage := platform.new_retained_arena('LibJS native compiler batch')
	mut scope := storage.enter_nested()
	batch := cache.prepare_background_batch(storage) or {
		scope.finish()
		message := err.msg().clone()
		storage.release()
		return error(message)
	}
	scope.finish()
	invoker := platform.capture_native_deferred_invoker_for_storage(storage) or {
		batch.build.discard()
		storage.release()
		return error('Native compiler requires an event loop')
	}
	cache.background_batch = batch
	spawn run_native_cache_background_batch(batch, invoker)
}

fn (cache &NativeCodeCache) prepare_background_batch(storage &platform.RetainedArena) !&NativeCacheBackgroundBatch {
	keys, selected := cache.select_batch()!
	// Keep generated source builders out of the batch's retained storage.
	scratch := platform.begin_thread_scratch('LibJS native compiler source')
	defer { scratch.finish() }
	build := prepare_native_library(selected, cache.directory, cache.compiler) or {
		scratch.leave()
		return error(err.msg().clone())
	}
	scratch.leave()
	return &NativeCacheBackgroundBatch{
		storage: storage
		keys: keys.map(it.clone())
		directory: cache.directory.clone()
		abi: cache.abi.clone()
		build: NativeLibraryBuild{
			compiler: build.compiler.clone()
			job: build.job.clone()
			stats: NativeCodeStats{...build.stats, library: build.stats.library.clone()}
		}
	}
}

fn run_native_cache_background_batch(batch &NativeCacheBackgroundBatch, invoker platform.NativeDeferredInvoker) {
	mut compiled := ?NativeCompiledLibrary(none)
	mut failure := ''
	if library := batch.compile_and_publish() {
		compiled = library
	} else {
		failure = err.msg()
	}
	invoker.deferred_invoke(fn [batch, compiled, failure] () {
		mut completed := unsafe { &NativeCacheBackgroundBatch(batch) }
		if completed.abandoned {
			if library := compiled { dl.close(library.handle) }
			return
		}
		mut storage := completed.storage
		mut scope := storage.enter_nested()
		if library := compiled {
			completed.compiled = NativeCompiledLibrary{
				handle: library.handle
				entries: library.entries.clone()
				stats: NativeCodeStats{...library.stats,
					library: library.stats.library.clone()
					library_sha256: library.stats.library_sha256.clone()
				}
			}
		}
		completed.failure = failure.clone()
		completed.finished = true
		scope.finish()
	})
}

fn (batch &NativeCacheBackgroundBatch) compile_and_publish() !NativeCompiledLibrary {
	compile_ms := batch.build.compile()!
	compiled := batch.build.load(compile_ms)!
	publish_native_cache_batch(batch.directory, batch.abi, batch.keys, compiled.stats) or {
		dl.close(compiled.handle)
		return err
	}
	return compiled
}

// Poll the posted compiler result on the origin thread. True means that the
// VM is ready to start another batch.
pub fn (mut vm VM) poll_background_native_cache_batch() !bool {
	if !vm.native_code_cache_is_idle() {
		return error('Native disk cache installation requires an idle VM')
	}
	mut tier := vm.native_tier or { return true }
	mut cache := tier.persistent or { return true }
	mut batch := cache.background_batch or { return true }
	if !batch.finished { return false }
	defer { cache.release_background_batch() }
	if batch.failure != '' {
		cache.stats.last_error = batch.failure.clone()
		return error(cache.stats.last_error)
	}
	compiled := batch.compiled or { return error('Missing compiled native cache library') }
	batch.compiled = none
	cache.install_batch(mut tier, batch.keys, compiled)!
	return true
}

pub fn (vm &VM) has_background_native_cache_batch() bool {
	if tier := vm.native_tier {
		if cache := tier.persistent { return cache.background_batch != none }
	}
	return false
}

fn (mut cache NativeCodeCache) release_background_batch() {
	mut batch := cache.background_batch or { return }
	cache.background_batch = none
	batch.abandoned = true
	if library := batch.compiled { dl.close(library.handle) }
	mut storage := batch.storage
	storage.release()
}
