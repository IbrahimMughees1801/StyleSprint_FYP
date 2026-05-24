# Fashion Store - Flutter E-commerce App

A complete e-commerce Flutter application featuring a clothing store with virtual try-on capabilities.

## Features

### 🎯 Core Features
- **Onboarding Flow**: 3-slide introduction with smooth animations
- **Authentication**: Sign in/Sign up screens with form validation
- **Home Screen**: 
  - Hero banner with promotional content
  - Category filtering
  - Store partners showcase
  - Product grid with AR badges
  - Bottom navigation
- **Product Details**: 
  - High-quality product images
  - Size and color selection
  - Ratings and reviews
  - Add to cart / Buy now
  - Virtual try-on integration
- **Shopping Cart**: 
  - Quantity management
  - Promo code input
  - Price breakdown (subtotal, shipping, tax)
- **User Profile**: 
  - User stats (orders, wishlist, reviews)
  - Settings and preferences
  - Sign out
- **Virtual Try-On**: AI-powered AR feature to visualize clothing

### 🎨 Design System
- Modern UI with purple/pink gradient theme
- Smooth animations and transitions
- Responsive layouts
- Dark mode ready (theme configured)
- Google Fonts (Inter) typography

## Project Structure

```
lib/
├── main.dart                    # App entry point and navigation
├── theme/
│   └── app_theme.dart          # Theme configuration and colors
├── models/
│   └── product.dart            # Product and CartItem models
├── screens/
│   ├── onboarding_screen.dart  # Welcome/intro screens
│   ├── signin_screen.dart      # User authentication
│   ├── signup_screen.dart      # User registration
│   ├── home_screen.dart        # Main shopping screen
│   ├── product_detail_screen.dart
│   ├── cart_screen.dart
│   ├── profile_screen.dart
│   └── virtual_tryon_screen.dart
└── widgets/
    ├── header.dart             # App header with cart badge
    ├── hero_banner.dart        # Promotional banner
    ├── category_bar.dart       # Horizontal category filter
    ├── virtual_tryon_card.dart # AR feature promotion
    ├── store_partners.dart     # Brand logos
    ├── product_grid.dart       # Product listing
    └── bottom_nav.dart         # Bottom navigation bar
```

## Getting Started

### Prerequisites
- Flutter SDK (^3.10.4)
- Dart SDK
- Android Studio / VS Code
- An emulator or physical device

### Installation

1. **Clone the repository**
```bash
cd fyp_app
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Run the app**
```bash
flutter run
```

## Dependencies

- **google_fonts**: Custom typography
- **cached_network_image**: Optimized image loading
- **camera**: Camera access for AR features
- **image_picker**: Image selection
- **flutter_animate**: Smooth animations
- **provider**: State management (configured, ready to use)

## Screenshots & Navigation Flow

1. **Onboarding** → Sign In/Sign Up
2. **Home Screen** → Product Grid → Product Details
3. **Product Details** → Cart or Virtual Try-On
4. **Bottom Nav**: Home, Search, Cart, Wishlist, Profile

## Customization

### Colors
Edit `lib/theme/app_theme.dart` to change:
- Primary colors (purple/pink gradient)
- Gray scale
- Accent colors (red, green, blue, etc.)

### Products
Add/modify products in `lib/models/product.dart`:
```dart
final List<Product> sampleProducts = [
  Product(
    id: 1,
    name: 'Your Product',
    store: 'Brand Name',
    price: '\$99.99',
    image: 'image_url',
    rating: 4.5,
    virtualTryOn: true,
    category: 'Category',
  ),
];
```

## Next Steps & Enhancements

### Backend Integration
- Connect to REST API/Firebase
- Real authentication
- User data persistence
- Order management

### Virtual Try-On
- Integrate AR SDK (ARCore/ARKit)
- Real-time camera feed processing
- AI model for clothing overlay

### Features to Add
- Search functionality
- Wishlist management
- Order tracking
- Payment gateway integration
- Push notifications
- Reviews and ratings system
- Social sharing

### Performance
- Add state management (Provider already configured)
- Implement lazy loading
- Optimize image caching
- Add error handling

## Development Tips

### Hot Reload
```bash
# Press 'r' in terminal for hot reload
# Press 'R' for hot restart
```

### Debug Mode
```bash
flutter run --debug
```

### Build Release
```bash
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

### Analyze Code
```bash
flutter analyze
```

## Known Issues

- `withOpacity` deprecation warnings (cosmetic, not affecting functionality)
- Virtual try-on is simulated (needs AR SDK integration)

## License

This is a Final Year Project. All rights reserved.

## Contact

For questions or collaboration, please contact the development team.

---

**Built with Flutter 💙**
