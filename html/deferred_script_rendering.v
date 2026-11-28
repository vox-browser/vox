module html

import dom
import os
import time

// Same-binary control: take rendering opportunities while the parser runs its
// deferred scripts.
const render_during_deferred_scripts = os.getenv('VOX_RENDER_DURING_DEFERRED_SCRIPTS') != ''
// Rendering resumes after this long even while the deferred scripts progress.
const deferred_script_rendering_limit_ns = u64(1_000_000_000)

// The end of parsing runs the deferred scripts in order as each becomes ready.
// Chromium has fetched and linked their module graphs by then and runs them
// back to back, so no rendering update (and no animation frame callback)
// falls between them. Vox evaluates a module graph through promises and took
// rendering opportunities between its deferred scripts: on the archived
// github.com/vlang/v page an animation frame let the lazy custom element
// loader start the page's React partials before the last deferred script
// started the code view, whose hydration then failed (React #418) and was
// rendered again on the client in about half of the loads.
//
// Skip a document's rendering update while its deferred scripts can make
// progress: a module graph evaluation is in flight or the next script is
// ready to run. A script still being fetched leaves rendering on, as an idle
// main thread would.
pub fn document_runs_deferred_scripts(document &dom.Document) bool {
	if render_during_deferred_scripts || !document.has_html_parser_end_state() { return false }
	state := unsafe { &HTMLParserEndState(document.html_parser_end_state()) }
	if state.phase_ != .waiting_for_deferred_scripts
		|| time.sys_mono_now() - state.started_ns > deferred_script_rendering_limit_ns {
		return false
	}
	if document.pending_module_readiness_scripts > 0 { return true }
	script := document.first_script_to_execute_when_parsing_has_finished() or { return false }
	return html_script_element_is_ready_to_be_parser_executed(script)
		&& !document.has_a_style_sheet_that_is_blocking_scripts()
}
