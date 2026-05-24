# StyleSprint Application Use Cases

This document contains report-ready use cases for the StyleSprint fashion ecommerce and virtual try-on application. The use cases cover authentication, product browsing, virtual try-on, cart, checkout, profile, and admin/data-related behavior.

## Primary Actors

- **Guest User:** A user who has opened the app but is not signed in.
- **Registered User:** A user who has a Firebase account and can access shopping features.
- **System:** The Flutter app, Firebase, Supabase, and backend API working together.
- **Backend API:** The virtual try-on processing server.
- **Database:** Supabase for products and Firebase/Firestore for user authentication/profile data.

---

## UC-01: View Onboarding Screen

**Primary Actor:** Guest User

**Goal:** Understand the purpose of the app before signing in.

**Preconditions:**

- The app is installed or opened in browser.
- The user is not currently signed in.

**Main Flow:**

1. User opens the app.
2. System displays the onboarding screen.
3. User reads the app introduction.
4. User taps the get started button.
5. System navigates to the sign-in screen.

**Alternative Flow:**

- If the user is already signed in, the system skips onboarding and opens the home screen.

**Postcondition:**

- User reaches the authentication flow.

---

## UC-02: Create New Account

**Primary Actor:** Guest User

**Goal:** Register a new account using email and password.

**Preconditions:**

- Firebase is configured.
- User does not already have an account with the same email.

**Main Flow:**

1. User opens the sign-up screen.
2. User enters full name, email, password, and confirm password.
3. System validates all fields.
4. User taps create account.
5. Firebase creates the user account.
6. System attempts to save user profile data in Firestore.
7. System navigates the user to the home screen.

**Alternative Flow:**

- If the email is already registered, the system displays an error message.
- If the password is weak, the system asks the user to enter a stronger password.
- If Firestore profile sync fails, account creation still succeeds and the user can continue.

**Postcondition:**

- A new Firebase user account is created.

---

## UC-03: Sign In With Email and Password

**Primary Actor:** Registered User

**Goal:** Access the app using an existing Firebase account.

**Preconditions:**

- User has a registered account.
- Firebase Auth service is available.

**Main Flow:**

1. User opens the sign-in screen.
2. User enters email and password.
3. System validates the fields.
4. User taps sign in.
5. Firebase verifies credentials.
6. System updates last login metadata if possible.
7. System navigates to the home screen.

**Alternative Flow:**

- If credentials are invalid, the system displays an error.
- If Firestore metadata update fails, sign-in still succeeds.

**Postcondition:**

- User is authenticated and can use shopping features.

---

## UC-04: Reset Forgotten Password

**Primary Actor:** Registered User

**Goal:** Reset account password through email.

**Preconditions:**

- User has an existing Firebase account.
- User knows the registered email.

**Main Flow:**

1. User enters email on the sign-in screen.
2. User taps forgot password.
3. System validates the email format.
4. Firebase sends a password reset email.
5. System shows a confirmation message.

**Alternative Flow:**

- If the email format is invalid, the system asks for a valid email.
- If Firebase rejects the request, the system shows an error.

**Postcondition:**

- User receives a reset email if the email is valid.

---

## UC-05: Sign Out

**Primary Actor:** Registered User

**Goal:** Log out of the application.

**Preconditions:**

- User is signed in.

**Main Flow:**

1. User opens the profile screen.
2. User selects sign out.
3. System asks for confirmation.
4. User confirms sign out.
5. Firebase signs the user out.
6. System navigates to the sign-in screen.

**Alternative Flow:**

- If sign-out fails, the system displays an error message.

**Postcondition:**

- User session is ended.

---

## UC-06: View Home Screen

**Primary Actor:** Registered User

**Goal:** Browse the main shopping experience.

**Preconditions:**

- User is signed in.

**Main Flow:**

1. User signs in successfully.
2. System displays the home screen.
3. User sees app header, hero banner, category bar, try-on card, store partners, and featured products.
4. User can navigate to product detail, search, cart, wishlist, profile, or virtual try-on.

**Alternative Flow:**

- If products fail to load, the product grid shows an error state.

**Postcondition:**

- User can begin shopping or try-on flow.

---

## UC-07: View Product Grid

**Primary Actor:** Registered User

**Goal:** See available products from Supabase.

**Preconditions:**

