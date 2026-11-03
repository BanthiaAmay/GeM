// Bid2Scale website: footer details, live GeM bids, and account deletion.
// Uses only the public Supabase anon key from js/config.js.
(function () {
  const config = window.BID2SCALE_CONFIG || {};
  const ready = Boolean(config.supabaseUrl && config.supabaseAnonKey &&
    !config.supabaseUrl.includes('YOUR_PROJECT') && window.supabase);
  const client = ready
    ? window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      })
    : null;

  const $ = (selector, root = document) => root.querySelector(selector);
  const el = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };

  // Footer year, contact address and store links.
  document.querySelectorAll('[data-year]').forEach((n) => (n.textContent = new Date().getFullYear()));
  document.querySelectorAll('[data-contact]').forEach((n) => {
    if (config.contactEmail) {
      const link = el('a', '', config.contactEmail);
      link.href = 'mailto:' + config.contactEmail;
      n.replaceChildren(link);
    }
  });
  for (const [attr, url] of [['data-play', config.playStoreUrl], ['data-appstore', config.appStoreUrl]]) {
    document.querySelectorAll(`[${attr}]`).forEach((n) => {
      if (url) n.href = url; else n.hidden = true;
    });
  }

  // ── Live GeM bids (home page) ───────────────────────────────────────────
  const list = $('#bids');
  if (list) {
    const form = $('#bid-search');
    const show = (message) => list.replaceChildren(el('div', 'state', message));
    const dateIST = (iso) => new Date(iso).toLocaleString('en-IN', {
      timeZone: 'Asia/Kolkata', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit',
    });
    const load = async (query) => {
      if (!client) return show('Live bids appear here once the website is connected to Bid2Scale.');
      show('Loading the latest GeM bids…');
      let request = client.from('gem_bids')
        .select('source_id,title,buyer,organisation,state,closes_at,source_url')
        .eq('published', true).gt('closes_at', new Date().toISOString())
        .order('starts_at', { ascending: false, nullsFirst: false }).limit(12);
      const words = (query || '').trim().replace(/[%_,()]/g, ' ').trim();
      if (words) request = request.ilike('title', `%${words}%`);
      const { data, error } = await request;
      if (error) return show('Bids could not be loaded right now. Please try again.');
      if (!data.length) return show(words ? `No open bids mention “${words}” yet.` : 'No open bids right now.');
      list.replaceChildren(...data.map((bid) => {
        const card = el('article', 'card bid');
        card.append(el('div', 'num', bid.source_id), el('h3', '', bid.title));
        const where = [bid.organisation || bid.buyer, bid.state].filter(Boolean).join(' · ');
        if (where) card.append(el('div', 'meta', where));
        card.append(el('div', 'closes', 'Closes ' + dateIST(bid.closes_at) + ' IST'));
        const link = el('a', '', 'View on GeM →');
        link.href = bid.source_url; link.target = '_blank'; link.rel = 'noopener';
        card.append(el('p', 'small', '')).lastChild.append(link);
        return card;
      }));
    };
    form?.addEventListener('submit', (event) => {
      event.preventDefault();
      load(new FormData(form).get('q'));
    });
    load('');
  }

  // ── Account deletion (delete-account page) ──────────────────────────────
  const flow = $('#delete-flow');
  if (flow) {
    const steps = { email: $('#step-email'), code: $('#step-code'), confirm: $('#step-confirm'), done: $('#step-done') };
    const status = $('#delete-status');
    const say = (message, kind = '') => { status.textContent = message; status.className = 'status ' + kind; };
    const go = (name) => Object.entries(steps).forEach(([key, node]) => (node.hidden = key !== name));
    let email = '';
    if (!client) {
      flow.hidden = true;
      $('#delete-offline').hidden = false;
      return;
    }
    $('#form-email').addEventListener('submit', async (event) => {
      event.preventDefault();
      email = String(new FormData(event.target).get('email') || '').trim();
      say('Sending a code…');
      const { error } = await client.auth.signInWithOtp({ email, options: { shouldCreateUser: false } });
      if (error) return say('We could not send a code to that address. Check it is the email you use in Bid2Scale.', 'error');
      say(`We sent a code to ${email}. It may take a minute; check spam too.`, 'ok');
      go('code');
    });
    $('#form-code').addEventListener('submit', async (event) => {
      event.preventDefault();
      const token = String(new FormData(event.target).get('code') || '').trim();
      say('Checking the code…');
      const { error } = await client.auth.verifyOtp({ email, token, type: 'email' });
      if (error) return say('That code did not work. Check it, or request a new one.', 'error');
      $('#signed-in-as').textContent = email;
      say('');
      go('confirm');
    });
    $('#understand').addEventListener('change', (event) => ($('#do-delete').disabled = !event.target.checked));
    $('#do-delete').addEventListener('click', async () => {
      $('#do-delete').disabled = true;
      say('Deleting your account…');
      const { error } = await client.rpc('delete_my_account');
      if (error) {
        $('#do-delete').disabled = false;
        return say('The account could not be deleted. Please try again or contact us.', 'error');
      }
      await client.auth.signOut();
      say('');
      go('done');
    });
    $('#restart').addEventListener('click', () => { say(''); go('email'); });
    go('email');
  }
})();
