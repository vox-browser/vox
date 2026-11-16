// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs

fn exception_message_with_stack(err IError) string {
	message := exception_message(err)
	if libjs.is_throw_completion(err) {
		value := libjs.thrown_value(err)
		if value.is_object() {
			if data := value.as_object().error_data {
				trace := data.stack_string(false).trim_right('\n')
				if trace != '' { return message + '\n' + trace }
			}
		}
	}
	return message
}
