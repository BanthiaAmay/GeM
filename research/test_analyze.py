import unittest
from datetime import datetime, timezone
from analyze import fisher_exact, analyze

class ResearchTests(unittest.TestCase):
    def test_known_fisher_table(self):
        self.assertAlmostEqual(fisher_exact(1,9,11,3),0.0027594561852200836)
    def test_no_comparison_does_not_claim_significance(self):
        row=dict(participant_id='a',cohort='tool_assisted',followup_due_at='2026-01-01T00:00:00Z',assignment_method='convenience',engaged='true',registration_intent='true',disqualified_by_choice='false',verified_registration='false',verified_first_order='false')
        result=analyze([row],datetime(2026,9,9,tzinfo=timezone.utc))
        self.assertIn('reason',result['primary_outcome'])
        self.assertEqual(result['groups']['tool_assisted']['verified_registration']['count'],0)
    def test_pending_followup_not_counted(self):
        row=dict(participant_id='a',followup_due_at='2030-01-01T00:00:00Z')
        self.assertEqual(analyze([row],datetime(2026,9,9,tzinfo=timezone.utc))['completed_followup'],0)
    def test_duplicate_is_rejected(self):
        with self.assertRaises(ValueError):analyze([{'participant_id':'a'},{'participant_id':'a'}],datetime.now(timezone.utc))
if __name__=='__main__': unittest.main()
