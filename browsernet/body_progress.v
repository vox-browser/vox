module browsernet

@[heap]
struct ResponseBodyProgress {
mut:
	previous          u64
	incomplete_prefix u64
	prefix            []u8
}

fn (mut progress ResponseBodyProgress) observe(chunk []u8, received u64, expected u64, status int) {
	if status < 200 || status >= 300 { return }
	if progress.prefix.len < 32 {
		count := if chunk.len < 32 - progress.prefix.len {
			chunk.len
		} else {
			32 - progress.prefix.len
		}
		progress.prefix << chunk[..count]
	}
	if expected > 0 && received < expected {
		progress.incomplete_prefix = received
	} else if expected == 0 && progress.previous > progress.incomplete_prefix {
		// With unknown length, the next body delivery proves the preceding
		// prefix was incomplete. A single buffered delivery stays complete.
		progress.incomplete_prefix = progress.previous
	}
	progress.previous = received
}
