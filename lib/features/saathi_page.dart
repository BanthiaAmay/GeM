import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'components.dart';

/// Saathi, the assistant: a chat about the seller's business, GeM and the
/// app. Answers come from the server (see AppStore.askSaathi), which feeds
/// the model this user's own data; nothing here holds an API key.
///
/// A question can arrive as the route argument (e.g. from search), and is
/// asked straight away. The conversation lives only on this screen.
class SaathiPage extends StatefulWidget {
  final AppStore store;
  const SaathiPage({super.key, required this.store});
  @override
  State<SaathiPage> createState() => _SaathiPageState();
}

class _SaathiPageState extends State<SaathiPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <SaathiTurn>[];
  bool _thinking = false;
  String? _error;
  bool _askedFromRoute = false;
  AppStore get s => widget.store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final question = ModalRoute.of(context)?.settings.arguments;
    if (!_askedFromRoute && question is String && question.trim().isNotEmpty) {
      _askedFromRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask(question));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _message(String code) => switch (code) {
    'daily_limit' => s.t(
      'You’ve reached today’s question limit. Please try again tomorrow.',
      'आज के सवालों की सीमा पूरी हो गई। कृपया कल फिर पूछें।',
    ),
    'sign_in_required' => s.t(
      'Sign in to ask Saathi.',
      'साथी से पूछने के लिए साइन इन करें।',
    ),
    _ => s.t(
      'Saathi couldn’t answer right now. Please try again.',
      'साथी अभी जवाब नहीं दे सका। कृपया फिर कोशिश करें।',
    ),
  };

  Future<void> _ask(String raw) async {
    final question = raw.trim();
    if (question.isEmpty || _thinking) return;
    HapticFeedback.selectionClick();
    setState(() {
      _turns.add(SaathiTurn('user', question));
      _thinking = true;
      _error = null;
      _input.clear();
    });
    _toBottom();
    try {
      final answer = await s.askSaathi(List.of(_turns));
      if (!mounted) return;
      setState(() => _turns.add(SaathiTurn('model', answer)));
    } on SaathiException catch (e) {
      if (mounted) setState(() => _error = _message(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = _message('unavailable'));
    } finally {
      if (mounted) setState(() => _thinking = false);
      _toBottom();
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: Motion.of(context, Motion.normal),
      curve: Motion.enter,
    );
  });

  List<String> get _suggestions => [
    s.t(
      'Which open bids suit my business right now?',
      'अभी कौन सी खुली बोलियाँ मेरे व्यवसाय के लिए सही हैं?',
    ),
    s.t(
      'What documents should I prepare first?',
      'मुझे पहले कौन से दस्तावेज़ तैयार करने चाहिए?',
    ),
    s.t(
      'Can I get MSE relaxations or EMD exemption?',
      'क्या मुझे MSE छूट या EMD छूट मिल सकती है?',
    ),
    s.t('How do I register on GeM?', 'मैं GeM पर पंजीकरण कैसे करूँ?'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    appBar: AppBar(title: Text(s.t('Saathi', 'साथी'))),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(AppSpace.gutter),
              children: [
                if (_turns.isEmpty)
                  _Intro(store: s, onAsk: _ask, suggestions: _suggestions),
                for (final turn in _turns)
                  _Bubble(turn: turn, key: ObjectKey(turn)),
                if (_thinking)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                    child: Row(
                      children: [
                        const SizedBox.square(
                          dimension: AppIconSize.sm,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Text(
                          s.t('Saathi is thinking…', 'साथी सोच रहा है…'),
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpace.md),
                      child: Text(
                        _error!,
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!s.signedIn)
            Padding(
              padding: const EdgeInsets.all(AppSpace.gutter),
              child: AppButton(
                label: s.t(
                  'Sign in to ask Saathi.',
                  'साथी से पूछने के लिए साइन इन करें।',
                ),
                onPressed: () => Navigator.pushNamed(context, '/auth'),
              ),
            )
          else
            _Composer(
              store: s,
              controller: _input,
              busy: _thinking,
              onSend: () => _ask(_input.text),
            ),
        ],
      ),
    ),
  );
}

class _Intro extends StatelessWidget {
  final AppStore store;
  final List<String> suggestions;
  final ValueChanged<String> onAsk;
  const _Intro({
    required this.store,
    required this.suggestions,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.lg),
        const DepthIcon(
          Icons.auto_awesome_outlined,
          size: AppIconSize.lg + 8,
          color: AppColors.brand,
          lifted: true,
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          s.t('Ask Saathi anything', 'साथी से कुछ भी पूछें'),
          style: AppText.h1,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          s.t(
            'Saathi knows your business details, readiness and matching bids. Answers are guidance; confirm important details on GeM.',
            'साथी आपके व्यवसाय की जानकारी, तैयारी और मेल खाती बोलियाँ जानता है। जवाब मार्गदर्शन हैं; ज़रूरी बातें GeM पर जाँचें।',
          ),
          style: AppText.secondary(AppText.body),
        ),
        const SizedBox(height: AppSpace.xl),
        for (final question in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpace.lg),
              onTap: () => onAsk(question),
              child: AppListTile(
                icon: Icons.chat_bubble_outline,
                title: question,
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final SaathiTurn turn;
  const _Bubble({super.key, required this.turn});

  @override
  Widget build(BuildContext context) {
    final mine = turn.role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpace.md),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.md,
          ),
          decoration: BoxDecoration(
            color: mine ? AppColors.ink : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: mine ? null : Border.all(color: AppColors.border),
            boxShadow: mine ? null : AppShadow.card,
          ),
          child: SelectableText(
            turn.text,
            style: AppText.body.copyWith(
              color: mine ? AppColors.surface : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final AppStore store;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  const _Composer({
    required this.store,
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.lg,
        AppSpace.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
              boxShadow: AppShadow.floating,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpace.lg),
                    child: TextField(
                      controller: controller,
                      enabled: !busy,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      style: AppText.body,
                      decoration: InputDecoration(
                        hintText: s.t('Ask a question', 'सवाल पूछें'),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                ),
                AppIconButton(
                  icon: Icons.arrow_upward,
                  tooltip: s.t('Send', 'भेजें'),
                  tonal: true,
                  onPressed: busy ? null : onSend,
                ),
                const SizedBox(width: AppSpace.xs),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            s.t(
              'Saathi can make mistakes. Check important details on GeM.',
              'साथी से गलती हो सकती है। ज़रूरी जानकारी GeM पर जाँचें।',
            ),
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
