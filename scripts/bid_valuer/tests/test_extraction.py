import importlib.util
import io
from pathlib import Path
import shutil
import unittest

from bid_valuer import extract, items
from bid_valuer.extract import Document

GEM_TEXT = (Path(__file__).resolve().parents[2] / 'fixtures' / 'gem_bid_document.txt').read_text()
BID = {'title': 'LED Luminaire For Road And Street Lights', 'category': '', 'quantity': 156,
       'details': {'item_category': 'LED Luminaire For Road And Street Lights Conforming To IS '
                                    '10322 (Part 5/Section 3)', 'quantity': 156, 'kind': 'product'}}
has = lambda module: importlib.util.find_spec(module) is not None


def codes(item):
    return {i['code'] for i in item.issues}


class GemDocument(unittest.TestCase):
    def test_single_item_from_bid_document(self):
        result = items.extract_items([Document('bid.pdf', 'pdf', GEM_TEXT)], BID)
        item = result.items[0]
        self.assertEqual(item.name, 'LED Luminaire For Road And Street Lights')
        self.assertEqual(item.qty, 156)
        self.assertEqual(item.spec, {'System Wattage (in Watt)': '36'})
        self.assertEqual(item.delivery, [{'location': 'Example Office, Example Town', 'qty': 156, 'days': None}])
        # GeM's document does not print a unit: flagged, not guessed.
        self.assertIn('unit_missing', codes(item))
        self.assertEqual(result.status, 'incomplete')

    def test_unit_stated_makes_it_complete(self):
        text = GEM_TEXT.replace('Total Quantity\n156\n', 'Total Quantity\n156 Nos\n')
        result = items.extract_items([Document('bid.pdf', 'pdf', text)], BID)
        self.assertEqual(result.items[0].unit, 'Nos')
        self.assertEqual(result.status, 'complete', result.reason)

    def test_several_products_without_boq_are_incomplete(self):
        text = GEM_TEXT + '\nTechnical Specifications\nColour\nWhite\n'
        result = items.extract_items([Document('bid.pdf', 'pdf', text)], BID)
        self.assertEqual(result.items, [])
        self.assertEqual(result.status, 'incomplete')
        self.assertIn('multiple_products_without_quantities', result.reason)

    def test_services_are_unpriceable(self):
        bid = {**BID, 'title': 'Manpower Outsourcing Services', 'details': {'kind': 'service'}}
        self.assertEqual(items.extract_items([Document('b', 'pdf', GEM_TEXT)], bid).status, 'unpriceable')


class Boq(unittest.TestCase):
    TABLE = [['S.No', 'Item Description', 'Qty', 'Unit', 'Brand', 'Consignee Location', 'Delivery Days'],
             ['1', 'Steel Almirah 78 inch', '10', 'Nos', 'Godrej', 'Lucknow', '30'],
             ['2', 'Office Chair (mesh)', '25', 'Nos', '', 'Kanpur', '30'],
             ['', 'Grand Total', '35', '', '', '', '']]

    def test_items_from_boq(self):
        result = items.extract_items([Document('b', 'pdf', '', [self.TABLE])], {**BID, 'details': {'quantity': 35}})
        self.assertEqual([(i.name, i.qty, i.unit, i.brand) for i in result.items],
                         [('Steel Almirah 78 inch', 10, 'Nos', 'Godrej'), ('Office Chair', 25, 'Nos', '')])
        self.assertEqual(result.items[0].delivery, [{'location': 'Lucknow', 'qty': 10, 'days': 30}])
        self.assertEqual(result.status, 'complete', result.reason)

    def test_declared_quantity_mismatch(self):
        result = items.extract_items([Document('b', 'pdf', '', [self.TABLE])], {**BID, 'details': {'quantity': 50}})
        self.assertEqual(result.status, 'incomplete')
        self.assertIn('declared_quantity_mismatch', result.reason)

    def test_missing_quantity_and_duplicates(self):
        table = [self.TABLE[0], ['1', 'Office Chair', 'as required', 'Nos', '', 'Agra', '30'],
                 ['2', 'Steel Almirah', '4', 'Nos', '', 'Agra', '30'],
                 ['3', 'Steel Almirah', '4', 'Nos', '', 'Agra', '30']]
        result = items.extract_items([Document('b', 'pdf', '', [table])], {**BID, 'details': {}})
        self.assertIn('quantity_missing', codes(result.items[0]))
        self.assertIn('duplicate_product', codes(result.items[2]))
        self.assertEqual(result.status, 'incomplete')

    def test_multiple_locations_and_conflicts(self):
        item = items.Item('Chair', 10, 'Nos', spec={'Seat Material': 'Mesh', 'Seat material': 'Leather'},
                          delivery=[{'location': 'A', 'qty': 4, 'days': 30}, {'location': 'B', 'qty': 4, 'days': None}])
        items.validate([item])
        self.assertTrue({'delivery_quantity_mismatch', 'conflicting_specification',
                         'delivery_days_missing'} <= codes(item))

    def test_missing_delivery_is_flagged_not_blocking(self):
        item = items.Item('Chair', 10, 'Nos', spec={'Seat Material': 'Mesh'})
        items.validate([item])
        self.assertIn('delivery_missing', codes(item))
        self.assertNotIn('delivery_missing', items.BLOCKING)


