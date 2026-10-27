// ============================================================
//  lib/core/services/report_export_service.dart
//
//  Serviço para exportar relatório da pele em PDF e compartilhar
//  nas redes sociais (WhatsApp, Instagram, etc.)
// ============================================================
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/scan/data/skin_analysis_result.dart';

class ReportExportService {
  /// Compartilha um resumo formatado da análise para redes sociais
  static Future<void> shareToSocial({
    required int score,
    required String skinType,
    required int oleosidade,
    required int acne,
    required int hidratacao,
    required List<AffiliateProduct> products,
    String? reportSnippet,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('✨ Fiz minha análise de pele com IA no PeleIA!');
    buffer.writeln('');
    buffer.writeln('📊 Score Geral: $score/100');
    buffer.writeln('💆 Tipo de Pele: ${skinType.toUpperCase()}');
    buffer.writeln('🛢️ Oleosidade: $oleosidade/10 | 😤 Acne: $acne/10 | 💧 Hidratação: $hidratacao/10');
    buffer.writeln('');

    if (products.isNotEmpty) {
      buffer.writeln('🌿 Produtos recomendados para meu perfil:');
      for (final p in products.take(3)) {
        buffer.writeln('• ${p.emoji} ${p.name} (${p.brand}) — ${p.priceFormatted}');
      }
      buffer.writeln('');
    }

    buffer.writeln('Descubra a rotina de skincare ideal para o seu rosto no PeleIA!');
    buffer.writeln('📲 https://peleia.com.br');

    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: 'Meu Relatório de Skincare PeleIA ($score pts)',
      ),
    );
  }

  /// Gera o arquivo PDF formatado e abre o menu de download/compartilhamento nativo
  static Future<void> exportAndDownloadPdf({
    required BuildContext context,
    required int score,
    required String skinType,
    required int oleosidade,
    required int acne,
    required int manchas,
    required int hidratacao,
    required String fullReport,
    required List<AffiliateProduct> products,
    required String dateFormatted,
  }) async {
    try {
      final doc = pw.Document();

      // Cor primária PeleIA (Terracotta elegante)
      final primaryColor = PdfColor.fromHex('C8714A');
      final textMuted = PdfColor.fromHex('8A7A6E');
      final cardBg = PdfColor.fromHex('F9F6F0');

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context pdfCtx) {
            return [
              // Cabeçalho da Marca
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PeleIA',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Relatório de Análise da Pele & Rotina Inteligente',
                        style: pw.TextStyle(color: textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Data: $dateFormatted',
                        style: pw.TextStyle(fontSize: 10, color: textMuted),
                      ),
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 4),
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          '$score / 100 PTS',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(color: primaryColor, thickness: 1),
              pw.SizedBox(height: 16),

              // Resumo dos Indicadores
              pw.Text(
                'Mapeamento dos Indicadores Cutâneos',
                style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPdfIndicator('Tipo de Pele', skinType.toUpperCase()),
                    _buildPdfIndicator('Oleosidade', '$oleosidade / 10'),
                    _buildPdfIndicator('Acne/Cravos', '$acne / 10'),
                    _buildPdfIndicator('Manchas', '$manchas / 10'),
                    _buildPdfIndicator('Hidratação', '$hidratacao / 10'),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Relatório da IA
              if (fullReport.isNotEmpty) ...[
                pw.Text(
                  'Orientação da Rotina Diária (IA)',
                  style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    fullReport,
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // Produtos Recomendados
              if (products.isNotEmpty) ...[
                pw.Text(
                  'Produtos Recomendados para sua Rotina',
                  style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                ...products.map((p) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: cardBg,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            p.name,
                            style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            '${p.brand} • Loja: ${p.storeLabel}',
                            style: pw.TextStyle(fontSize: 9, color: textMuted),
                          ),
                        ],
                      ),
                      pw.Text(
                        p.priceFormatted,
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )),
                pw.SizedBox(height: 16),
              ],

              // Aviso Regulatório (ANVISA)
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Text(
                'Aviso Legal & Regulatório: Este documento é um guia cosmético gerado por inteligência artificial '
                'com base em selfie fotográfica e histórico pessoal. Não constitui diagnóstico médico, '
                'prescrição clínica ou tratamento dermatológico.',
                style: pw.TextStyle(fontSize: 8, color: textMuted),
                textAlign: pw.TextAlign.center,
              ),
            ];
          },
        ),
      );

      final pdfBytes = await doc.save();
      final filename = 'peleia_relatorio_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Abre menu nativo para salvar no aparelho (Downloads) ou compartilhar direto
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar PDF: $e')),
        );
      }
    }
  }

  static pw.Widget _buildPdfIndicator(String title, String value) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }
}