- Supabase project is active.
- Product table contains products.
- Row Level Security allows public read access.

**Main Flow:**

1. User opens the home screen.
2. System requests products from Supabase.
3. Supabase returns product records.
4. System displays products in a grid.
5. User scrolls through the product list.

**Alternative Flow:**

- If Supabase is paused or unavailable, system shows a loading/error message.
- If no products exist, system shows an empty state.

**Postcondition:**

- User can select a product.

---

## UC-08: Open Product Detail

**Primary Actor:** Registered User

**Goal:** View details of a selected product.

**Preconditions:**

- Product exists in Supabase.

**Main Flow:**

1. User taps a product card.
2. System passes product ID to product detail screen.
3. System fetches product by ID from Supabase.
4. System displays product image, name, price, rating, sizes, colors, and description.
5. User can add item to cart, buy now, favorite it, or try it on.

**Alternative Flow:**

- If product cannot be loaded, system displays an error message.

**Postcondition:**

- User can make a purchase decision.

---

## UC-09: Select Product Size

**Primary Actor:** Registered User

**Goal:** Choose the correct clothing size.

**Preconditions:**

- User is on the product detail screen.

**Main Flow:**

1. System displays available sizes.
2. User taps a size option.
3. System highlights the selected size.
4. Selected size is used for cart or checkout flow.

**Alternative Flow:**

- If size is unavailable in future implementation, system disables that option.

**Postcondition:**

- Product size is selected.

---

## UC-10: Select Product Color

**Primary Actor:** Registered User

**Goal:** Choose preferred product color.

**Preconditions:**

- User is on the product detail screen.

**Main Flow:**

1. System displays color swatches.
2. User taps a color.
3. System highlights selected color.
4. Product configuration updates visually.

**Alternative Flow:**

- If a color is unavailable, system disables the swatch.

**Postcondition:**

- Product color is selected.

---

## UC-11: Add Product to Wishlist

**Primary Actor:** Registered User

**Goal:** Save a product for later.

**Preconditions:**

- User is viewing product card or product detail.

**Main Flow:**

1. User taps the favorite icon.
2. System marks product as favorite.
3. Product appears in wishlist.
4. System gives visual feedback.

**Alternative Flow:**

- If wishlist storage is unavailable, system can keep temporary local state and notify user.

**Postcondition:**

- Product is saved to wishlist.

---

## UC-12: View Wishlist

**Primary Actor:** Registered User

**Goal:** View saved products.

**Preconditions:**

- User has opened the wishlist screen.

**Main Flow:**

1. User taps wishlist in bottom navigation.
2. System displays saved products.
3. User can open product detail, remove an item, or add all to cart.

**Alternative Flow:**

- If wishlist is empty, system displays an empty wishlist state.

**Postcondition:**

- User can manage saved items.

---

## UC-13: Search Products

**Primary Actor:** Registered User

**Goal:** Find products by name or keyword.

**Preconditions:**

- Product data is available from Supabase.

**Main Flow:**

1. User opens search screen.
2. User enters a search keyword.
3. System filters products by product name.
4. System displays matching results.
5. User taps a result to open product detail.

**Alternative Flow:**

- If no products match, system displays a no-results message.
- If product loading fails, system displays an error.

**Postcondition:**

- User finds and opens a relevant product.

---

## UC-14: Use Product Filters and Sorting

**Primary Actor:** Registered User

**Goal:** Narrow product results by category or sorting preference.

**Preconditions:**

- User is on the search screen.
- Product data is loaded.

**Main Flow:**

1. User performs or opens search.
2. System displays filter chips and sort options.
3. User selects a category filter.
4. User selects sorting preference.
5. System updates visible product results.

**Alternative Flow:**

- If filters are not connected to real database fields yet, the system only updates the UI state.

**Postcondition:**

- User sees a refined product list.

---

## UC-15: Start Virtual Try-On From Home

**Primary Actor:** Registered User

**Goal:** Open the full virtual try-on experience.

**Preconditions:**

- User is signed in.

**Main Flow:**

1. User opens home screen.
2. User taps the virtual try-on card.
3. System navigates to the virtual try-on screen.
4. System displays options to take a photo or choose from gallery.

**Alternative Flow:**

- If camera permissions are unavailable, user can choose a photo from gallery.

**Postcondition:**

