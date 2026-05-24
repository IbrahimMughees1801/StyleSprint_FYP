# Google Stitch Prompt: StyleSprint UI Redesign

Design a complete modern Flutter mobile app UI for a fashion ecommerce app called **StyleSprint**. The app combines online clothing shopping with an AI-powered virtual try-on feature.

## Product Context

StyleSprint lets users:

- Sign in or create an account.
- Browse fashion products.
- View product details.
- Select product size and color.
- Try clothing virtually by uploading/capturing a photo.
- Search products.
- Save items to wishlist.
- Add items to cart.
- Checkout.
- View profile, orders, and settings.

The design should feel polished enough for a final-year project demo and realistic enough to look like a real fashion shopping app.

## Main Design Goal

Create a clean, premium, mobile-first fashion shopping experience where the **virtual try-on feature feels like the hero feature**, not a hidden extra.

The UI should be modern, clear, and usable. Avoid looking like a generic template.

## Visual Directions To Explore

Please generate UI concepts in multiple possible styles:

### Direction 1: Premium Minimal Fashion

- White or soft off-white background.
- Black/charcoal typography.
- Large product photography.
- Subtle borders and shadows.
- Simple luxury ecommerce feel.
- Accent color can be deep purple, black, or muted rose.
- Best for a polished fashion-brand look.

### Direction 2: AI Try-On First

- The app feels like a shopping app built around AI.
- Home screen should prominently show "Virtual Try-On".
- Use clean futuristic accents, but do not make it too sci-fi.
- Use gradients sparingly for AI actions.
- Try-on screen should feel like a camera/editor tool.
- Best for showing the FYP innovation clearly.

### Direction 3: Youthful Streetwear Marketplace

- Energetic, bold, trend-focused.
- Larger product cards.
- Category chips like Hoodies, Dresses, Sneakers, Shirts.
- More playful colors, but still clean.
- Home screen can feel like a discovery feed.
- Best for a student/fashion audience.

### Direction 4: Practical Shopping Utility

- Dense, efficient layout.
- Product browsing is fast and clear.
- Bottom navigation is always visible on shopping screens.
- Search and filters are easy to reach.
- Minimal decoration.
- Best if the app should feel reliable and functional.

## Preferred Final Direction

Use a blend of:

- Premium Minimal Fashion
- AI Try-On First

The app should feel like a real fashion ecommerce app, with the virtual try-on feature presented as the key differentiator.

## App Screens To Design

Design the following screens:

1. Splash or onboarding screen
2. Sign in screen
3. Sign up screen
4. Home screen
5. Product listing/grid section
6. Product detail screen
7. Virtual try-on start screen
8. Virtual try-on active camera/photo screen
9. Virtual try-on result screen
10. Search screen
11. Wishlist screen
12. Cart screen
13. Checkout screen
14. Profile screen
15. Order history screen
16. Order tracking screen

## Navigation

Use bottom navigation for the main shopping app:

- Home
- Search
- Try-On
- Wishlist
- Profile

Cart can be accessed from the header or product detail page.

Try-On should be central or visually emphasized in the bottom navigation because it is the main unique feature.

## Home Screen Requirements

The home screen should include:

- Top app bar with brand name **StyleSprint**
- Search shortcut
- Cart icon
- Hero section using real-looking fashion/product imagery
- Prominent Virtual Try-On CTA
- Category chips or tabs
- Featured/New Arrival product grid
- Product cards loaded from ecommerce data

Avoid a generic landing page. The first screen should already feel like a usable shopping app.

## Product Card Requirements

Each product card should show:

- Product image
- Product name
- Price
- Rating or small review indicator
- Wishlist/favorite button
- Small "Try-On" or sparkle badge if try-on is supported

Cards should be clean and scannable.

## Product Detail Requirements

The product detail screen should include:

