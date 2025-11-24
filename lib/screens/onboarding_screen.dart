import 'package:aqar_app/screens/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // قائمة الميزات التي نريد شرحها بناءً على تحليلنا للتطبيق
  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'مرحباً بك في عقار بلص',
      'desc': 'المنصة العقارية الأذكى للبيع والشراء والإيجار.',
      'icon': Icons.real_estate_agent_rounded,
      'color': Colors.blue,
    },
    {
      'title': 'خريطة تفاعلية ذكية',
      'desc': 'استكشف العقارات حولك، وارسم مساراً مباشراً للوصول إليها.',
      'icon': Icons.map_outlined,
      'color': Colors.green,
    },
    {
      'title': 'تواصل مباشر',
      'desc': 'دردشة فورية مع الملاك وتنبيهات لحظية عبر تيليجرام.',
      'icon': Icons.chat_bubble_outline,
      'color': Colors.orange,
    },
  ];

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (ctx) => const AuthGate()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // خلفية متدرجة خفيفة
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                ],
              ),
            ),
          ),

          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // الأيقونة مع حركة
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: (page['color'] as Color).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              page['icon'],
                              size: 100,
                              color: page['color'],
                            ),
                          ).animate().scale(
                            duration: 600.ms,
                            curve: Curves.elasticOut,
                          ),

                          const SizedBox(height: 40),

                          Text(
                            page['title'],
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                          const SizedBox(height: 16),

                          Text(
                            page['desc'],
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.grey[600],
                                  height: 1.5,
                                ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 400.ms),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // مؤشر الصفحات والأزرار
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // مؤشر النقاط
                    Row(
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8),
                          height: 8,
                          width: _currentIndex == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentIndex == index
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    // زر التالي أو البدء
                    ElevatedButton(
                      onPressed: () {
                        if (_currentIndex == _pages.length - 1) {
                          _finishOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentIndex == _pages.length - 1
                            ? 'ابدأ الآن'
                            : 'التالي',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
