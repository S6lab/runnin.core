import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class ProfileActionButtons extends StatelessWidget {
  final VoidCallback? onEditProfile;
  final VoidCallback? onLogout;

  const ProfileActionButtons({
    super.key,
    required this.onEditProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEditProfileButton(context, palette, type),
        const SizedBox(height: 8),
        _buildLogoutButton(context, palette, type),
      ],
    );
  }

  Widget _buildEditProfileButton(
    BuildContext context,
    RunninPalette palette,
    RunninTypography type,
  ) {
    return Container(
      height: 47,
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.03),
        border: Border.all(color: palette.border.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: onEditProfile,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: palette.text.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 8),
            Text(
              'Editar perfil ↗',
              style: type.dataSm.copyWith(
                fontWeight: FontWeight.w500,
                color: palette.text.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(
    BuildContext context,
    RunninPalette palette,
    RunninTypography type,
  ) {
    return SizedBox(
      height: 43,
      child: InkWell(
        onTap: onLogout,
        child: Center(
          child: Text(
            'Logout',
            style: type.dataSm.copyWith(
              fontWeight: FontWeight.w500,
              color: palette.muted.withValues(alpha: 0.2),
            ),
          ),
        ),
      ),
    );
  }
}
