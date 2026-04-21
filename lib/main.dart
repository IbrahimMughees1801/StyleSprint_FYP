import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/virtual_tryon_screen.dart';
import 'screens/wishlist_screen.dart';
import 'screens/search_screen.dart';
import 'screens/order_history_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'services/firebase_auth_service.dart';
import 'services/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
  home,
  product,
  cart,
  profile,
  tryon,
  wishlist,
  search,
  orderHistory,
  checkout,
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
  bool _hasSeenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          if (user != null) {
            // User is signed in, navigate to home
            _currentScreen = AppScreen.home;
          } else if (_hasSeenOnboarding) {
            // User signed out, go to sign in
            _currentScreen = AppScreen.signin;
          }
        });
      }
    });

    // Check if user is already logged in
    if (_authService.currentUser != null) {
      _currentScreen = AppScreen.home;
      _hasSeenOnboarding = true;
    }
  }

  void _navigateTo(AppScreen screen) {
    setState(() {
      if (screen == AppScreen.home || screen == AppScreen.signin || screen == AppScreen.signup) {
        _hasSeenOnboarding = true;
      }
      _currentScreen = screen;
    });
  }

  void _navigateToProduct(int productId) {
    setState(() {
      _selectedProductId = productId;
      _currentScreen = AppScreen.product;
    });
  }

  void _navigateToOrderTracking(String orderId) {
    setState(() {
      _selectedOrderId = orderId;
      _currentScreen = AppScreen.orderTracking;
    });
  }

  Widget _buildCurrentScreen() {
    switch (_currentScreen) {
      case AppScreen.onboarding:
        return OnboardingScreen(
          onGetStarted: () => _navigateTo(AppScreen.signin),
        );
      case AppScreen.signin:
        return SignInScreen(
          onSignIn: () => _navigateTo(AppScreen.home),
          onSignUp: () => _navigateTo(AppScreen.signup),
        );
      case AppScreen.signup:
        return SignUpScreen(
          onSignUp: () => _navigateTo(AppScreen.home),
          onSignIn: () => _navigateTo(AppScreen.signin),
        );
      case AppScreen.home:
        return HomeScreen(
          onNavigate: _navigateTo,
          onProductClick: _navigateToProduct,
        );
      case AppScreen.product:
        return ProductDetailScreen(
          productId: _selectedProductId ?? 1,
          onBack: () => _navigateTo(AppScreen.home),
          onNavigate: _navigateTo,
        );
      case AppScreen.cart:
        return CartScreen(
          onBack: () => _navigateTo(AppScreen.home),
          onNavigate: _navigateTo,
        );
      case AppScreen.profile:
        return ProfileScreen(
          onBack: () => _navigateTo(AppScreen.home),
          onSignOut: () => _navigateTo(AppScreen.signin),
          onNavigate: _navigateTo,
          onThemeChange: widget.onThemeChange,
        );
      case AppScreen.tryon:
        return VirtualTryOnScreen(
          onBack: () => _navigateTo(AppScreen.home),
        );
      case AppScreen.wishlist:
        return WishlistScreen(
          onBack: () => _navigateTo(AppScreen.home),
          onProductClick: _navigateToProduct,
        );
      case AppScreen.search:
        return SearchScreen(
          onProductClick: _navigateToProduct,
          onBack: () => _navigateTo(AppScreen.home),
        );
      case AppScreen.orderHistory:
        return OrderHistoryScreen(
          onBack: () => _navigateTo(AppScreen.home),
          onOrderClick: _navigateToOrderTracking,
        );
      case AppScreen.checkout:
        return CheckoutScreen(
          onBack: () => _navigateTo(AppScreen.cart),
          onOrderPlaced: () => _navigateTo(AppScreen.orderHistory),
        );
      case AppScreen.orderTracking:
        return OrderTrackingScreen(
          orderId: _selectedOrderId ?? 'ORD-2024-001',
          onBack: () => _navigateTo(AppScreen.orderHistory),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildCurrentScreen();
  }
}
