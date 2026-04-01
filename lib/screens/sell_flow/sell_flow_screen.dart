import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/item.dart';
import '../../models/app_settings.dart';
import '../../providers/app_providers.dart';
import '../../utils/keyword_matcher.dart';
import '../../widgets/voice_indicator.dart';

class SellFlowScreen extends ConsumerStatefulWidget {
  final String itemId;
  const SellFlowScreen({super.key, required this.itemId});

  @override
  ConsumerState<SellFlowScreen> createState() => _SellFlowScreenState();
}

class _SellFlowScreenState extends ConsumerState<SellFlowScreen> {
  Item? _item;
  bool _autoMode = true; // semi-auto: listen for each field

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    final item = await ref.read(databaseServiceProvider).getItem(widget.itemId);
    if (item != null && mounted) {
      setState(() => _item = item);
      WidgetsBinding.instance.addPostFrameCallback((_) => _startFlow());
    }
  }

  Future<void> _startFlow() async {
    if (_item == null) return;
    final settings = ref.read(settingsProvider);
    final tts = ref.read(ttsServiceProvider);
    final speech = ref.read(speechServiceProvider);
    final flow = ref.read(sellFlowProvider.notifier);
    final ai = ref.read(aiServiceProvider);

    await speech.initialize();
    flow.reset();

    // ── Step 1: Marketplace ────────────────────────────────────────────────
    await tts.speak(
      'Which marketplace? Say eBay, Amazon, Facebook, Craigslist, Etsy, '
      'OfferUp, Poshmark, or Mercari.',
      settings: settings,
    );
    final mpResp = await speech.listenOnce(timeoutSeconds: AppConstants.sellFlowListenTimeoutSeconds);
    final mp = KeywordMatcher.matchMarketplace(mpResp ?? '') ??
        settings.defaultMarketplace;
    flow.setMarketplace(mp);
    await tts.speak('${Marketplace.displayName(mp)} selected.', settings: settings);

    // ── Step 2: Listing type ───────────────────────────────────────────────
    await tts.speak(
      'Listing type: Buy It Now, Auction, or Auction with Buy It Now?',
      settings: settings,
    );
    final ltResp = await speech.listenOnce(timeoutSeconds: AppConstants.sellFlowListenTimeoutSeconds);
    final lt = KeywordMatcher.matchListingType(ltResp ?? '') ?? ListingType.buyItNow;
    flow.setListingType(lt);

    // ── Step 3: Title ──────────────────────────────────────────────────────
    final suggestedTitle = _item!.barcodeProductName ?? _item!.identifiedAs;
    String? title;
    if (suggestedTitle != null) {
      await tts.speak(
        'Suggested title: $suggestedTitle. Say "yes" to accept or speak a new title.',
        settings: settings,
      );
      final titleResp = await speech.listenOnce(timeoutSeconds: AppConstants.sellFlowListenTimeoutSeconds);
      title = (titleResp != null && KeywordMatcher.isAffirmative(titleResp))
          ? suggestedTitle
          : titleResp;
    } else {
      await tts.speak('What is the listing title?', settings: settings);
      title = await speech.listenOnce(timeoutSeconds: AppConstants.sellFlowListenTimeoutSeconds);
    }

    // AI-generate title if none given
    if ((title == null || title.isEmpty) && settings.openAiApiKey.isNotEmpty) {
      title = await ai.generateTitle(
        itemName: _item!.displayName,
        marketplace: mp,
        apiKey: settings.openAiApiKey,
      );
      title = title != null ? '[$title]' : '[${_item!.displayName}]';
    }
    flow.setTitle(title ?? '[${_item!.displayName}]');

    // ── Step 4: Subtitle ───────────────────────────────────────────────────
    await tts.speak('Subtitle? Say "skip" to leave blank.', settings: settings);
    final subResp = await speech.listenOnce(timeoutSeconds: AppConstants.sellFlowListenTimeoutSeconds);
    flow.setSubtitle(
        (subResp == null || KeywordMatcher.isNegative(subResp)) ? null : subResp);

    // ── Step 5: Price ──────────────────────────────────────────────────────
    double? price;
    if (settings.openAiApiKey.isNotEmpty) {
      price = await ai.estimatePrice(
        itemName: _item!.displayName,
        marketplace: mp,
        apiKey: settings.openAiApiKey,
      );
    }
    if (price != null) {
      await tts.sayPrice(price, s: settings);
      await tts.speak('Say "yes" to accept or speak a different price.', settings: settings);
      final priceResp = await speech.listenOnce(timeoutSeconds: AppConstants.sellFlowListenTimeoutSeconds);
      if (priceResp != null && !KeywordMatcher.isAffirmative(priceResp)) {
        price = KeywordMatcher.extractPrice(priceResp) ?? price;
      }
    } else {
      await tts.speak('What price? Say a dollar amount.', settings: settings);
      final priceResp = await speech.listenOnce(timeoutSeconds: AppConstants.sellFlowListenTimeoutSeconds);
      price = priceResp != null ? KeywordMatcher.extractPrice(priceResp) : null;
    }
    flow.setPrice(price ?? 9.99);

    // ── Step 6: Description ────────────────────────────────────────────────
    await tts.speak(
      'Would you like to speak a description? Say "yes" or "no".',
      settings: settings,
    );
    final descChoice = await speech.listenOnce(timeoutSeconds: AppConstants.sellFlowListenTimeoutSeconds);
    String? description;
    if (descChoice != null && KeywordMatcher.isAffirmative(descChoice)) {
      await tts.speak('Go ahead — speak the description.', settings: settings);
      description = await speech.listenOnce(timeoutSeconds: 15);
    }
    if (description == null && settings.openAiApiKey.isNotEmpty) {
      description = await ai.generateDescription(
        itemName: _item!.displayName,
        marketplace: mp,
        voiceNotes: _item!.voiceDescription,
        apiKey: settings.openAiApiKey,
      );
      if (description != null) description = '[AI: $description]';
    }
    flow.setDescription(description ?? '[No description]');

    // ── Step 7: Shipping ───────────────────────────────────────────────────
    await tts.speak(
      'Shipping: free, buyer arranges, exact cost, flat rate, or local pickup?',
      settings: settings,
    );
    final shipResp = await speech.listenOnce(timeoutSeconds: AppConstants.sellFlowListenTimeoutSeconds);
    final shipping = shipResp != null
        ? (KeywordMatcher.matchShipping(shipResp, null) ?? ShippingOption.free)
        : ShippingOption.free;
    double? shipCost;
    if (shipping == ShippingOption.flatRate) {
      await tts.speak('What is the flat rate shipping cost?', settings: settings);
      final costResp = await speech.listenOnce(timeoutSeconds: AppConstants.sellFlowListenTimeoutSeconds);
      shipCost = costResp != null ? KeywordMatcher.extractPrice(costResp) : null;
    }
    flow.setShipping(shipping, cost: shipCost);

    // ── Step 8: Condition ──────────────────────────────────────────────────
    await tts.speak(
      'Condition: new, like new, good, fair, or poor?',
      settings: settings,
    );
    final condResp = await speech.listenOnce(timeoutSeconds: AppConstants.sellFlowListenTimeoutSeconds);
    flow.setCondition(condResp ?? 'good');

    // ── Save ───────────────────────────────────────────────────────────────
    final flowState = ref.read(sellFlowProvider);
    final sellDetails = flowState.toSellDetails();
    if (sellDetails != null && _item != null) {
      final updated = _item!.copyWith(sellDetails: sellDetails, updatedAt: DateTime.now());
      await ref.read(itemsProvider.notifier).updateItem(updated);

      await tts.speak(
        'Listing details saved. ${settings.autoListOnSell ? "Submitting to ${Marketplace.displayName(mp)}." : "Tap Submit to list."}',
        settings: settings,
      );

      if (settings.autoListOnSell) {
        final result = await ref.read(marketplaceServiceProvider).listItem(updated, settings);
        if (result.success) {
          await tts.sayListingCreated(Marketplace.displayName(mp), s: settings);
        }
      }
    }
    flow.markDone();
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(sellFlowProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Listing'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: flowState.isComplete
          ? _DoneView(itemId: widget.itemId)
          : _FlowInProgress(flowState: flowState, item: _item),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FlowInProgress extends StatelessWidget {
  final SellFlowState flowState;
  final Item? item;

  const _FlowInProgress({required this.flowState, required this.item});

  @override
  Widget build(BuildContext context) {
    final steps = SellFlowStep.values
        .where((s) => s != SellFlowStep.done)
        .toList();
    final currentIndex = steps.indexOf(flowState.step);

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: currentIndex / (steps.length - 1),
          minHeight: 6,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _stepTitle(flowState.step),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (flowState.isListening)
                  const VoiceIndicator(transcript: '', speechState: SpeechState.listening),
                const SizedBox(height: 24),
                // Show collected data so far
                _SummaryCard(state: flowState),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _stepTitle(SellFlowStep step) => switch (step) {
        SellFlowStep.marketplace  => 'Which marketplace?',
        SellFlowStep.listingType  => 'Listing type?',
        SellFlowStep.title        => 'Listing title?',
        SellFlowStep.subtitle     => 'Subtitle?',
        SellFlowStep.price        => 'Selling price?',
        SellFlowStep.description  => 'Description?',
        SellFlowStep.shipping     => 'Shipping method?',
        SellFlowStep.condition    => 'Item condition?',
        SellFlowStep.review       => 'Review listing',
        SellFlowStep.done         => 'Done!',
      };
}

class _SummaryCard extends StatelessWidget {
  final SellFlowState state;
  const _SummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void add(String label, String? value) {
      if (value == null) return;
      rows.add(Row(children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
      ]));
    }

    add('Marketplace', state.marketplace != null ? Marketplace.displayName(state.marketplace!) : null);
    add('Type',        state.listingType?.displayName);
    add('Title',       state.title);
    add('Subtitle',    state.subtitle);
    add('Price',       state.price != null ? '\$${state.price!.toStringAsFixed(2)}' : null);
    add('Shipping',    state.shippingOption?.displayName);
    add('Condition',   state.condition);

    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }
}

class _DoneView extends ConsumerWidget {
  final String itemId;
  const _DoneView({required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 16),
          const Text('Listing details saved!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/item/$itemId'),
            icon: const Icon(Icons.visibility),
            label: const Text('View item'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final item = await ref.read(databaseServiceProvider).getItem(itemId);
              final settings = ref.read(settingsProvider);
              if (item == null) return;
              await ref.read(marketplaceServiceProvider).listItem(item, settings);
            },
            icon: const Icon(Icons.upload_outlined),
            label: const Text('Submit to marketplace'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
