// ============================================================
//  lib/features/onboarding/presentation/onboarding_screen.dart
//
//  3 páginas de boas-vindas + permissão de câmera + quiz
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Provider: controla se onboarding já foi visto ────────
final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_done') ?? false;
});

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_done', true);
}

// ── Dados das páginas ────────────────────────────────────
class _OnboardPage {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<String> bullets;

  const _OnboardPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.bullets,
  });
}

const _pages = [
  _OnboardPage(
    emoji: '🌿',
    title: 'Sua pele merece\ncuidado inteligente',
    subtitle: 'Diagnóstico de pele por IA em 30 segundos,\npersonalizado para o clima do Brasil 🇧🇷',
    accentColor: Color(0xFFC8714A),
    bullets: [
      '📸 Tire uma selfie — sem maquiagem',
      '🔬 IA analisa oleosidade, acne e manchas',
      '📋 Receba sua rotina personalizada em PT-BR',
    ],
  ),
  _OnboardPage(
    emoji: '☀️',
    title: 'Feito para o\nclima brasileiro',
    subtitle: 'O Brasil tem um dos índices UV mais altos do mundo.\nNossa IA entende isso.',
    accentColor: Color(0xFFE8A44A),
    bullets: [
      '🛢️ Controle de oleosidade para o calor',
      '😤 Tratamento de acne e cravos',
      '🌑 Proteção e clareza para manchas solares',
    ],
  ),
  _OnboardPage(
    emoji: '💰',
    title: 'Produtos acessíveis\npara você',
    subtitle: 'Recomendamos marcas brasileiras e importadas\na partir de R\$ 35 nas melhores plataformas.',
    accentColor: Color(0xFF6AB187),
    bullets: [
      '🛍️ Shopee, Mercado Livre e Amazon Brasil',
      '💚 Principia, Sallve, CeraVe, La Roche-Posay',
      '✅ Rotina completa a partir de R\$ 120',
    ],
  ),
];

