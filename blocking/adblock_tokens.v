module main

import dom
import os
import platform

const disable_adblock_token_reuse = os.getenv('VOX_DISABLE_ADBLOCK_TOKEN_REUSE') == '1'
const adblock_token_diagnostics = os.getenv('VOX_ADBLOCK_TOKEN_DIAGNOSTICS') == '1'

__global adblock_token_reuse_reported bool

// Browser policy owns this survey. Keep scalar document identity and token
// strings, so a closed document is never retained by the cache. Callers borrow
// the tokens only until the next survey/release; the filter bridge serializes
// them synchronously and retains its independent request text.
struct BrowserAdblockTokenCache {
mut:
	document voidptr
	tree_version u64
	attribute_version u64
	global_attribute_version u64
	global_tree_version u64
	id_class_attributes_only bool
	valid bool
	tokens []string
	storage &platform.Arena = unsafe { nil }
}

fn (mut cache BrowserAdblockTokenCache) survey(document &dom.Document) []string {
	stamp := site_cosmetic_token_attribute_stamp(document)
	tree_version := stamp.tree_version
	attribute_version := stamp.version
	if !disable_adblock_token_reuse && cache.valid && cache.document == voidptr(document)
		&& cache.tree_version == tree_version && cache.attribute_version == attribute_version
		&& cache.id_class_attributes_only == stamp.id_class_only {
		report_site_cosmetic_token_reuse(stamp.id_class_only,
			cache.global_attribute_version != document.attribute_version()
				|| cache.global_tree_version != document.dom_tree_version())
		if adblock_token_diagnostics && !adblock_token_reuse_reported {
			adblock_token_reuse_reported = true
			eprintln('Vox adblock tokens: reused unchanged light-DOM survey')
		}
		return cache.tokens
	}
	// A separate reusable arena bounds this browser-owned payload even while
	// surveys run inside disposable frame/document storage. The maps and split
	// tokens still use browser_adblock_tokens' temporary survey workspace.
	$if prealloc {
		if cache.storage == unsafe { nil } {
			persistent := platform.enter_persistent()
			cache.storage = platform.new_arena('adblock token cache')
			platform.leave_persistent(persistent)
		}
		cache.tokens = []string{}
		cache.storage.reset()
		entry := cache.storage.enter()
		cache.tokens = browser_adblock_tokens(document)
		cache.storage.leave(entry)
	} $else {
		cache.tokens = browser_adblock_tokens(document)
	}
	cache.document = voidptr(document)
	cache.tree_version = tree_version
	cache.attribute_version = attribute_version
	cache.global_attribute_version = document.attribute_version()
	cache.global_tree_version = document.dom_tree_version()
	cache.id_class_attributes_only = stamp.id_class_only
	cache.valid = true
	return cache.tokens
}

fn (mut cache BrowserAdblockTokenCache) release() {
	cache.tokens = []string{}
	cache.document = unsafe { nil }
	cache.valid = false
	if cache.storage != unsafe { nil } {
		cache.storage.release()
		cache.storage = unsafe { nil }
	}
}

fn (mut app BrowserApp) refresh_browser_adblock() {
	refresh_browser_adblock_with_tokens(app.document, app.js_runtime, mut app.js_messages,
		mut app.adblock_tokens)
}
