module html

import dom
import webidl

fn test_extract_error_information_reads_native_dom_exception_name_and_message() {
	names := ['NotFoundError', 'AbortError', '', '', 'OperationError']
	messages := ['Missing node', '', 'Message only', '', 'Ошибка \u0000 😀']
	expected := ['NotFoundError: Missing node', 'AbortError', 'Message only', '',
		'OperationError: Ошибка \u0000 😀']
	for index, name in names {
		native := webidl.DOMException.create_record(name, messages[index])
		exception := dom.js_webidl_value(webidl.dom_exception_value_for_record(native))
		information := extract_error_information(exception, ErrorExtractionContext{
			// The actual DOMException fields take precedence over a generic
			// own-property fallback supplied by the embedding runtime.
			own_message:     'wrong own-property fallback'
			execution_stack: [ErrorSourceLocation{ filename: 'dom-exception.js', line: 9, column: 4 }]
		})
		assert information.message == expected[index]
		assert information.filename == 'dom-exception.js'
		assert information.lineno == 9 && information.colno == 4
		assert voidptr(information.error.native_value_?.dom_exception_?) == voidptr(native)
	}
}

fn test_extract_error_information_uses_own_message_and_error_traceback() {
	exception := dom.js_object(unsafe { nil })
	information := extract_error_information(exception, ErrorExtractionContext{
		own_message:        'broken'
		exception_is_error: true
		traceback:          [
			ErrorSourceLocation{
				filename: 'ignored.js'
			},
			ErrorSourceLocation{
				filename: 'app.js'
				line:     12
				column:   7
			},
		]
	})
	assert information.message == 'broken'
	assert information.filename == 'app.js'
	assert information.lineno == 12
	assert information.colno == 7
	assert information.error.kind == .object
}

fn test_extract_error_information_uses_newest_execution_context() {
	information := extract_error_information(dom.js_string('failure'), ErrorExtractionContext{
		execution_stack: [
			ErrorSourceLocation{
				filename: 'old.js'
				line:     1
				column:   2
			},
			ErrorSourceLocation{
				filename: 'new.js'
				line:     8
				column:   9
			},
		]
	})
	assert information.message == 'Uncaught exception: failure'
	assert information.filename == 'new.js'
	assert information.lineno == 8
	assert information.colno == 9
}
