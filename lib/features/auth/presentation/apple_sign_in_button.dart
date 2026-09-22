import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';

/// « Continuer avec Apple », placé au-dessus de Google sur iOS (Apple exige
/// une visibilité au moins égale aux autres connexions).
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'auth_continue_apple'.tr(),
      icon: Icons.apple,
      variant: AppButtonVariant.apple,
      expand: true,
      loading: loading,
      onPressed: onPressed,
    );
  }
}
