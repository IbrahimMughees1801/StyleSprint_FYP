# StyleSprint UI Remake README

This file explains the current Flutter UI so the entire interface can be redesigned without losing the app's behavior. The app is a fashion shopping experience with Firebase login, Supabase product loading, cart/checkout screens, profile screens, and a virtual try-on flow connected to the backend API.

## App Purpose

StyleSprint is a fashion store app where users can:

- Sign in or create an account with Firebase Auth.
- Browse products loaded from Supabase.
- Open product details.
- Try clothing virtually using the backend try-on API.
- Search products.
- Manage wishlist/cart/profile.
- Move through checkout and order tracking demo flows.

The UI can be remade visually, but these user flows should stay intact.

## Navigation Structure

Main navigation is controlled manually in `lib/main.dart` through the `AppScreen` enum and `AppNavigator`.

Current screens:

- `onboarding`
- `signin`
- `signup`
- `home`
- `product`
- `cart`
- `profile`
- `tryon`
- `wishlist`
- `search`
- `orderHistory`
- `checkout`
- `orderTracking`

There is no router package right now. Each screen receives callbacks such as `onBack`, `onNavigate`, or `onProductClick`, and calls those callbacks to switch screens.

Recommended remake approach:

- Keep the same `AppScreen` enum initially.
- Redesign screens one by one.
- Later, replace manual navigation with `go_router` or Flutter `Navigator` routes if needed.

## Current Design Language

Main theme file: `lib/theme/app_theme.dart`

Current style:

- White/light ecommerce layout.
- Purple-to-pink gradient as the main brand accent.
- Rounded cards and buttons.
- Material icons.
- Inter font from Google Fonts.
- Soft shadows.
- Product cards with image-first layout.
- Bottom navigation on main shopping screens.

Main colors:

- Purple: `AppTheme.purple600`
- Pink: `AppTheme.pink600`
- Dark text: `AppTheme.gray900`
- Light backgrounds: `AppTheme.gray50`, `gray100`
- Error: `AppTheme.red600`
- Success: `AppTheme.green600`

If remaking the UI, decide whether to keep the purple/pink identity or move to a cleaner fashion-brand palette.

## Screen-by-Screen Explanation

### 1. Onboarding

File: `lib/screens/onboarding_screen.dart`

Purpose:

- First app entry screen for new users.
- Sends user to sign-in through `onGetStarted`.

Remake notes:

- Should clearly introduce the app: fashion shopping plus virtual try-on.
- Needs one strong primary CTA: "Get Started" or "Start Shopping".

### 2. Sign In

File: `lib/screens/signin_screen.dart`

Purpose:

- Firebase email/password sign-in.
- Password reset.
- Link to sign-up screen.

Important behavior:

- Calls `FirebaseAuthService.signInWithEmail`.
- On success, calls `widget.onSignIn()` and navigates to home.
- Shows snackbars for auth errors.

Current UI:

- Gradient background.
- Centered white login card.
- Email and password fields.
- Password visibility toggle.
- Forgot password action.
- Gradient sign-in button.

Remake notes:

- Keep strong validation states.
- Keep password visibility toggle.
- Do not add Google/GitHub buttons unless those auth providers are actually implemented.

### 3. Sign Up

File: `lib/screens/signup_screen.dart`

Purpose:

- Firebase account creation.
- Creates user profile data in Firestore when possible.

Important behavior:

- Calls `FirebaseAuthService.signUpWithEmail`.
- Requires name, email, password, and confirm password.
- On success, calls `widget.onSignUp()` and navigates home.

Current UI:

- Same visual system as sign-in.
- Gradient background.
- White form card.
- Back button to sign-in.

Remake notes:

- Keep password confirmation.
- Add terms/privacy text if this becomes production-facing.

### 4. Home

File: `lib/screens/home_screen.dart`

Purpose:

- Main shopping landing screen after login.
- Combines header, hero, categories, virtual try-on promo, partners, product grid, and bottom nav.

Current layout order:

1. `Header`
2. `HeroBanner`
3. `CategoryBar`
4. `VirtualTryOnCard`
5. `StorePartners`
6. `ProductGrid`
7. `BottomNav`

Remake notes:

- This is the main screen to redesign first.
- Make products and try-on the most visible features.
- Current hero is promotional; a better remake could show a real product/editorial image.

### 5. Product Grid

File: `lib/widgets/product_grid.dart`

Purpose:

- Fetches products from Supabase.
- Displays product cards in a 2-column grid.

Important behavior:

- Uses `SupabaseProductsService.fetchProducts()`.
- Product tap calls `onProductClick(product.id)`.

Current UI:

- Product image.
- AR badge.
- Favorite icon.
- Brand label.
- Product name.
- Rating.
- Static price.

Remake notes:

- Product grid currently mixes real Supabase name/image with static price/rating.
- Future UI should support real price, category, and availability fields once database has them.

### 6. Product Detail

File: `lib/screens/product_detail_screen.dart`

Purpose:

- Displays one product from Supabase.
- Lets user choose size/color.
- Opens try-on dialog for that specific product.
- Has add-to-cart/buy-now actions.

Important behavior:

