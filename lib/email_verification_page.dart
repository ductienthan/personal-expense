import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'homepage.dart';
import 'signin_page.dart';
import 'services/firebase_service.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;
  
  const EmailVerificationPage({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  late Timer _timer;
  bool _isEmailVerified = false;
  bool _canResendEmail = true;
  int _resendTimeout = 30;

  @override
  void initState() {
    super.initState();
    _isEmailVerified = auth.currentUser?.emailVerified ?? false;
    
    if (!_isEmailVerified) {
      _startVerificationTimer();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startVerificationTimer() {
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkEmailVerified(),
    );
  }

  void _startResendTimeout() {
    setState(() {
      _canResendEmail = false;
      _resendTimeout = 30;
    });

    Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) {
        if (_resendTimeout == 0) {
          setState(() {
            _canResendEmail = true;
          });
          timer.cancel();
        } else {
          setState(() {
            _resendTimeout--;
          });
        }
      },
    );
  }

  Future<void> _checkEmailVerified() async {
    await auth.currentUser?.reload();
    final user = auth.currentUser;
    
    setState(() {
      _isEmailVerified = user?.emailVerified ?? false;
    });

    if (_isEmailVerified && user != null) {
      _timer.cancel();
      
      try {
        // Create user document after email verification
        await _firebaseService.createUserDocument(user);
        
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              isAuthenticated: true,
              userId: user.uid,
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating user profile: $e')),
        );
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await auth.currentUser?.sendEmailVerification();
      _startResendTimeout();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending verification email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 100,
                color: Color(0xFF0095FF),
              ),
              const SizedBox(height: 32),
              const Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C161D),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We\'ve sent a verification email to:\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF457AA1),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _canResendEmail ? _resendVerificationEmail : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0095FF),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _canResendEmail
                      ? 'Resend Verification Email'
                      : 'Resend in $_resendTimeout seconds',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await auth.signOut();
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignInPage(),
                    ),
                  );
                },
                child: const Text(
                  'Back to Sign In',
                  style: TextStyle(
                    color: Color(0xFF0095FF),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 