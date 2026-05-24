# Firebase Authentication Setup Guide

Complete guide to setting up Firebase Authentication for your StyleSprint app.

---

## 📋 Prerequisites

- Flutter project (already set up ✅)
- Google account
- Node.js installed (for Firebase CLI)

---

## 🚀 Quick Setup with FlutterFire CLI (RECOMMENDED)

This is the **easiest and most modern** way to set up Firebase!

### Step 1: Install Firebase CLI

```bash
npm install -g firebase-tools
```

Verify installation:
```bash
firebase --version
```

### Step 2: Login to Firebase

```bash
firebase login
```

This will open a browser window for you to sign in with your Google account.

### Step 3: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

Verify installation:
```bash
flutterfire --version
```

### Step 4: Configure Firebase (THE MAGIC COMMAND! ✨)

From your project root directory:

```bash
flutterfire configure
```

This command will:
1. 🔍 Ask you to **select or create a Firebase project**
2. 📱 Automatically create Android and iOS apps in Firebase
3. 📥 Download `google-services.json` (Android) 
4. 📥 Download `GoogleService-Info.plist` (iOS)
5. ✨ Generate `lib/firebase_options.dart` with all configuration
6. ⚙️ Configure everything automatically!

**Select options when prompted:**
- Project: Create new or select existing
- Platforms: Select **Android**, **iOS** (optional), **Web** (optional)
- App identifier: Use default (com.example.fyp_app)

### Step 5: Update main.dart to use generated config

Update your `lib/main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Import generated file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // ... rest of your code
}
```

### Step 6: Enable Authentication in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Build → Authentication**
4. Click **"Get started"**
5. Enable **"Email/Password"** provider
6. Click **"Save"**

### Step 7: Create Firestore Database

1. In Firebase Console: **Build → Firestore Database**
2. Click **"Create database"**
3. Choose **"Start in test mode"**
4. Select location (closest to your users)
5. Click **"Enable"**

### Step 8: Test Your App!

```bash
flutter run
```

✅ **That's it!** Firebase is now fully configured!

---

## 🔄 Re-run Configuration (If Needed)

If you add new platforms or need to update configuration:

```bash
flutterfire configure
```

It will update everything automatically!

---

## 📖 Manual Setup (Alternative Method)

<details>
<summary>Click here for manual setup instructions (not recommended)</summary>

## 🚀 Part 1: Firebase Console Setup

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or **"Create a project"**
3. Enter project name: `StyleSprint` (or your preferred name)
4. Enable Google Analytics (optional but recommended)
5. Click **"Create project"**

### Step 2: Register Your Android App

1. In Firebase Console, click the **Android icon** ⚙️
2. Fill in the form:
   - **Android package name**: `com.example.fyp_app` 
     - ⚠️ Find this in `android/app/build.gradle` under `applicationId`
   - **App nickname**: `StyleSprint Android` (optional)
   - **Debug signing certificate SHA-1**: (optional for now, needed for Google Sign-In later)
3. Click **"Register app"**

### Step 3: Download Configuration File

1. Download `google-services.json`
2. Place it in: `android/app/google-services.json`
   ```
   fyp_app/
   └── android/
       └── app/
           └── google-services.json  ← Put it here
   ```

### Step 4: Enable Authentication Methods

1. In Firebase Console sidebar, go to **"Build" → "Authentication"**
2. Click **"Get started"**
3. Go to **"Sign-in method"** tab
4. Enable **"Email/Password"**:
   - Click on "Email/Password"
   - Toggle **"Enable"** switch
   - Click **"Save"**

### Step 5: Create Firestore Database (for user data)

1. In Firebase Console sidebar, go to **"Build" → "Firestore Database"**
2. Click **"Create database"**
3. Choose **"Start in test mode"** (we'll secure it later)
4. Select a Cloud Firestore location (choose closest to your users)
5. Click **"Enable"**

---

## 🔧 Part 2: Flutter App Configuration

### Step 1: Install Firebase Dependencies

Already done! ✅ Your `pubspec.yaml` includes:
```yaml
firebase_core: ^3.8.1
firebase_auth: ^5.3.4
cloud_firestore: ^5.5.2
```

Run to install:
```bash
flutter pub get
```

### Step 2: Configure Android App

#### 2.1: Update `android/build.gradle`

Add this to `dependencies` block:
```gradle
buildscript {
    dependencies {
        // Add this line
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

#### 2.2: Update `android/app/build.gradle`

Add this at the **bottom** of the file:
```gradle
apply plugin: 'com.google.gms.google-services'
```

Also ensure `minSdkVersion` is at least 21:
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Must be 21 or higher
    }
}
```

### Step 3: iOS Setup (Optional - if testing on iOS)

1. In Firebase Console, click **iOS icon** 
2. Download `GoogleService-Info.plist`
3. Place it in: `ios/Runner/GoogleService-Info.plist`
4. Open Xcode and add the file to Runner target

---

## 🧪 Part 3: Testing the Setup

### Step 1: Run Flutter App

```bash
flutter run
```

### Step 2: Test Sign Up

1. Open your app
2. Go through onboarding → Click **"Sign Up"**
3. Fill in:
   - Full Name: `Test User`
   - Email: `test@example.com`
   - Password: `Test123!`
   - Confirm Password: `Test123!`
4. Click **"Sign Up"**

### Step 3: Verify in Firebase Console

1. Go to Firebase Console → **Authentication → Users**
2. You should see your new user with email `test@example.com`

### Step 4: Test Sign In

1. Sign out from app (Profile → Sign Out)
2. Sign in with the credentials you created
3. Should navigate to home screen ✅

### Step 5: Test Password Reset

1. Go to Sign In screen
2. Enter your email
3. Click **"Forgot Password?"**
4. Check email inbox for reset link

---

## 🔐 Part 4: Security Rules (Production Ready)

### Firestore Security Rules

Replace test mode rules with these in Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Products collection - everyone can read, only admins can write
    match /products/{productId} {
      allow read: if true;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
    
    // Orders collection - users can only access their own orders
    match /orders/{orderId} {
      allow read, write: if request.auth != null && 
                            resource.data.userId == request.auth.uid;
    }
  }
}
```

Click **"Publish"** to apply rules.

---

## 🐛 Troubleshooting

### Error: "Default FirebaseApp is not initialized"

**Solution**: Make sure `Firebase.initializeApp()` is called in `main.dart`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();  // ← Must be here
  runApp(const MyApp());
}
```