- User enters the try-on flow.

---

## UC-16: Start Virtual Try-On From Product Detail

**Primary Actor:** Registered User

**Goal:** Try on a specific product from its detail page.

**Preconditions:**

- Product detail screen is open.
- Product image URL is available.

**Main Flow:**

1. User taps "Try This On" on product detail screen.
2. System opens virtual try-on dialog.
3. User chooses or captures a person image.
4. System uses the selected product image as the clothing image.
5. System sends both images to backend.

**Alternative Flow:**

- If product image cannot be downloaded, system shows an error.
- If backend is unavailable, system shows a backend error.

**Postcondition:**

- User receives a virtual try-on preview if processing succeeds.

---

## UC-17: Capture Photo for Try-On

**Primary Actor:** Registered User

**Goal:** Capture a personal photo for virtual try-on.

**Preconditions:**

- Device has camera access or image picker support.
- User is on virtual try-on screen.

**Main Flow:**

1. User selects camera option.
2. System opens camera or image picker camera mode.
3. User captures a photo.
4. System stores the captured image temporarily.
5. System prompts user to select a product.

**Alternative Flow:**

- If camera fails, system shows an error and allows gallery upload.

**Postcondition:**

- Person image is ready for try-on processing.

---

## UC-18: Choose Gallery Photo for Try-On

**Primary Actor:** Registered User

**Goal:** Use an existing image for virtual try-on.

**Preconditions:**

- User is on virtual try-on screen.
- Device/gallery access is available.

**Main Flow:**

1. User selects gallery option.
2. System opens image picker.
3. User selects a photo.
4. System loads photo into try-on preview.
5. User selects a product for try-on.

**Alternative Flow:**

- If image selection is cancelled, system stays on the try-on screen.
- If image loading fails, system shows an error.

**Postcondition:**

- Person image is ready for processing.

---

## UC-19: Select Product for Try-On

**Primary Actor:** Registered User

**Goal:** Choose clothing item to apply in virtual try-on.

**Preconditions:**

- User has selected or captured a person photo.
- Supabase products are loaded.

**Main Flow:**

1. System displays product carousel or product list.
2. User taps a product.
3. System highlights the selected product.
4. User taps generate try-on.

**Alternative Flow:**

- If products fail to load, system shows an error state.

**Postcondition:**

- Selected cloth image is ready for backend processing.

---

## UC-20: Generate Virtual Try-On Result

**Primary Actor:** Registered User

**Goal:** Generate a virtual clothing preview.

**Preconditions:**

- User has selected a person photo.
- User has selected a product.
- Backend API is running.

**Main Flow:**

1. User taps generate try-on.
2. System checks backend availability.
3. System downloads selected product image.
4. System sends person image and cloth image to backend.
5. Backend processes images.
6. System receives session ID or result.
7. System fetches result image.
8. System displays try-on result.

**Alternative Flow:**

- If backend is unavailable, system shows backend error.
- If real ML processing fails, system can return simplified preview mode.
- If image processing fails, system shows try-on failed message.

**Postcondition:**

- User sees a virtual try-on output or a meaningful error.

---

## UC-21: View Try-On Result

**Primary Actor:** Registered User

**Goal:** Review generated try-on image.

**Preconditions:**

- Backend generated a result image.

**Main Flow:**

1. System displays result image.
2. User reviews how the product looks.
3. User can try another product, save result, share, or add product to cart.

**Alternative Flow:**

- If result cannot be loaded, system shows error and allows retry.

**Postcondition:**

- User can make a shopping decision based on preview.

---

## UC-22: Add Product to Cart

**Primary Actor:** Registered User

**Goal:** Add selected product to shopping cart.

**Preconditions:**

- Product detail screen is open.
- User has selected size and color.

**Main Flow:**

1. User taps add to cart.
2. System adds item to cart.
3. System navigates to cart or shows confirmation.
4. Cart displays the selected item.

**Alternative Flow:**

- If required options are missing, system asks user to select size/color.

**Postcondition:**

- Product is available in cart.

---

## UC-23: Update Cart Quantity

**Primary Actor:** Registered User

**Goal:** Change quantity of a cart item.

**Preconditions:**

- Cart contains at least one product.

**Main Flow:**

1. User opens cart.
2. User taps plus or minus quantity control.
3. System updates item quantity.
4. System recalculates subtotal, tax, shipping, and total.

