import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final features = <_FeatureItem>[
      _FeatureItem(
        icon: Icons.explore_outlined,
        title: 'تصفح ذكي ومتجدد',
        body:
            'أقسام مميزة للعروض البارزة، الأحدث، الأكثر مشاهدة، المخفضة، وبحسب نوع العقار وفئته.',
      ),
      _FeatureItem(
        icon: Icons.search_rounded,
        title: 'بحث وتصفية متقدمة',
        body:
            'بحث بالعنوان مع فلاتر للسعر، عدد الغرف، والتصنيف، مع تحديث فوري للنتائج.',
      ),
      _FeatureItem(
        icon: Icons.photo_library_outlined,
        title: 'إعلانات غنية بالوسائط',
        body:
            'رفع صور متعددة وفيديو للعقار، مع مواصفات تفصيلية مثل المساحة، العمر، والمزايا.',
      ),
      _FeatureItem(
        icon: Icons.map_outlined,
        title: 'خرائط تفاعلية',
        body:
            'تحديد موقع العقار على الخريطة، وعرض العقارات مجمعة بعلامات ذكية حسب النوع والفئة.',
      ),
      _FeatureItem(
        icon: Icons.alt_route_rounded,
        title: 'إظهار المسارات',
        body:
            'رسم مسار الوصول للعقار عبر Directions API مع توجيه مرئي على الخريطة.',
      ),
      _FeatureItem(
        icon: Icons.chat_bubble_outline,
        title: 'محادثات فورية',
        body:
            'دردشة مرتبطة بالعقار، تحديث لحظي عبر WebSocket، وإحصاء للرسائل غير المقروءة.',
      ),
      _FeatureItem(
        icon: Icons.notifications_active_outlined,
        title: 'تنبيهات ذكية',
        body:
            'إشعارات فورية عبر Firebase Messaging مع فتح المحادثة مباشرة عند الضغط.',
      ),
      _FeatureItem(
        icon: Icons.star_border,
        title: 'تقييمات وسمعة',
        body: 'نظام تقييم للمستخدمين مع متوسط النجوم والمراجعات التفصيلية.',
      ),
      _FeatureItem(
        icon: Icons.favorite_border,
        title: 'قائمة مفضلة',
        body: 'حفظ العقارات المميزة ومراجعتها بسرعة مع مزامنة حالة المفضلة.',
      ),
      _FeatureItem(
        icon: Icons.report_gmailerrorred_outlined,
        title: 'بلاغات ومراجعة محتوى',
        body:
            'نظام بلاغات تفصيلي لمراقبة جودة الإعلانات ومكافحة المحتوى المخالف.',
      ),
      _FeatureItem(
        icon: Icons.admin_panel_settings_outlined,
        title: 'إدارة متقدمة',
        body:
            'لوحة إدارة تشمل الإحصاءات، إدارة المستخدمين، مراقبة المحادثات، والتحكم بالصيانة.',
      ),
      _FeatureItem(
        icon: Icons.cloud_off_outlined,
        title: 'عمل بدون إنترنت',
        body: 'تخزين محلي للعقارات مع طابور مزامنة للطلبات عند عودة الاتصال.',
      ),
    ];

    final services = <String>[
      'API Server',
      'WebSocket Realtime',
      'Firebase Messaging',
      'Cloudinary Uploads',
      'Google Maps',
      'Offline Cache',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق')),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _GlowBlob(
              color: colorScheme.primary.withOpacity(0.15),
              size: 240,
              drift: 18,
            ),
          ),
          Positioned(
            bottom: -140,
            left: -90,
            child: _GlowBlob(
              color: colorScheme.secondary.withOpacity(0.18),
              size: 260,
              drift: 20,
              duration: Duration(seconds: 8),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Reveal(
                  delay: const Duration(milliseconds: 80),
                  child: _HeroCard(colorScheme: colorScheme, theme: theme),
                ),
                const SizedBox(height: 18),
                const _Reveal(
                  delay: Duration(milliseconds: 140),
                  child: _SectionHeader(
                    title: 'About the App (English)',
                    subtitle: 'A quick overview for English speakers.',
                  ),
                ),
                const SizedBox(height: 8),
                _Reveal(
                  delay: const Duration(milliseconds: 200),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      'Aqar Plus is a full real-estate platform that lets owners publish listings with rich media, '
                      'while buyers browse, filter, and chat instantly. It combines a smart map experience, '
                      'reputation system, and admin controls to keep the marketplace clean and reliable.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const _Reveal(
                  delay: Duration(milliseconds: 260),
                  child: _SectionHeader(
                    title: 'أبرز الميزات',
                    subtitle: 'كل ما يحتاجه المستخدم في تجربة واحدة.',
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 620;
                    final spacing = 14.0;
                    final itemWidth = isWide
                        ? (constraints.maxWidth - spacing) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: features.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return _Reveal(
                          delay: Duration(milliseconds: 120 + (index * 60)),
                          child: _FeatureCard(item: item, width: itemWidth),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 26),
                const _Reveal(
                  delay: Duration(milliseconds: 260),
                  child: _SectionHeader(
                    title: 'الخدمات والتكاملات',
                    subtitle: 'طبقات تقنية متكاملة تبقي الأداء سريعاً.',
                  ),
                ),
                const SizedBox(height: 8),
                _Reveal(
                  delay: const Duration(milliseconds: 300),
                  child: Text(
                    'يعتمد التطبيق على بنية خدمات مرنة تجمع بين API مركزي، تخزين وسائط، وإشعارات فورية لضمان تجربة موثوقة وسريعة.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ),
                const SizedBox(height: 12),
                _Reveal(
                  delay: const Duration(milliseconds: 360),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: services
                        .map(
                          (label) => Chip(
                            label: Text(label),
                            backgroundColor: colorScheme.primary.withOpacity(
                              0.1,
                            ),
                            labelStyle: TextStyle(color: colorScheme.primary),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                _Reveal(
                  delay: const Duration(milliseconds: 380),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'هوية الحساب',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'تسجيل دخول بالبريد وكلمة المرور، مع دعم تسجيل جوجل، وإدارة صلاحيات متعددة للمستخدمين (عضو عادي، مالك/مكتب، مدير).',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: const [
                            _StatChip(
                              icon: Icons.verified_user,
                              label: 'حسابات موثوقة',
                            ),
                            _StatChip(icon: Icons.group, label: 'أدوار متعددة'),
                            _StatChip(
                              icon: Icons.security,
                              label: 'خصوصية محمية',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const _Reveal(
                  delay: Duration(milliseconds: 420),
                  child: _SectionHeader(
                    title: 'قنوات التواصل',
                    subtitle: 'ابقَ على اتصال لمعرفة الجديد أولاً بأول.',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Reveal(
                      delay: const Duration(milliseconds: 480),
                      child: _ContactCard(
                        icon: Icons.campaign_outlined,
                        title: 'قناة التطبيق',
                        subtitle: 't.me/+yj3zSKtT_mYyZmU0',
                        onTap: () =>
                            _openLink('https://t.me/+yj3zSKtT_mYyZmU0'),
                      ),
                    ),
                    _Reveal(
                      delay: const Duration(milliseconds: 540),
                      child: _ContactCard(
                        icon: Icons.code_rounded,
                        title: 'مراسلة المطور',
                        subtitle: 't.me/DevDrond',
                        onTap: () => _openLink('https://t.me/DevDrond'),
                      ),
                    ),
                    _Reveal(
                      delay: const Duration(milliseconds: 600),
                      child: _ContactCard(
                        icon: Icons.phone_outlined,
                        title: 'اتصال مباشر',
                        subtitle: '+963991260012',
                        onTap: () => _makePhoneCall('+963991260012'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String body;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _HeroCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _HeroCard({required this.colorScheme, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            colorScheme.primary.withOpacity(0.2),
            colorScheme.secondary.withOpacity(0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'images/aqar_plus_bn.jpg',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عقار بلس',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'منصة عقارية متكاملة في تجربة واحدة.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _StatChip(icon: Icons.map, label: 'خرائط ذكية'),
                        _StatChip(icon: Icons.chat, label: 'محادثات فورية'),
                        _StatChip(icon: Icons.star, label: 'سمعة موثوقة'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'عقار بلس هو تطبيق عقاري شامل يتيح نشر العقارات مع صور وفيديو ومواصفات دقيقة، '
            'ويقدم تجربة تصفح سريعة مدعومة بخرائط ذكية وتواصل مباشر بين المالك والمهتم. '
            'تم تصميمه ليخدم احتياجات السوق المحلي مع أدوات متقدمة للإدارة والحماية.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatefulWidget {
  final Color color;
  final double size;
  final double drift;
  final Duration duration;

  const _GlowBlob({
    required this.color,
    required this.size,
    required this.drift,
    this.duration = const Duration(seconds: 6),
  });

  @override
  State<_GlowBlob> createState() => _GlowBlobState();
}

class _GlowBlobState extends State<_GlowBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shift = (widget.drift * (_controller.value - 0.5));
        final scale = 1 + (_controller.value * 0.1);
        return Transform.translate(
          offset: Offset(0, shift),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}

class _Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _Reveal({required this.child, this.delay = Duration.zero});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _scale = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _FeatureItem item;
  final double width;

  const _FeatureCard({required this.item, required this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.surface, colorScheme.surface.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primary.withOpacity(0.1),
            child: Icon(item.icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.body,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
