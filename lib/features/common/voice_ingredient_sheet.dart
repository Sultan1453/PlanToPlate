import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/weekly_summary_service.dart';

/// Mikrofonla malzeme dinler; bitince parsed isimleri döner.
Future<List<String>?> showVoiceIngredientSheet(BuildContext context) async {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _VoiceIngredientSheet(),
  );
}

class _VoiceIngredientSheet extends StatefulWidget {
  const _VoiceIngredientSheet();

  @override
  State<_VoiceIngredientSheet> createState() => _VoiceIngredientSheetState();
}

class _VoiceIngredientSheetState extends State<_VoiceIngredientSheet> {
  final _speech = SpeechToText();
  var _ready = false;
  var _listening = false;
  var _transcript = '';
  String? _error;
  var _disposed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ok = await _speech.initialize(
        onError: (e) {
          if (_disposed || !mounted) return;
          setState(() => _error = e.errorMsg);
        },
        onStatus: (status) {
          if (_disposed || !mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
      );
      if (_disposed || !mounted) return;
      setState(() {
        _ready = ok;
        if (!ok) _error = 'Mikrofon / konuşma tanıma kullanılamıyor.';
      });
      if (ok) await _start();
    } catch (_) {
      if (_disposed || !mounted) return;
      setState(() => _error = 'Ses izni veya tanıma başlatılamadı.');
    }
  }

  Future<void> _start() async {
    if (_disposed || !mounted) return;
    setState(() {
      _listening = true;
      _error = null;
      _transcript = '';
    });
    await _speech.listen(
      onResult: (result) {
        if (_disposed || !mounted) return;
        setState(() => _transcript = result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        localeId: 'tr_TR',
      ),
    );
  }

  Future<void> _stopAndSubmit() async {
    await _speech.stop();
    final items = SpokenIngredientParser.parse(_transcript);
    if (_disposed || !mounted) return;
    if (items.isEmpty) {
      setState(() {
        _listening = false;
        _error = 'Anlaşılan malzeme yok. Tekrar dene.';
      });
      return;
    }
    Navigator.pop(context, items);
  }

  @override
  void dispose() {
    _disposed = true;
    // stop() async callback'leri tetikleyebilir; bayrak setState'i engeller.
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sesli ekle',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Örn: “yağ, yumurta, soğan”',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 20),
          Icon(
            _listening ? Icons.mic : Icons.mic_none,
            size: 56,
            color: _listening ? AppColors.accentOrange : AppColors.primaryGreenDark,
          ),
          const SizedBox(height: 12),
          Text(
            _listening ? 'Dinleniyor…' : (_ready ? 'Hazır' : 'Hazırlanıyor…'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (_transcript.isNotEmpty)
            Text(
              _transcript,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _ready && !_listening ? _start : null,
                  child: const Text('Tekrar dinle'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _transcript.trim().isEmpty ? null : _stopAndSubmit,
                  child: const Text('Ekle'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
