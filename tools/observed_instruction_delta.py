"""Conservative deltas between two retained process-counter snapshots.

The caller owns endpoint selection and clock calibration. This helper neither
reads processes nor establishes that two browsers rendered equivalent content.
"""


def observed_instruction_delta(baseline, endpoint, history=()):
    if baseline.sampled_at >= endpoint.sampled_at:
        raise ValueError("The endpoint must follow the baseline")
    if baseline.root_identity is None or baseline.root_identity != endpoint.root_identity:
        raise ValueError("Snapshots must belong to the same observed root process")

    starts = {key: value for key, value in baseline.readings.items()
              if key not in baseline.missing_final}
    for snapshot in sorted(history, key=lambda item: item.sampled_at):
        if not baseline.sampled_at <= snapshot.sampled_at <= endpoint.sampled_at:
            continue
        if snapshot.root_identity != baseline.root_identity:
            raise ValueError("History must belong to the same observed root process")
        for key, reading in snapshot.readings.items():
            if key not in snapshot.missing_final:
                # A newly observed task starts at its first actual reading,
                # never an invented lifetime zero or a retained failed read.
                starts.setdefault(key, reading)

    rows, omitted = [], []
    for key, reading in sorted(endpoint.readings.items()):
        reason = ("endpoint read unavailable" if key in endpoint.missing_final else
                  "no fresh baseline reading" if key not in starts else None)
        if reason:
            omitted.append(dict(pid=reading.pid, start_ticks=reading.start, reason=reason))
            continue
        first = starts[key]
        instructions = reading.instructions - first.instructions
        cycles = reading.cycles - first.cycles
        if instructions < 0 or cycles < 0:
            raise RuntimeError(f"Hardware counters decreased for PID {reading.pid}")
        rows.append(dict(pid=reading.pid, start_ticks=reading.start,
                         executable=endpoint.paths.get(key, f"pid:{reading.pid}"),
                         baseline_instructions=first.instructions,
                         end_instructions=reading.instructions,
                         instructions=instructions, cycles=cycles,
                         final_exit_sample=reading.exited))
    return dict(instructions=sum(row["instructions"] for row in rows),
                aggregate_is_lower_bound=True, processes=rows, omitted_processes=omitted,
                baseline_sample_completed=baseline.sampled_at,
                endpoint_sample_completed=endpoint.sampled_at,
                scope="Observed task deltas only; unavailable reads and unsampled tasks "
                      "are omitted. New tasks start at their first fresh observation.")