**Alternative Flow:**

- If quantity reaches minimum, system prevents it from going below one.

**Postcondition:**

- Cart totals reflect updated quantity.

---

## UC-24: Remove Item From Cart

**Primary Actor:** Registered User

**Goal:** Delete unwanted product from cart.

**Preconditions:**

- Cart contains at least one product.

**Main Flow:**

1. User opens cart.
2. User taps remove/delete action on an item.
3. System removes the item.
4. System updates cart total.

**Alternative Flow:**

- If cart becomes empty, system displays an empty cart state.

**Postcondition:**

- Item no longer appears in cart.

---

## UC-25: Apply Promo Code

**Primary Actor:** Registered User

**Goal:** Apply discount before checkout.

**Preconditions:**

- User is on the cart screen.

**Main Flow:**

1. User enters promo code.
2. User taps apply.
3. System validates promo code.
4. System updates price summary.

**Alternative Flow:**

- If promo code is invalid, system displays an error message.

**Postcondition:**

- Discount is applied if code is valid.

---

## UC-26: Proceed to Checkout

**Primary Actor:** Registered User

**Goal:** Begin purchase flow for cart items.

**Preconditions:**

- Cart contains at least one product.

**Main Flow:**

1. User opens cart.
2. User reviews cart items and total.
3. User taps proceed to checkout.
4. System navigates to checkout screen.

**Alternative Flow:**

- If cart is empty, checkout button is disabled or hidden.

**Postcondition:**

- User enters checkout process.

---

## UC-27: Select Delivery Address

**Primary Actor:** Registered User

**Goal:** Choose where order should be delivered.

**Preconditions:**

- User is on checkout screen.

**Main Flow:**

1. System displays saved addresses.
2. User selects preferred address.
3. System highlights selected address.
4. User continues to payment step.

**Alternative Flow:**

- If no address exists, system prompts user to add a new address.

**Postcondition:**

- Delivery address is selected.

---

## UC-28: Select Payment Method

**Primary Actor:** Registered User

**Goal:** Choose payment option for order.

**Preconditions:**

- User is on checkout screen.

**Main Flow:**

1. System displays payment methods.
2. User selects payment method.
3. System highlights selected method.
4. User continues to order review.

**Alternative Flow:**

- If online payment is unavailable, user may choose cash on delivery.

**Postcondition:**

- Payment method is selected.

---

## UC-29: Place Order

**Primary Actor:** Registered User

**Goal:** Confirm and place final order.

**Preconditions:**

- User has selected address and payment method.
- Cart contains products.

**Main Flow:**

1. User reviews order summary.
2. User taps place order.
3. System creates order.
4. System displays order placed confirmation.
5. User can navigate to order tracking.

**Alternative Flow:**

- If order creation fails, system displays error and allows retry.

**Postcondition:**

- Order is placed and can be tracked.

---

## UC-30: View Order History

**Primary Actor:** Registered User

**Goal:** See previous orders.

**Preconditions:**

- User is signed in.

**Main Flow:**

1. User opens profile screen.
2. User selects my orders.
3. System displays order history.
4. User taps an order to view tracking details.

**Alternative Flow:**

- If no orders exist, system displays an empty state.

**Postcondition:**

- User can review previous purchases.

---

## UC-31: Track Order

**Primary Actor:** Registered User

**Goal:** Check delivery status of an order.

**Preconditions:**

- User has selected an order from order history.

**Main Flow:**

1. User taps an order.
2. System opens order tracking screen.
3. System displays order ID and current status.
4. User reviews delivery progress.

**Alternative Flow:**

- If tracking data is unavailable, system displays basic order status.

**Postcondition:**

- User knows current order status.

---

## UC-32: Toggle App Theme

**Primary Actor:** Registered User

**Goal:** Switch between light and dark mode.

**Preconditions:**

- User is on profile screen.

**Main Flow:**

1. User opens profile screen.
2. User toggles theme switch.
3. System changes app theme mode.
4. UI updates colors accordingly.

**Alternative Flow:**

- If theme preference is not persisted, theme resets after app restart.

**Postcondition:**

- App theme is updated for current session.

---

## UC-33: View User Profile

**Primary Actor:** Registered User

**Goal:** See account details and profile options.

