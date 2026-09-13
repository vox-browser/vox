// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module page

fn window_request_completion_text(completion_ids []u64) string {
	if completion_ids.len == 0 {
		return ''
	}
	return completion_ids[0].str()
}

fn window_request_completion_suffix(completion_ids []u64) string {
	text := window_request_completion_text(completion_ids)
	return if text == '' { '' } else { ':${text}' }
}
