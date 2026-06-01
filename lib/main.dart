import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/home_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/virtual_tryon_screen.dart';
import 'screens/wishlist_screen.dart';
import 'screens/search_screen.dart';
import 'screens/order_history_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/order_success_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'services/firebase_auth_service.dart';
import 'services/saved_tryon_service.dart';
import 'services/supabase_config.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with generated options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fashion Store',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: AppNavigator(
        onThemeChange: (mode) {
          setState(() {
            _themeMode = mode;
          });
        },
      ),
    );
  }
}

enum AppScreen {
  onboarding,
  signin,
  signup,
  verifyEmail,
  home,
  product,
  cart,
  profile,
  tryon,
  wishlist,
  search,
  orderHistory,
  checkout,
  orderSuccess,
  orderTracking,
}

class AppNavigator extends StatefulWidget {
  final Function(ThemeMode) onThemeChange;

  const AppNavigator({super.key, required this.onThemeChange});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  AppScreen _currentScreen = AppScreen.onboarding;
  int? _selectedProductId;
  String? _selectedOrderId;
  final _authService = FirebaseAuthService();
  final _savedTryOnService = SavedTryOnService.instance;
  bool _hasSeenOnboarding = false;
  final List<_NavigationEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    _savedTryOnService.addListener(_handleSavedTryOnUpdate);
    unawaited(_savedTryOnService.load());
  }

  @override
  void dispose() {
    _savedTryOnService.removeListener(_handleSavedTryOnUpdate);
    super.dispose();
  }

  void _handleSavedTryOnUpdate() {
    final completedSessionId = _savedTryOnService
        .consumeLatestCompletedSessionId();
    if (completedSessionId == null || !mounted) return;

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Your try-on is ready.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            _navigateTo(AppScreen.profile);
          },
        ),
      ),
    );
  }

  void _checkAuthState() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          if (user != null) {
            _hasSeenOnboarding = true;
            if (_authService.isCurrentUserPasswordAccount &&
                !_authService.isCurrentUserEmailVerified) {
              _history.clear();
              _currentScreen = AppScreen.verifyEmail;
            } else {
              _history.clear();
              _currentScreen = AppScreen.home;
            }
          } else if (_hasSeenOnboarding) {
            // User signed out, go to sign in
            _history.clear();
            _currentScreen = AppScreen.signin;
          }
        });
      }
    });

    // Check if user is already logged in
    if (_authService.currentUser != null) {
      if (_authService.isCurrentUserPasswordAccount &&
          !_authService.isCurrentUserEmailVerified) {
        _currentScreen = AppScreen.verifyEmail;
      } else {
        _currentScreen = AppScreen.home;
      }
      _hasSeenOnboarding = true;
    }
  }

  _NavigationEntry get _currentEntry {
    return _NavigationEntry(
      screen: _currentScreen,
      productId: _selectedProductId,
      orderId: _selectedOrderId,
    );
  }

  bool get _isRootScreen {
    return _currentScreen == AppScreen.onboarding ||
        _currentScreen == AppScreen.signin ||
        _currentScreen == AppScreen.home;
  }

  void _navigateTo(
    AppScreen screen, {
    bool trackHistory = true,
    bool clearHistory = false,
  }) {
    setState(() {
      if (clearHistory) {
        _history.clear();
      } else if (trackHistory && screen != _currentScreen) {
        _history.add(_currentEntry);
      }

      if (screen == AppScreen.home ||
          screen == AppScreen.signin ||
          screen == AppScreen.signup ||
          screen == AppScreen.verifyEmail) {
        _hasSeenOnboarding = true;
      }
      _currentScreen = screen;
    });
  }

  void _navigateToProduct(int productId) {
    setState(() {
      if (_currentScreen != AppScreen.product ||
          _selectedProductId != productId) {
        _history.add(_currentEntry);
      }
      _selectedProductId = productId;
      _currentScreen = AppScreen.product;
    });
  }

  void _navigateToOrderTracking(String orderId) {
    setState(() {
      if (_currentScreen != AppScreen.orderTracking ||
          _selectedOrderId != orderId) {
        _history.add(_currentEntry);
      }
      _selectedOrderId = orderId;
      _currentScreen = AppScreen.orderTracking;
    });
  }

  void _navigateToOrderSuccess(String orderId) {
    setState(() {
      if (_currentScreen != AppScreen.orderSuccess ||
          _selectedOrderId != orderId) {
        _history.add(_currentEntry);
      }
      _selectedOrderId = orderId;
      _currentScreen = AppScreen.orderSuccess;
    });
  }

  bool _goBack({AppScreen fallback = AppScreen.home}) {
    if (_history.isNotEmpty) {
      final previous = _history.removeLast();
      setState(() {
        _currentScreen = previous.screen;
        _selectedProductId = previous.productId;
        _selectedOrderId = previous.orderId;
      });
      return true;
    }

    if (_currentScreen != fallback && !_isRootScreen) {
      _navigateTo(fallback, trackHistory: false);
      return true;
    }

    return false;
  }

  void _handleSystemBack() {
    final handled = _goBack();
    if (!handled) {
      SystemNavigator.pop();
    }
  }

  Widget _buildCurrentScreen() {
    switch (_currentScreen) {
      case AppScreen.onboarding:
        return OnboardingScreen(
          onGetStarted: () => _navigateTo(AppScreen.signin),
        );
      case AppScreen.signin:
        return SignInScreen(
          onSignIn: () => _navigateTo(AppScreen.home, clearHistory: true),
          onSignUp: () => _navigateTo(AppScreen.signup),
          onEmailVerificationRequired: () => _navigateTo(AppScreen.verifyEmail),
        );
      case AppScreen.signup:
        return SignUpScreen(
          onSignUp: () => _navigateTo(AppScreen.home, clearHistory: true),
          onSignIn: () => _goBack(fallback: AppScreen.signin),
          onEmailVerificationRequired: () => _navigateTo(AppScreen.verifyEmail),
        );
      case AppScreen.verifyEmail:
        return EmailVerificationScreen(
          onVerified: () => _navigateTo(AppScreen.home, clearHistory: true),
          onBackToSignIn: () =>
              _navigateTo(AppScreen.signin, clearHistory: true),
        );
      case AppScreen.home:
        return HomeScreen(
          onNavigate: _navigateTo,
          onProductClick: _navigateToProduct,
        );
      case AppScreen.product:
        return ProductDetailScreen(
          productId: _selectedProductId ?? 1,
          onBack: () => _goBack(),
          onNavigate: _navigateTo,
        );
      case AppScreen.cart:
        return CartScreen(onBack: () => _goBack(), onNavigate: _navigateTo);
      case AppScreen.profile:
        return ProfileScreen(
          onBack: () => _goBack(),
          onSignOut: () => _navigateTo(AppScreen.signin, clearHistory: true),
          onNavigate: _navigateTo,
          onThemeChange: widget.onThemeChange,
        );
      case AppScreen.tryon:
        return VirtualTryOnScreen(onBack: () => _goBack());
      case AppScreen.wishlist:
        return WishlistScreen(
          onBack: () => _goBack(),
          onProductClick: _navigateToProduct,
        );
      case AppScreen.search:
        return SearchScreen(
          onProductClick: _navigateToProduct,
          onBack: () => _goBack(),
        );
      case AppScreen.orderHistory:
        return OrderHistoryScreen(
          onBack: () => _goBack(),
          onOrderClick: _navigateToOrderTracking,
        );
      case AppScreen.checkout:
        return CheckoutScreen(
          onBack: () => _goBack(fallback: AppScreen.cart),
          onOrderPlaced: _navigateToOrderSuccess,
        );
      case AppScreen.orderSuccess:
        return OrderSuccessScreen(
          orderId: _selectedOrderId ?? '',
          onContinueShopping: () =>
              _navigateTo(AppScreen.home, clearHistory: true),
          onViewOrders: () => _navigateTo(AppScreen.orderHistory),
          onTrackOrder: _navigateToOrderTracking,
        );
      case AppScreen.orderTracking:
        return OrderTrackingScreen(
          orderId: _selectedOrderId ?? '',
          onBack: () => _goBack(fallback: AppScreen.orderHistory),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: _buildCurrentScreen(),
    );
  }
}

class _NavigationEntry {
  final AppScreen screen;
  final int? productId;
  final String? orderId;

  const _NavigationEntry({required this.screen, this.productId, this.orderId});
}
