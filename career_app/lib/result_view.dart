// lib/result_view.dart
import 'package:flutter/material.dart';

class RoleResult {
  final String name;
  final double match; // 0.0 - 1.0
  final List<String> matched;
  final List<String> missing;
  RoleResult({
    required this.name,
    required this.match,
    required this.matched,
    required this.missing,
  });
  factory RoleResult.fromMap(Map m) => RoleResult(
    name: m['name'] ?? '',
    match: (m['match'] is num) ? (m['match'] as num).toDouble() : 0.0,
    matched: List<String>.from(m['matched'] ?? []),
    missing: List<String>.from(m['missing'] ?? []),
  );
}

class ResultView extends StatelessWidget {
  final List<RoleResult> roles;
  const ResultView({super.key, required this.roles});

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) return const Center(child: Text('Hiç rol bulunamadı.'));
    return ListView.separated(
      itemCount: roles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, i) {
        final r = roles[i];
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${(r.match * 100).round()}%',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: r.match, minHeight: 8),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (r.matched.isNotEmpty)
                      Chip(label: Text('Matched: ${r.matched.join(", ")}')),
                    if (r.missing.isNotEmpty)
                      Chip(label: Text('Missing: ${r.missing.join(", ")}')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // TODO: eksik beceriler için öneriler göster (yeni ekran veya modal)
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Öneriler — ${r.name}'),
                            content: Text(
                              'Eksik: ${r.missing.join(", ")}\n\nÖnerilen kurslar eklenecek.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Kapat'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Öneriler'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        // TODO: kaydet / paylaş
                      },
                      child: const Text('Kaydet / Paylaş'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
