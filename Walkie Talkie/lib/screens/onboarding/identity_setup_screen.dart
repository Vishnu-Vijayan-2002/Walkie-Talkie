import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';

class IdentitySetupScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onComplete;

  const IdentitySetupScreen({
    super.key,
    required this.state,
    required this.onComplete,
  });

  @override
  State<IdentitySetupScreen> createState() => _IdentitySetupScreenState();
}

class _IdentitySetupScreenState extends State<IdentitySetupScreen> {
  late TextEditingController _nameController;
  String _selectedTeam = 'Security Team';
  final bool _micChecked = true;
  final bool _speakerChecked = true;

  final List<String> _teams = [
    'Security Team',
    'Emergency & Medical',
    'Field Operations',
    'Command Center',
    'Event Logistics',
  ];

  @override
  void initState() {
    super.initState();
    final savedName = widget.state.deviceIdentity?.displayName ?? '';
    _nameController = TextEditingController(text: savedName);
    if (widget.state.deviceIdentity != null && widget.state.deviceIdentity!.unitOrTeam.isNotEmpty) {
      _selectedTeam = widget.state.deviceIdentity!.unitOrTeam;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveAndProceed() {
    final enteredName = _nameController.text.trim();
    final name = enteredName.isEmpty ? 'Operator' : enteredName;
    widget.state.updateProfileName(name, _selectedTeam);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceId = widget.state.deviceIdentity?.hardwareCallsign ?? widget.state.currentUser.deviceId;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.liveGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.liveGreen, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.radio_rounded, size: 38, color: AppColors.liveGreen),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to ConnectX',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Text(
                'Instant Tactical Communication Setup',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 36),

              // Auto-Generated Hardware ID Badge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phonelink_setup_rounded, color: AppColors.tacticalBlueLight, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AUTO-GENERATED HARDWARE ID',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: AppColors.tacticalBlueLight),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            deviceId,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.liveGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('AUTO-PROVISIONED', style: TextStyle(color: AppColors.liveGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Operator Name Input
              const Text(
                'Choose your call sign / display name',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Enter any name (e.g. Rahul, John, Lead-1)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Unit selection
              const Text(
                'Assigned Unit / Workspace',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTeam,
                    isExpanded: true,
                    dropdownColor: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                    items: _teams.map((team) {
                      return DropdownMenuItem(
                        value: team,
                        child: Text(team, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedTeam = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _micChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          color: _micChecked ? AppColors.liveGreen : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text('Microphone Ready (Noise Suppression ON)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          _speakerChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          color: _speakerChecked ? AppColors.liveGreen : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text('Speaker Ready (Loudness Boost ON)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              ElevatedButton(
                onPressed: _saveAndProceed,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ENTER CONSOLE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