- Large product image/gallery
- Back button
- Favorite/share actions
- Product name
- Price
- Rating/reviews
- Size selector
- Color selector
- Description
- Delivery/returns/payment trust indicators
- Sticky bottom bar with:
  - Add to Cart
  - Try On
  - Buy Now

The **Try On** button should be highly visible.

## Virtual Try-On Flow

Design the try-on flow as a focused tool:

### Try-On Start Screen

- Clear headline: "Try outfits on yourself"
- Options:
  - Take photo
  - Choose from gallery
- Product selection preview
- Friendly instruction text

### Try-On Active Screen

- Full-screen camera/photo area
- Top back button
- Current selected product preview
- Bottom product carousel
- Capture/select controls
- Main CTA: "Generate Try-On"

### Try-On Result Screen

- Shows result image large
- Compare before/after option
- Buttons:
  - Try another product
  - Save result
  - Add product to cart
  - Share

Include graceful loading and error states:

- Backend unavailable
- Processing try-on
- Result failed
- Simplified preview mode

## Auth Screens

Design polished Firebase email/password auth screens:

### Sign In

- Brand name/logo
- Email field
- Password field
- Password visibility toggle
- Forgot password
- Sign in button
- Link to create account

### Sign Up

- Full name
- Email
- Password
- Confirm password
- Create account button
- Link back to sign in

Do not include Google/GitHub buttons unless shown as disabled/future options.

## Search Screen

Include:

- Search bar at top
- Recent searches
- Trending searches
- Category filter chips
- Sort/filter icon
- Product results grid/list
- Empty state for no results

## Wishlist Screen

Include:

- Saved product list/grid
- Remove item action
- Add all to cart
- Empty wishlist state

## Cart Screen

Include:

- Cart item cards
- Quantity stepper
- Remove item action
- Promo code input
- Price summary
- Sticky checkout button

## Checkout Screen

Include:

- Step-based layout:
  - Address
  - Payment
  - Review
- Order summary
- Place order button
- Order placed success state

## Profile Screen

Include:

- User avatar
- Name and email
- Order count
- Wishlist count
- Menu items:
  - My Orders
  - Saved Addresses
  - Payment Methods
  - Notifications
  - Theme
  - Help & Support
  - Sign Out

## Theme Requirements

Create a cohesive design system:

- Typography scale
- Color palette
- Button styles
- Text field styles
- Product card style
- Bottom navigation style
- Empty/loading/error states

Recommended palette:

- Background: white or very light gray
- Text: near-black charcoal
- Secondary text: cool gray
- Primary accent: deep purple or muted magenta
- AI/Try-On accent: purple-to-pink gradient used sparingly
- Success: green
- Error: red

Avoid overusing purple gradients across the entire app. Use gradients mainly for AI try-on CTAs and key actions.

## Layout Requirements

- Mobile-first design.
- Must work on small phones and larger phones.
- No text overflow.
- Buttons should be easy to tap.
- Product grids should be readable.
- Use real-looking image placeholders, not abstract illustrations.
- Avoid nested cards inside cards.
- Keep checkout/profile screens clean and organized.

## Components To Include

Design reusable components:

- App header
- Bottom navigation
- Product card
- Product image gallery
- Primary button
- Secondary button
- Text field
- Category chip
- Size selector
- Color swatch selector
- Price summary card
- Empty state
- Loading state
- Try-on processing state

## Important Existing Behavior To Preserve

The app already has:

- Firebase email/password authentication.
- Supabase product loading.
- Backend virtual try-on API.
- Product detail by product ID.
- Try-on from product detail and full try-on screen.
- Cart/checkout/profile demo flows.

The redesign should only change the UI/UX, not remove these flows.

## Final Output Needed

Generate a full app UI concept with:

- Screen layouts
- Component design
- Color and typography direction
- Main user flows
- Mobile responsive behavior

Focus especially on:

- Home screen
- Product detail screen
- Virtual try-on flow
- Sign in/sign up screens

The result should look like a polished fashion ecommerce app with a strong AI try-on feature.
