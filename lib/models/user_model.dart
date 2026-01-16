import 'package:cloud_firestore/cloud_firestore.dart';

/// User model for storing user data in Firestore
class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final List<String> wishlist;
  final List<String> orderHistory;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    this.photoUrl,
    required this.createdAt,
    this.lastLogin,
    this.wishlist = const [],
    this.orderHistory = const [],
  });

  /// Create UserModel from Firebase user registration
  factory UserModel.fromRegistration({
    required String uid,
    required String email,
    required String fullName,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      fullName: fullName,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
  }

  /// Create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLogin: data['lastLogin'] != null
          ? (data['lastLogin'] as Timestamp).toDate()
          : null,
      wishlist: List<String>.from(data['wishlist'] ?? []),
      orderHistory: List<String>.from(data['orderHistory'] ?? []),
    );
  }

  /// Convert UserModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'wishlist': wishlist,
      'orderHistory': orderHistory,
    };
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLogin,
    List<String>? wishlist,
    List<String>? orderHistory,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      wishlist: wishlist ?? this.wishlist,
      orderHistory: orderHistory ?? this.orderHistory,
    );
  }
}
