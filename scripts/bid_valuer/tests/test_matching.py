import unittest

from bid_valuer.items import Item
from bid_valuer.matching import normalise as n, scoring, specifications as sp
from bid_valuer.sources.base import Offer


def offer(title, price=1000.0, unit='Piece', currency='INR', **kw):
    return Offer('test', kw.pop('url', 'https://example.in/p/' + title.replace(' ', '-')),
                 title, price, currency, unit, **kw)


class Normalise(unittest.TestCase):
    def test_units(self):
        self.assertEqual(n.unit_of('Nos'), ('count', 1))
        self.assertEqual(n.unit_of('Kg'), ('mass', 1000))
        self.assertEqual(n.unit_of('sq ft'), ('area', 0.092903))
        self.assertIsNone(n.unit_of('lot'))
        self.assertIsNone(n.unit_of(''))

    def test_pack_and_conversion(self):
        per_piece = n.pack_of('Office Chair', 'Piece')
        self.assertEqual(n.price_per_item_unit(2000, per_piece, 'Nos'), 2000)
        ten = n.pack_of('Ball pen, pack of 10', '')
        self.assertEqual(n.price_per_item_unit(100, ten, 'Nos'), 10)
        dozen = n.pack_of('Ball pen', 'Dozen')
        self.assertEqual(n.price_per_item_unit(120, dozen, 'Nos'), 10)
        bottles = n.pack_of('Hand wash 500 ml x 12', '')
        self.assertAlmostEqual(n.price_per_item_unit(1200, bottles, 'Litre'), 200)
        per_kg = n.pack_of('Detergent powder', 'Kg')
        self.assertEqual(n.price_per_item_unit(90, per_kg, 'Kg'), 90)
        self.assertEqual(n.price_per_item_unit(90, per_kg, 'gm'), 0.09)

    def test_unconvertible_units_are_refused(self):
        self.assertIsNone(n.price_per_item_unit(1500, n.pack_of('Steel wardrobe', 'sq ft'), 'Nos'))
        self.assertIsNone(n.price_per_item_unit(90, n.pack_of('Detergent', 'Kg'), 'Litre'))
        self.assertIsNone(n.price_per_item_unit(100, n.pack_of('Chair', 'Piece'), ''),
                          'a missing bid unit is never assumed')
        # A size in a title is not pack contents for a count unit...
        self.assertEqual(n.price_per_item_unit(3000, n.pack_of('Chair 45 cm seat', ''), 'Nos'), 3000)
        # ...and a count listing cannot price a measured unit.
        self.assertIsNone(n.price_per_item_unit(3000, n.pack_of('Chair', ''), 'Kg'))

    def test_prices_and_currency(self):
        self.assertEqual(n.parse_price('₹ 1,23,456.50/Piece'), (123456.5, 'INR'))
        self.assertEqual(n.parse_price('Rs. 450'), (450.0, 'INR'))
        self.assertEqual(n.parse_price('$12.99'), (12.99, 'USD'))
        self.assertEqual(n.parse_price('450'), (450.0, None), 'no currency is never read as INR')

    def test_gst(self):
        self.assertEqual(n.parse_gst('Price inclusive of all taxes'), (True, None))
        self.assertEqual(n.parse_gst('₹ 500 + GST @ 18%'), (False, 18.0))
        self.assertEqual(n.parse_gst('Exclusive of GST'), (False, None))
        self.assertEqual(n.parse_gst('₹ 500/Piece'), (None, None))
        self.assertEqual(n.to_gst_inclusive(100, True, None), (100, 'gst_inclusive'))
        self.assertEqual(n.to_gst_inclusive(100, False, 18), (118.0, 'gst_inclusive'))
        self.assertEqual(n.to_gst_inclusive(100, False, None), (100, 'gst_exclusive'))
        self.assertEqual(n.to_gst_inclusive(100, None, 18), (100, 'unknown'))

    def test_seller_key(self):
        self.assertEqual(n.seller_key('Sharan Elecmech Private Limited'),
                         n.seller_key('SHARAN ELECMECH PVT. LTD.'))
        self.assertEqual(n.seller_key('Any name', '27AAPFU0939F1ZV'), 'gstin:27AAPFU0939F1ZV')
        self.assertEqual(n.seller_key('', fallback='shop.example.in'), 'site:shop.example.in')


class Specifications(unittest.TestCase):
    def test_measures_and_ranges(self):
        attrs = sp.measures('LED street light 36W, 220-240 V, IP66, 5700K')
        self.assertEqual(attrs['power_w'], {(36.0, 36.0)})
        self.assertEqual(attrs['voltage_v'], {(220.0, 240.0)})
        self.assertEqual(attrs['ip_rating'], {(66.0, 66.0)})
        self.assertEqual(attrs['colour_temp_k'], {(5700.0, 5700.0)})
        self.assertNotIn('length_mm', sp.measures('2 in 1 printer'))
        self.assertTrue(sp.overlaps(sp.measures('230 V')['voltage_v'], attrs['voltage_v']))

    def test_spec_text_uses_key_unit_hint(self):
        self.assertIn('36 Watt', sp.spec_text({'System Wattage (in Watt)': '36'}))
        self.assertEqual(sp.measures(sp.spec_text({'System Wattage (in Watt)': '36'}))['power_w'],
                         {(36.0, 36.0)})

    def test_materials_and_models(self):
        self.assertEqual(sp.materials('Mild Steel Cupboard'), {'mild steel'})
        self.assertFalse(sp.materials_conflict({'mild steel'}, {'steel'}))
        self.assertTrue(sp.materials_conflict({'mesh'}, {'polyester'}))
        self.assertIn('LJ1220', sp.model_tokens('HP LaserJet LJ-1220 printer'))
        self.assertNotIn('36W', sp.model_tokens('36W light'))


