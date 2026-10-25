module main

import processmetrics

fn C.vox_browser_stage_document_submission(fn (voidptr, i64, u64, u64), voidptr, i64, u64) u64

// Called synchronously by Cocoa after the image reaches layer.contents and its
// transaction is submitted. This does not claim physical display presentation.
fn native_document_layer_submitted(target voidptr, generation i64, installation u64, frame u64) {
	end := processmetrics.begin_instructions()
	mut app := unsafe { &BrowserApp(target) }
	report := app.paint_timing.submission.accept(DocumentSubmissionClaim{int(generation), installation},
		app.navigation_generation, frame)
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
