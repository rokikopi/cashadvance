import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cashadvance/theme/constants.dart';
import 'package:cashadvance/screens/register_page.dart';
import 'package:cashadvance/screens/login_page.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late PageController _imageController;
  int _virtualPage = 1000;
  Timer? _timer;
  bool _isUserInteracting = false;

  // Hover state for the login link
  bool _isLoginHovered = false;

  final List<Map<String, String>> slideData = [
    {"title": "Manage Your Finances Smarter", "image": "assets/images/page1.jpg"},
    {"title": "Instant Cash Advances When Needed", "image": "assets/images/page2.jpg"},
    {"title": "Secure and Fast Transactions", "image": "assets/images/page3.jpg"},
  ];

  @override
  void initState() {
    super.initState();
    _imageController = PageController(initialPage: _virtualPage);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isUserInteracting) {
        _virtualPage++;
        _animateToIndex(_virtualPage);
      }
    });
  }

  void _animateToIndex(int index) {
    if (_imageController.hasClients) {
      _imageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOutQuart,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int actualIndex = _virtualPage % slideData.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 900;
          return Row(
            children: [
              Expanded(
                flex: isDesktop ? 7 : 1,
                child: isDesktop
                    ? _buildImageSlider()
                    : _buildMobileStackedLayout(actualIndex),
              ),
              if (isDesktop)
                Expanded(
                  flex: 3,
                  child: _buildFixedContentArea(true, actualIndex),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileStackedLayout(int actualIndex) {
    return Column(
      children: [
        Expanded(flex: 3, child: _buildImageSlider()),
        Expanded(flex: 2, child: _buildFixedContentArea(false, actualIndex)),
      ],
    );
  }

  Widget _buildImageSlider() {
    return ScrollConfiguration(
      behavior: AppScrollBehavior(),
      child: Listener(
        onPointerDown: (_) => setState(() => _isUserInteracting = true),
        onPointerUp: (_) {
          setState(() => _isUserInteracting = false);
          _startTimer();
        },
        child: PageView.builder(
          key: const PageStorageKey('myInfiniteSlider'),
          controller: _imageController,
          onPageChanged: (index) => setState(() => _virtualPage = index),
          itemBuilder: (context, index) {
            int dataIndex = index % slideData.length;
            return Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(slideData[dataIndex]["image"]!),
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFixedContentArea(bool isDesktop, int actualIndex) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40.0, 20.0, 40.0, 20.0),
      child: Stack(
        children: [
          Align(
            alignment: isDesktop ? Alignment.topLeft : Alignment.topCenter,
            child: Image.network(
              'assets/assets/images/logo.png',
              height: isDesktop ? 120 : 80,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.account_balance_wallet,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          ),

          Align(
            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isDesktop
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Text(
                    slideData[actualIndex]["title"]!,
                    key: ValueKey<int>(actualIndex),
                    textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: isDesktop ? 36.0 : 26.0,
                      height: 1.2,
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                _buildPageIndicator(actualIndex),
              ],
            ),
          ),

          Align(
            alignment: isDesktop
                ? Alignment.bottomLeft
                : Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryButton(
                  text: "Get Started",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12.0), // Slightly increased spacing
                _buildLoginLink(),
                const SizedBox(height: 10.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int actualIndex) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(slideData.length, (index) {
        return GestureDetector(
          onTap: () {
            int currentActual = _virtualPage % slideData.length;
            setState(() {
              _virtualPage += (index - currentActual);
              _animateToIndex(_virtualPage);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: index == actualIndex ? 30.0 : 10.0,
            height: 10.0,
            margin: const EdgeInsets.only(right: 8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: index == actualIndex
                  ? AppColors.primary
                  : AppColors.highlight,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLoginLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        MouseRegion(
          onEnter: (_) => setState(() => _isLoginHovered = true),
          onExit: (_) => setState(() => _isLoginHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isLoginHovered
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isLoginHovered
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                "Log In",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _isLoginHovered
                      ? AppColors.primaryHover
                      : AppColors.primary,
                  fontWeight: _isLoginHovered
                      ? FontWeight.w800
                      : FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  const PrimaryButton({super.key, required this.text, required this.onPressed});

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: double.infinity,
          height: 55,
          transform: isHovered
              ? Matrix4.diagonal3Values(1.02, 1.02, 1.0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: isHovered ? AppColors.primaryHover : AppColors.primary,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: isHovered ? 0.4 : 0.2,
                ),
                blurRadius: isHovered ? 15 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.text,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
