#!/usr/bin/env python3
"""Export a completed cohort to a compact ledger with repository-relative paths.

Reads receipts only; never launches a browser, reparses raw profiles, changes
observers or replaces an output. The unchanged measurement driver remains the
authority for strict counter parsing. Counts are cross-checked against each
capture report, and both acceptance inequalities are independently recomputed.
"""

import argparse
import hashlib
import json
from pathlib import Path
import statistics


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cohort', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--evidence-archive', type=Path)
    parser.add_argument('--evidence-manifest', type=Path)
    parser.add_argument('--independent-audit', type=Path)
    parser.add_argument('--validation-summary', type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    evidence_root = Path(__file__).resolve().parent
    cohort = args.cohort.resolve()
    summary_path = cohort / 'summary.json'
    summary = read(summary_path)
    require(summary.get('status') == 'completed' and summary.get('valid') is True,
            'Cohort is not complete and valid; no final ledger generated')
    require(summary.get('counter_backend') == 'cachegrind'
            and summary.get('instruction_metric') == 'cachegrind_guest_instruction_references'
            and summary.get('hardware_retired') is False, 'Unexpected counter metric')
    count = summary['pairs_requested']
    require(type(count) is int and count > 0, 'Invalid pair count')
    require(len(summary['pairs']) == count and len(summary['observations']) == 2 * count,
            'Incomplete observations')
    require(not args.output.exists(), 'Output exists; earlier evidence must be preserved')

    def portable(value):
        if isinstance(value, dict):
            return {portable(k): portable(v) for k, v in value.items()}
        if isinstance(value, list):
            return [portable(v) for v in value]
        prefix = str(repo) + '/'
        return value[len(prefix):] if isinstance(value, str) and value.startswith(prefix) else value

    rows, attempts, receipts = {}, [], {}
    for row in summary['observations']:
        key = (row['pair'], row['variant'])
        require(key not in rows and 1 <= key[0] <= count and key[1] in ('baseline', 'candidate'),
                'Duplicate or invalid pair/variant')
        require(row['status'] == 'valid' and row['driver_exit'] == 0
                and all(row.get(k) is True for k in ('pixel_exact', 'content_exact', 'geometry_exact')),
                'Observation failed correctness or completion checks')
        report_path = Path(row['report'])
        report = read(report_path)
        instructions = report['instructions']
        require(type(instructions) is int and instructions > 0 and instructions == row['instructions'],
                'Raw instruction count differs from summary')
        require(report.get('counter_backend') == 'cachegrind'
                and report.get('instruction_metric') == summary['instruction_metric']
                and report.get('hardware_retired') is False
                and report.get('exit') == 0 and report.get('root_final_exit_sample') is True,
                'Report has an incompatible metric or incomplete process exit')
        require(report['binary_sha256'] == summary['binaries'][row['variant']]['sha256'],
                'Binary identity mismatch')
        pixels = report['screenshot_validation']
        require(pixels.get('exact') is True
                and pixels['decoded_rgba_sha256'] == summary['reference_decoded_rgba_sha256'],
                'Reference pixels mismatch')
        rows[key] = instructions
        attempts.append({k: row[k] for k in
                         ('pair', 'variant', 'instructions', 'status', 'driver_exit', 'report',
                          'pixel_exact', 'content_exact', 'geometry_exact',
                          'native_renderer_diagnostic_count', 'raw_native_audit_sha256')})
        attempts[-1]['raw_profile'] = report['cachegrind_output']
        attempts[-1]['screenshot'] = report['screenshot']
        receipts[str(report_path)] = sha(report_path)
    before = [rows[(i, 'baseline')] for i in range(1, count + 1)]
    after = [rows[(i, 'candidate')] for i in range(1, count + 1)]
    require(before == summary['baseline_counts'] and after == summary['candidate_counts'],
            'Final arrays differ from observation reports')
    supplement = read(evidence_root / 'supplementary-control.json')
    retained = supplement['instructions']
    require(retained == 6842705460 and supplement['candidate_observations'] == 0
            and summary['supplementary_control']['instructions'] == retained
            and summary['supplementary_control']['strict_reparse_passed'] is True,
            'Mandatory retained control changed or was not strictly reparsed')
    left, normal_right = 10 * max(after), 9 * min(before)
    supplementary_right = 9 * min(before + [retained])
    normal_pass, supplementary_pass = left <= normal_right, left <= supplementary_right
    require(summary['normal_cohort_target_met'] is normal_pass
            and summary['supplementary_conservative_gate']['target_met'] is supplementary_pass
            and summary['target_met'] is (normal_pass and supplementary_pass),
            'Recomputed gate disagrees with observer')
    guard_path = cohort.with_suffix('.guard.json')
    guard = read(guard_path)
    require(guard['reason'] == 'completed'
            and guard['child_exit_code'] == (0 if summary['target_met'] else 1),
            'Outer guard did not complete with the expected observer exit')
    baseline_median, candidate_median = statistics.median(before), statistics.median(after)
    derived = {
        'baseline_counts': before, 'candidate_counts': after,
        'baseline_median': baseline_median, 'candidate_median': candidate_median,
        'paired_instruction_savings': [a - b for a, b in zip(before, after)],
        'median_reduction_percent': 100 * (baseline_median - candidate_median) / baseline_median,
        'normal_conservative_reduction_percent': 100 * (1 - max(after) / min(before)),
        'supplementary_conservative_reduction_percent': 100 * (1 - max(after) / min(before + [retained])),
        'normal_gate': {'left_integer': left, 'right_integer': normal_right, 'passed': normal_pass},
        'supplementary_gate': {'retained_control': retained, 'left_integer': left,
                               'right_integer': supplementary_right, 'passed': supplementary_pass},
        'target_met': normal_pass and supplementary_pass,
    }
    for path in (summary_path, guard_path, Path(__file__).resolve(),
                 evidence_root / 'environment.json', evidence_root / 'relink-variants.json',
                 evidence_root / 'supplementary-control.json',
                 evidence_root / 'observer-correction-01/provenance.json',
                 evidence_root / 'observer-correction-02/provenance.json'):
        receipts[str(path)] = sha(path)
    supporting_receipts = {
        'baseline_build': 'baseline-build-summary.json',
        'matched_links': 'relink-variants.json',
        'implementation_files': 'implementation-files.json',
        'diagnostic_profile_attribution': 'shadow-typeface-proposal/findings.json',
        'original_object_native_test': 'shadow-typeface-proposal/native-test-results.json',
        'durable_adapter_native_test': 'shadow-native-adapter-02/result.json',
        'durable_adapter_native_test_inputs': 'shadow-native-adapter-02/inputs.json',
        'observer_correction_1': 'observer-correction-01/provenance.json',
        'observer_correction_1_validation': 'observer-correction-01/validation.json',
        'observer_correction_2': 'observer-correction-02/provenance.json',
        'observer_correction_2_validation': 'observer-correction-02/validation.json',
        'native_diagnostic_contract': 'expected-native-diagnostics.json',
    }
    supporting = {}
    for name, relative in supporting_receipts.items():
        path = evidence_root / relative
        supporting[name] = read(path)
        receipts[str(path)] = sha(path)
    archives = {}
    for name, path in (('archive', args.evidence_archive), ('manifest', args.evidence_manifest)):
        if path:
            path = path.resolve()
            archives[name] = {'path': str(path), 'sha256': sha(path), 'bytes': path.stat().st_size}
    if args.evidence_archive and args.evidence_manifest:
        archive_manifest = read(args.evidence_manifest)
        require(archive_manifest['archive']['sha256'] == archives['archive']['sha256']
                and archive_manifest['archive']['bytes'] == archives['archive']['bytes']
                and archive_manifest['frozen_final_summary']['sha256'] == sha(summary_path),
                'Evidence archive or final summary differs from its manifest')
    independent_audit = None
    if args.independent_audit:
        independent_audit = read(args.independent_audit)
        require(independent_audit['status'] == 'passed'
                and independent_audit['summary']['sha256'] == sha(summary_path)
                and independent_audit['target_met'] is summary['target_met']
                and independent_audit['pin_verification']['verified'] is True
                and independent_audit['frozen_inputs_modified'] is False,
                'Independent audit failed or refers to different evidence')
        receipts[str(args.independent_audit.resolve())] = sha(args.independent_audit)
    validation = {'status': 'pending'}
    if args.validation_summary:
        validation = read(args.validation_summary)
        require(validation.get('passed') is True, 'Selected V regression summary failed')
        for group in validation['groups']:
            for attempt in group['attempts']:
                require(attempt.get('passed') is True and attempt['compile_exit'] == 0
                        and attempt['runtime_exit'] == 0 and not attempt['changed_inputs'],
                        'A selected V regression attempt failed or changed inputs')
                for phase in ('compile_guard', 'runtime_guard'):
                    validation_guard_path = repo / attempt[phase]['path']
                    require(sha(validation_guard_path) == attempt[phase]['sha256'], 'V guard receipt changed')
                    test_guard = read(validation_guard_path)
                    require(test_guard['reason'] == 'completed' and test_guard['child_exit_code'] == 0,
                            'Selected V guard did not complete successfully')
        receipts[str(args.validation_summary.resolve())] = sha(args.validation_summary)
    result = {
        'schema_version': 1, 'path_basis': 'Paths inside the checkout are relative to repository root; external tool/font paths retain their recorded identity',
        'scope': {k: summary[k] for k in
                  ('counter_backend', 'instruction_metric', 'hardware_retired', 'endpoint',
                   'scope_note', 'cache_note', 'reference_policy', 'diagnostic_policy')},
        'source_environment': read(evidence_root / 'environment.json'),
        'binaries': summary['binaries'],
        'fonts_and_configuration': summary['fonts'],
        'observer_inputs_sha256': summary['observer_inputs_sha256'],
        'runtime_assets_sha256': summary['runtime_assets_sha256'],
        'valgrind': summary['valgrind'],
        'controlled_environment': summary['controlled_environment'],
        'network_policy': summary['network_policy'],
        'fixture': {k: summary['fixture'][k] for k in
                    ('workload', 'viewport', 'file_sha256', 'file_manifest_sha256')},
        'reference_capture': summary['reference_capture'], 'observations_in_execution_order': attempts,
        'derived': derived, 'outer_guard': guard,
        'retained_invalid_attempt': supplement,
        'supporting_receipts': supporting,
        'independent_acceptance_audit': independent_audit,
        'durable_raw_evidence': archives,
        'selected_v_regression_validation': validation,
        'regression_scope': 'Selected native Skia, portable-shadow layout and platform-font checks; this is not a claim that every repository test ran.',
        'evidence_sha256': receipts,
        'qualification': 'This exports receipt data; it does not replace raw profiles, screenshots, complete audits or the strict measurement parser. Broad regression results must be recorded separately.',
    }
    with args.output.open('x') as stream:
        json.dump(portable(result), stream, indent=2)
        stream.write('\n')
    print(json.dumps({'ledger': str(args.output), **derived}, indent=2))


if __name__ == '__main__':
    main()
