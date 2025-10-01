import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'participant_screen.dart';
import 'supervisor_screen.dart';
import 'statistics_screen.dart';
import 'offline_database_screen.dart';
import 'unsent_data_screen.dart';
import 'settings_screen.dart';
import '../design/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _fadeAnimations;

  final List<MenuItemData> _menuItems = [
    MenuItemData(
      title: 'İmtahan iştirakçıları',
      icon: Icons.school,
      gradient: AppColors.participantGradient,
      route: '/participants',
    ),
    MenuItemData(
      title: 'Nəzarətçilər',
      icon: Icons.supervisor_account,
      gradient: AppColors.supervisorGradient,
      route: '/supervisors',
    ),
    MenuItemData(
      title: 'Göndərilməmiş\nməlumatlar',
      icon: Icons.signal_cellular_off,
      gradient: AppColors.orangeGradient,
      route: '/offline-data',
    ),
    MenuItemData(
      title: 'Statistika',
      icon: Icons.analytics,
      gradient: AppColors.greenGradient,
      route: '/statistics',
    ),
    MenuItemData(
      title: 'Oflayn baza',
      icon: Icons.storage,
      gradient: AppColors.purpleGradient,
      route: '/database',
    ),
    MenuItemData(
      title: 'Ayarlar',
      icon: Icons.settings,
      gradient: AppColors.blueGradient,
      route: '/settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Initialize animation controllers for each menu item
    _animationControllers = List.generate(
      _menuItems.length,
      (index) => AnimationController(
        duration: Duration(milliseconds: 800 + (index * 100)),
        vsync: this,
      ),
    );

    // Initialize scale animations
    _scaleAnimations = _animationControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.elasticOut),
      );
    }).toList();

    // Initialize fade animations
    _fadeAnimations = _animationControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeIn),
      );
    }).toList();

    // Start animations with staggered delay
    _startAnimations();
  }

  void _startAnimations() {
    for (int i = 0; i < _animationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _animationControllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    AppColors.backgroundDark,
                    AppColors.backgroundMedium,
                    AppColors.backgroundLight,
                  ]
                : [
                    AppColors.lightBackground,
                    AppColors.lightGrey,
                  ],
          ),
        ),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Custom App Bar
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.lightBlue,
                        AppColors.darkBlue,
                        AppColors.primaryBlue,
                      ],
                    ),
                  ),
                  child: const SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 40),
                        Text(
                          'Xoş gəldiniz',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Buraxılış sistemini idarə edin',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Menu Grid
            SliverPadding(
              padding: const EdgeInsets.all(20.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return AnimatedBuilder(
                      animation: _scaleAnimations[index],
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimations[index].value,
                          child: FadeTransition(
                            opacity: _fadeAnimations[index],
                            child: MenuCard(
                              item: _menuItems[index],
                              onTap: () => _handleMenuTap(_menuItems[index]),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  childCount: _menuItems.length,
                ),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuTap(MenuItemData item) {
    // Add haptic feedback
    HapticFeedback.lightImpact();

    // Navigate to the respective screen
    switch (item.route) {
      case '/participants':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ParticipantScreen(),
          ),
        );
        break;
      case '/supervisors':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SupervisorScreen(),
          ),
        );
        break;
      case '/offline-data':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const UnsentDataScreen(),
          ),
        );
        break;
      case '/statistics':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const StatisticsScreen(),
          ),
        );
        break;
      case '/database':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const OfflineDatabaseScreen(),
          ),
        );
        break;
      case '/settings':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
          ),
        );
        break;
    }
  }

  void _showComingSoonDialog(String screenName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(screenName),
        content: const Text('Bu bölmə tezliklə hazır olacaq...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}

class MenuCard extends StatefulWidget {
  final MenuItemData item;
  final VoidCallback onTap;

  const MenuCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<MenuCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _pressController.forward(),
            onTapUp: (_) => _pressController.reverse(),
            onTapCancel: () => _pressController.reverse(),
            onTap: widget.onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.item.gradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.item.gradient.first.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon container
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          widget.item.icon,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Title
                      Flexible(
                        child: Text(
                          widget.item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MenuItemData {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final String route;

  MenuItemData({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.route,
  });
}
