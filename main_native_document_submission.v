module main

import processmetrics
import time

fn C.vox_browser_stage_document_submission(fn (voidptr, i64, u64, u64), voidptr, i64, u64) u64

// Called synchronously by Cocoa after the image reaches layer.contents and its
// transaction is submitted. This does not claim physical display presentation.
fn native_document_layer_submitted(target voidptr, generation i64, installation u64, frame u64) {
	end := processmetrics.begin_instructions()
	mut app := unsafe { &BrowserApp(target) }
	report := app.paint_timing.submission.accept(DocumentSubmissionClaim{int(generation), installation},
		app.navigation_generation, frame)
	// Keep the wall-clock endpoint beside the instruction endpoint. The draw
	// callback can finish before Cocoa has submitted the document's image.
	if debug_timing_enabled() && (report.installation || report.navigation) {
		now := time.sys_mono_now()
		if report.installation && app.paint_timing.document_install_start_ns > 0 {
			eprintln('Ladybird V timing: document_install_to_first_native_layer_submission ${(now - app.paint_timing.document_install_start_ns) / 1_000_000} ms')
		}
		if report.navigation && app.paint_timing.navigation_start_ns > 0 {
			eprintln('Ladybird V timing: navigation_to_first_native_layer_submission ${(now - app.paint_timing.navigation_start_ns) / 1_000_000} ms')
		}
		C.fflush(C.stderr)
	}
	if report.installation {
		processmetrics.report_instructions('document_install_to_first_native_layer_submission',
			app.paint_timing.submission.installation_instructions, end)
	}
	if report.navigation {
		processmetrics.report_instructions('navigation_to_first_native_layer_submission',
			app.paint_timing.submission.navigation_instructions, end)
	}
}

fn (mut app BrowserApp) stage_native_document_submission(claim DocumentSubmissionClaim) {
	$if macos {
		if !app.ctx.native_rendering || !app.paint_timing.submission.matches(claim, app.navigation_generation) {
			return
		}
		frame := C.vox_browser_stage_document_submission(native_document_layer_submitted, app,
			i64(claim.navigation), claim.installation)
		app.paint_timing.submission.stage(claim, app.navigation_generation, frame)
	}
}
