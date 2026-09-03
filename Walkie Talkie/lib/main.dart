import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/main_navigation_shell.dart';
import 'screens/onboarding/identity_setup_screen.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ConnectXApp());
}

class ConnectXApp extends StatefulWidget {
  const ConnectXApp({super.key});

  @override
  State<ConnectXApp> createState() => _ConnectXAppState();
}

class _ConnectXAppState extends State<ConnectXApp> {
  final AppState _appState = AppState();
  bool _isOnboardingCompleted = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        final bool showMainApp = _isOnboardingCompleted || 
            (_appState.deviceIdentity?.isConfigured == true);

        return MaterialApp(
          title: 'ConnectX',
          debugShowCheckedModeBanner: false,
          themeMode: _appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          home: showMainApp
              ? MainNavigationShell(state: _appState)
              : IdentitySetupScreen(
                  state: _appState,
                  onComplete: () {
                    setState(() => _isOnboardingCompleted = true);
                  },
                ),
        );
      },
    );
  }
}
