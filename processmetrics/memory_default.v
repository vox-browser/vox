module processmetrics

$if !darwin && !linux {
	pub fn memory_snapshot() MemorySnapshot {
		return MemorySnapshot{}
	}
}
