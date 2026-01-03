import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SignInScreen extends StatefulWidget {
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  const SignInScreen({
    super.key,
    required this.onSignIn,
    required this.onSignUp,
  });

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      widget.onSignIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
          children: [
            // Header with gradient
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.purplePinkGradient,
              ),
              child: Stack(
                children: [
                  // Decorative elements
                  Positioned(
                    top: 40,
                    right: 40,
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 48, 24, 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back!',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to continue shopping',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Form container
            Transform.translate(
              offset: const Offset(0, -32),
              child: Container(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      // Email field
                      Text(
                        'Email Address',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.gray700,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'your@email.com',
                          prefixIcon: const Icon(Icons.mail_outline),
                          filled: true,
                          fillColor: AppTheme.gray50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppTheme.gray200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppTheme.gray200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppTheme.purple600, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // Password field
                      Text(
                        'Password',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.gray700,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: AppTheme.gray50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppTheme.gray200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppTheme.gray200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppTheme.purple600, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: AppTheme.purple600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Sign in button
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.purplePinkGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.purple600.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: AppTheme.gray200)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(color: AppTheme.gray500),
                            ),
                          ),
                          Expanded(child: Divider(color: AppTheme.gray200)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Google sign in
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: Container(
                          width: 20,
                          height: 20,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Stack(
                            children: [
                              // Google "G" multicolor
                              CustomPaint(
                                size: const Size(16, 16),
                                painter: GoogleLogoPainter(),
                              ),
                            ],
                          ),
                        ),
                        label: const Text('Continue with Google'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppTheme.gray200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          foregroundColor: AppTheme.gray700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // GitHub sign in
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.code, color: Colors.white),
                        label: const Text('Continue with GitHub'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Sign up link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(color: AppTheme.gray600),
                          ),
                          TextButton(
                            onPressed: widget.onSignUp,
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppTheme.purple600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// Custom Google Logo Painter
class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Blue section
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..close();
    canvas.drawPath(bluePath, paint);

    // Red section
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.5, 0)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(0, size.height * 0.5)
      ..close();
    canvas.drawPath(redPath, paint);

    // Yellow section
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(0, size.height * 0.5)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Green section
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.5, size.height)
      ..close();
    canvas.drawPath(greenPath, paint);

    // White center circle (G shape)
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.25,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
