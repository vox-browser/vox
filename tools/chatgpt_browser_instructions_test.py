import base64
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import capture_chatgpt_archive as capture
import chatgpt_browser_instructions as comparison


class ChatGPTInstructionsTests(unittest.TestCase):
    def pairs(self, count=7, vox=95, brave=100):
        def row(value):
            return dict(exit=0, pixels_exact=True, content_exact=True,
                        launch_instruction_interval=dict(lower=value, upper=value))
        return [dict(vox=row(vox), brave=row(brave)) for _ in range(count)]

    def test_five_percent_gate_includes_boundary_exactly(self):
        self.assertTrue(comparison.summarize(self.pairs())['passed'])
        self.assertFalse(comparison.summarize(self.pairs(vox=96))['passed'])

    def test_gate_uses_worst_vox_and_best_brave_including_outliers(self):
        pairs = self.pairs(vox=90)
        pairs[0]['brave']['launch_instruction_interval']['lower'] = 94
        self.assertFalse(comparison.summarize(pairs)['passed'])
        pairs = self.pairs(vox=90)
        pairs[-1]['vox']['launch_instruction_interval']['upper'] = 96
        self.assertFalse(comparison.summarize(pairs)['passed'])

    def test_integer_gate_preserves_counts_above_float_precision(self):
        scale = 2 ** 60
        pairs = self.pairs(vox=95 * scale, brave=100 * scale)
        self.assertTrue(comparison.summarize(pairs)['passed'])
        pairs[0]['vox']['launch_instruction_interval']['upper'] += 1
        self.assertFalse(comparison.summarize(pairs)['passed'])

    def test_diagnostic_cohort_cannot_supply_acceptance(self):
        result = comparison.summarize(self.pairs(count=6, vox=1))
        self.assertFalse(result['passed'])
        self.assertTrue(result['diagnostic_only'])

    def test_failed_load_or_changed_pixels_invalidates_gate(self):
        for key, value in [('exit', 6), ('pixels_exact', False), ('content_exact', False)]:
            pairs = self.pairs(vox=1)
            pairs[0]['vox'][key] = value
            with self.assertRaises(RuntimeError):
                comparison.summarize(pairs)

    def state(self):
        return dict(url=capture.URL, title='ChatGPT: Chat, Work, Create & Code with AI',
                    ready='complete', editor=True, heading='Where should we begin?',
                    fonts='loaded', viewport=[1024, 768], scale=2, serviceBlocked=False)

    def test_capture_requires_real_homepage_editor_and_readiness(self):
        self.assertTrue(capture.ready(self.state()))
        for key, value in [('url', 'https://example.com/'), ('title', 'Just a moment...'),
                           ('editor', False), ('ready', 'interactive'), ('serviceBlocked', True),
                           ('fonts', 'loading'), ('viewport', [800, 600])]:
            state = self.state()
            state[key] = value
            self.assertFalse(capture.ready(state), key)

    def test_capture_retains_original_script_bytes_and_response_variation(self):
        with tempfile.TemporaryDirectory() as temporary:
            out = Path(temporary)
            (out / 'bodies').mkdir()
            client = capture.Capture.__new__(capture.Capture)
            client.output, client.responses, client.errors = out, {}, []
            body = b'<script>window.original = true;</script>'
            response = dict(url=capture.URL, status=200,
                            headers={'Content-Type': 'text/html', 'Content-Encoding': 'gzip'})
            client.body(dict(result=dict(body=base64.b64encode(body).decode(), base64Encoded=True)),
                        dict(method='GET'), response)
            entry = client.responses[capture.URL]
            self.assertEqual((out / 'bodies' / entry['sha256']).read_bytes(), body)
            self.assertEqual(entry['headers'], [dict(name='Content-Type', value='text/html')])
            client.body(dict(result=dict(body='different')), dict(method='GET'), response)
            self.assertEqual(client.responses[capture.URL], entry)
            self.assertEqual(len(client.errors), 1)

    def audit(self):
        groups = [dict(name=name, count=1, elements=[dict(rect=dict(width=50, height=20))])
                  for name in ['headings', 'editors', 'buttons', 'links']]
        return dict(url=capture.URL, title='ChatGPT', ready='complete',
                    viewport_width=1024, viewport_height=768, selections=groups,
                    native_reported_errors=[], javascript_diagnostics=[])

    def test_content_rejects_truncation_missing_editor_and_runtime_errors(self):
        comparison.content_gate(self.audit(), 'ChatGPT')
        truncated = self.audit()
        truncated['selections'][0]['count'] = 2
        invisible = self.audit()
        invisible['selections'][1]['elements'][0]['rect']['width'] = 0
        native_error = self.audit()
        native_error['native_reported_errors'] = ['error']
        for audit in [truncated, invisible, native_error]:
            with self.assertRaises(RuntimeError):
                comparison.content_gate(audit, 'ChatGPT')

    def test_content_checks_full_source_link_and_heading_identity(self):
        audit = self.audit()
        groups = {g['name']: g for g in audit['selections']}
        groups['headings']['elements'][0]['text'] = 'Where should we begin?'
        groups['links']['elements'][0].update(text='Terms', attributes={'href': '/terms'})
        expected = dict(headings=['Where should we begin?'], links=[('/terms', 'Terms')],
                        buttons=1, editors=1)
        comparison.content_gate(audit, 'ChatGPT', expected)
        groups['links']['elements'][0]['attributes']['href'] = '/different'
        with self.assertRaisesRegex(RuntimeError, 'link identity'):
            comparison.content_gate(audit, 'ChatGPT', expected)

    def test_hydrated_hidden_dialog_count_can_change_with_exact_viewport_controls(self):
        audit = self.audit()
        buttons = next(g for g in audit['selections'] if g['name'] == 'buttons')
        buttons['elements'][0].update(text='Log in', attributes={})
        hidden = dict(text='Sign up for free', attributes={}, rect=dict(width=0, height=0))
        buttons['elements'].append(hidden)
        buttons['count'] = 2
        reference = comparison.viewport_button_identities(audit)
        self.assertEqual(reference, [('Log in', '')])
        comparison.content_gate(audit, 'ChatGPT', reference_buttons=reference)
        buttons['elements'].pop()
        buttons['count'] = 1
        comparison.content_gate(audit, 'ChatGPT', reference_buttons=reference)

    def test_hidden_replacement_cannot_hide_a_missing_viewport_button(self):
        audit = self.audit()
        buttons = next(g for g in audit['selections'] if g['name'] == 'buttons')
        buttons['elements'][0].update(text='Log in', attributes={})
        reference = comparison.viewport_button_identities(audit)
        buttons['elements'][0]['rect']['width'] = 0
        with self.assertRaisesRegex(RuntimeError, 'button identity'):
            comparison.content_gate(audit, 'ChatGPT', reference_buttons=reference)

    def test_bootstrap_marker_is_required_for_scripted_comparison(self):
        audit = self.audit()
        with self.assertRaisesRegex(RuntimeError, 'bootstrap'):
            comparison.content_gate(audit, 'ChatGPT', require_bootstrap=True)
        audit['selections'].append(dict(name='bootstrap', count=1, elements=[]))
        comparison.content_gate(audit, 'ChatGPT', require_bootstrap=True)

    def test_author_exceptions_are_retained_and_fail_content_gate(self):
        client = comparison.ChatGPTCDP.__new__(comparison.ChatGPTCDP)
        client.author_exceptions = []
        event = dict(method='Runtime.exceptionThrown', params=dict(exceptionDetails=dict(text='unhandled')))
        with mock.patch.object(comparison.CDP, 'receive', return_value=event):
            client.receive()
        value = self.audit()
        with mock.patch.object(comparison.CDP, 'call', return_value=dict(result=dict(value=value))):
            result = client.call('Runtime.evaluate', dict(expression=comparison.audit_expression()))
        with self.assertRaisesRegex(RuntimeError, 'script/native errors'):
            comparison.content_gate(result['result']['value'], 'ChatGPT')


if __name__ == '__main__':
    unittest.main()
