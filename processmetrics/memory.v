module processmetrics

// The browser hosts the document, JavaScript and renderer in one process.
// Its physical footprint includes their memory and shared browser overhead.
pub struct MemorySnapshot {
pub:
	bytes     u64
	available bool
}

pub fn (snapshot MemorySnapshot) ram_label() string {
	if !snapshot.available {
		return 'RAM: unavailable'
	}
	if snapshot.bytes >= 1_000_000_000 {
		return 'RAM: ${f64(snapshot.bytes) / 1_000_000_000:.1f} GB'
	}
	return 'RAM: ${f64(snapshot.bytes) / 1_000_000:.1f} MB'
}
