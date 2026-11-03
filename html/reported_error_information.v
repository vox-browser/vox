module html

// Retain the report-time, possibly muted ErrorEvent fields separately from
// the thrown value. Observers can read these without another JS conversion.
pub struct ReportedErrorInformation {
pub:
	message string
	filename string
	lineno u32
	colno u32
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) reported_error_count() int {
	return scope.reported_errors_.len
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) reported_error_information() []ReportedErrorInformation {
	return scope.reported_error_information_.clone()
}