class Scoring(unittest.TestCase):
    street = Item('LED Luminaire For Road And Street Lights', 10, 'Nos',
                  spec={'System Wattage (in Watt)': '36'})

    def test_accepts_matching_product(self):
        m = scoring.score(self.street, offer('LED Street Light 36W', 2500, gst_included=True))
        self.assertTrue(m.accepted, m.reason)
        self.assertEqual((m.unit_price, m.tax_basis), (2500, 'gst_inclusive'))

    def test_hard_rejects(self):
        cases = {
            'power_w conflict': offer('LED Street Light 45W'),
            'unit not convertible': offer('LED Street Light 36W', unit='sq ft'),
            'different product type': offer('LED Panel Light 36W'),
        }
        for reason, candidate in cases.items():
            m = scoring.score(self.street, candidate)
            self.assertFalse(m.accepted)
            self.assertIn(reason, m.reason)

    def test_brand_and_model_conflicts(self):
        printer = Item('Laser Printer', 2, 'Nos', brand='HP', model='LJ1220')
        self.assertIn('brand conflict', scoring.score(printer, offer('Laser Printer', brand='Canon')).reason)
        self.assertIn('model conflict', scoring.score(printer, offer('HP Laser Printer M126nw', brand='HP')).reason)
        self.assertTrue(scoring.score(printer, offer('HP LaserJet LJ1220 Laser Printer', brand='HP')).accepted)

    def test_similar_name_alone_is_not_enough(self):
        chair = Item('Office Chair', 5, 'Nos')
        m = scoring.score(chair, offer('Office Chair'))
        self.assertFalse(m.accepted)
        self.assertIn('no brand, size or specification', m.reason)

    def test_spec_field_conflict_and_agreement(self):
        almirah = Item('Steel Almirah', 10, 'Nos', spec={'Material': 'Mild Steel', 'Number of Doors': '2'})
        four = offer('Steel Almirah Office', specs={'No. of Doors': '4', 'Material': 'Mild Steel'})
        self.assertIn('specification conflict', scoring.score(almirah, four).reason)
        two = offer('Steel Almirah Office', specs={'No. of Doors': '2', 'Material': 'Mild Steel'})
        self.assertTrue(scoring.score(almirah, two).accepted)

    def test_spec_field_names_do_not_count_as_the_product(self):
        almirah = Item('Steel Almirah', 10, 'Nos', spec={'Material': 'Mild Steel'})
        rack = offer('Office Steel Rack', specs={'Almirah Type': 'Office', 'Material': 'Mild Steel'})
        m = scoring.score(almirah, rack)
        self.assertFalse(m.accepted)
        self.assertIn('different product type', m.reason)
        # In Indian usage an almirah is a cupboard: synonyms of the product word count.
        cupboard = offer('Office Steel Cupboard', specs={'Material': 'Mild Steel'})
        self.assertTrue(scoring.score(almirah, cupboard).accepted)

    def test_material_hierarchy(self):
        self.assertFalse(sp.materials_conflict({'mild steel'}, {'metal'}))
        self.assertFalse(sp.materials_conflict({'steel'}, {'stainless steel'}))
        self.assertTrue(sp.materials_conflict({'mild steel'}, {'stainless steel', 'glass'}))
        almirah = Item('Steel Almirah', 10, 'Nos', spec={'Material': 'Mild Steel'})
        vague = scoring.score(almirah, offer('Steel Almirah', specs={'Material': 'Metal'}))
        self.assertFalse(vague.accepted, 'a vaguer material is consistent but does not confirm')
        self.assertNotIn('conflict', vague.reason)
        generic = Item('Steel Almirah', 10, 'Nos', spec={'Material': 'Steel'})
        self.assertTrue(scoring.score(generic, offer('Steel Almirah', specs={'Material': 'Mild Steel'})).accepted)
        self.assertIn('material conflict',
                      scoring.score(almirah, offer('SS Almirah', specs={'Material': 'Stainless Steel'})).reason)

    def test_unstated_spec_fields_lower_the_score(self):
        almirah = Item('Steel Almirah', 10, 'Nos', spec={'Material': 'Mild Steel', 'Number of Doors': '2',
                                                          'Lock Type': 'Godrej type'})
        silent = scoring.score(almirah, offer('Steel Almirah', specs={'Material': 'Mild Steel'}))
        agrees = scoring.score(almirah, offer('Steel Almirah', specs={
            'Material': 'Mild Steel', 'Number of Doors': '2', 'Lock Type': 'Godrej type'}))
        self.assertLess(silent.score, agrees.score)

    def test_material_conflict(self):
        chair = Item('Office Chair', 5, 'Nos', spec={'Seat Material': 'Mesh'})
        self.assertIn('material conflict', scoring.score(chair, offer('Polyester Office Chair')).reason)
        self.assertTrue(scoring.score(chair, offer('Mesh Office Chair High Back')).accepted)


if __name__ == '__main__':
    unittest.main()
