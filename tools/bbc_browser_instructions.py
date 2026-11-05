#!/usr/bin/env python3
"""Measure the archived BBC homepage from fresh launch through document PNG.

Run under the adoption-aware memory guard. Both engines use original HTTPS
origins, one non-forwarding replay, original author scripts, empty profiles and
caches, and the same native viewport/scale. Reference capture is a separate
diagnostic; acceptance requires seven alternating pairs and unchanged references.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import threading
import time
from urllib.parse import urlsplit

import hacker_news_browser_instructions as browser
from measure_sealed_github_instructions import FixtureHTML, text_content
from page_archive import Replay, load_archive
from stackoverflow_browser_instructions import local_only_font_sources
from browser_input_evidence import preserve_replay_inputs, verify_preservation_identity

REPO = Path(__file__).resolve().parents[1]
URL = 'https://www.bbc.com/'
SELECTORS = [dict(name='body', selector='body', limit=1, attributes=[]),
             dict(name='headlines', selector='[data-testid="card-headline"]', limit=1000,
                  attributes=['data-testid']),
             dict(name='images', selector='img', limit=1000, attributes=['src', 'srcset', 'alt']),
             dict(name='all', selector='*', limit=0, attributes=[])]
SCOPE = ('Exclusive resource-coalition creation through encoded document PNG availability; '
         'fresh process, empty private profile/cache, sealed HTTPS responses via one local '
         'SOCKS/TLS replay without forwarding, original author JavaScript enabled. '
         'Vox ends before PNG file write; Brave includes CDP PNG delivery and target/window setup. '
         'Readiness polling and two seconds of settlement are included; semantic audits and '
         'teardown follow the endpoint. Exited helpers and explicitly allowed coalition-owned '
         'services are included. GPU execution, observer/replay and outside services are excluded. '
         'The fixture records any shared JavaScript wall-clock override; monotonic timers remain real. '
         'OS filesystem/shader caches are retained. Per-engine references test stability; '
         'cross-browser pixel differences are reported separately.')


def fixture_expectations(archive):
    manifest = load_archive(archive)
    browser.require(manifest['url'] == URL, 'Expected the BBC homepage, not /news')
    entry = manifest['responses'][URL]
    browser.require(entry['status'] == 200, 'BBC document response must be successful')
    parser = FixtureHTML()
    parser.feed((archive / 'bodies' / entry['sha256']).read_text())
    title = next(text_content(node) for node in parser.nodes if node['tag'] == 'title')
    headlines = [text_content(node) for node in parser.nodes
                 if node['attrs'].get('data-testid') == 'card-headline']
    images = [node for node in parser.nodes if node['tag'] == 'img']
    styles = [text_content(node) for node in parser.nodes if node['tag'] == 'style']
    placeholders = sorted({node['attrs'].get('src', '') for node in images
                           if urlsplit(node['attrs'].get('src', '')).path.endswith('/grey-placeholder.png')})
    browser.require(title.startswith('BBC Home') and len(headlines) >= 20 and len(images) >= 10,
                    'BBC source lacks complete homepage content')
    return dict(url=URL, title=title, headlines=headlines, source_image_count=len(images),
                image_sources=sorted(node['attrs'].get('src', '') for node in images
                                     if node['attrs'].get('src', '') not in placeholders),
                placeholder_sources=placeholders,
                local_font_fallback_sources=local_only_font_sources(styles),
                document_sha256=entry['sha256'], document_bytes=entry['bytes'],
                responses=len(manifest['responses']),
                benchmark_clock=manifest.get('benchmark_clock'),
                workload=manifest.get('workload', 'Original archived responses and author scripts'),
                manifest_sha256=browser.sha(archive / 'manifest.json'))


def validate_document(audit, expected):
    browser.require(audit.get('url') == URL and audit.get('title') == expected['title']
                    and audit.get('ready') == 'complete'
                    and [audit.get('viewport_width'), audit.get('viewport_height')] == [1024, 768],
                    'BBC document identity/readiness/viewport failed')
    selections = {row['name']: row for row in audit.get('selections', [])}
    browser.require({'body', 'headlines', 'images', 'all'} <= selections.keys(),
                    'BBC semantic audit is missing a selection')
    headlines = selections['headlines']
    actual = [row['text'] for row in headlines['elements']]
    browser.require(headlines['count'] == len(actual) and actual == expected['headlines'],
                    'BBC source headline inventory changed, was truncated or reordered')
    bodies = selections['body']['elements']
    browser.require(selections['body']['count'] == 1 and len(bodies) == 1
                    and len(bodies[0]['text']) > 1000 and selections['all']['count'] > 500,
                    'BBC body or DOM is incomplete')
    images = selections['images']
    browser.require(images['count'] == len(images['elements']), 'BBC image audit was truncated')
    sources = sorted(row.get('attributes', {}).get('src', '') for row in images['elements']
                     if row.get('attributes', {}).get('src', '') not in expected['placeholder_sources'])
    # BBC removes grey loading placeholders after each real image decodes.
    # Every authored photograph must remain; only those explicit placeholders
    # may disappear during hydration, independently of any measured candidate.
    browser.require(sources == expected['image_sources'], 'BBC photograph source inventory changed')
    visible = []
    for row in images['elements']:
        rect = row['rect']
        if (rect['width'] <= 0 or rect['height'] <= 0 or rect['x'] >= 1024
                or rect['y'] >= 768 or rect['x'] + rect['width'] <= 0
                or rect['y'] + rect['height'] <= 0):
            continue
        image = row.get('image') or {}
        browser.require((image.get('complete') and image.get('natural_width', 0) > 0)
                        or (image.get('paint_decoded') and image.get('paint_width', 0) > 0),
                        'BBC visible image is not decoded: ' + str(row.get('attributes')))
        visible.append(row)
    browser.require(visible, 'BBC has no visible decoded images')
    browser.require(audit.get('fonts_status') == 'loaded', 'BBC fonts are unsettled')
    local_fallbacks = []
    for face in audit.get('font_faces', []):
        allowed = expected.get('local_font_fallback_sources', {}).get(face.get('family', '').casefold(), [])
        sources = face.get('declared_sources', [])
        local_missing = face['status'] == 'error' and bool(sources) and all(s in allowed for s in sources)
        browser.require(face['status'] not in ('loading', 'error') or local_missing,
                        'BBC requested font failed')
        if local_missing:
            local_fallbacks.append(dict(family=face['family'], sources=sources))
        browser.require(face['status'] != 'loaded' or face.get('parsed_font_present'),
                        'BBC loaded font has no parsed data')
    return dict(passed=True, headlines=len(actual), images=images['count'],
                visible_decoded_images=len(visible), dom_elements=selections['all']['count'],
                unavailable_local_fallbacks=local_fallbacks,
                body_text_sha256=hashlib.sha256(bodies[0]['text'].encode()).hexdigest())


def audit_expression():
    return '''({url:location.href,title:document.title,ready:document.readyState,
      viewport_width:innerWidth,viewport_height:innerHeight,fonts_status:document.fonts.status,
      font_faces:[...document.fonts].map(f=>({family:f.family,status:f.status,
        parsed_font_present:f.status==='loaded'})),selections:''' + json.dumps(SELECTORS) + '''.map(s=>{
        const nodes=[...document.querySelectorAll(s.selector)];
        return {name:s.name,count:nodes.length,elements:nodes.slice(0,s.limit).map(e=>{
          const r=e.getBoundingClientRect();return {text:e.textContent,
            attributes:Object.fromEntries(s.attributes.map(a=>[a,e.getAttribute(a)])),
            rect:{x:r.x,y:r.y,width:r.width,height:r.height},
            image:e.tagName==='IMG'?{complete:e.complete,natural_width:e.naturalWidth,
              natural_height:e.naturalHeight,current_src:e.currentSrc}:null}})}})})'''



def trial_order(index, control=False):
    order = ['control', 'vox', 'brave'] if control else ['vox', 'brave']
    return order if index % 2 == 0 else order[::-1]


def verify_benchmark_inputs(paths, pinned, trial_folder):
    """Keep each post-trial observation, including later-superseded bundles."""
    try:
        observed = browser.fingerprint(paths)
    except OSError as error:
        browser.write_json(trial_folder / 'input-identity-failure.json', dict(
            invalidates_cohort=True, unavailable_input=error.filename,
            error=str(error)))
        raise
    if observed != pinned:
        changed = [dict(path=path, expected=pinned.get(path), observed=observed.get(path))
                   for path in sorted(pinned.keys() | observed.keys())
                   if pinned.get(path) != observed.get(path)]
        browser.write_json(trial_folder / 'input-identity-failure.json', dict(
            invalidates_cohort=True, changed_inputs=changed))
        browser.require(False, 'Pinned benchmark input changed')
    browser.write_json(trial_folder / 'input-identity-after.json', dict(
        passed=True, observed_unix=time.time(), files=observed))


def audit_instruction_logging(row, log, diagnostic=False):
    prefixes = ('Vox retained block font generation:', 'Vox retained inline font generation:',
                'Vox retained text font generation:')
    count = None if log is None else sum(line.startswith(prefixes) for line in log.splitlines())
    row['font_generation_diagnostic_lines'] = count
    row['font_generation_diagnostics_allowed'] = diagnostic
    if count is None or (count and not diagnostic):
        reason = ('Missing native browser log for instruction diagnostic audit' if count is None else
                  'Verbose retained-font tracing is enabled outside a diagnostic run')
        row['exit'] = 1
        row['error'] = '; '.join(filter(None, [row.get('error'), reason]))
    return row


def loaded_native_images(log, root_pid, executable):
    """Read a separate discovery run, including libraries opened with dlopen."""
    browser.require(type(root_pid) is int and root_pid > 0, 'Missing runtime discovery PID')
    endpoint = log.find('"label":"capture_document_encoded"')
    browser.require(endpoint >= 0, 'Missing encoded PNG endpoint in runtime discovery')
    pattern = rf'^dyld\[{root_pid}\]: <[^>]+> (.+)$'
    images = {Path(match[1]).resolve() for match in re.finditer(pattern, log[:endpoint], re.M)
              if not match[1].startswith(('/System/Library/', '/usr/lib/'))}
    browser.require(executable.resolve() in images, 'Runtime discovery did not identify its executable')
    browser.require(all(path.is_file() for path in images), 'Unavailable discovered runtime image')
    return images


def discover_runtime_libraries(args, apps, paths, pinned):
    """Trace only diagnostic launches; acceptance runs keep their original environment."""
    saved = args.vox_environment
    discoveries = []
    images = set()
    manifest = args.output / 'runtime-libraries.json'
    try:
        for engine in ['vox'] + (['control'] if 'control' in apps else []):
            folder = args.output / ('runtime-discovery-' + engine)
            args.vox_environment = dict(saved, DYLD_PRINT_LIBRARIES='1')
            row = run_trial(engine, apps[engine], folder, args)
            row.update(acceptance=False, purpose='Separate runtime library discovery; no performance credit')
            browser.write_json(folder / 'result.json', row)
            verify_benchmark_inputs(paths, pinned, folder)
            browser.require(row['exit'] == 0 and row.get('kernel_exit_status') == 0
                            and row.get('pixels_exact') is True and row.get('content_exact') is True,
                            'Runtime discovery requires a normal exit and exact original pixels/content')
            root_pid = row.get('root', {}).get('pid')
            found = loaded_native_images((folder / 'browser.log').read_text(errors='replace'),
                                         root_pid, apps[engine] / 'Contents/MacOS/Vox')
            images.update(found)
            discoveries.append(dict(engine=engine, root_pid=root_pid,
                                    images=[str(path) for path in sorted(found)]))
        # Include load-command dependencies of late-bound images too. Their
        # actual bytes are pinned before the first acceptance launch.
        runtime_paths = set(images)
        for discovery in discoveries:
            runtime_paths.update(browser.native_dependencies(
                apps[discovery['engine']] / 'Contents/MacOS/Vox',
                extra_images=[Path(image) for image in discovery['images']]))
        check_folder = args.output / 'runtime-discovery-input-check'
        check_folder.mkdir()
        verify_benchmark_inputs(paths, pinned, check_folder)
        candidate_paths = paths | runtime_paths
        candidate_pins = {**pinned, **browser.fingerprint(runtime_paths - paths)}
        # The discovery run cannot pin previously unknown libraries before it
        # loads them. Validate the observed set again in fresh traced processes
        # with every discovered byte already pinned, without extending that set
        # or silently accepting a later browser replacement.
        for engine in ['vox'] + (['control'] if 'control' in apps else []):
            folder = args.output / ('runtime-validation-' + engine)
            args.vox_environment = dict(saved, DYLD_PRINT_LIBRARIES='1')
            row = run_trial(engine, apps[engine], folder, args)
            row.update(acceptance=False, purpose='Validate already pinned runtime images; no performance credit')
            browser.write_json(folder / 'result.json', row)
            verify_benchmark_inputs(candidate_paths, candidate_pins, folder)
            browser.require(row['exit'] == 0 and row.get('kernel_exit_status') == 0
                            and row.get('pixels_exact') is True and row.get('content_exact') is True,
                            'Runtime validation requires a normal exit and exact original pixels/content')
            root_pid = row.get('root', {}).get('pid')
            found = loaded_native_images((folder / 'browser.log').read_text(errors='replace'),
                                         root_pid, apps[engine] / 'Contents/MacOS/Vox')
            browser.require(found <= runtime_paths, 'Previously unpinned image in runtime validation')
            discoveries.append(dict(engine=engine, phase='validation', root_pid=root_pid,
                                    images=[str(path) for path in sorted(found)]))
        browser.write_json(manifest, dict(passed=True, acceptance=False, discoveries=discoveries,
            libraries=browser.fingerprint(runtime_paths),
            policy='Root images observed through PNG in separate traced launches, plus their '
                   'transitive load commands. Application files and owned service binaries remain '
                   'pinned. Fresh private caches/profiles; OS caches retained after diagnostics. '
                   'No instruction credit from discovery or this protocol correction.'))
        return candidate_paths | {manifest}, {**candidate_pins, **browser.fingerprint({manifest})}
    except Exception as error:
        browser.write_json(manifest, dict(passed=False, acceptance=False, discoveries=discoveries,
                                         error=str(error)))
        raise
    finally:
        args.vox_environment = saved


def run_trial(engine, app, folder, args):
    environment = args.vox_environment
    try:
        if engine in ('vox', 'control'):
            warmup = getattr(args, 'control_jsc_baseline_warmup' if engine == 'control'
                             else 'jsc_baseline_warmup', None)
            args.vox_environment = dict(environment, **jsc_baseline_environment(warmup))
        if engine == 'control':
            if getattr(args, 'control_retain_empty_deleted_conditional_targets', False):
                args.vox_environment['VOX_RETAIN_EMPTY_DELETED_CONDITIONAL_TARGETS'] = '1'
            if getattr(args, 'control_retain_broad_conditional_rule_deletion', False):
                args.vox_environment['VOX_RETAIN_BROAD_CONDITIONAL_RULE_DELETION'] = '1'
            if getattr(args, 'control_retain_descendant_navigable_scan', False):
                args.vox_environment['VOX_RETAIN_DESCENDANT_NAVIGABLE_SCAN'] = '1'
            if getattr(args, 'control_retain_uncached_item_paint', False):
                args.vox_environment['VOX_RETAIN_UNCACHED_ITEM_PAINT'] = '1'
            if getattr(args, 'control_retain_inline_measurement_indefinite_height', False):
                args.vox_environment['VOX_RETAIN_INLINE_MEASUREMENT_INDEFINITE_HEIGHT'] = '1'
            if getattr(args, 'control_retain_initial_resource_viewport_after_style', False):
                args.vox_environment['VOX_RETAIN_INITIAL_RESOURCE_VIEWPORT_AFTER_STYLE'] = '1'
            if getattr(args, 'control_retain_parent_longhand_hashing', False):
                args.vox_environment['VOX_RETAIN_PARENT_LONGHAND_HASHING'] = '1'
            if getattr(args, 'control_retain_invalidation_value_copies', False):
                args.vox_environment['VOX_RETAIN_INVALIDATION_VALUE_COPIES'] = '1'
            if getattr(args, 'control_retain_cascade_value_copies', False):
                args.vox_environment['VOX_RETAIN_CASCADE_VALUE_COPIES'] = '1'
            if getattr(args, 'control_retain_absolute_length_context', False):
                args.vox_environment['VOX_RETAIN_ABSOLUTE_LENGTH_CONTEXT'] = '1'
            if getattr(args, 'control_retain_image_attribute_source_parse', False):
                args.vox_environment['VOX_RETAIN_IMAGE_ATTRIBUTE_SOURCE_PARSE'] = '1'
            if getattr(args, 'control_retain_flow_style_identities', False):
                args.vox_environment['VOX_RETAIN_FLOW_STYLE_IDENTITIES'] = '1'
            if getattr(args, 'control_retain_ancestor_rehash', False):
                args.vox_environment['VOX_RETAIN_ANCESTOR_REHASH'] = '1'
            if getattr(args, 'control_disable_retained_formatting_trees', False):
                args.vox_environment['VOX_DISABLE_RETAINED_FORMATTING_TREES'] = '1'
            if getattr(args, 'control_retain_property_edge_resolution', False):
                args.vox_environment['VOX_RETAIN_PROPERTY_EDGE_RESOLUTION'] = '1'
            if getattr(args, 'control_disable_retained_simple_svg', False):
                args.vox_environment['VOX_DISABLE_RETAINED_SIMPLE_SVG'] = '1'
            if getattr(args, 'control_retain_definite_intrinsic_measurement', False):
                args.vox_environment['VOX_RETAIN_DEFINITE_INTRINSIC_MEASUREMENT'] = '1'
            if getattr(args, 'control_retain_selector_substring_scan', False):
                args.vox_environment['VOX_RETAIN_SELECTOR_SUBSTRING_SCAN'] = '1'
            if getattr(args, 'control_retain_redundant_sheet_removal', False):
                args.vox_environment['VOX_RETAIN_REDUNDANT_SHEET_REMOVAL'] = '1'
            if getattr(args, 'control_retain_full_font_input_scan', False):
                args.vox_environment['VOX_RETAIN_FULL_FONT_INPUT_SCAN'] = '1'
            if getattr(args, 'control_disable_early_text_font_requests', False):
                args.vox_environment['VOX_DISABLE_EARLY_TEXT_FONT_REQUESTS'] = '1'
            if getattr(args, 'control_retain_selector_rule_font_sync', False):
                args.vox_environment['VOX_RETAIN_SELECTOR_RULE_FONT_SYNC'] = '1'
            if getattr(args, 'control_retain_empty_procedural_styles', False):
                args.vox_environment['VOX_RETAIN_EMPTY_PROCEDURAL_STYLES'] = '1'
            if getattr(args, 'control_copy_stationary_raster_pixels', False):
                args.vox_environment['VOX_COPY_STATIONARY_RASTER_PIXELS'] = '1'
            if getattr(args, 'control_disable_inline_measurement_reuse', False):
                args.vox_environment['VOX_DISABLE_INLINE_MEASUREMENT_REUSE'] = '1'
            if args.control_disable_grid_width_only:
                args.vox_environment['VOX_DISABLE_GRID_WIDTH_ONLY'] = '1'
            if getattr(args, 'control_disable_stationary_raster', False):
                args.vox_environment['VOX_DISABLE_STATIONARY_RASTER_REUSE'] = '1'
            if getattr(args, 'control_disable_client_geometry_index', False):
                args.vox_environment['VOX_DISABLE_VISUAL_CONTEXT_INDEX'] = '1'
            if getattr(args, 'control_disable_tracked_persistent_shortcut', False):
                args.vox_environment['VOX_DISABLE_TRACKED_PERSISTENT_SHORTCUT'] = '1'
            if getattr(args, 'control_disable_attribute_case_buckets', False):
                args.vox_environment['VOX_DISABLE_ATTRIBUTE_CASE_BUCKETS'] = '1'
            if getattr(args, 'control_disable_persistent_scope_jumps', False):
                args.vox_environment['VOX_DISABLE_PERSISTENT_SCOPE_JUMPS'] = '1'
            if getattr(args, 'control_disable_extended_longhand_reuse', False):
                args.vox_environment['VOX_DISABLE_EXTENDED_LONGHAND_REUSE'] = '1'
            if getattr(args, 'control_disable_color_longhand_reuse', False):
                args.vox_environment['VOX_DISABLE_COLOR_LONGHAND_REUSE'] = '1'
            if getattr(args, 'control_copy_stationary_raster_commands', False):
                args.vox_environment['VOX_COPY_STATIONARY_RASTER_COMMANDS'] = '1'
            if getattr(args, 'control_disable_retained_flow_items', False):
                args.vox_environment['VOX_DISABLE_RETAINED_FLOW_ITEMS'] = '1'
            if getattr(args, 'control_disable_constant_longhand_reuse', False):
                args.vox_environment['VOX_DISABLE_CONSTANT_LONGHAND_REUSE'] = '1'
            if getattr(args, 'control_disable_live_pending_text_reuse', False):
                args.vox_environment['VOX_DISABLE_LIVE_PENDING_TEXT_REUSE'] = '1'
            if getattr(args, 'control_disable_intrinsic_seed_visits', False):
                args.vox_environment['VOX_DISABLE_INTRINSIC_SEED_VISITS'] = '1'
            if getattr(args, 'control_disable_retained_grid_layout', False):
                args.vox_environment['VOX_DISABLE_RETAINED_GRID_LAYOUT'] = '1'
            if getattr(args, 'control_disable_grid_measurement_reuse', False):
                args.vox_environment['VOX_DISABLE_GRID_MEASUREMENT_REUSE'] = '1'
            if getattr(args, 'control_disable_compact_query_envelope', False):
                args.vox_environment['VOX_DISABLE_COMPACT_QUERY_ENVELOPE'] = '1'
            if getattr(args, 'control_disable_committed_inline_measurement_reuse', False):
                args.vox_environment['VOX_DISABLE_COMMITTED_INLINE_MEASUREMENT_REUSE'] = '1'
            if getattr(args, 'control_disable_committed_grid_measurement_reuse', False):
                args.vox_environment['VOX_DISABLE_COMMITTED_GRID_MEASUREMENT_REUSE'] = '1'
            if getattr(args, 'control_disable_committed_flex_measurement_reuse', False):
                args.vox_environment['VOX_DISABLE_COMMITTED_FLEX_MEASUREMENT_REUSE'] = '1'
            if getattr(args, 'control_disable_retained_flow_image_trees', False):
                args.vox_environment['VOX_DISABLE_RETAINED_FLOW_IMAGE_TREES'] = '1'
            if getattr(args, 'control_disable_markerless_measurements', False):
                args.vox_environment['VOX_DISABLE_MARKERLESS_MEASUREMENTS'] = '1'
            if getattr(args, 'control_disable_grid_placement_reuse', False):
                args.vox_environment['VOX_DISABLE_GRID_PLACEMENT_REUSE'] = '1'
            if getattr(args, 'control_disable_unused_measurement_heights', False):
                args.vox_environment['VOX_DISABLE_UNUSED_MEASUREMENT_HEIGHTS'] = '1'
            if getattr(args, 'control_disable_retained_flow_svg_trees', False):
                args.vox_environment['VOX_DISABLE_RETAINED_FLOW_SVG_TREES'] = '1'
            if getattr(args, 'control_disable_object_receiver_call', False):
                args.vox_environment['VOX_DISABLE_OBJECT_RECEIVER_CALL'] = '1'
            if getattr(args, 'control_disable_native_callback_call', False):
                args.vox_environment['VOX_DISABLE_NATIVE_CALLBACK_CALL'] = '1'
            if getattr(args, 'control_disable_extended_image_measurements', False):
                args.vox_environment['VOX_DISABLE_EXTENDED_IMAGE_MEASUREMENTS'] = '1'
            if getattr(args, 'control_disable_extended_image_trees', False):
                args.vox_environment['VOX_DISABLE_EXTENDED_IMAGE_TREES'] = '1'
            if getattr(args, 'control_disable_inline_tree_measurement_reuse', False):
                args.vox_environment['VOX_DISABLE_INLINE_TREE_MEASUREMENT_REUSE'] = '1'
            if getattr(args, 'control_retain_covered_style_sheet_walk', False):
                args.vox_environment['VOX_RETAIN_COVERED_STYLE_SHEET_WALK'] = '1'
            if getattr(args, 'control_retain_covered_style_sheet_anchor_walks', False):
                args.vox_environment['VOX_RETAIN_COVERED_STYLE_SHEET_ANCHOR_WALKS'] = '1'
            if getattr(args, 'control_disable_svg_measurement_reuse', False):
                args.vox_environment['VOX_DISABLE_SVG_MEASUREMENT_REUSE'] = '1'
            if getattr(args, 'control_disable_relative_measurement_reuse', False):
                args.vox_environment['VOX_DISABLE_RELATIVE_MEASUREMENT_REUSE'] = '1'
            if getattr(args, 'control_disable_flex_image_measurement_reuse', False):
                args.vox_environment['VOX_DISABLE_FLEX_IMAGE_MEASUREMENT_REUSE'] = '1'
            if getattr(args, 'control_disable_flex_measurement_reuse', False):
                args.vox_environment['VOX_DISABLE_FLEX_MEASUREMENT_REUSE'] = '1'
            if getattr(args, 'control_disable_frame_task_layout_coalescing', False):
                args.vox_environment['VOX_DISABLE_FRAME_TASK_LAYOUT_COALESCING'] = '1'
            if getattr(args, 'control_disable_adblock_token_reuse', False):
                args.vox_environment['VOX_DISABLE_ADBLOCK_TOKEN_REUSE'] = '1'
            if getattr(args, 'control_disable_grid_auto_height_seed', False):
                args.vox_environment['VOX_DISABLE_GRID_AUTO_HEIGHT_SEED'] = '1'
            if getattr(args, 'control_disable_resolved_edge_reuse', False):
                args.vox_environment['VOX_DISABLE_RESOLVED_EDGE_REUSE'] = '1'
            if getattr(args, 'control_disable_document_filter_memo', False):
                args.vox_environment['VOX_DISABLE_DOCUMENT_FILTER_MEMO'] = '1'
            if getattr(args, 'control_disable_static_user_style_filter', False):
                args.vox_environment['VOX_DISABLE_STATIC_USER_STYLE_FILTER'] = '1'
            if getattr(args, 'control_disable_targeted_user_style_changes', False):
                args.vox_environment['VOX_DISABLE_TARGETED_USER_STYLE_CHANGES'] = '1'
            if getattr(args, 'control_disable_deleted_style_rule_invalidation', False):
                args.vox_environment['VOX_DISABLE_DELETED_STYLE_RULE_INVALIDATION'] = '1'
            if getattr(args, 'control_disable_attribute_tag_buckets', False):
                args.vox_environment['VOX_DISABLE_ATTRIBUTE_TAG_BUCKETS'] = '1'
            if getattr(args, 'control_disable_shared_node_properties', False):
                args.vox_environment['VOX_DISABLE_SHARED_NODE_PROPERTIES'] = '1'
            if getattr(args, 'control_disable_shared_element_geometry', False):
                args.vox_environment['VOX_DISABLE_SHARED_ELEMENT_GEOMETRY'] = '1'
            if getattr(args, 'control_disable_protected_value_index', False):
                args.vox_environment['VOX_DISABLE_PROTECTED_VALUE_INDEX'] = '1'
            if getattr(args, 'control_disable_longhand_eligibility_first', False):
                args.vox_environment['VOX_DISABLE_LONGHAND_ELIGIBILITY_FIRST'] = '1'
            if getattr(args, 'control_disable_longhand_shape_reuse', False):
                args.vox_environment['VOX_DISABLE_LONGHAND_SHAPE_REUSE'] = '1'
            if getattr(args, 'control_disable_classic_import_word_scan', False):
                args.vox_environment['VOX_DISABLE_CLASSIC_IMPORT_WORD_SCAN'] = '1'
            if getattr(args, 'control_disable_inactive_conditional_sheet_skip', False):
                args.vox_environment['VOX_DISABLE_INACTIVE_CONDITIONAL_SHEET_SKIP'] = '1'
            if getattr(args, 'control_disable_conditional_sheet_invalidation', False):
                args.vox_environment['VOX_DISABLE_CONDITIONAL_SHEET_INVALIDATION'] = '1'
            if getattr(args, 'control_disable_positioned_definite_image_reuse', False):
                args.vox_environment['VOX_DISABLE_POSITIONED_DEFINITE_IMAGE_REUSE'] = '1'
            if getattr(args, 'control_disable_positioned_image_ratio_reuse', False):
                args.vox_environment['VOX_DISABLE_POSITIONED_IMAGE_RATIO_REUSE'] = '1'
            if getattr(args, 'control_disable_live_pending_font_refresh', False):
                args.vox_environment['VOX_DISABLE_LIVE_PENDING_FONT_REFRESH'] = '1'
            if getattr(args, 'control_disable_pending_intrinsic_font_reuse', False):
                args.vox_environment['VOX_DISABLE_PENDING_INTRINSIC_FONT_REUSE'] = '1'
            if getattr(args, 'control_disable_intrinsic_font_reuse', False):
                args.vox_environment['VOX_DISABLE_INTRINSIC_FONT_REUSE'] = '1'
            if getattr(args, 'control_disable_face_specific_font_display', False):
                args.vox_environment['VOX_DISABLE_FACE_SPECIFIC_FONT_DISPLAY'] = '1'
        return browser.run_browser('vox' if engine == 'control' else engine, app, folder, args)
    finally:
        args.vox_environment = environment


def jsc_baseline_environment(warmup):
    if warmup is None:
        return {}
    return dict(JSC_thresholdForJITAfterWarmUp=str(warmup),
                JSC_thresholdForJITSoon=str(max(1, warmup // 5)))


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--memory-guard-registry', type=Path, required=True)
    parser.add_argument('--vox-app', type=Path, default=REPO / 'Build/v/Vox.app')
    parser.add_argument('--control-vox-app', type=Path, help='Also run a pinned Vox control before each candidate/Brave pair')
    parser.add_argument('--control-retain-broad-conditional-rule-deletion', action='store_true',
                        help='Invalidate the whole stylesheet after conditional rule deletion in the matched control')
    parser.add_argument('--control-retain-empty-deleted-conditional-targets', action='store_true',
                        help='Invalidate subjects of declaration-free deleted conditional leaves in the matched control')
    parser.add_argument('--control-retain-descendant-navigable-scan', action='store_true',
                        help='Traverse documents without owned navigable containers in the matched control')
    parser.add_argument('--control-retain-uncached-item-paint', action='store_true',
                        help='Rebuild flex and grid item paint projections in the matched control')
    parser.add_argument('--control-retain-inline-measurement-indefinite-height', action='store_true',
                        help='Retain unused stored heights in closed text measurement cache keys in the control')
    parser.add_argument('--control-retain-initial-resource-viewport-after-style', action='store_true',
                        help='Resolve device-layout styles before installing the actual initial viewport in the control')
    parser.add_argument('--control-retain-parent-longhand-hashing', action='store_true',
                        help='Rehash all inherited parent longhands for every eligible control element')
    parser.add_argument('--control-retain-invalidation-value-copies', action='store_true',
                        help='Copy typed scalar wrappers during style invalidation in the control')
    parser.add_argument('--control-retain-cascade-value-copies', action='store_true',
                        help='Copy typed wrappers during cascade checks in the matched control')
    parser.add_argument('--control-retain-absolute-length-context', action='store_true',
                        help='Consult the rounding context for zero pixel lengths in the matched control')
    parser.add_argument('--control-retain-image-attribute-source-parse', action='store_true',
                        help='Parse image attributes before reading available requests in the matched control')
    parser.add_argument('--control-retain-flow-style-identities', action='store_true',
                        help='Reject replacement style objects during retained-tree validation in the control')
    parser.add_argument('--control-retain-ancestor-rehash', action='store_true',
                        help='Rehash attributes when removing ancestors in the matched control')
    parser.add_argument('--control-disable-retained-formatting-trees', action='store_true',
                        help='Rebuild unchanged grid/flex trees in the matched Vox control')
    parser.add_argument('--control-retain-property-edge-resolution', action='store_true',
                        help='Resolve box edges through individual properties in the matched control')
    parser.add_argument('--control-disable-retained-simple-svg', action='store_true',
                        help='Recompute independent contexts containing simple SVG shapes in the matched control')
    parser.add_argument('--control-retain-definite-intrinsic-measurement', action='store_true',
                        help='Measure overwritten content widths in the matched Vox control')
    parser.add_argument('--control-retain-selector-substring-scan', action='store_true',
                        help='Use the previous bounded attribute substring scan in the matched control')
    parser.add_argument('--control-retain-redundant-sheet-removal', action='store_true',
                        help='Restyle after redundant adjacent inline stylesheet removal in the matched control')
    parser.add_argument('--control-retain-full-font-input-scan', action='store_true',
                        help='Scan all CSS longhands before font-cache reuse in the matched control')
    parser.add_argument('--control-disable-early-text-font-requests', action='store_true',
                        help='Keep text font requests at first layout in the matched control')
    parser.add_argument('--control-retain-selector-rule-font-sync', action='store_true',
                        help='Rescan font registrations after selector-only CSSOM edits in the matched control')
    parser.add_argument('--control-retain-empty-procedural-styles', action='store_true',
                        help='Retain comment-only procedural CSS replacement in the matched control')
    parser.add_argument('--control-copy-stationary-raster-pixels', action='store_true',
                        help='Copy unchanged document pixels instead of retaining the immutable native frame')
    parser.add_argument('--control-disable-inline-measurement-reuse', action='store_true',
                        help='Recompute closed text layouts in each temporary measurement of the matched control')
    parser.add_argument('--jsc-baseline-warmup', type=int,
                        help='Explicit baseline-JIT warmup threshold for Vox; soon threshold is max(1, warmup // 5)')
    parser.add_argument('--control-jsc-baseline-warmup', type=int,
                        help='Explicit baseline-JIT warmup threshold for the matched Vox control')
    parser.add_argument('--control-disable-grid-width-only', action='store_true',
                        help='Disable only grid width-probe reuse in the pinned Vox control')
    parser.add_argument('--control-disable-stationary-raster', action='store_true',
                        help='Disable stationary document pixel reuse in the pinned Vox control')
    parser.add_argument('--control-disable-client-geometry-index', action='store_true',
                        help='Use recursive visual-context lookup in the pinned Vox control')
    parser.add_argument('--control-disable-tracked-persistent-shortcut', action='store_true',
                        help='Walk detached allocation blocks in the pinned Vox control')
    parser.add_argument('--control-disable-attribute-case-buckets', action='store_true',
                        help='Search all HTML enumerated attribute names in the pinned Vox control')
    parser.add_argument('--control-disable-persistent-scope-jumps', action='store_true',
                        help='Visit every allocation block when leaving scopes in the pinned Vox control')
    parser.add_argument('--control-disable-extended-longhand-reuse', action='store_true',
                        help='Keep the original computed-value cache eligibility in the pinned Vox control')
    parser.add_argument('--control-disable-color-longhand-reuse', action='store_true',
                        help='Disable only parsed RGB computed-value reuse in the pinned Vox control')
    parser.add_argument('--control-copy-stationary-raster-commands', action='store_true',
                        help='Copy retained paint commands during raster eligibility checks in the pinned Vox control')
    parser.add_argument('--control-disable-retained-flow-items', action='store_true',
                        help='Rebuild unchanged grid/flex flow items in the pinned Vox control')
    parser.add_argument('--control-disable-face-specific-font-display', action='store_true',
                        help='Invalidate whole font families on display changes or failures in the pinned Vox control')
    parser.add_argument('--control-disable-constant-longhand-reuse', action='store_true',
                        help='Disable numeric-ratio, angle-free font-style and time value reuse in the pinned Vox control')
    parser.add_argument('--control-disable-live-pending-text-reuse', action='store_true',
                        help='Discard text shapes after unrelated pending-font changes in the pinned Vox control')
    parser.add_argument('--control-disable-intrinsic-seed-visits', action='store_true',
                        help='Use per-probe hash visitation for external containing-block seeds in the pinned Vox control')
    parser.add_argument('--control-disable-retained-grid-layout', action='store_true',
                        help='Recompute ordinary independent grids in the pinned Vox control')
    parser.add_argument('--control-disable-grid-measurement-reuse', action='store_true',
                        help='Rerun temporary grid geometry in the matched Vox control')
    parser.add_argument('--control-disable-compact-query-envelope', action='store_true',
                        help='Use the general JSON query decoder in the matched Vox control')
    parser.add_argument('--control-disable-committed-inline-measurement-reuse', action='store_true',
                        help='Rerun measured text when committing geometry in the matched Vox control')
    parser.add_argument('--control-disable-markerless-measurements', action='store_true',
                        help='Keep markerless list items out of closed grid/flex measurements in control')
    parser.add_argument('--control-disable-grid-placement-reuse', action='store_true',
                        help='Recompute grid item placement in the matched Vox control')
    parser.add_argument('--control-disable-unused-measurement-heights', action='store_true',
                        help='Keep unused numeric heights in closed grid/flex measurement keys in the matched Vox control')
    parser.add_argument('--control-disable-retained-flow-svg-trees', action='store_true',
                        help='Rebuild closed SVG shape branches in the matched Vox control')
    parser.add_argument('--control-disable-object-receiver-call', action='store_true',
                        help='Retain the argument-array helper for object receivers in the matched Vox control')
    parser.add_argument('--control-disable-native-callback-call', action='store_true',
                        help='Use the JavaScript-array callback helper in the matched Vox control')
    parser.add_argument('--control-disable-extended-image-measurements', action='store_true',
                        help='Keep pending and absolute images out of within-pass grid/flex reuse in the matched Vox control')
    parser.add_argument('--control-disable-extended-image-trees', action='store_true',
                        help='Rebuild pending and absolute image tree branches in control only')
    parser.add_argument('--control-disable-retained-flow-image-trees', action='store_true',
                        help='Rebuild unchanged decoded raster image branches in control only')
    parser.add_argument('--control-disable-committed-flex-measurement-reuse', action='store_true',
                        help='Keep final flex layout from consuming an existing measured result in control only')
    parser.add_argument('--control-disable-committed-grid-measurement-reuse', action='store_true',
                        help='Rerun measured grids when committing geometry in the matched Vox control')
    parser.add_argument('--control-disable-inline-tree-measurement-reuse', action='store_true',
                        help='Keep styled inline descendants out of temporary line reuse in the matched Vox control')
    parser.add_argument('--control-retain-covered-style-sheet-walk', action='store_true',
                        help='Walk primary stylesheet targets during a pending full cascade in the matched Vox control')
    parser.add_argument('--control-retain-covered-style-sheet-anchor-walks', action='store_true',
                        help='Retain anchor walks covered by a pending full cascade in the control arm')
    parser.add_argument('--control-disable-svg-measurement-reuse', action='store_true',
                        help='Keep closed SVG shapes out of temporary grid/flex reuse in the matched Vox control')
    parser.add_argument('--control-disable-relative-measurement-reuse', action='store_true',
                        help='Keep unshifted relative boxes out of temporary grid/flex reuse in the matched Vox control')
    parser.add_argument('--control-disable-flex-image-measurement-reuse', action='store_true',
                        help='Keep decoded images out of temporary flex reuse in the matched Vox control')
    parser.add_argument('--control-disable-flex-measurement-reuse', action='store_true',
                        help='Rerun temporary flex geometry in the matched Vox control')
    parser.add_argument('--control-disable-frame-task-layout-coalescing', action='store_true',
                        help='Lay out each dirty script synchronization immediately in the matched Vox control')
    parser.add_argument('--control-disable-adblock-token-reuse', action='store_true',
                        help='Resurvey light-DOM IDs and classes at every cosmetic refresh in the matched Vox control')
    parser.add_argument('--control-disable-grid-auto-height-seed', action='store_true',
                        help='Remeasure max-content heights of closed auto-row grids in the matched Vox control')
    parser.add_argument('--control-disable-resolved-edge-reuse', action='store_true',
                        help='Resolve absolute and percentage box edges again in the matched Vox control')
    parser.add_argument('--control-disable-document-filter-memo', action='store_true',
                        help='Reevaluate repeated default cosmetic queries in the pinned Vox control')
    parser.add_argument('--control-disable-static-user-style-filter', action='store_true',
                        help='Use coarse subject predicates when replacing user styles in the pinned Vox control')
    parser.add_argument('--control-disable-targeted-user-style-changes', action='store_true',
                        help='Invalidate the entire document after user stylesheet replacement in the pinned Vox control')
    parser.add_argument('--control-disable-deleted-style-rule-invalidation', action='store_true',
                        help='Invalidate entire inline stylesheet owners after style rule deletion in the pinned Vox control')
    parser.add_argument('--control-disable-attribute-tag-buckets', action='store_true',
                        help='Prefer tag buckets over required attributes in the pinned Vox control')
    parser.add_argument('--retain-incremental-webp-paint-policy', action='store_true',
                        help='Reproduce the historical WebP paint policy in both Vox arms; no decoder optimization credit')
    parser.add_argument('--retain-logical-paint-snapping', action='store_true',
                        help='Retain the fixed references\' historical logical-pixel snapping in both Vox arms; no policy-change credit')
    parser.add_argument('--retain-css-layout-for-svg', action='store_true',
                        help='Retain the fixed references\' CSS-coordinate inline-SVG layout in both Vox arms; no policy-change credit')
    parser.add_argument('--retain-degenerate-border-msaa', action='store_true',
                        help='Retain the fixed references\' tile MSAA for degenerate border arcs in both Vox arms; no policy-change credit')
    parser.add_argument('--control-disable-shared-node-properties', action='store_true',
                        help='Create separate text/comment/fragment property accessors in the pinned Vox control')
    parser.add_argument('--control-disable-shared-element-geometry', action='store_true',
                        help='Create separate geometry accessors for every element in the pinned Vox control')
    parser.add_argument('--control-disable-protected-value-index', action='store_true',
                        help='Use linear protected-value removal in the pinned Vox control')
    parser.add_argument('--control-disable-longhand-eligibility-first', action='store_true',
                        help='retain inherited hashing before eligibility checks in the matched control')
    parser.add_argument('--control-disable-longhand-shape-reuse', action='store_true',
                        help='disable viewport/grid/radius longhand reuse in the matched control')
    parser.add_argument('--control-disable-classic-import-word-scan', action='store_true',
                        help='disable classic-script import identifier rejection in the matched control')
    parser.add_argument('--control-disable-inactive-conditional-sheet-skip', action='store_true',
                        help='disable skipping inactive conditional style rules in the matched control')
    parser.add_argument('--control-disable-conditional-sheet-invalidation', action='store_true',
                        help='Invalidate the whole document after conditional group insertion in the pinned Vox control')
    parser.add_argument('--control-disable-positioned-definite-image-reuse', action='store_true',
                        help='Relayout positioned images whose two dimensions are independent of natural size in the matched control')
    parser.add_argument('--control-disable-positioned-image-ratio-reuse', action='store_true',
                        help='Relayout positioned images after same-ratio source changes in the pinned Vox control')
    parser.add_argument('--control-disable-live-pending-font-refresh', action='store_true',
                        help='Relayout unchanged live pending fonts during refresh in the pinned Vox control')
    parser.add_argument('--control-disable-pending-intrinsic-font-reuse', action='store_true',
                        help='Expire intrinsic sizes with unchanged pending fonts in the pinned Vox control')
    parser.add_argument('--control-disable-intrinsic-font-reuse', action='store_true',
                        help='Expire all intrinsic sizes after unrelated font changes in the pinned Vox control')
    parser.add_argument('--brave-app', type=Path, default=Path('/Applications/Brave Browser.app'))
    parser.add_argument('--diff-tool', type=Path, default=REPO / 'Build/hn-home-instructions-20261031/pixel_diff')
    parser.add_argument('--expected-vox', type=Path)
    parser.add_argument('--expected-brave', type=Path)
    parser.add_argument('--preserve-inputs', type=Path,
                        help='Verify and preserve sealed replay bytes and supplied references in a tar.gz outside Build before launching')
    parser.add_argument('--capture-reference', action='store_true')
    parser.add_argument('--reference-engine', choices=['vox', 'brave', 'both'], default='both')
    parser.add_argument('--repeat', type=int, default=7)
    parser.add_argument('--scale', type=int, choices=[1, 2], default=2)
    parser.add_argument('--timeout', type=float, default=180)
    parser.add_argument('--settle-seconds', type=float, default=2)
    args = parser.parse_args(argv)
    for warmup in (args.jsc_baseline_warmup, args.control_jsc_baseline_warmup):
        if warmup is not None and not 1 <= warmup <= 2147483647:
            parser.error('JSC baseline warmup must be a positive signed 32-bit integer')
    if args.control_jsc_baseline_warmup is not None and not args.control_vox_app:
        parser.error('The JSC baseline control needs --control-vox-app')
    if (args.control_disable_frame_task_layout_coalescing or args.control_disable_adblock_token_reuse
            or args.control_disable_grid_auto_height_seed
            or args.control_disable_positioned_definite_image_reuse
            or args.control_disable_object_receiver_call
            or args.control_disable_retained_flow_svg_trees) and not args.control_vox_app:
        parser.error('Disabling the control optimization needs --control-vox-app')
    if any((args.control_disable_markerless_measurements, args.control_disable_grid_placement_reuse, args.control_disable_unused_measurement_heights, args.control_disable_native_callback_call, args.control_disable_extended_image_measurements, args.control_disable_extended_image_trees, args.control_disable_retained_flow_image_trees, args.control_disable_committed_flex_measurement_reuse, args.control_disable_inline_tree_measurement_reuse, args.control_retain_covered_style_sheet_walk, args.control_retain_covered_style_sheet_anchor_walks, args.control_disable_svg_measurement_reuse, args.control_disable_relative_measurement_reuse, args.control_disable_flex_image_measurement_reuse, args.control_disable_resolved_edge_reuse, args.control_disable_flex_measurement_reuse, args.control_disable_committed_grid_measurement_reuse, args.control_disable_committed_inline_measurement_reuse, args.control_disable_compact_query_envelope, args.control_disable_grid_measurement_reuse, args.control_retain_empty_deleted_conditional_targets, args.control_retain_broad_conditional_rule_deletion, args.control_retain_descendant_navigable_scan, args.control_retain_uncached_item_paint, args.control_retain_inline_measurement_indefinite_height, args.control_retain_initial_resource_viewport_after_style, args.control_retain_parent_longhand_hashing, args.control_retain_invalidation_value_copies, args.control_retain_cascade_value_copies, args.control_retain_absolute_length_context, args.control_retain_image_attribute_source_parse, args.control_retain_flow_style_identities, args.control_retain_ancestor_rehash, args.control_disable_retained_formatting_trees, args.control_retain_property_edge_resolution, args.control_disable_retained_simple_svg, args.control_retain_definite_intrinsic_measurement, args.control_retain_selector_substring_scan, args.control_retain_redundant_sheet_removal, args.control_retain_full_font_input_scan, args.control_disable_early_text_font_requests, args.control_retain_selector_rule_font_sync, args.control_retain_empty_procedural_styles, args.control_copy_stationary_raster_pixels, args.control_disable_inline_measurement_reuse,
            args.control_disable_grid_width_only, args.control_disable_stationary_raster,
            args.control_disable_client_geometry_index,
            args.control_disable_tracked_persistent_shortcut, args.control_disable_attribute_case_buckets,
            args.control_disable_persistent_scope_jumps,
            args.control_disable_extended_longhand_reuse,
            args.control_disable_color_longhand_reuse,
            args.control_copy_stationary_raster_commands,
            args.control_disable_retained_flow_items,
            args.control_disable_face_specific_font_display,
            args.control_disable_constant_longhand_reuse,
            args.control_disable_intrinsic_font_reuse,
            args.control_disable_pending_intrinsic_font_reuse,
            args.control_disable_live_pending_text_reuse,
            args.control_disable_live_pending_font_refresh,
            args.control_disable_positioned_image_ratio_reuse,
            args.control_disable_conditional_sheet_invalidation or args.control_disable_inactive_conditional_sheet_skip or args.control_disable_classic_import_word_scan or args.control_disable_longhand_shape_reuse or args.control_disable_longhand_eligibility_first or args.control_disable_protected_value_index or args.control_disable_shared_element_geometry or args.control_disable_shared_node_properties or args.control_disable_attribute_tag_buckets or args.control_disable_deleted_style_rule_invalidation or args.control_disable_targeted_user_style_changes or args.control_disable_static_user_style_filter or args.control_disable_document_filter_memo or args.control_disable_retained_grid_layout or args.control_disable_intrinsic_seed_visits)) and not args.control_vox_app:
        parser.error('Disabling the control optimization needs --control-vox-app')
    if not args.capture_reference and (args.repeat < 7 or not args.expected_vox or not args.expected_brave):
        parser.error('Acceptance needs seven pairs and both existing pixel references')
    if not args.capture_reference and args.reference_engine != 'both':
        parser.error('Single-engine runs are only for reference diagnostics')
    if args.timeout <= 0 or not 0 <= args.settle_seconds < args.timeout:
        parser.error('Invalid timeout or settle duration')
    for key, value in vars(args).items():
        if isinstance(value, Path):
            setattr(args, key, value.resolve())
    if args.preserve_inputs and (args.preserve_inputs == REPO / 'Build'
                                or REPO / 'Build' in args.preserve_inputs.parents):
        parser.error('Preserved inputs must be outside Build so build cleanup cannot remove them')
    if args.preserve_inputs and (args.preserve_inputs == args.output
                                or args.output in args.preserve_inputs.parents):
        parser.error('Preserved inputs must be outside the trial output directory')
    return args


def evaluate_cohort(pairs, has_control=False):
    """Keep the optional control out of the Vox/Brave pair schema."""
    browser.require(len(pairs) >= 7, 'Acceptance needs seven complete pairs')
    engines = {'vox', 'brave', 'control'} if has_control else {'vox', 'brave'}
    browser.require(all(set(pair) == engines for pair in pairs), 'Incomplete BBC cohort')
    browser.require(all(pair[engine].get('capture_ownership_audit', {}).get('passed') is True
                        for pair in pairs for engine in engines - {'brave'}),
                    'Every Vox capture needs endpoint-matched live coalition ownership')
    summary = browser.evaluate_pairs(
        [dict(vox=pair['vox'], brave=pair['brave']) for pair in pairs], .9, 'launch')
    if has_control:
        # This also validates every control's content, pixels, exit and bounds.
        summary['matched_control'] = browser.evaluate_pairs(
            [dict(vox=pair['vox'], brave=pair['control']) for pair in pairs], .9, 'launch')
    return summary


def replay_vox_environment(args, ready):
    environment = dict(VOX_PROXY=ready['proxy'], SSL_CERT_FILE=ready['ca'],
                       VOX_BLOCK_COOKIE_BANNERS='0')
    if args.retain_incremental_webp_paint_policy:
        environment['VOX_RETAIN_INCREMENTAL_WEBP_PAINT_POLICY'] = '1'
    if args.retain_logical_paint_snapping:
        environment['VOX_RETAIN_LOGICAL_PAINT_SNAPPING'] = '1'
    if getattr(args, 'retain_css_layout_for_svg', False):
        environment['VOX_RETAIN_CSS_LAYOUT_FOR_SVG'] = '1'
    if getattr(args, 'retain_degenerate_border_msaa', False):
        environment['VOX_RETAIN_DEGENERATE_BORDER_MSAA'] = '1'
    return environment


def preserve_parallel_compilation_receipt(output, binary, receipt, published, selected,
                                         manifest, preserved):
    """Retain verified split-build provenance without claiming sealed C exists."""
    mode = receipt.get('c_compile', {})
    before = receipt.get('inputs', {}).get('build_inputs_sha256')
    after = receipt.get('verified_inputs', {}).get('build_inputs_sha256')
    browser.require(mode.get('mode') == 'parallel' and before and before == after
                    and not receipt.get('superseded'),
                    'Parallel production receipt lacks unchanged verified build inputs')
    expected = receipt['executable_sha256']
    candidates = []
    for path in (REPO / 'Build/production-build/receipts').glob('*/result.json'):
        if path.read_bytes() == published:
            candidates.append(path)
    browser.require(len(candidates) == 1, 'Parallel publication lacks a unique matching receipt')
    result_path = candidates[0]
    c_mode_path = result_path.parent / 'c-compile.json'
    before_path = result_path.parent / 'inputs-before.json'
    c_mode_bytes = c_mode_path.read_bytes()
    before_bytes = before_path.read_bytes()
    browser.require(json.loads(c_mode_bytes) == mode
                    and json.loads(before_bytes) == receipt['inputs'],
                    'Parallel compilation metadata differs from the published receipt')
    compiler = Path(mode['compiler'])
    runtime_path = compiler.parent.parent / 'manifest.json'
    runtime_bytes = runtime_path.read_bytes()
    runtime = json.loads(runtime_bytes)
    browser.require(hashlib.sha256(compiler.read_bytes()).hexdigest() == runtime['compiler_sha256'],
                    'Parallel compiler no longer matches its staged runtime identity')
    folder = output / 'production-compilation' / expected
    folder.mkdir(parents=True, exist_ok=False)
    for name, source, data in [('published-receipt.json', REPO / 'Build/production-build/latest.json', published),
                               ('result.json', result_path, published),
                               ('c-compile.json', c_mode_path, c_mode_bytes),
                               ('inputs-before.json', before_path, before_bytes),
                               ('compiler-runtime.json', runtime_path, runtime_bytes)]:
        target = folder / name
        target.write_bytes(data)
        browser.require(source.read_bytes() == data, f'Parallel receipt changed: {source}')
        preserved.add(target)
        manifest['files'][str(target)] = dict(source=str(source),
            sha256=hashlib.sha256(data).hexdigest(), bytes=len(data))
    browser.require((REPO / 'Build/production-build/latest.json').read_bytes() == published
                    and browser.fingerprint({binary})[str(binary)]['sha256'] == expected,
                    'Production browser or receipt changed during preservation')
    for engine in selected:
        manifest['engines'][engine] = dict(executable_sha256=expected,
            evidence_directory=str(folder), c_compile=mode,
            compiler_sha256=runtime['compiler_sha256'], generated_c_preserved=False,
            source_evidence='Equal complete production build-input fingerprints before/after compilation; '
                            'no sealed generated C is provided by the parallel build receipt')


def preserve_production_compilation(output, apps, pinned):
    """Archive generated compiler evidence before shared receipts can retire."""
    canonical = (REPO / 'Build/v/Vox.app').resolve()
    manifest_path = output / 'production-compilation.json'
    manifest = dict(passed=False, scope='Compiler receipts and preprocessed outputs only; '
                    'browser bundles, native libraries and repository tools remain in place.',
                    engines={}, files={})
    preserved = {manifest_path}
    try:
        selected = [engine for engine in ('vox', 'control')
                    if engine in apps and apps[engine].resolve() == canonical]
        if selected:
            binary = canonical / 'Contents/MacOS/Vox'
            expected = pinned[str(binary)]['sha256']
            published_path = REPO / 'Build/production-build/latest.json'
            published = published_path.read_bytes()
            receipt = json.loads(published)
            browser.require(receipt.get('exit') == 0 and
                            Path(receipt['executable']).resolve() == binary and
                            receipt['executable_sha256'] == expected,
                            'Production receipt does not match the pinned executable')
            if not receipt.get('frozen_compilation'):
                preserve_parallel_compilation_receipt(output, binary, receipt, published,
                    selected, manifest, preserved)
                manifest['passed'] = True
                return preserved
            meta_path = Path(receipt['frozen_compilation'])
            metadata = meta_path.read_bytes()
            frozen = json.loads(metadata)
            sources = [(Path(path), digest) for path, digest in frozen['sealed_inputs'].items()
                       if Path(path).name.endswith('.i')]
            browser.require(any(path.name == '0-Vox.c.i' for path, _ in sources),
                            'Production receipt lacks preprocessed browser C')
            folder = output / 'production-compilation' / expected
            folder.mkdir(parents=True, exist_ok=False)
            for name, origin, data in [('published-receipt.json', published_path, published),
                                       ('frozen-compile.json', meta_path, metadata)]:
                target = folder / name
                target.write_bytes(data)
                preserved.add(target)
                manifest['files'][str(target)] = dict(source=str(origin),
                    sha256=hashlib.sha256(data).hexdigest(), bytes=len(data))
            for index, (source, digest) in enumerate(sorted(sources)):
                target = folder / f'{index}-{source.name}'
                shutil.copyfile(source, target)
                actual = browser.fingerprint({target})[str(target)]
                browser.require(actual['sha256'] == digest,
                                f'Compiler artifact changed while preserving it: {source}')
                preserved.add(target)
                manifest['files'][str(target)] = dict(source=str(source), **actual)
            browser.require(published_path.read_bytes() == published and
                            browser.fingerprint({binary})[str(binary)]['sha256'] == expected,
                            'Production browser or receipt changed during preservation')
            for engine in selected:
                manifest['engines'][engine] = dict(executable_sha256=expected,
                    evidence_directory=str(folder))
        manifest['passed'] = True
    except Exception as error:
        manifest['error'] = str(error)
        raise
    finally:
        browser.write_json(manifest_path, manifest)
    return preserved


def main():
    args = parse_args()
    expected = fixture_expectations(args.archive)
    preserved = None
    if args.preserve_inputs:
        preserved = preserve_replay_inputs(args.archive,
            {engine: path for engine, path in [('vox', args.expected_vox), ('brave', args.expected_brave)]
             if path}, args.preserve_inputs)
        browser.require(preserved['replay_manifest_sha256'] == expected['manifest_sha256'],
                        'Replay manifest changed after fixture validation')
    args.output.mkdir(parents=True, exist_ok=False)
    args.audit_config = args.output / 'audit-config.json'
    browser.write_json(args.audit_config, dict(selectors=SELECTORS))
    args.expected = None
    args.instruction_scope = 'launch'
    args.audit_vox_capture_ownership = True
    args.vox_arguments = ['--js-engine', 'javascriptcore']
    args.content_validator = lambda audit: validate_document(audit, expected)
    args.audit_expression = audit_expression()
    # Only viewport images are required: offscreen lazy images need not decode.
    args.readiness_expression = f'''location.href==={json.dumps(URL)} && document.readyState==='complete'
      && document.fonts.status==='loaded' && innerWidth===1024 && innerHeight===768
      && devicePixelRatio==={args.scale} && [...document.images].filter(i=>{{const r=i.getBoundingClientRect();
        return r.width>0&&r.height>0&&r.x<1024&&r.y<768&&r.right>0&&r.bottom>0}})
        .every(i=>i.complete&&i.naturalWidth>0)'''
    # `complete` establishes resource availability; decode() also waits for the
    # image decoder before the unchanged two-second raster settlement period.
    args.post_readiness_expression = '''Promise.all([...document.images].filter(i=>{
      const r=i.getBoundingClientRect();return r.width>0&&r.height>0&&r.x<1024&&r.y<768
        &&r.right>0&&r.bottom>0}).map(i=>i.decode())).then(()=>true)'''
    sources = [('vox', args.vox_app), ('brave', args.brave_app)]
    if args.control_vox_app:
        sources.append(('control', args.control_vox_app))
    apps = browser.reference_browser_apps(args.output, sources)
    paths = {path for app in apps.values() for path in app.rglob('*') if path.is_file()}
    paths.add(args.output / 'browser-apps.json')
    paths.update(browser.native_dependencies(apps['vox'] / 'Contents/MacOS/Vox'))
    paths.update(path for path in args.archive.rglob('*') if path.is_file())
    paths.update(path for path in browser.COALITION_SERVICES if path.is_file())
    paths.update(REPO / 'tools' / name for name in ('bbc_browser_instructions.py',
        'hacker_news_browser_instructions.py', 'page_archive.py', 'coalition_instruction_counts.py',
        'measure_sealed_github_instructions.py', 'measure_browser_instructions.py',
        'capture_brave_reference.py', 'process_instruction_counts.py', 'run_memory_bounded.py',
        'check_pixel_equality.py', 'pikabu_browser_instructions.py'))
    paths.add(REPO / 'tools/stackoverflow_browser_instructions.py')
    paths.add(REPO / 'tools/browser_input_evidence.py')
    paths.update(path for path in (args.expected_vox, args.expected_brave) if path)
    paths.update((args.diff_tool, args.audit_config))
    if args.preserve_inputs:
        paths.add(args.preserve_inputs)
    pinned = browser.fingerprint(paths)
    compilation_paths = preserve_production_compilation(args.output, apps, pinned)
    browser.require(browser.fingerprint(paths) == pinned,
                    'Pinned inputs changed during compiler evidence preservation')
    paths.update(compilation_paths)
    pinned.update(browser.fingerprint(compilation_paths))
    if preserved:
        verify_preservation_identity(preserved, pinned)
    browser.write_json(args.output / 'inputs.json', dict(files=pinned, scope=SCOPE,
        production_compilation_evidence=str(args.output / 'production-compilation.json'),
        preserved_input_archive=preserved,
        font_generation_diagnostic_policy='Per-cache-hit tracing is rejected outside reference diagnostics; counting alone must not enable it',
        fixture=expected, original_scripts_retained=True, author_javascript_enabled=True,
        viewport=[1024, 768], scale=args.scale, settle_seconds=args.settle_seconds,
        javascript_backends=dict(vox='javascriptcore', brave='v8'),
        vox_capture_ownership_policy='Require a stable live ownership scan matching the native PNG endpoint task totals; cumulative counters include exited tasks',
        jsc_baseline_environment=dict(vox=jsc_baseline_environment(args.jsc_baseline_warmup),
            control=jsc_baseline_environment(args.control_jsc_baseline_warmup)),
        retain_incremental_webp_paint_policy=args.retain_incremental_webp_paint_policy,
        webp_policy_credit='None: explicit historical workload compatibility only',
        retain_logical_paint_snapping=args.retain_logical_paint_snapping,
        paint_snapping_policy='historical logical pixels' if args.retain_logical_paint_snapping else 'default presenting device grid',
        paint_snapping_policy_credit='None: both Vox arms retain the declared policy; references unchanged',
        retain_css_layout_for_svg=args.retain_css_layout_for_svg,
        svg_layout_policy='historical CSS coordinates' if args.retain_css_layout_for_svg else 'default device-density coordinates',
        svg_layout_policy_credit='None: both Vox arms retain the declared policy; references unchanged',
        control_disable_retained_simple_svg=args.control_disable_retained_simple_svg,
        control_disable_retained_formatting_trees=args.control_disable_retained_formatting_trees,
        control_retain_flow_style_identities=args.control_retain_flow_style_identities,
        control_retain_cascade_value_copies=args.control_retain_cascade_value_copies,
        control_retain_broad_conditional_rule_deletion=args.control_retain_broad_conditional_rule_deletion,
        control_retain_empty_deleted_conditional_targets=args.control_retain_empty_deleted_conditional_targets,
        control_retain_descendant_navigable_scan=args.control_retain_descendant_navigable_scan,
        control_retain_uncached_item_paint=args.control_retain_uncached_item_paint,
        control_retain_inline_measurement_indefinite_height=args.control_retain_inline_measurement_indefinite_height,
        control_retain_initial_resource_viewport_after_style=args.control_retain_initial_resource_viewport_after_style,
        control_retain_parent_longhand_hashing=args.control_retain_parent_longhand_hashing,
        control_retain_invalidation_value_copies=args.control_retain_invalidation_value_copies,
        control_retain_absolute_length_context=args.control_retain_absolute_length_context,
        control_retain_image_attribute_source_parse=args.control_retain_image_attribute_source_parse,
        control_retain_ancestor_rehash=args.control_retain_ancestor_rehash,
        control_retain_property_edge_resolution=args.control_retain_property_edge_resolution,
        control_retain_definite_intrinsic_measurement=args.control_retain_definite_intrinsic_measurement,
        control_retain_selector_substring_scan=args.control_retain_selector_substring_scan,
        control_retain_redundant_sheet_removal=args.control_retain_redundant_sheet_removal,
        control_retain_full_font_input_scan=args.control_retain_full_font_input_scan,
        control_disable_early_text_font_requests=args.control_disable_early_text_font_requests,
        control_retain_selector_rule_font_sync=args.control_retain_selector_rule_font_sync,
        control_retain_empty_procedural_styles=args.control_retain_empty_procedural_styles,
        control_disable_grid_width_only=args.control_disable_grid_width_only,
        control_disable_stationary_raster=args.control_disable_stationary_raster,
        control_disable_client_geometry_index=args.control_disable_client_geometry_index,
        control_disable_tracked_persistent_shortcut=args.control_disable_tracked_persistent_shortcut,
        control_disable_attribute_case_buckets=args.control_disable_attribute_case_buckets,
        control_disable_persistent_scope_jumps=args.control_disable_persistent_scope_jumps,
        control_disable_inline_measurement_reuse=args.control_disable_inline_measurement_reuse,
        control_copy_stationary_raster_pixels=args.control_copy_stationary_raster_pixels,
        control_disable_extended_longhand_reuse=args.control_disable_extended_longhand_reuse,
        control_disable_color_longhand_reuse=args.control_disable_color_longhand_reuse,
        control_copy_stationary_raster_commands=args.control_copy_stationary_raster_commands,
        control_disable_retained_flow_items=args.control_disable_retained_flow_items,
        control_disable_face_specific_font_display=args.control_disable_face_specific_font_display,
        control_disable_constant_longhand_reuse=args.control_disable_constant_longhand_reuse,
        control_disable_intrinsic_font_reuse=args.control_disable_intrinsic_font_reuse,
        control_disable_pending_intrinsic_font_reuse=args.control_disable_pending_intrinsic_font_reuse,
        control_disable_live_pending_text_reuse=args.control_disable_live_pending_text_reuse,
        control_disable_live_pending_font_refresh=args.control_disable_live_pending_font_refresh,
        control_disable_positioned_image_ratio_reuse=args.control_disable_positioned_image_ratio_reuse,
        control_disable_positioned_definite_image_reuse=args.control_disable_positioned_definite_image_reuse,
        control_disable_conditional_sheet_invalidation=args.control_disable_conditional_sheet_invalidation,
        control_disable_inactive_conditional_sheet_skip=args.control_disable_inactive_conditional_sheet_skip,
        control_disable_classic_import_word_scan=args.control_disable_classic_import_word_scan,
        control_disable_longhand_shape_reuse=args.control_disable_longhand_shape_reuse,
        control_disable_longhand_eligibility_first=args.control_disable_longhand_eligibility_first,
        control_disable_protected_value_index=args.control_disable_protected_value_index,
        control_disable_shared_element_geometry=args.control_disable_shared_element_geometry,
        control_disable_shared_node_properties=args.control_disable_shared_node_properties,
        control_disable_attribute_tag_buckets=args.control_disable_attribute_tag_buckets,
        control_disable_deleted_style_rule_invalidation=args.control_disable_deleted_style_rule_invalidation,
        control_disable_targeted_user_style_changes=args.control_disable_targeted_user_style_changes,
        control_disable_static_user_style_filter=args.control_disable_static_user_style_filter,
        control_disable_document_filter_memo=args.control_disable_document_filter_memo,
        control_disable_intrinsic_seed_visits=args.control_disable_intrinsic_seed_visits,
        control_disable_retained_grid_layout=args.control_disable_retained_grid_layout,
        control_disable_grid_measurement_reuse=args.control_disable_grid_measurement_reuse,
        control_disable_compact_query_envelope=args.control_disable_compact_query_envelope,
        control_disable_committed_inline_measurement_reuse=args.control_disable_committed_inline_measurement_reuse,
        control_disable_committed_grid_measurement_reuse=args.control_disable_committed_grid_measurement_reuse,
        control_disable_inline_tree_measurement_reuse=args.control_disable_inline_tree_measurement_reuse,
        control_retain_covered_style_sheet_walk=args.control_retain_covered_style_sheet_walk,
        control_retain_covered_style_sheet_anchor_walks=args.control_retain_covered_style_sheet_anchor_walks,
        control_disable_svg_measurement_reuse=args.control_disable_svg_measurement_reuse,
        control_disable_relative_measurement_reuse=args.control_disable_relative_measurement_reuse,
        control_disable_markerless_measurements=args.control_disable_markerless_measurements,
        control_disable_grid_placement_reuse=args.control_disable_grid_placement_reuse,
        control_disable_unused_measurement_heights=args.control_disable_unused_measurement_heights,
        control_disable_native_callback_call=args.control_disable_native_callback_call,
        control_disable_object_receiver_call=args.control_disable_object_receiver_call,
        control_disable_retained_flow_svg_trees=args.control_disable_retained_flow_svg_trees,
        control_disable_extended_image_measurements=args.control_disable_extended_image_measurements,
        control_disable_flex_image_measurement_reuse=args.control_disable_flex_image_measurement_reuse,
        control_disable_flex_measurement_reuse=args.control_disable_flex_measurement_reuse,
        control_disable_frame_task_layout_coalescing=args.control_disable_frame_task_layout_coalescing,
        control_disable_adblock_token_reuse=args.control_disable_adblock_token_reuse,
        control_disable_grid_auto_height_seed=args.control_disable_grid_auto_height_seed,
        control_disable_resolved_edge_reuse=args.control_disable_resolved_edge_reuse,
        brave_post_readiness_expression=args.post_readiness_expression,
        readiness_correction='Await visible image decode before the original settlement; no engine credit',
        system=subprocess.check_output(['sw_vers'], text=True)))
    replay = Replay(args.archive, args.output / 'replay')
    thread = threading.Thread(target=replay.server.serve_forever, daemon=True)
    thread.start()
    pairs = []
    try:
        public = subprocess.check_output(['openssl', 'x509', '-in', replay.ready['ca'], '-pubkey', '-noout'])
        der = subprocess.check_output(['openssl', 'pkey', '-pubin', '-outform', 'der'], input=public)
        spki = base64.b64encode(hashlib.sha256(der).digest()).decode()
        args.url = URL
        args.vox_environment = replay_vox_environment(args, replay.ready)
        args.brave_proxy_argument = '--proxy-server=' + replay.ready['proxy'].replace('socks5h:', 'socks5:')
        args.brave_arguments = ['--ignore-certificate-errors-spki-list=' + spki]
        if not args.capture_reference:
            paths, pinned = discover_runtime_libraries(args, apps, paths, pinned)
            inputs = json.loads((args.output / 'inputs.json').read_text())
            inputs['files_before_runtime_discovery'] = inputs['files']
            inputs['files'] = pinned
            inputs['runtime_library_manifest'] = str(args.output / 'runtime-libraries.json')
            inputs['runtime_library_policy'] = ('Late-bound libraries discovered in separate '
                'diagnostic launches and pinned before acceptance; no dyld tracing in acceptance')
            browser.write_json(args.output / 'inputs.json', inputs)
        for index in range(1 if args.capture_reference else args.repeat):
            pair = {}
            order = trial_order(index, bool(args.control_vox_app))
            if args.capture_reference and args.reference_engine != 'both':
                order = [args.reference_engine]
            for engine in order:
                row = run_trial(engine, apps[engine], args.output / f'pair-{index+1}-{engine}', args)
                if engine in ('vox', 'control'):
                    try:
                        log = (args.output / f'pair-{index+1}-{engine}/browser.log').read_text(errors='replace')
                    except OSError:
                        log = None
                    audit_instruction_logging(row, log, args.capture_reference)
                row['scope'] = SCOPE
                browser.write_json(args.output / f'pair-{index+1}-{engine}/result.json', row)
                pair[engine] = row
                verify_benchmark_inputs(paths, pinned,
                                        args.output / f'pair-{index+1}-{engine}')
                print(json.dumps(browser.progress_record(index+1, engine, row, 'launch')), flush=True)
            pairs.append(pair)
            browser.write_json(args.output / 'pairs.json', pairs)
        if args.capture_reference:
            summary = dict(reference_capture=True, passed=all(row['exit'] == 0 for row in pairs[0].values()),
                           acceptance=False)
        else:
            try:
                summary = evaluate_cohort(pairs, bool(args.control_vox_app))
            except RuntimeError as error:
                summary = dict(passed=False, error=str(error), pairs=len(pairs))
            summary['cross_browser_pixels'] = browser.compare(args.expected_brave, args.expected_vox,
                args.output / 'cross-browser.diff.png', args.diff_tool)
        browser.write_json(args.output / 'summary.json', summary)
        print(json.dumps(summary, indent=2), flush=True)
        return 0 if summary['passed'] else 1
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        thread.join(timeout=5)


if __name__ == '__main__':
    raise SystemExit(main())
