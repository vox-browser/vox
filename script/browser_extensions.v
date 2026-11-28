module main

import browserextensions
import browserjs
import css
import platform

fn (mut app BrowserApp) prepare_browser_extension_injections(loaded LoadedPage) []browserextensions.Injection {
	if app.document.is_xml_document() || loaded.status == 'Navigation error' || loaded.javascript_url_source != none {
		return []browserextensions.Injection{}
	}
	mut scratch := platform.begin_thread_scratch('browser extensions')
	defer { scratch.finish() }
	injections := browserextensions.injections(browserextensions.profile_path(), loaded.url) or {
		scratch.leave()
		app.js_messages << 'Extensions: ${err.msg()}'
		return []browserextensions.Injection{}
	}
	if injections.css.len == 0 && injections.js.len == 0 {
		return []browserextensions.Injection{}
	}
	scratch.leave()
	mut storage := app.document.enter_native_storage()
	defer { storage.finish() }
	for sheet in injections.css {
		css.add_document_author_style_sheet_at(app.document, sheet.text.clone(), sheet.url.clone())
	}
	if !app.document.as_node().is_scripting_enabled() {
		return []browserextensions.Injection{}
	}
	return injections.js.map(browserextensions.Injection{
		url:    it.url.clone()
		text:   it.text.clone()
		run_at: it.run_at
	})
}

fn (mut host BrowserParserScriptHost) run_browser_extensions(stage browserextensions.RunAt) {
	if host.closed || host.parser_generation != 1 || !host.document.is_fully_active()
		|| !host.extension_scripts.any(it.run_at == stage) || !compact_document_can_run_script(host.document)
		|| !host.initialize() {
		return
	}
	for script in host.extension_scripts {
		if host.closed || host.parser_generation != 1 || !host.document.is_fully_active() {
			break
		}
		if script.run_at != stage {
			continue
		}
		if host.engine != .libjs {
			host.runtime.evaluate_host('__ladybirdRefreshNamedElements()') or {
				host.messages << 'Extension ${script.url}: ${err.msg()}'
				continue
			}
		}
		for message in host.runtime.run_document_scripts_collect_errors([
			browserjs.ScriptSource{ code: script.text, url: script.url },
		]) {
			host.messages << 'Extension ${script.url}: ${message}'
		}
		if host.engine != .libjs {
			flush_compact_dom_mutations(host.document, host.runtime) or {
				host.messages << 'Extension ${script.url}: ${err.msg()}'
			}
		}
		mut runtime := host.runtime
		runtime.mark_document_state_dirty()
		host.scripts.discover()
	}
}