### Error: "google-services.json missing"

**Solution**: 
1. Download from Firebase Console
2. Place in `android/app/google-services.json`
3. Run `flutter clean` then `flutter pub get`

### Error: "Multidex issue" on Android

**Solution**: Add to `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        multiDexEnabled true
    }
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
}
```

### User email not showing in profile

**Solution**: Display name is set during signup, reload the page or check:
```dart
_authService.currentUser?.displayName
```

### Password reset email not received

**Solution**:
1. Check spam folder
2. Verify email in Firebase Console → Authentication → Templates
3. Ensure Email/Password provider is enabled

---

## 📱 Part 5: Additional Features (Optional)

### Enable Google Sign-In

1. In Firebase Console → Authentication → Sign-in method
2. Enable **"Google"**
3. Add SHA-1 certificate to Android app settings
4. Add `google_sign_in` package to Flutter
5. Implement Google Sign-In button

### Enable Anonymous Authentication

Good for testing:
1. Firebase Console → Authentication → Sign-in method
2. Enable **"Anonymous"**
3. Users can use app without creating account

### Email Verification

Add after signup:
```dart
await userCredential.user?.sendEmailVerification();
```

Check if verified:
```dart
if (user.emailVerified) {
  // Allow access
}
```

---

## ✅ Checklist

Before deploying to production:

- [ ] `google-services.json` in `android/app/`
- [ ] Firebase initialization in `main.dart`
- [ ] Email/Password authentication enabled
- [ ] Firestore database created
- [ ] Security rules configured (not in test mode)
- [ ] Password reset tested
- [ ] Sign up/Sign in flow tested
- [ ] User data persists in Firestore
- [ ] Error handling implemented
- [ ] Network error handling added

---

## 🎯 What's Working Now

✅ **Sign Up** - Creates Firebase user + Firestore document  
✅ **Sign In** - Authenticates and updates last login  
✅ **Sign Out** - Clears session and returns to auth  
✅ **Password Reset** - Sends reset email  
✅ **Session Management** - Auto-login on app restart  
✅ **Profile Display** - Shows user name and email  
✅ **User Data** - Stored in Firestore `users` collection  

---

## 📚 Next Steps

1. **Add product database** with Firestore
2. **Implement wishlist** with user document updates
3. **Add order history** with Firestore orders collection
4. **Enable Google Sign-In** for easier onboarding
5. **Add email verification** for security
6. **Implement password change** functionality

---

## 📖 Resources

- [Firebase Auth Docs](https://firebase.google.com/docs/auth)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase Console](https://console.firebase.google.com/)

---

**Need Help?** Check the Firebase Console logs and Flutter debug console for detailed error messages.

---

</details>

---

## 🎯 What FlutterFire CLI Does Automatically

✅ Creates Firebase project apps for all platforms  
✅ Downloads all configuration files  
✅ Generates `firebase_options.dart` with all credentials  
✅ Configures Android Gradle files  
✅ Configures iOS project  
✅ Updates with latest Firebase SDKs  
✅ Handles all the manual steps for you!

---

## 📝 Quick Reference Commands

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (run from project root)
flutterfire configure

# Reconfigure or add platforms
flutterfire configure --platforms=android,ios,web

# Specify project explicitly
flutterfire configure --project=your-project-id
```

---

## 🎓 What You've Already Got

Your app already has:
- ✅ Firebase dependencies in `pubspec.yaml`
- ✅ Firebase Auth Service (`lib/services/firebase_auth_service.dart`)
- ✅ User Model (`lib/models/user_model.dart`)
- ✅ Sign In/Sign Up screens integrated
- ✅ Session management in `main.dart`

You just need to:
1. Run `flutterfire configure`
2. Update `main.dart` to use generated `firebase_options.dart`
3. Enable Email/Password auth in Firebase Console

---
