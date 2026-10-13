import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/session.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  session.start();
  runApp(const JankiStaffApp());
}

class JankiStaffApp extends StatelessWidget {
  const JankiStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Janki Staff',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Root(),
    );
  }
}

/// Picks the first screen from the login state.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  SessionState? _last;

  @override
  void initState() {
    super.initState();
    session.addListener(_onSession);
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    // Logged out (by the user, or by the website) → close any open form and show the login
    if (_last == SessionState.loggedIn && session.state == SessionState.loggedOut) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _last = session.state;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    switch (session.state) {
      case SessionState.loggedIn:
        return const HomeScreen();
      case SessionState.loggedOut:
        return const LoginScreen();
      case SessionState.starting:
        return _Splash(error: session.startupError);
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.forest,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌿', style: TextStyle(fontSize: 54)),
                const SizedBox(height: 12),
                const Text(
                  'Janki Agro Tourism',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 28),
                if (error == null)
                  const CircularProgressIndicator(color: AppColors.gold)
                else ...[
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.forestDark),
                    onPressed: session.start,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: session.logout,
                    child: const Text('Log in with another account', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
