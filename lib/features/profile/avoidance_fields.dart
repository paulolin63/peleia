import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

/// Chips de ingredientes e condições, mais a observação livre. A lista vem da config.
class AvoidanceFields extends StatelessWidget {
  final AppConfig config;
  final Set<String> avoid;
  final Set<String> conditions;
  final TextEditingController note;
  final void Function(VoidCallback fn) onChanged;

  const AvoidanceFields({
    super.key,
    required this.config,
    required this.avoid,
    required this.conditions,
    required this.note,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingredientes a evitar',
          style: TextStyle(color: Color(0xFFE8C9A0), fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in config.ingredients)
              FilterChip(
                label: Text(option.label),
                selected: avoid.contains(option.id),
                onSelected: (selected) => onChanged(() {
                  if (selected) {
                    avoid.add(option.id);
                  } else {
                    avoid.remove(option.id);
                  }
                }),
                selectedColor: const Color(0xFFC8714A),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: avoid.contains(option.id) ? Colors.white : const Color(0xFFE8C9A0),
                  fontSize: 12,
                ),
                backgroundColor: const Color(0xFF1C1712),
                side: const BorderSide(color: Color(0xFF2C1A10)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Condições',
          style: TextStyle(color: Color(0xFFE8C9A0), fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in config.conditions)
              FilterChip(
                label: Text(option.label),
                selected: conditions.contains(option.id),
                onSelected: (selected) => onChanged(() {
                  if (selected) {
                    conditions.add(option.id);
                  } else {
                    conditions.remove(option.id);
                  }
                }),
                selectedColor: const Color(0xFF6AB187),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: conditions.contains(option.id) ? Colors.white : const Color(0xFFE8C9A0),
                  fontSize: 12,
                ),
                backgroundColor: const Color(0xFF1C1712),
                side: const BorderSide(color: Color(0xFF2C1A10)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Observação pessoal',
          style: TextStyle(color: Color(0xFFE8C9A0), fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: note,
          maxLength: 280,
          maxLines: 3,
          style: const TextStyle(color: Color(0xFFF5F0EC), fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Ex.: alergia à marca X, uso isotretinoína',
            hintStyle: TextStyle(color: Color(0xFF8A7A6E), fontSize: 13),
            counterStyle: TextStyle(color: Color(0xFF8A7A6E)),
            filled: true,
            fillColor: Color(0xFF1C1712),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Isso fica no seu aparelho e só vai para a IA na hora de montar a rotina. Confira sempre o rótulo do produto.',
          style: TextStyle(color: Color(0xFF8A7A6E), fontSize: 11, height: 1.4),
        ),
      ],
    );
  }
}
