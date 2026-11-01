import copy
import unittest
from measure_brave_scroll import MARK, summarize


def trace():
    events=[dict(name=MARK,pid=42,ts=-1)]
    for i in range(4):
        events += [
            dict(name='EventLatency',ph='b',pid=42,ts=i*100000,args=dict(event_latency=dict(
                event_type='FIRST_GESTURE_SCROLL_UPDATE',event_latency_id=i))),
            dict(name='ScrollJankV4',ph='b',pid=42,ts=i*100000,args=dict(scroll_jank_v4=dict(
                result_id=i,damage_type='DAMAGING',updates=dict(real=dict(
                    first_event_latency_id=i,total_raw_delta_pixels=8.4))))),
            dict(name='Presentation',ph='n',pid=42,ts=i*100000+20000,
                 args=dict(scroll_jank_v4=dict(result_id=i))),
            dict(name='PipelineReporter',ph='b',pid=42,ts=i*100000,id2=dict(local='0x1'),
                 args=dict(frame_reporter=dict(state='STATE_PRESENTED_ALL',has_missing_content=False))),
            dict(name='PipelineReporter',ph='e',pid=42,ts=i*100000+20000,id2=dict(local='0x1'),args={})]
    return dict(traceEvents=events)


class BraveScrollTests(unittest.TestCase):
    def test_full_input_window_includes_boundary_gaps_and_excludes_tail(self):
        s=summarize(trace(),4)
        self.assertEqual(s['completed_inputs'],4)
        self.assertEqual(s['completed_presentations'],4)
        self.assertEqual(s['measured_presentations'],3)
        self.assertEqual(s['moving_intervals'],2)
        self.assertAlmostEqual(s['mean_scroll_fps'],2/.3)
        self.assertEqual(s['first_counted_scroll_delay_us'],120000)
        self.assertEqual(s['last_scroll_publication_gap_us'],80000)
        self.assertEqual(s['fraction_over_budget'],1)
        self.assertEqual(s['scroll_interval_us']['p95'],100000)

    def test_animation_and_foreign_renderer_frames_cannot_inflate_scroll_fps(self):
        t=trace(); original=summarize(t,4)
        t['traceEvents'] += [dict(name='Presentation',ph='n',pid=42,ts=25000,args=dict(scroll_jank_v4=dict(result_id=999)))]
        foreign=copy.deepcopy(t['traceEvents'][1:])
        for e in foreign:e['pid']=99
        t['traceEvents'] += foreign
        self.assertEqual(summarize(t,4),original)

    def test_coalesced_inputs_need_not_each_have_a_separate_presentation(self):
        t=trace()
        t['traceEvents'].append(dict(name='EventLatency',ph='b',pid=42,ts=150000,
            args=dict(event_latency=dict(event_type='GESTURE_SCROLL_UPDATE',event_latency_id=99))))
        s=summarize(t,5)
        self.assertEqual(s['completed_inputs'],5)
        self.assertEqual(s['completed_presentations'],4)

    def test_large_signed_frame_ids_keep_exact_identity(self):
        t=trace()
        for e in t['traceEvents']:
            data=e.get('args',{}).get('scroll_jank_v4')
            if data is not None:data['result_id'] -= 2**62
        self.assertEqual(summarize(t,4)['completed_presentations'],4)

    def test_missing_and_duplicate_input_records_rejected(self):
        for duplicate in [False,True]:
            t=trace()
            if duplicate:t['traceEvents'].append(copy.deepcopy(t['traceEvents'][1]))
            else:t['traceEvents'].pop(1)
            with self.assertRaisesRegex(ValueError,'inputs'):summarize(t,4)

    def test_requires_unambiguous_target_and_last_input_presentation(self):
        t=trace();t['traceEvents'].pop(0)
        with self.assertRaisesRegex(ValueError,'marker'):summarize(t,4)
        t=trace();t['traceEvents'].append(copy.deepcopy(t['traceEvents'][0]))
        with self.assertRaisesRegex(ValueError,'marker'):summarize(t,4)
        t=trace();t['traceEvents']=[e for e in t['traceEvents'] if not (
            e['name']=='ScrollJankV4' and e['args']['scroll_jank_v4']['result_id']==3)]
        with self.assertRaisesRegex(ValueError,'Last input'):summarize(t,4)

    def test_feedback_must_be_unique_and_confirmed_by_complete_compositor_frame(self):
        t=trace(); t['traceEvents'].append(copy.deepcopy(t['traceEvents'][3]))
        with self.assertRaisesRegex(ValueError,'Duplicate presentation'):summarize(t,4)
        t=trace();t['traceEvents'][4]['args']['frame_reporter']['state']='STATE_DROPPED'
        with self.assertRaisesRegex(ValueError,'complete compositor'):summarize(t,4)
        t=trace();t['traceEvents'][4]['args']['frame_reporter']['has_missing_content']=True
        with self.assertRaisesRegex(ValueError,'complete compositor'):summarize(t,4)
        t=trace();t['traceEvents'].pop(3)
        with self.assertRaisesRegex(ValueError,'Missing damaging'):summarize(t,4)

    def test_unknown_input_or_presentation_before_input_is_rejected(self):
        t=trace();t['traceEvents'][2]['args']['scroll_jank_v4']['updates']['real']['first_event_latency_id']=999
        with self.assertRaisesRegex(ValueError,'unmeasured input'):summarize(t,4)
        t=trace();t['traceEvents'][3]['ts']=-1
        with self.assertRaisesRegex(ValueError,'precedes'):summarize(t,4)

    def test_damaging_flag_and_nonzero_scroll_delta_required(self):
        for field,value in [('damage_type','NON_DAMAGING'),('delta',0)]:
            t=trace()
            for e in t['traceEvents']:
                if e['name']=='ScrollJankV4':
                    data=e['args']['scroll_jank_v4']
                    if field=='delta':data['updates']['real']['total_raw_delta_pixels']=value
                    else:data[field]=value
            with self.assertRaisesRegex(ValueError,'Missing damaging'):summarize(t,4)


if __name__=='__main__':unittest.main()