**Preconditions:**

- User is signed in.

**Main Flow:**

1. User taps profile in bottom navigation.
2. System displays user's name and email from Firebase.
3. System displays order/wishlist/review stats.
4. User can open orders, addresses, payment methods, notifications, theme, help, or sign out.

**Alternative Flow:**

- If display name is missing, system shows a default user label.

**Postcondition:**

- User can manage account-related actions.

---

## UC-34: Backend Try-On Readiness Check

**Primary Actor:** System

**Goal:** Check whether virtual try-on backend is available.

**Preconditions:**

- Backend API URL is configured.

**Main Flow:**

1. User starts try-on processing.
2. System calls backend readiness or health endpoint.
3. Backend returns availability status.
4. System proceeds if backend is available.

**Alternative Flow:**

- If backend is offline, system displays a message asking user to start backend server.

**Postcondition:**

- App knows whether try-on processing can continue.

---

## UC-35: Handle Supabase Product Loading Failure

**Primary Actor:** System

**Goal:** Provide useful feedback when product data cannot be loaded.

**Preconditions:**

- App requests products from Supabase.

**Main Flow:**

1. System sends request to Supabase.
2. Supabase returns an error or no response.
3. System catches the error.
4. UI displays an error message.
5. User can retry later.

**Alternative Flow:**

- If Supabase project is paused, products do not load until the project is resumed.
- If RLS policy blocks read access, system receives permission-related error.

**Postcondition:**

- App does not crash and user understands product loading failed.

---

## UC-36: Fallback to Simplified Try-On

**Primary Actor:** Backend API

**Goal:** Return a usable try-on preview when full ML pipeline cannot run.

**Preconditions:**

- User submits person and clothing images.
- Full ML pipeline fails or is disabled.

**Main Flow:**

1. Backend receives try-on request.
2. Backend attempts configured processing mode.
3. Full ML pipeline is unavailable, fails, or is blocked by hardware memory.
4. Backend uses simplified overlay try-on mode.
5. Backend returns result image.
6. App displays simplified result.

**Alternative Flow:**

- If fallback is disabled, backend returns an error instead.

**Postcondition:**

- User receives either a simplified preview or a clear error.

---

## Summary Table

| ID | Use Case | Primary Actor |
|---|---|---|
| UC-01 | View Onboarding Screen | Guest User |
| UC-02 | Create New Account | Guest User |
| UC-03 | Sign In With Email and Password | Registered User |
| UC-04 | Reset Forgotten Password | Registered User |
| UC-05 | Sign Out | Registered User |
| UC-06 | View Home Screen | Registered User |
| UC-07 | View Product Grid | Registered User |
| UC-08 | Open Product Detail | Registered User |
| UC-09 | Select Product Size | Registered User |
| UC-10 | Select Product Color | Registered User |
| UC-11 | Add Product to Wishlist | Registered User |
| UC-12 | View Wishlist | Registered User |
| UC-13 | Search Products | Registered User |
| UC-14 | Use Product Filters and Sorting | Registered User |
| UC-15 | Start Virtual Try-On From Home | Registered User |
| UC-16 | Start Virtual Try-On From Product Detail | Registered User |
| UC-17 | Capture Photo for Try-On | Registered User |
| UC-18 | Choose Gallery Photo for Try-On | Registered User |
| UC-19 | Select Product for Try-On | Registered User |
| UC-20 | Generate Virtual Try-On Result | Registered User |
| UC-21 | View Try-On Result | Registered User |
| UC-22 | Add Product to Cart | Registered User |
| UC-23 | Update Cart Quantity | Registered User |
| UC-24 | Remove Item From Cart | Registered User |
| UC-25 | Apply Promo Code | Registered User |
| UC-26 | Proceed to Checkout | Registered User |
| UC-27 | Select Delivery Address | Registered User |
| UC-28 | Select Payment Method | Registered User |
| UC-29 | Place Order | Registered User |
| UC-30 | View Order History | Registered User |
| UC-31 | Track Order | Registered User |
| UC-32 | Toggle App Theme | Registered User |
| UC-33 | View User Profile | Registered User |
| UC-34 | Backend Try-On Readiness Check | System |
| UC-35 | Handle Supabase Product Loading Failure | System |
| UC-36 | Fallback to Simplified Try-On | Backend API |
