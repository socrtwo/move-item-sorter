import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

class ApiKeysScreen extends ConsumerStatefulWidget {
  const ApiKeysScreen({super.key});
  @override
  ConsumerState<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends ConsumerState<ApiKeysScreen> {
  late Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _ctrls = {
      'googleVision': TextEditingController(text: s.googleVisionApiKey),
      'openAi':       TextEditingController(text: s.openAiApiKey),
      'ebayAppId':    TextEditingController(text: s.ebayAppId),
      'ebayDevId':    TextEditingController(text: s.ebayDevId),
      'ebayCertId':   TextEditingController(text: s.ebayCertId),
      'ebayToken':    TextEditingController(text: s.ebayUserToken),
      'amazonSeller': TextEditingController(text: s.amazonSellerId),
      'amazonToken':  TextEditingController(text: s.amazonMwsAuthToken),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(
      googleVisionApiKey: _ctrls['googleVision']!.text.trim(),
      openAiApiKey:       _ctrls['openAi']!.text.trim(),
      ebayAppId:          _ctrls['ebayAppId']!.text.trim(),
      ebayDevId:          _ctrls['ebayDevId']!.text.trim(),
      ebayCertId:         _ctrls['ebayCertId']!.text.trim(),
      ebayUserToken:      _ctrls['ebayToken']!.text.trim(),
      amazonSellerId:     _ctrls['amazonSeller']!.text.trim(),
      amazonMwsAuthToken: _ctrls['amazonToken']!.text.trim(),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('API keys saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys'),
        actions: [
          FilledButton(onPressed: _save, child: const Text('Save')),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Warning(),
          _group('Google Cloud Vision', [
            _field('Vision API Key', _ctrls['googleVision']!),
          ]),
          _group('OpenAI (GPT-4o)', [
            _field('OpenAI API Key', _ctrls['openAi']!),
          ]),
          _group('eBay Trading API', [
            _field('App ID (Client ID)', _ctrls['ebayAppId']!),
            _field('Dev ID', _ctrls['ebayDevId']!),
            _field('Cert ID (Client Secret)', _ctrls['ebayCertId']!),
            _field('User Token', _ctrls['ebayToken']!, obscure: true),
          ]),
          _group('Amazon SP-API', [
            _field('Seller ID', _ctrls['amazonSeller']!),
            _field('MWS Auth Token', _ctrls['amazonToken']!, obscure: true),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      );

  Widget _field(String label, TextEditingController ctrl,
          {bool obscure = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class _Warning extends StatelessWidget {
  const _Warning();
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(children: [
          Icon(Icons.lock_outline),
          SizedBox(width: 8),
          Expanded(child: Text(
            'API keys are stored locally on this device only and are '
            'never transmitted except to the respective API endpoint.',
          )),
        ]),
      ),
    );
  }
}
