"""Text and tables from bid documents and attachments.

PDF text comes from PyMuPDF and tables from pdfplumber. Pages with almost no
text layer (scans) are rendered and read with Tesseract OCR. XLSX BOQs are
read with openpyxl and DOCX with python-docx. Heavy libraries are imported
only when a document of that kind is read."""
from dataclasses import dataclass, field
import io
import os
import re

OCR_MIN_CHARS = 50
MAX_PDF_PAGES = 60


@dataclass
class Document:
    url: str
    kind: str                      # 'pdf', 'xlsx', 'docx', 'unknown'
    text: str = ''
    tables: list = field(default_factory=list)   # list of rows; each row a list of cells
    ocr_pages: int = 0
    error: str = ''


def kind_of(raw, url=''):
    if raw[:4] == b'%PDF':
        return 'pdf'
    if raw.lstrip()[:1] == b'<':
        return 'html'
    if raw[:2] == b'PK':
        lowered = url.lower()
        if lowered.endswith('.docx'):
            return 'docx'
        if lowered.endswith(('.xlsx', '.xlsm')):
            return 'xlsx'
        # Zip with no telling extension: look inside.
        head = raw[:4000]
        return 'docx' if b'word/' in head else 'xlsx' if b'xl/' in head else 'unknown'
    return 'unknown'


def _clean_cell(value):
    return ' '.join(str(value).split()) if value is not None else ''


def read_pdf(raw, url=''):
    import fitz  # PyMuPDF
    import pdfplumber
    doc = Document(url, 'pdf')
    texts, ocr = [], 0
    with fitz.open(stream=raw, filetype='pdf') as pdf:
        for page in list(pdf)[:MAX_PDF_PAGES]:
            text = page.get_text('text') or ''
            if len(text.strip()) < OCR_MIN_CHARS:
                ocr_text = _ocr_page(page)
                if ocr_text:
                    text, ocr = ocr_text, ocr + 1
            texts.append(text)
    doc.text, doc.ocr_pages = '\n'.join(texts), ocr
    try:
        with pdfplumber.open(io.BytesIO(raw)) as pdf:
            for page in pdf.pages[:MAX_PDF_PAGES]:
                for table in page.extract_tables() or []:
                    rows = [[_clean_cell(c) for c in row] for row in table if row]
                    if rows:
                        doc.tables.append(rows)
    except Exception as error:  # A table failure must not lose the text.
        doc.error = f'tables: {type(error).__name__}'
    return doc


def _ocr_page(page):
    """Tesseract OCR of one rendered page; '' when Tesseract is unavailable."""
    try:
        import pytesseract
        from PIL import Image
    except ImportError:
        return ''
    windows_default = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
    if os.environ.get('TESSERACT_CMD'):
        pytesseract.pytesseract.tesseract_cmd = os.environ['TESSERACT_CMD']
    elif os.name == 'nt' and os.path.exists(windows_default):
        pytesseract.pytesseract.tesseract_cmd = windows_default
    pixmap = page.get_pixmap(dpi=200)
    image = Image.open(io.BytesIO(pixmap.tobytes('png')))
    try:
        return pytesseract.image_to_string(image, lang='eng')
    except Exception:  # Tesseract binary missing or failed
        return ''


def read_xlsx(raw, url=''):
    import openpyxl
    doc = Document(url, 'xlsx')
    book = openpyxl.load_workbook(io.BytesIO(raw), read_only=True, data_only=True)
    lines = []
    for sheet in book.worksheets:
        rows = []
        for row in sheet.iter_rows(values_only=True):
            cells = [_clean_cell(c) for c in row]
            if any(cells):
                rows.append(cells)
                lines.append(' | '.join(c for c in cells if c))
        if rows:
            doc.tables.append(rows)
    doc.text = '\n'.join(lines)
    return doc


def read_docx(raw, url=''):
    import docx
    doc = Document(url, 'docx')
    word = docx.Document(io.BytesIO(raw))
    doc.text = '\n'.join(p.text for p in word.paragraphs)
    for table in word.tables:
        rows = [[_clean_cell(cell.text) for cell in row.cells] for row in table.rows]
        if rows:
            doc.tables.append(rows)
    return doc


def read_html(raw, url=''):
    """A linked HTML page (e.g. a GeM catalogue specification): text and tables."""
    from selectolax.parser import HTMLParser
    doc = Document(url, 'html')
    tree = HTMLParser(raw.decode('utf-8', errors='replace'))
    for node in tree.css('script, style, noscript'):
        node.decompose()
    for table in tree.css('table'):
        rows = [[_clean_cell(cell.text()) for cell in row.css('th, td')] for row in table.css('tr')]
        rows = [r for r in rows if any(r)]
        if rows:
            doc.tables.append(rows)
    body = tree.body
    doc.text = body.text(separator='\n') if body else ''
    return doc


def read(raw, url=''):
    kind = kind_of(raw, url)
    readers = {'pdf': read_pdf, 'xlsx': read_xlsx, 'docx': read_docx, 'html': read_html}
    if kind not in readers:
        return Document(url, kind, error='unsupported file type')
    try:
        return readers[kind](raw, url)
    except Exception as error:
        return Document(url, kind, error=f'{type(error).__name__}: {str(error)[:120]}')


def normalise_header(cell):
    return re.sub(r'[^a-z ]', ' ', cell.lower()).split()
