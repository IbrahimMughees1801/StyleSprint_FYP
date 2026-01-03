import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fashion Store',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppNavigator(),
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
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  AppScreen _currentScreen = AppScreen.onboarding;
  int? _selectedProductId;
  String? _selectedOrderId;

  void _navigateTo(AppScreen screen) {
    setState(() {
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
