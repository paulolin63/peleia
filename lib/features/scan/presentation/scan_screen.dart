// ============================================================
//  lib/features/scan/presentation/scan_screen.dart
//
//  Tela principal de captura + animação de análise
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/quota_service.dart';
import 'scan_provider.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  void _showDailyLimitDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1712),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🌙 ', style: TextStyle(fontSize: 22)),
            Text(
              'Limite Diário',
              style: TextStyle(color: Color(0xFFF5F0EC), fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(color: Color(0xFFE8C9A0), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'A pele precisa de tempo para absorver os ativos dos produtos. Volte amanhã para um novo diagnóstico!',
              style: TextStyle(color: Color(0xFF8A7A6E), fontSize: 12, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Color(0xFFC8714A), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanProvider);

    // Navega para resultado ou Paywall quando necessário
    ref.listen<ScanState>(scanProvider, (prev, next) {
      if (next.step == ScanStep.done) {
        context.push('/result');
      } else if (next.step == ScanStep.quotaBlocked) {
        if (next.quotaReason == QuotaBlockReason.proDailyExceeded) {
          _showDailyLimitDialog(context, next.errorMessage ?? '');
        } else {
          // Limite gratuito atingido → abre tela de planos
          context.push('/premium');
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 32),
              Expanded(
                child: _buildContent(scanState),
              ),
              const SizedBox(height: 24),
              _buildActions(scanState),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text('✨', style: TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 10),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Pele',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF5F0EC),
                ),
              ),
              TextSpan(
                text: 'IA',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFC8714A),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => context.push('/history'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1712),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC8714A).withAlpha(75)),
            ),
            child: const Row(
              children: [
                Text('📈', style: TextStyle(fontSize: 14)),
                SizedBox(width: 6),
                Text(
                  'Evolução',
                  style: TextStyle(
                    color: Color(0xFFE8C9A0),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildContent(ScanState state) {
    if (state.isLoading) {
      return _buildScanAnimation(state);
    }

    if (state.step == ScanStep.error) {
      return _buildError(state.errorMessage ?? 'Erro desconhecido');
    }

    return _buildIdleState();
  }

  Widget _buildIdleState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ilustração do rosto com overlay de scan
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final value = _pulseController.value;
                return Container(
                  width: 230 + (value * 30),
                  height: 280 + (value * 30),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFC8714A)
                          .withAlpha((255 * (1 - value)).round()),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(115),
                  ),
                );
              },
            ),

            // Face container
            Container(
              width: 200,
              height: 250,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF3D2518), Color(0xFF2C1A10)],
                ),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: const Color(0xFFC8714A).withAlpha(100),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text('👤', style: TextStyle(fontSize: 80)),
              ),
            ),

            // Corner markers
            ..._buildCornerMarkers(),
          ],
        )
            .animate()
            .fadeIn(duration: 800.ms)
            .scale(begin: const Offset(0.9, 0.9)),

        const SizedBox(height: 32),

        Text(
          'Análise de Pele com IA',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFFF5F0EC),
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: 12),

        Text(
          'Posicione seu rosto dentro do frame e\ntire uma selfie com boa iluminação natural ☀️',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF8A7A6E),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 400.ms),

        const SizedBox(height: 24),

        // Feature tags
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: const [
            _FeatureTag(emoji: '🛢️', label: 'Oleosidade'),
            _FeatureTag(emoji: '😤', label: 'Acne'),
            _FeatureTag(emoji: '☀️', label: 'Manchas UV'),
            _FeatureTag(emoji: '💧', label: 'Hidratação'),
          ],
        ).animate().fadeIn(delay: 600.ms),

        const SizedBox(height: 20),

        // ── Dicas de Ouro para Foto Precisa ──────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1712),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC8714A).withAlpha(40)),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('💡 ', style: TextStyle(fontSize: 14)),
                  Text(
                    'Para a IA acertar com 100% de precisão:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE8C9A0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _CaptureMiniTip(emoji: '☀️', label: 'Luz Natural'),
                  _CaptureMiniTip(emoji: '✨', label: 'Sem Filtro/Beleza'),
                  _CaptureMiniTip(emoji: '🧼', label: 'Pele sem Make'),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: 700.ms),
      ],
    );
  }

  Widget _buildScanAnimation(ScanState state) {
    final steps = [
      '🔬 Detectando tipo de pele...',
      '💧 Analisando oleosidade e poros...',
      '😤 Mapeando acne e cravos...',
      '☀️ Calculando risco UV...',
      '📋 Criando sua rotina personalizada...',
    ];

    final currentStepIndex = state.step == ScanStep.generatingReport ? 4 : 2;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Foto com overlay de scan
        if (state.imageBytes != null)
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Image.memory(
                  state.imageBytes!,
                  width: 200,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),

              // Scan line overlay
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: AnimatedBuilder(
                  animation: _scanLineController,
                  builder: (_, __) {
                    return Container(
                      width: 200,
                      height: 250,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Align(
                        alignment: Alignment(
                          0,
                          _scanLineController.value * 2 - 1,
                        ),
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFFC8714A).withAlpha(200),
                                const Color(0xFFF2A58B),
                                const Color(0xFFC8714A).withAlpha(200),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFFC8714A),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Semitransparent overlay
              Container(
                width: 200,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: const Color(0xFF1C1712).withAlpha(120),
                ),
              ),

              ..._buildCornerMarkers(),
            ],
          ),

        const SizedBox(height: 32),

        // Status steps
        ...List.generate(steps.length, (i) {
          final isDone = i < currentStepIndex;
          final isActive = i == currentStepIndex;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? const Color(0xFF6AB187).withAlpha(50)
                        : isActive
                            ? const Color(0xFFC8714A).withAlpha(50)
                            : Colors.transparent,
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFF6AB187)
                          : isActive
                              ? const Color(0xFFC8714A)
                              : const Color(0xFF4A3E35),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Text('✓',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6AB187),
                              fontWeight: FontWeight.bold,
                            ))
                        : isActive
                            ? const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFC8714A),
                                ),
                              )
                            : null,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 13,
                    color: isDone
                        ? const Color(0xFF6AB187)
                        : isActive
                            ? const Color(0xFFF5F0EC)
                            : const Color(0xFF4A3E35),
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('❌', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFFD96B6B),
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => ref.read(scanProvider.notifier).reset(),
            child: const Text(
              'Tentar novamente',
              style: TextStyle(color: Color(0xFFC8714A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ScanState state) {
    if (state.isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Botão principal — câmera
        GestureDetector(
          onTap: () => ref.read(scanProvider.notifier).captureAndAnalyze(),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC8714A).withAlpha(100),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('📸', style: TextStyle(fontSize: 20)),
                SizedBox(width: 10),
                Text(
                  'Analisar Minha Pele',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ).animate().slideY(begin: 0.3, end: 0).fadeIn(delay: 800.ms),

        const SizedBox(height: 12),

        // Botão secundário — galeria
        GestureDetector(
          onTap: () => ref.read(scanProvider.notifier).pickFromGallery(),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFC8714A).withAlpha(100),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🖼️', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Text(
                  'Usar foto da galeria',
                  style: TextStyle(
                    color: Color(0xFFC8714A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 900.ms),
      ],
    );
  }

  List<Widget> _buildCornerMarkers() {
    const size = 20.0;
    const thickness = 3.0;
    const offset = -4.0;
    const color = Color(0xFFC8714A);

    return [
      Positioned(
        top: offset,
        left: offset,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: thickness),
              left: BorderSide(color: color, width: thickness),
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        top: offset,
        right: offset,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: thickness),
              right: BorderSide(color: color, width: thickness),
            ),
            borderRadius: BorderRadius.only(topRight: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        bottom: offset,
        left: offset,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: thickness),
              left: BorderSide(color: color, width: thickness),
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        bottom: offset,
        right: offset,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: thickness),
              right: BorderSide(color: color, width: thickness),
            ),
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(4)),
          ),
        ),
      ),
    ];
  }
}

// ── Widget auxiliar: feature tag ─────────────────────────
class _FeatureTag extends StatelessWidget {
  final String emoji;
  final String label;

  const _FeatureTag({required this.emoji, required this.label});

  void _showDailyLimitDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1712),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🌙 ', style: TextStyle(fontSize: 22)),
            Text(
              'Limite Diário',
              style: TextStyle(color: Color(0xFFF5F0EC), fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(color: Color(0xFFE8C9A0), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'A pele precisa de tempo para absorver os ativos dos produtos. Volte amanhã para um novo diagnóstico!',
              style: TextStyle(color: Color(0xFF8A7A6E), fontSize: 12, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Color(0xFFC8714A), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFC8714A).withAlpha(30),
        border: Border.all(color: const Color(0xFFC8714A).withAlpha(75)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF2A58B),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget auxiliar: dica rápida de captura ──────────────
class _CaptureMiniTip extends StatelessWidget {
  final String emoji;
  final String label;
  const _CaptureMiniTip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFFF5F0EC),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