- Loads product by ID using `SupabaseProductsService.fetchProductById`.
- Try-on button opens `VirtualTryOnDialog`.
- Add to cart navigates to cart screen.

Current UI:

- Large image header using `SliverAppBar`.
- Favorite/share buttons.
- Floating "Try This On" button over product image.
- Product name, rating, price, color, size, description, features.
- Sticky bottom action bar.

Remake notes:

- Keep the try-on CTA very visible.
- Improve image gallery if multiple product photos are added later.
- Replace fake static price/rating with database fields later.

### 7. Virtual Try-On Screen

File: `lib/screens/virtual_tryon_screen.dart`

Purpose:

- Full-screen try-on experience.
- User captures/selects their photo.
- User selects a product.
- App sends person image and product image to backend.
- Shows generated result image.

Important behavior:

- Loads products from Supabase.
- Uses camera on mobile.
- Uses image picker fallback on web.
- Calls `VirtualTryOnService.processBase64Images`.
- Checks backend availability at `http://127.0.0.1:8000`.

Current UI:

- Black full-screen camera-style layout.
- Welcome screen before camera starts.
- Dialog for camera/gallery choice.
- Product carousel at bottom.
- Processing button.
- Result appears full-screen after backend returns it.

Remake notes:

- This should feel like a tool, not a product card.
- Make states very clear:
  - No photo selected.
  - Photo selected.
  - Product selected.
  - Processing.
  - Result ready.
  - Backend unavailable.
- Add a fallback message when real ML diffusion cannot run due to memory.

### 8. Virtual Try-On Dialog

File: `lib/widgets/virtual_tryon_dialog.dart`

Purpose:

- Product-specific try-on flow from product detail page.
- Uses selected product image as cloth.
- Lets user pick/capture a person image.

Remake notes:

- Could be replaced by navigating to the full try-on screen with selected product preloaded.
- That would make the UX more consistent.

### 9. Search

File: `lib/screens/search_screen.dart`

Purpose:

- Search products by name.
- Shows recent/trending search suggestions.
- Shows filter chips and sort menu.

Important behavior:

- Loads Supabase products.
- Local filtering by product name.
- Product result tap opens product detail.

Current UI:

- Top search bar.
- Recent searches.
- Trending chips.
- Filter bar with categories.
- Sort popup.

Remake notes:

- Current categories/sort are mostly UI-only.
- Make search feel simple: search bar, suggestions, results.
- Only show filters that actually affect data.

### 10. Wishlist

File: `lib/screens/wishlist_screen.dart`

Purpose:

- Displays saved products.
- Allows remove from wishlist.
- Has "Add All to Cart".

Current behavior:

- Uses first few Supabase products as demo wishlist data.
- Not yet connected to real user wishlist persistence.

Remake notes:

- Treat it as a saved-products screen.
- Later connect to Firestore user document or Supabase table.

### 11. Cart

File: `lib/screens/cart_screen.dart`

Purpose:

- Shopping cart demo screen.
- Quantity controls.
- Remove item.
- Promo code area.
- Bottom price summary.
- Checkout CTA.

Current behavior:

- Uses hardcoded cart items.
- Checkout navigates to checkout screen.

Remake notes:

- Cart is currently demo-state only.
- If remaking the UI, keep the bottom summary sticky.
- Later connect cart state to user/session storage.

### 12. Checkout

File: `lib/screens/checkout_screen.dart`

Purpose:

- Demo checkout flow.
- Address selection.
- Payment method selection.
- Order summary.
- Place order confirmation.

Current behavior:

- Loads a couple of Supabase products as cart demo items.
- Uses hardcoded addresses and payment methods.
- On order placed, navigates to order history.

Remake notes:

- Current payment/address data is fake.
- Keep checkout visually structured into steps.
- Avoid over-polishing payment until real order backend exists.

### 13. Profile

File: `lib/screens/profile_screen.dart`

Purpose:

- Shows Firebase user's display name/email.
- Provides profile menu actions.
- Theme toggle.
- Sign out.

Important behavior:

- Uses `FirebaseAuthService.currentUser`.
- Calls `FirebaseAuthService.signOut`.
- Theme change callback updates app theme.

Current UI:

- Gradient header.
- Avatar circle.
- Stats card.
- Menu list.
- Bottom nav.

Remake notes:

- Some menu items are placeholders.
- Keep sign out clear and safe.
- Use real order/wishlist counts later.

### 14. Order History and Tracking

Files:

- `lib/screens/order_history_screen.dart`
- `lib/screens/order_tracking_screen.dart`

Purpose:

- Demo post-checkout order screens.
- Show previous orders.
- Track an order by ID.

Current behavior:

- Mostly static/demo data.

Remake notes:

- These can stay simple for now.
- The main project value is product browsing plus virtual try-on.

## Reusable Widgets

### Header

File: `lib/widgets/header.dart`

Current role:

- Home top bar.
- Menu/profile button.
- Center brand text.
- Cart button with hardcoded badge.

Remake idea:

- Replace "Fashion Store" with final brand name.
- Add search shortcut.
- Make cart count dynamic later.

### BottomNav

