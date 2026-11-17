// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import libjs

// Document entries share one budget across their module graph and nested
// callbacks. GitHub's repository React commits can exceed 10 million
// instructions during hydration and same-document navigation.
const libjs_document_instruction_limit = u64(20_000_000)

fn (runtime &Runtime) libjs_execution_limits() libjs.ExecutionLimits {
	return libjs.ExecutionLimits{max_instructions: if runtime.libjs_document_host_ != none {
		libjs_document_instruction_limit
	} else { u64(1000000) }}
}