// ══════════════════════════════════════════════════════════
//  ONBOARDING SCREEN
// ══════════════════════════════════════════════════════════
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _showingQuiz = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      setState(() => _showingQuiz = true);
    }
  }

  void _skip() {
    setState(() => _showingQuiz = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showingQuiz) {
      return _QuizScreen(
        onComplete: (skinType) async {
          await markOnboardingDone();
          if (mounted) context.go('/');
        },
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _skip,
                    child: const Text(
                      'Pular',
                      style: TextStyle(color: Color(0xFF8A7A6E), fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _OnboardPageView(page: _pages[i]),
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? _pages[_currentPage].accentColor
                              : const Color(0xFF4A3E35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // CTA button
                  GestureDetector(
                    onTap: _nextPage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _pages[_currentPage].accentColor,
                            _pages[_currentPage].accentColor.withAlpha(200),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _pages[_currentPage].accentColor.withAlpha(75),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _currentPage < _pages.length - 1
                              ? 'Continuar →'
                              : 'Descobrir meu tipo de pele ✨',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Página individual do onboarding ──────────────────────
class _OnboardPageView extends StatelessWidget {
  final _OnboardPage page;
  const _OnboardPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big emoji
          Text(
            page.emoji,
            style: const TextStyle(fontSize: 80),
          )
              .animate()
              .scale(begin: const Offset(0.5, 0.5), duration: 600.ms, curve: Curves.elasticOut)
              .fadeIn(),

          const SizedBox(height: 28),

          // Title
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFFF5F0EC),
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2, end: 0),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            page.subtitle,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF8A7A6E),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 250.ms),

          const SizedBox(height: 32),

          // Bullet points
          Column(
            children: page.bullets.map((bullet) {
              final index = page.bullets.indexOf(bullet);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: page.accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: page.accentColor.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      Text(bullet.split(' ').first,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bullet.substring(bullet.indexOf(' ') + 1),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFE8C9A0),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 350 + index * 100))
                  .slideX(begin: 0.1, end: 0);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  QUIZ DE TIPO DE PELE
// ══════════════════════════════════════════════════════════
class _QuizScreen extends StatefulWidget {
  final void Function(String skinType) onComplete;
  const _QuizScreen({required this.onComplete});

  @override
  State<_QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<_QuizScreen> {
  int _quizStep = 0;   // 0 = pergunta, 1 = permissão câmera, 2 = concluído
  String? _selectedAnswer;
  String _detectedSkinType = 'mista';

  // Perguntas do quiz
  final _questions = [
    _QuizQuestion(
      question: 'Como sua pele fica no meio do dia?',
      emoji: '🕛',
      options: [
        _QuizOption('Muito oleosa, brilhando toda', 'oleosa', '🛢️'),
        _QuizOption('Oleosa na zona T (testa e nariz)', 'mista', '🔀'),
        _QuizOption('Normal, sem muito brilho', 'normal', '😊'),
        _QuizOption('Seca, apertada ou descamando', 'seca', '💧'),
      ],
    ),
    _QuizQuestion(
      question: 'Você tem problemas frequentes de acne?',
      emoji: '😤',
      options: [
        _QuizOption('Sim, tenho acne ativa com frequência', 'acne_alta', '🔴'),
        _QuizOption('Às vezes, especialmente no calor', 'acne_media', '🟡'),
        _QuizOption('Raramente, só em época de estresse', 'acne_baixa', '🟢'),
        _QuizOption('Não tenho acne', 'sem_acne', '✅'),
      ],
    ),
    _QuizQuestion(
      question: 'Você usa protetor solar todo dia?',
      emoji: '☀️',
      options: [
        _QuizOption('Sim, sempre FPS 50+', 'spf_sim', '🌟'),
        _QuizOption('Às vezes, quando lembro', 'spf_as_vezes', '😅'),
        _QuizOption('Não costumo usar', 'spf_nao', '❌'),
        _QuizOption('Uso só quando vou à praia', 'spf_praia', '🏖️'),
      ],
    ),
  ];

  int _currentQuestion = 0;
  final Map<int, String> _answers = {};

  void _selectAnswer(String value) {
    setState(() {
      _selectedAnswer = value;
      _answers[_currentQuestion] = value;
    });
  }

  void _nextQuestion() {
    if (_selectedAnswer == null) return;

    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _currentQuestion++;
        _selectedAnswer = _answers[_currentQuestion];
      });
    } else {
      // Calcula tipo de pele baseado nas respostas
      _detectedSkinType = _calculateSkinType();
      setState(() => _quizStep = 1); // vai para permissão de câmera
    }
  }

  String _calculateSkinType() {
    final oilyAnswer = _answers[0] ?? '';
    if (oilyAnswer == 'oleosa') return 'oleosa';
    if (oilyAnswer == 'mista') return 'mista';
    if (oilyAnswer == 'seca') return 'seca';
    return 'normal';
  }

  @override
  Widget build(BuildContext context) {
    if (_quizStep == 1) {
      return _CameraPermissionStep(
        skinType: _detectedSkinType,
        onContinue: () => widget.onComplete(_detectedSkinType),
      );
    }

    final question = _questions[_currentQuestion];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress
              Row(
                children: [
                  Text(
                    'Pergunta ${_currentQuestion + 1} de ${_questions.length}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A7A6E),
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${((_currentQuestion + 1) / _questions.length * 100).toInt()}%',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFC8714A),
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentQuestion + 1) / _questions.length,
                  backgroundColor: const Color(0xFF2C1A10),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFC8714A)),
                  minHeight: 6,
                ),
              ),

              const SizedBox(height: 32),

              // Question
              Text(
                question.emoji,
                style: const TextStyle(fontSize: 48),
              ).animate(key: ValueKey(_currentQuestion)).fadeIn().scale(
                    begin: const Offset(0.7, 0.7),
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(height: 16),

              Text(
                question.question,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF5F0EC),
                  height: 1.3,
                ),
              ).animate(key: ValueKey('q$_currentQuestion')).fadeIn(delay: 100.ms),

              const SizedBox(height: 24),

              // Options
              Expanded(
                child: ListView(
                  children: question.options.asMap().entries.map((entry) {
                    final i = entry.key;
                    final option = entry.value;
                    final isSelected = _selectedAnswer == option.value;

                    return GestureDetector(
                      onTap: () => _selectAnswer(option.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFC8714A).withAlpha(30)
                              : const Color(0xFF1C1712),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFC8714A)
                                : const Color(0xFF2C1A10),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(option.emoji,
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFFE8C9A0)
                                      : const Color(0xFFF5F0EC),
                                ),
                              ),
                            ),
                            AnimatedOpacity(
                              opacity: isSelected ? 1 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(Icons.check_circle,
                                  color: Color(0xFFC8714A), size: 20),
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: 150 + i * 80))
                        .slideX(begin: 0.1, end: 0);
                  }).toList(),
                ),
              ),

              // Next button
              GestureDetector(
                onTap: _selectedAnswer != null ? _nextQuestion : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _selectedAnswer != null
                        ? const LinearGradient(
                            colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
                          )
                        : null,
                    color: _selectedAnswer == null
                        ? const Color(0xFF2C1A10)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _currentQuestion < _questions.length - 1
                          ? 'Próxima →'
                          : 'Ver meu resultado ✨',
                      style: TextStyle(
                        color: _selectedAnswer != null
                            ? Colors.white
                            : const Color(0xFF4A3E35),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Modelos do quiz ───────────────────────────────────────
class _QuizQuestion {
  final String question;
  final String emoji;
  final List<_QuizOption> options;
  const _QuizQuestion({
    required this.question,
    required this.emoji,
    required this.options,
  });
}

class _QuizOption {
  final String label;
  final String value;
  final String emoji;
  const _QuizOption(this.label, this.value, this.emoji);
}

// ══════════════════════════════════════════════════════════
//  PERMISSÃO DE CÂMERA
// ══════════════════════════════════════════════════════════
class _CameraPermissionStep extends StatefulWidget {
  final String skinType;
  final VoidCallback onContinue;

  const _CameraPermissionStep({
    required this.skinType,
    required this.onContinue,
  });

  @override
  State<_CameraPermissionStep> createState() => _CameraPermissionStepState();
}

class _CameraPermissionStepState extends State<_CameraPermissionStep> {
  bool _requesting = false;

  String get _skinTypeLabel {
    const labels = {
      'oleosa': 'Pele Oleosa 🛢️',
      'mista': 'Pele Mista 🔀',
      'normal': 'Pele Normal 😊',
      'seca': 'Pele Seca 💧',
    };
    return labels[widget.skinType] ?? 'Pele Mista';
  }

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);

    // Web não tem permission_handler — pula direto
    if (kIsWeb) {
      setState(() => _requesting = false);
      widget.onContinue();
      return;
    }

    final status = await Permission.camera.request();
    setState(() => _requesting = false);

    if (status.isGranted || status.isLimited) {
      widget.onContinue();
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      widget.onContinue();
    }
  }

  Widget _buildTipRow(String emoji, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE8C9A0),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A7A6E),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Resultado do quiz
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C1A10), Color(0xFF1C1712)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFC8714A).withAlpha(75),
                  ),
                ),
                child: Column(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 36))
                        .animate()
                        .scale(curve: Curves.elasticOut, duration: 800.ms),
                    const SizedBox(height: 8),
                    const Text(
                      'Pelo quiz rápido, seu tipo de pele é:',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A7A6E),
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _skinTypeLabel,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE8C9A0),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

              const SizedBox(height: 18),

              // ── Dicas de Ouro para Foto Perfeita ────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1712),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFC8714A).withAlpha(50)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('📸 ', style: TextStyle(fontSize: 16)),
                        Text(
                          '3 Dicas de Ouro para a IA Acertar:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF5F0EC),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTipRow(
                      '☀️',
                      'Luz Natural de Frente',
                      'Fique de frente para uma janela. Evite lâmpadas amarelas ou luz de costas.',
                    ),
                    const SizedBox(height: 8),
                    _buildTipRow(
                      '✨',
                      'Desative o Filtro de Beleza',
                      'Câmeras de celular costumam aplicar suavização. Desligue o embelezador para a IA ver sua textura real!',
                    ),
                    const SizedBox(height: 8),
                    _buildTipRow(
                      '🧼',
                      'Pele Limpa e Sem Make',
                      'Bases e corretivos mascaram manchas e oleosidade. Foto ao natural é muito mais precisa.',
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),

              const SizedBox(height: 20),

              // Permissão câmera
              const Text('📸', style: TextStyle(fontSize: 56))
                  .animate()
                  .fadeIn(delay: 400.ms),

              const SizedBox(height: 16),

              const Text(
                'Permitir acesso à câmera',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF5F0EC),
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 10),

              const Text(
                'Usamos a câmera APENAS para analisar sua pele.\nNenhuma foto é salva em nossos servidores.',
                style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8A7A6E),
                    height: 1.6),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 32),

              // Privacy note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF6AB187).withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: const Color(0xFF6AB187).withAlpha(50)),
                ),
                child: const Row(
                  children: [
                    Text('🔒', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sua privacidade é protegida. As imagens são processadas pela IA e descartadas imediatamente.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF6AB187)),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 700.ms),

              const SizedBox(height: 28),

              // Allow button
              GestureDetector(
                onTap: _requesting ? null : _requestPermission,
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC8714A).withAlpha(75),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _requesting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Permitir câmera e começar ✨',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3),

              const SizedBox(height: 12),

              // Skip permission
              TextButton(
                onPressed: widget.onContinue,
                child: const Text(
                  'Não agora — usar galeria',
                  style: TextStyle(color: Color(0xFF8A7A6E), fontSize: 13),
                ),
              ).animate().fadeIn(delay: 900.ms),
            ],
          ),
        ),
      ),
    );
  }
}
