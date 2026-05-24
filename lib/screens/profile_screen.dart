import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../services/firebase_auth_service.dart';
import '../services/order_service.dart';
import '../services/wishlist_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSignOut;
  final Function(AppScreen)? onNavigate;
  final Function(ThemeMode)? onThemeChange;

  const ProfileScreen({
    super.key,
    required this.onBack,
    required this.onSignOut,
    this.onNavigate,
    this.onThemeChange,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = FirebaseAuthService();
  final _orderService = OrderService.instance;
  final _wishlistService = WishlistService.instance;
  final _firestore = FirebaseFirestore.instance;
  final _imagePicker = ImagePicker();

  final Map<String, _SavedAddress> _savedAddresses = {
    'home': _SavedAddress.empty('Home'),
    'work': _SavedAddress.empty('Work'),
  };
  final List<Map<String, dynamic>> _savedPaymentCards = [];
  Uint8List? _profilePhotoBytes;
  bool _isSavingAddress = false;
  bool _isUpdatingPhoto = false;

  @override
  void initState() {
    super.initState();
    _orderService.addListener(_refresh);
    _wishlistService.addListener(_refresh);
    _orderService.loadOrders();
    _wishlistService.load();
    _loadProfileMetadata();
  }

  @override
  void dispose() {
    _orderService.removeListener(_refresh);
    _wishlistService.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  int get _reviewCount {
    return _orderService.orders.where((order) {
      return order.status == 'Delivered';
    }).length;
  }

  String get _addressSummary {
    final savedCount = _savedAddresses.values.where((item) {
      return item.isSaved;
    }).length;
    if (savedCount == 0) return 'Save home and work delivery addresses';
    if (savedCount == 1) return '1 of 2 addresses saved';
    return 'Home and work addresses saved';
  }

  String get _paymentSummary {
    if (_savedPaymentCards.isEmpty) return 'Cash on delivery and demo cards';
    if (_savedPaymentCards.length == 1) return '1 demo card saved';
    return '${_savedPaymentCards.length} demo cards saved';
  }

  Future<void> _loadProfileMetadata() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      final rawPhoto = data?['profilePhotoBase64'];
      final rawAddresses = data?['savedAddresses'];
      final rawCards = data?['savedPaymentCards'];

      final updated = Map<String, _SavedAddress>.from(_savedAddresses);
      if (rawAddresses is Map) {
        for (final entry in rawAddresses.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is Map && updated.containsKey(key)) {
            updated[key] = _SavedAddress.fromMap(
              updated[key]!.label,
              Map<String, dynamic>.from(value),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        if (rawPhoto is String && rawPhoto.isNotEmpty) {
          _profilePhotoBytes = base64Decode(rawPhoto);
        }
        _savedAddresses
          ..clear()
          ..addAll(updated);
        _savedPaymentCards
          ..clear()
          ..addAll(
            rawCards is List
                ? rawCards.whereType<Map>().map(
                    (item) => Map<String, dynamic>.from(item),
                  )
                : const <Map<String, dynamic>>[],
          );
      });
    } catch (_) {
      // Addresses are optional profile metadata; a temporary read issue should
      // not block the rest of the profile screen.
    }
  }

  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) return;

    try {
      await _authService.signOut();
      if (mounted) widget.onSignOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: AppTheme.red600,
        ),
      );
    }
  }

  Future<void> _chooseProfilePhoto(ImageSource source) async {
    final user = _authService.currentUser;
    if (user == null || _isUpdatingPhoto) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 180,
        maxHeight: 180,
        imageQuality: 58,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final encoded = base64Encode(bytes);

      if (!mounted) return;
      setState(() {
        _profilePhotoBytes = bytes;
        _isUpdatingPhoto = true;
      });

      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set({
              'profilePhotoBase64': encoded,
              'profilePhotoUpdatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } on TimeoutException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo updated here. Cloud sync is taking longer.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo updated here, but cloud sync failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) setState(() => _isUpdatingPhoto = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update profile photo: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showProfilePhotoSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Profile Photo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildSupportAction(
                  Icons.photo_library_outlined,
                  'Choose from gallery',
                  'Select an existing profile photo.',
                  onTap: () {
                    Navigator.pop(context);
                    _chooseProfilePhoto(ImageSource.gallery);
                  },
                ),
                _buildSupportAction(
                  Icons.photo_camera_outlined,
                  'Take a photo',
                  'Open camera and capture a new profile photo.',
                  onTap: () {
                    Navigator.pop(context);
                    _chooseProfilePhoto(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddressSheet(String key) async {
    final current = _savedAddresses[key] ?? _SavedAddress.empty('Address');
    final nameController = TextEditingController(text: current.name);
    final phoneController = TextEditingController(text: current.phone);
    final addressController = TextEditingController(text: current.address);
    final cityController = TextEditingController(text: current.city);
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> save() async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final user = _authService.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sign in to save addresses.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              setSheetState(() => _isSavingAddress = true);
              final address = _SavedAddress(
                label: current.label,
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
                address: addressController.text.trim(),
                city: cityController.text.trim(),
              );

              try {
                await _firestore.collection('users').doc(user.uid).set({
                  'savedAddresses': {key: address.toMap()},
                  'savedAddressesUpdatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                if (!mounted || !context.mounted) return;
                setState(() => _savedAddresses[key] = address);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${current.label} address saved'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted || !context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not save address: $e'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } finally {
                if (mounted) {
                  setSheetState(() => _isSavingAddress = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${current.label} Address',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        _buildAddressField(
                          controller: nameController,
                          label: 'Receiver name',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                        _buildAddressField(
                          controller: phoneController,
                          label: 'Contact number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        _buildAddressField(
                          controller: addressController,
                          label: 'Street address',
                          icon: Icons.home_outlined,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        _buildAddressField(
                          controller: cityController,
                          label: 'City / area',
                          icon: Icons.location_city_outlined,
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _isSavingAddress ? null : save,
                          icon: _isSavingAddress
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSavingAddress ? 'Saving...' : 'Save Address',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    cityController.dispose();
  }

  Widget _buildAddressField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (value) {
        if (value?.trim().isEmpty ?? true) return 'Required';
        return null;
      },
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }

  void _showSupportSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Help & Support',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildSupportAction(
                  Icons.mail_outline,
                  'Email support',
                  'stylesprint.support@example.com',
                ),
                _buildSupportAction(
                  Icons.local_shipping_outlined,
                  'Order help',
                  'Open orders to track or review a purchase.',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNavigate?.call(AppScreen.orderHistory);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFaqSheet() {
    const faqs = [
      (
        question: 'How do I track my order?',
        answer:
            'Go to My Orders and tap the order you want to check. You will see its current status and delivery details there.',
      ),
      (
        question: 'Can I pay with cash on delivery?',
        answer:
            'Yes. Pick Cash on Delivery at checkout and pay when your order reaches you.',
      ),
      (
        question: 'Why can virtual try-on take some time?',
        answer:
            'It creates a new preview image from your photo and the selected outfit, so it can take longer than normal browsing.',
      ),
      (
        question: 'How do I save a delivery address?',
        answer:
            'Open Saved Addresses, choose Home or Work, fill in the details, and tap Save Address.',
      ),
      (
        question: 'How do I remove an item from wishlist?',
        answer:
            'Open Wishlist and tap Remove on the item you no longer want to keep.',
      ),
      (
        question: 'Can I change my delivery address after checkout?',
        answer:
            'For now, place the order with the correct address during checkout. Saved Home and Work addresses help you fill it faster.',
      ),
      (
        question: 'Why do some product images look similar?',
        answer:
            'Some products have several photos of the same item, like front, back, and detail views.',
      ),
      (
        question: 'What if my order takes a moment to appear?',
        answer:
            'Give it a few seconds and open My Orders again. If your internet is slow, the app may show a small sync message.',
      ),
      (
        question: 'Can I retake my try-on photo?',
        answer:
            'Yes. After capturing a photo, choose Take Again before using it for the try-on process.',
      ),
      (
        question: 'Are card payments real?',
        answer:
            'Card saving is only for showing the checkout flow right now. The app does not charge your card.',
      ),
      (
        question: 'Can I edit my profile photo?',
        answer:
            'Yes. Tap the profile photo, then choose a picture from your gallery or take a new one.',
      ),
      (
        question: 'Can I buy the same item again?',
        answer:
            'Yes. Open My Orders and use Buy Again on delivered orders to add those items back to your cart.',
      ),
      (
        question: 'Do I need an account to keep my wishlist?',
        answer:
            'Yes, sign in so your wishlist, saved addresses, and orders stay connected to your profile.',
      ),
    ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('FAQ', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: faqs.length,
                    itemBuilder: (context, index) {
                      final faq = faqs[index];
                      return ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(faq.question),
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              faq.answer,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddressesSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Saved Addresses',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildAddressTile('home', Icons.home_outlined),
                _buildAddressTile('work', Icons.work_outline),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPaymentMethodsSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Payment Methods',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.payments_outlined),
                  title: Text('Cash on Delivery'),
                  subtitle: Text('Available for checkout'),
                ),
                if (_savedPaymentCards.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.credit_card_off_outlined),
                    title: Text('No saved demo cards'),
                    subtitle: Text(
                      'Use card payment during checkout to save a card summary.',
                    ),
                  )
                else
                  ..._savedPaymentCards.map((card) {
                    final brand = card['brand'] as String? ?? 'Card';
                    final last4 = card['last4'] as String? ?? '----';
                    final expiry = card['expiry'] as String? ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.credit_card),
                      title: Text('$brand ending $last4'),
                      subtitle: Text(
                        expiry.isEmpty
                            ? 'Saved for demo checkout'
                            : 'Expires $expiry | Demo checkout only',
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupportAction(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  Widget _buildAddressTile(String key, IconData icon) {
    final address = _savedAddresses[key] ?? _SavedAddress.empty(key);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(address.label),
      subtitle: Text(
        address.isSaved
            ? '${address.name}\n${address.address}, ${address.city}'
            : 'No ${address.label.toLowerCase()} address saved',
      ),
      isThreeLine: address.isSaved,
      trailing: const Icon(Icons.edit_outlined),
      onTap: () {
        Navigator.pop(context);
        _showAddressSheet(key);
      },
    );
  }

  Widget _buildProfileAvatar() {
    final imageBytes = _profilePhotoBytes;
    return GestureDetector(
      onTap: _showProfilePhotoSheet,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageBytes == null
                ? const Icon(
                    Icons.person_outline,
                    size: 34,
                    color: Colors.white,
                  )
                : Image.memory(imageBytes, fit: BoxFit.cover),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.atelierAccent,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.atelierDark, width: 2),
              ),
              child: _isUpdatingPhoto
                  ? const Padding(
                      padding: EdgeInsets.all(7),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppTheme.atelierDark,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.atelierDarkGradient,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: widget.onBack,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildProfileAvatar(),
                          const SizedBox(height: 12),
                          Text(
                            user?.displayName ?? 'StyleSprint User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user?.email ?? 'user@email.com',
                            style: const TextStyle(
                              color: AppTheme.atelierAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildStatsCard(),
                        const SizedBox(height: 18),
                        _buildMenuItem(
                          icon: Icons.shopping_bag_outlined,
                          label: 'My Orders',
                          description: 'Track and view your orders',
                          onTap: () =>
                              widget.onNavigate?.call(AppScreen.orderHistory),
                        ),
                        _buildMenuItem(
                          icon: Icons.favorite_border,
                          label: 'Wishlist',
                          description: 'View saved products',
                          onTap: () =>
                              widget.onNavigate?.call(AppScreen.wishlist),
                        ),
                        _buildMenuItem(
                          icon: Icons.rate_review_outlined,
                          label: 'Reviews',
                          description:
                              '$_reviewCount delivered ${_reviewCount == 1 ? 'order' : 'orders'} ready for review',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No reviews yet. Delivered orders can be reviewed here soon.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.location_on_outlined,
                          label: 'Saved Addresses',
                          description: _addressSummary,
                          onTap: _showAddressesSheet,
                        ),
                        _buildMenuItem(
                          icon: Icons.credit_card,
                          label: 'Payment Methods',
                          description: _paymentSummary,
                          onTap: _showPaymentMethodsSheet,
                        ),
                        _buildThemeToggle(isDarkMode),
                        _buildMenuItem(
                          icon: Icons.help_outline,
                          label: 'Help & Support',
                          description: 'Get help and contact us',
                          onTap: _showSupportSheet,
                        ),
                        _buildMenuItem(
                          icon: Icons.quiz_outlined,
                          label: 'FAQ',
                          description: 'Common questions and answers',
                          onTap: _showFaqSheet,
                        ),
                        _buildMenuItem(
                          icon: Icons.logout,
                          label: 'Sign Out',
                          description: 'Log out from your account',
                          destructive: true,
                          onTap: _handleSignOut,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: AppTheme.gray400,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 118),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNav(onNavigate: widget.onNavigate ?? (_) {}),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat('${_orderService.orderCount}', 'Orders'),
          Container(
            width: 1,
            height: 36,
            color: Theme.of(context).dividerColor,
          ),
          _buildStat('${_wishlistService.count}', 'Wishlist'),
          Container(
            width: 1,
            height: 36,
            color: Theme.of(context).dividerColor,
          ),
          _buildStat('$_reviewCount', 'Reviews'),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive
        ? AppTheme.red600
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: destructive
                      ? AppTheme.red500.withValues(alpha: 0.1)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.gray400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dark Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isDarkMode
                        ? 'Switch to light theme'
                        : 'Switch to dark theme',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isDarkMode,
              onChanged: (value) {
                widget.onThemeChange?.call(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
              activeThumbColor: AppTheme.atelierMidnight,
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedAddress {
  final String label;
  final String name;
  final String phone;
  final String address;
  final String city;

  const _SavedAddress({
    required this.label,
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
  });

  factory _SavedAddress.empty(String label) {
    return _SavedAddress(
      label: label,
      name: '',
      phone: '',
      address: '',
      city: '',
    );
  }

  factory _SavedAddress.fromMap(String label, Map<String, dynamic> map) {
    return _SavedAddress(
      label: label,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? '',
    );
  }

  bool get isSaved {
    return name.trim().isNotEmpty ||
        phone.trim().isNotEmpty ||
        address.trim().isNotEmpty ||
        city.trim().isNotEmpty;
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'phone': phone, 'address': address, 'city': city};
  }
}
