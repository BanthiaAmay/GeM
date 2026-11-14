"""Bid documents with SHA-256 hashes, so unchanged documents are neither
downloaded again nor re-extracted.

The bid PDF is always read (GeM sends no cache headers to compare against).
If its hash matches the stored one and every attachment it links to has a
stored hash, the attachments are not downloaded and the stored item list
is reused. A changed bid PDF (e.g. a corrigendum) re-reads everything."""
import hashlib

from gem_source import GemError

from .select import gem_id

ATTACHMENT_KINDS = ('buyer_document', 'specification')
MAX_ATTACHMENTS = 8


def sha256(raw):
    return hashlib.sha256(raw).hexdigest()


def combined_hash(hashes):
    return sha256('\n'.join(f'{u} {h}' for u, h in sorted(hashes.items())).encode())


def attachment_urls(bid):
    links = (bid.get('details') or {}).get('links') or []
    return [l['url'] for l in links if isinstance(l, dict) and l.get('kind') in ATTACHMENT_KINDS
            and str(l.get('url', '')).startswith('https://')][:MAX_ATTACHMENTS]


def fetch(gem, bid, stored_hashes):
    """(files [(url, raw)], hashes {url: sha256}, unchanged: bool, notes).
    `unchanged` means the stored item list can be reused."""
    doc_id = gem_id(bid['source_url'])
    if doc_id is None:
        raise GemError(f'No GeM document id in {bid["source_url"]}')
    bid_url = bid['source_url']
    raw = gem.document(doc_id)
    hashes, files, notes = {bid_url: sha256(raw)}, [(bid_url, raw)], []
    urls = attachment_urls(bid)
    if stored_hashes.get(bid_url) == hashes[bid_url] and all(u in stored_hashes for u in urls):
        hashes.update({u: stored_hashes[u] for u in urls})
        return files, hashes, True, notes
    for url in urls:
        try:
            status, body = gem._fetch(url, headers={'Referer': bid_url})
        except GemError as error:
            notes.append(f'attachment unreachable: {error}')
            continue
        if status != 200 or not body:
            notes.append(f'attachment HTTP {status}: {url[:80]}')
            continue
        hashes[url] = sha256(body)
        files.append((url, body))
    return files, hashes, False, notes
