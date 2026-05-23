import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

/// Service class for Firebase Authentication operations
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isCurrentUserEmailVerified => currentUser?.emailVerified ?? false;

  bool get isCurrentUserPasswordAccount {
    final user = currentUser;
    if (user == null) return false;
    return user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
  }

  /// Sign up with email and password
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Create user in Firebase Auth
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Update display name
      await userCredential.user?.updateDisplayName(fullName);
      await userCredential.user?.sendEmailVerification();

      // Create user document in Firestore
      if (userCredential.user != null) {
        final userModel = UserModel.fromRegistration(
          uid: userCredential.user!.uid,
          email: email,
          fullName: fullName,
        );

        try {
          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(userModel.toFirestore(), SetOptions(merge: true));
        } catch (_) {
          // The auth account is already created; do not block sign-up on a
          // profile sync issue such as a temporary Firestore rules problem.
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred during sign up';
    }
  }

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      // Update last login timestamp
      if (userCredential.user != null) {
        try {
          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
                'email': userCredential.user!.email ?? email,
                'fullName': userCredential.user!.displayName ?? 'User',
                'lastLogin': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        } catch (_) {
          // Firebase Auth sign-in succeeded; profile metadata can sync later.
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred during sign in';
    }
  }

  /// Resend verification email for the current user
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user == null) throw 'No user logged in';
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to send verification email';
    }
  }

  /// Reload current user and return latest email verification state
  Future<bool> reloadAndCheckEmailVerified() async {
    try {
      final user = currentUser;
      if (user == null) return false;
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      throw 'Failed to check verification status';
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _syncSignedInUserProfile(userCredential.user);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Google sign-in failed. Please try again.';
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out';
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to send password reset email';
    }
  }

  Future<void> _syncSignedInUserProfile(User? user) async {
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email ?? '',
        'fullName': user.displayName ?? 'User',
        'photoUrl': user.photoURL,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Firebase Auth succeeded; profile metadata can sync later.
    }
  }

  /// Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw 'Failed to fetch user data';
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({String? fullName, String? photoUrl}) async {
    try {
      final user = currentUser;
      if (user == null) throw 'No user logged in';

      // Update Firebase Auth profile
      if (fullName != null) {
        await user.updateDisplayName(fullName);
      }
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Update Firestore document
      Map<String, dynamic> updates = {};
      if (fullName != null) updates['fullName'] = fullName;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(updates);
      }
    } catch (e) {
      throw 'Failed to update profile';
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) throw 'No user logged in';

      // Delete Firestore document
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete Firebase Auth user
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Please log in again before deleting your account';
      }
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to delete account';
    }
  }

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'operation-not-allowed':
        return 'Operation not allowed. Please contact support';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return e.message ?? 'Authentication error occurred';
    }
  }
}
