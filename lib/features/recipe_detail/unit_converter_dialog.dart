import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Su bardağı / yemek kaşığı / gram dönüştürücü.
class UnitConverterDialog extends StatefulWidget {
  const UnitConverterDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const UnitConverterDialog(),
    );
  }

  @override
  State<UnitConverterDialog> createState() => _UnitConverterDialogState();
}

class _UnitConverterDialogState extends State<UnitConverterDialog> {
  final _controller = TextEditingController(text: '1');
  _ConvUnit _from = _ConvUnit.tbsp;
  _ConvUnit _to = _ConvUnit.gram;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _input {
    return double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
  }

  double get _output {
    final grams = _input * _from.toGrams;
    if (_to.toGrams == 0) return 0;
    return grams / _to.toGrams;
  }

  @override
  Widget build(BuildContext context) {
    final out = _output;
    final outText = out == out.roundToDouble()
        ? out.toStringAsFixed(0)
        : out.toStringAsFixed(1);

    return AlertDialog(
      title: const Text('Canlı ölçü çevirici'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Miktar',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButton<_ConvUnit>(
                  isExpanded: true,
                  value: _from,
                  items: [
                    for (final u in _ConvUnit.values)
                      DropdownMenuItem(value: u, child: Text(u.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _from = v);
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward),
              ),
              Expanded(
                child: DropdownButton<_ConvUnit>(
                  isExpanded: true,
                  value: _to,
                  items: [
                    for (final u in _ConvUnit.values)
                      DropdownMenuItem(value: u, child: Text(u.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _to = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '≈ $outText ${_to.label}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yaklaşık su bazlı dönüşüm (1 su bardağı ≈ 200 ml / 200 g).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

enum _ConvUnit {
  cup,
  tbsp,
  tsp,
  gram,
  ml,
}

extension on _ConvUnit {
  String get label {
    switch (this) {
      case _ConvUnit.cup:
        return 'su bardağı';
      case _ConvUnit.tbsp:
        return 'yemek kaşığı';
      case _ConvUnit.tsp:
        return 'çay kaşığı';
      case _ConvUnit.gram:
        return 'gram';
      case _ConvUnit.ml:
        return 'ml';
    }
  }

  /// Su densitesine yakın yaklaşık gram eşdeğeri.
  double get toGrams {
    switch (this) {
      case _ConvUnit.cup:
        return 200;
      case _ConvUnit.tbsp:
        return 15;
      case _ConvUnit.tsp:
        return 5;
      case _ConvUnit.gram:
        return 1;
      case _ConvUnit.ml:
        return 1;
    }
  }
}