File: `lib/widgets/bottom_nav.dart`

Current role:

- Bottom navigation for Home, Search, Cart, Wishlist, Profile.

Current issue:

- It stores selected tab internally, so selected state can become wrong when navigation happens externally.

Remake idea:

- Pass current tab from parent.
- Keep bottom nav only on main tabs, not on focused flows like try-on or checkout.

### HeroBanner

File: `lib/widgets/hero_banner.dart`

Current role:

- Promotional banner for "Summer Collection 2026".

Current issue:

- Contains broken encoded emoji text.
- Uses decorative circles instead of real fashion imagery.

Remake idea:

- Use a real product/fashion image background.
- Keep text readable and CTA clear.

### CategoryBar

File: `lib/widgets/category_bar.dart`

Current role:

- Horizontal categories.

Remake idea:

- Connect categories to real product filters.

### VirtualTryOnCard

File: `lib/widgets/virtual_tryon_card.dart`

Current role:

- Promotional card on home screen that opens the try-on screen.

Remake idea:

- Make this a high-priority section.
- Explain value in one line: upload photo, select outfit, preview.

### StorePartners

File: `lib/widgets/store_partners.dart`

Current role:

- Shows partner/store branding.

Remake idea:

- Keep only if partner stores matter to the project.
- Otherwise replace with "Trending styles" or "New arrivals".

## Data Sources

### Firebase

Used for:

- User authentication.
- User profile document sync in Firestore.

Files:

- `lib/services/firebase_auth_service.dart`
- `lib/firebase_options.dart`

Current auth:

- Email/password sign-in.
- Email/password sign-up.
- Password reset.
- Sign out.

### Supabase

Used for:

- Product photos/products.

Files:

- `lib/services/supabase_config.dart`
- `lib/services/supabase_products_service.dart`
- `lib/models/product_photo.dart`

Important:

- Products currently show in the app after Supabase project resume and RLS policy fix.

### Backend API

Used for:

- Virtual try-on image processing.

Files:

- `lib/services/virtual_tryon_service.dart`
- Backend URL currently points to `http://127.0.0.1:8000`.

Current backend modes:

- Simplified overlay works.
- Real ML pipeline reaches DCI diffusion but is blocked by machine memory.

## Current UI Problems to Fix in Remake

High priority:

- Make navigation state cleaner.
- Make bottom nav selected state controlled by parent.
- Replace hardcoded cart/wishlist/profile stats.
- Replace static prices/ratings with real data fields.
- Improve backend unavailable/error states in try-on.
- Remove placeholder buttons that do nothing.
- Make hero/banner use real fashion imagery.
- Fix broken encoded emoji text in some files.

Medium priority:

- Make product detail responsive for web/tablet.
- Add empty states for all Supabase loading failures.
- Add skeleton loaders instead of only spinners.
- Create shared button/input/card components.
- Use consistent border radius and spacing.

Low priority:

- Add animations after layout is stable.
- Add social login only after Firebase providers are configured.
- Add real order/payment/address persistence later.

## Recommended New UI Architecture

When remaking the UI, create a cleaner structure:

```text
lib/
  app/
    app.dart
    app_router.dart
  theme/
    app_theme.dart
    app_colors.dart
    app_spacing.dart
  screens/
    auth/
    home/
    product/
    tryon/
    cart/
    profile/
  widgets/
    app_button.dart
    app_text_field.dart
    app_card.dart
    app_bottom_nav.dart
    product_card.dart
```

Suggested remake order:

1. Theme and shared components.
2. Auth screens.
3. Home screen.
4. Product grid/card.
5. Product detail.
6. Try-on screen.
7. Cart and checkout.
8. Profile.
9. Search/wishlist/order screens.

## Suggested New Visual Direction

For a final-year project demo, the UI should feel polished but not overloaded.

Recommended style:

- Clean fashion ecommerce look.
- White/near-white background.
- Dark text.
- One strong accent color.
- Real clothing images as primary visual asset.
- Fewer decorative gradients.
- Cards with 8-16px radius.
- Clear CTAs.
- Dense enough for shopping, not a marketing landing page.

Good first screen:

- Header with brand/search/cart.
- Large product/trend section with real product imagery.
- Virtual try-on CTA.
- Product grid from Supabase.

## Preserve These Behaviors During Redesign

Do not break:

- Firebase initialization in `main.dart`.
- Supabase initialization in `main.dart`.
- Auth callbacks from sign-in/sign-up to home.
- Product grid fetching from Supabase.
- Product detail loading by product ID.
- Try-on API calls through `VirtualTryOnService`.
- Profile sign-out.
- Checkout navigation to order history.

## Quick Status

Current project UI readiness:

- Auth UI: polished recently.
- Product browsing: working with Supabase.
- Product detail: working.
- Try-on UI: working with simplified backend result.
- Real ML try-on: backend reaches final diffusion but hardware memory blocks completion.
- Cart/checkout/profile/search: usable demo flows, partly static.

Estimated UI remake effort:

- Light visual refresh: 1-2 days.
- Full redesign with shared components: 3-5 days.
- Full redesign plus real cart/wishlist/order persistence: 1-2 weeks.
