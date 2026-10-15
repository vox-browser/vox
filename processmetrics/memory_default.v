module processmetrics

$if !darwin {
	pub fn memory_snapshot() MemorySnapshot {
		return MemorySnapshot{}
	}
}
