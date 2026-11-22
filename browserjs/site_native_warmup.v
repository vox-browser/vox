module browserjs

import browsersettings
import libjs
import os
import platform
import sync.stdatomic

const site_warmup_limit = 4 * 1024 * 1024

__global (
	site_warmup_worker = chan bool{cap: 1}
)

@[heap]
pub struct SiteNativeWarmup {
	root string
	identity string
mut:
	sources []libjs.NativeWarmupSource
	bytes int
	sealed bool
	compilation ?&SiteNativeCompilation
}

@[heap]
struct SiteNativeCompilation {
	storage &platform.RetainedArena
mut:
	// Published by the worker. A negative value means it has finished.
	percent i64
}

fn (mut warmup SiteNativeWarmup) compilation_progress() ?int {
	job := warmup.compilation or { return none }
	percent := stdatomic.load_i64(&job.percent)
	if percent >= 0 { return int(percent) }
	warmup.release_compilation()
	return none
}

fn (mut warmup SiteNativeWarmup) release_compilation() {
	job := warmup.compilation or { return }
	warmup.compilation = none
	mut storage := job.storage
	storage.release()
}


fn site_warmup_options() libjs.NativeCodeCacheOptions {
	return libjs.NativeCodeCacheOptions{
		generated_code_identity: os.getenv('VOX_LIBJS_NATIVE_GENERATED_CODE_CACHE') == '1'
	}
}

fn native_cache_root() string {
	choice := os.getenv('VOX_LIBJS_NATIVE_CACHE')
	if choice in ['0', 'off'] { return '' }
	if choice != '' && choice != '1' { return choice }
	return os.join_path(os.dir(browsersettings.default_path()), 'libjs-native-code')
}

// The profile preference selects an engine at navigation time. An unfinished
// or unavailable cache keeps the visit on JSC.
pub fn plan_site_native_warmup(address string) (Engine, ?&SiteNativeWarmup) {
	if !address.starts_with('https://') && !address.starts_with('http://') {
		return .libjs, none
	}
	root := native_cache_root()
	if root == '' { return .javascriptcore, none }
	identity := address.all_before('#')
	if os.is_dir(root) && libjs.native_site_cache_ready(root, identity, site_warmup_options()) {
		return .libjs, none
	}
	warmup := ?&SiteNativeWarmup(&SiteNativeWarmup{root: root.clone(), identity: identity.clone()})
	return .javascriptcore, warmup
}

pub fn (mut runtime Runtime) set_site_native_warmup(warmup ?&SiteNativeWarmup) {
	runtime.site_native_warmup_ = warmup
}

fn (runtime &Runtime) collect_site_root_script(source ScriptSource) {
	mut filename := source.url
	if source.source_type == .module {
		if element := source.element {
			// External modules are recorded when JSC receives their response.
			if element.has_attribute('src') { return }
			filename = element.document().base_url().serialize().all_before('#')
		} else {
			return
		}
	}
	runtime.collect_site_native_source(libjs.NativeWarmupSource{
		code: source.code
		filename: filename
		kind: source.source_type
		line: u32(source.starting_line)
	})
}

fn (runtime &Runtime) collect_site_native_source(source libjs.NativeWarmupSource) {
	mut warmup := runtime.site_native_warmup_ or { return }
	if warmup.sealed || source.code == '' { return }
	for previous in warmup.sources {
		if previous.filename == source.filename && previous.kind == source.kind
			&& previous.line == source.line && previous.code == source.code { return }
	}
	if warmup.sources.len == 128 || source.code.len > site_warmup_limit - warmup.bytes {
		warmup.sealed = true
		warmup.sources = []
		return
	}
	settings := runtime.scripting_settings_ or { return }
	document := settings.responsible_document() or { return }
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	warmup.bytes += source.code.len
	warmup.sources << libjs.NativeWarmupSource{...source, code: source.code.clone(), filename: source.filename.clone()}
}

pub fn (mut warmup SiteNativeWarmup) start_after_load(wake fn ()) {
	if warmup.sealed || warmup.sources.len == 0 { return }
	warmup.sealed = true
	defer { warmup.sources = [] }
	select {
		site_warmup_worker <- true {}
		else { return }
	}
	mut storage := platform.new_retained_arena('LibJS site source snapshot')
	mut scope := storage.enter_nested()
	job := &SiteNativeCompilation{ storage: storage }
	sources := warmup.sources.map(libjs.NativeWarmupSource{
		...it
		code: it.code.clone()
		filename: it.filename.clone()
	})
	root := os.real_path(warmup.root)
	identity := warmup.identity.clone()
	compiler := (os.getenv_opt('VOX_LIBJS_NATIVE_COMPILER') or { 'clang' }).clone()
	options := site_warmup_options()
	scope.finish()
	invoker := platform.capture_native_deferred_invoker_for_storage(storage) or {
		storage.release()
		_ := <-site_warmup_worker
		return
	}
	// The document owns the initial lease. The deferred invoker keeps the
	// source snapshot and progress alive until the worker finishes.
	warmup.compilation = job
	wake()
	spawn run_site_native_warmup(root, identity, compiler, options, sources, invoker, job, wake)
}

fn run_site_native_warmup(root string, identity string, compiler string,
	options libjs.NativeCodeCacheOptions, sources []libjs.NativeWarmupSource,
	invoker platform.NativeDeferredInvoker, job &SiteNativeCompilation, wake fn ()) {
	libjs.compile_native_site_cache(root, identity, compiler, options, sources,
		on_progress: fn [job, wake] (completed int, total int) {
			stdatomic.store_i64(&job.percent, i64(completed * 100 / total))
			wake()
		}
	) or {}
	stdatomic.store_i64(&job.percent, -1)
	wake()
	_ := <-site_warmup_worker
	invoker.deferred_invoke(fn () {})
}