class Readers(unittest.TestCase):
    @unittest.skipUnless(has('openpyxl'), 'openpyxl not installed')
    def test_xlsx_boq(self):
        import openpyxl
        book = openpyxl.Workbook()
        for row in Boq.TABLE[:3]:
            book.active.append(row)
        raw = io.BytesIO()
        book.save(raw)
        doc = extract.read(raw.getvalue(), 'https://gem.gov.in/boq.xlsx')
        self.assertEqual(doc.kind, 'xlsx')
        self.assertEqual(len(items.items_from_boq(doc.tables)), 2)

    @unittest.skipUnless(has('docx'), 'python-docx not installed')
    def test_docx_table(self):
        import docx
        word = docx.Document()
        table = word.add_table(rows=3, cols=3)
        for r, row in enumerate([['Item', 'Quantity', 'Unit'], ['Dustbin 60 L', '12', 'Nos'],
                                 ['Broom', '30', 'Nos']]):
            for c, text in enumerate(row):
                table.cell(r, c).text = text
        raw = io.BytesIO()
        word.save(raw)
        doc = extract.read(raw.getvalue(), 'https://gem.gov.in/spec.docx')
        self.assertEqual([(i.name, i.qty) for i in items.items_from_boq(doc.tables)],
                         [('Dustbin 60 L', 12), ('Broom', 30)])

    @unittest.skipUnless(has('fitz') and has('pdfplumber'), 'PyMuPDF / pdfplumber not installed')
    def test_pdf_text(self):
        import fitz
        pdf = fitz.open()
        pdf.new_page().insert_text((72, 72), 'Bid Document\nItem Category\nLED Street Light\n'
                                             'Total Quantity\n156 Nos\nTechnical Specifications')
        doc = extract.read(pdf.tobytes(), 'bid.pdf')
        self.assertEqual((doc.kind, doc.ocr_pages), ('pdf', 0))
        self.assertIn('156 Nos', doc.text)

    @unittest.skipUnless(has('fitz') and has('pytesseract') and shutil.which('tesseract'),
                         'Tesseract OCR not installed')
    def test_scanned_page_is_ocr_read(self):
        import fitz
        source = fitz.open()
        source.new_page().insert_text((72, 120), 'Total Quantity 156', fontsize=28)
        image = source[0].get_pixmap(dpi=150).tobytes('png')
        scanned = fitz.open()
        scanned.new_page().insert_image(fitz.Rect(0, 0, 595, 842), stream=image)
        doc = extract.read(scanned.tobytes(), 'scan.pdf')
        self.assertEqual(doc.ocr_pages, 1)
        self.assertIn('156', doc.text)

    def test_unknown_files_are_reported(self):
        doc = extract.read(b'\x00\x01binary', 'x.bin')
        self.assertEqual(doc.error, 'unsupported file type')


if __name__ == '__main__':
    unittest.main()
