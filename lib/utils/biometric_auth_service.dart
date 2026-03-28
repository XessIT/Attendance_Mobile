import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// App-aligned accent colors (login / premium app bar)
const Color _kFpBlueDark = Color(0xFF1565C0);
const Color _kFpBlueLight = Color(0xFF42A5F5);
const Color _kFpIndigo = Color(0xFF667EEA);

class BiometricAuthService {
  static const String biometricMobileKey = 'biometric_mobile_number';
  static const String biometricPasswordKey = 'biometric_password';
  static const String biometricCompanyIdKey = 'biometric_company_id';
  static const String biometricEnabledKey = 'biometric_enabled';
  /// User chose "Not now" on the home-screen fingerprint offer.
  static const String fingerprintOfferDismissedKey =
      'fingerprint_enable_offer_dismissed';

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<bool> isSupported() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final supported = await _localAuth.isDeviceSupported();
    return canCheck && supported;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(biometricEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(biometricEnabledKey, enabled);
  }

  Future<bool> hasStoredCredentials() async {
    final mobile = await _secureStorage.read(key: biometricMobileKey);
    final password = await _secureStorage.read(key: biometricPasswordKey);
    return mobile != null &&
        mobile.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  Future<void> storeCredentials({
    required String mobileNumber,
    required String password,
    int? companyId,
  }) async {
    await _secureStorage.write(key: biometricMobileKey, value: mobileNumber);
    await _secureStorage.write(key: biometricPasswordKey, value: password);
    if (companyId != null) {
      await _secureStorage.write(
        key: biometricCompanyIdKey,
        value: companyId.toString(),
      );
    } else {
      await _secureStorage.delete(key: biometricCompanyIdKey);
    }
  }

  Future<({String mobile, String password, int? companyId})> readCredentials() async {
    final mobile = await _secureStorage.read(key: biometricMobileKey) ?? '';
    final password = await _secureStorage.read(key: biometricPasswordKey) ?? '';
    final companyIdRaw = await _secureStorage.read(key: biometricCompanyIdKey);
    return (
      mobile: mobile,
      password: password,
      companyId: int.tryParse(companyIdRaw ?? ''),
    );
  }

  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: biometricMobileKey);
    await _secureStorage.delete(key: biometricPasswordKey);
    await _secureStorage.delete(key: biometricCompanyIdKey);
  }

  Future<bool> authenticate({
    required String reason,
  }) async {
    return _localAuth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }

  Future<bool> enableWithBiometricPrompt() async {
    final authed = await authenticate(
      reason: 'Authenticate to enable fingerprint login',
    );
    if (!authed) return false;
    await setEnabled(true);
    return true;
  }

  Future<void> disableAndClear() async {
    await setEnabled(false);
    await clearCredentials();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(fingerprintOfferDismissedKey);
  }
}

Widget _fingerprintDialogHeader({
  required IconData icon,
  required String badge,
  Color? iconBackground,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_kFpBlueDark, _kFpBlueLight],
      ),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: iconBackground ?? Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, size: 42, color: Colors.white),
        ),
        const SizedBox(height: 14),
        Text(
          badge,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.95),
            letterSpacing: 0.6,
          ),
        ),
      ],
    ),
  );
}

TextStyle _fpTitleStyle() => GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF1A202C),
      height: 1.25,
    );

TextStyle _fpBodyStyle() => GoogleFonts.poppins(
      fontSize: 14,
      height: 1.5,
      color: Colors.grey[700],
    );

/// After password login, offer enabling fingerprint from Home / Employee home.
Future<void> showEnableFingerprintOfferIfNeeded(BuildContext context) async {
  final bio = BiometricAuthService();
  if (!await bio.isSupported()) return;
  if (!context.mounted) return;
  if (await bio.isEnabled()) return;
  if (!await bio.hasStoredCredentials()) return;

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(BiometricAuthService.fingerprintOfferDismissedKey) ??
      false) {
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _fingerprintDialogHeader(
              icon: Icons.fingerprint_rounded,
              badge: 'QUICK SIGN-IN',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enable fingerprint login?',
                    textAlign: TextAlign.center,
                    style: _fpTitleStyle(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in faster next time with your fingerprint. Your mobile number and password are stored securely on this device only.',
                    textAlign: TextAlign.center,
                    style: _fpBodyStyle(),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await prefs.setBool(
                              BiometricAuthService.fingerprintOfferDismissedKey,
                              true,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kFpIndigo,
                            side: const BorderSide(color: _kFpIndigo, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Not now',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            final ok = await bio.enableWithBiometricPrompt();
                            if (!context.mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Fingerprint login enabled',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _kFpIndigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Enable',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// App bar entry: enable or disable fingerprint login.
Future<void> showFingerprintLoginOptionsDialog(BuildContext context) async {
  final bio = BiometricAuthService();
  final supported = await bio.isSupported();
  if (!context.mounted) return;

  if (!supported) {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _fingerprintDialogHeader(
                icon: Icons.info_outline_rounded,
                badge: 'NOT AVAILABLE',
                iconBackground: Colors.white.withValues(alpha: 0.18),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Fingerprint login',
                      textAlign: TextAlign.center,
                      style: _fpTitleStyle(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This device does not support fingerprint or face unlock for app sign-in.',
                      textAlign: TextAlign.center,
                      style: _fpBodyStyle(),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kFpIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Got it',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    return;
  }

  final hasCreds = await bio.hasStoredCredentials();
  final enabled = await bio.isEnabled();
  if (!context.mounted) return;

  final String title;
  final String body;
  final String statusBadge;
  final IconData headerIcon;

  if (!hasCreds) {
    title = 'Set up fingerprint';
    body =
        'Sign in once with your password on the login screen so we can save your details securely. Then return here to enable fingerprint login.';
    statusBadge = 'STEP REQUIRED';
    headerIcon = Icons.lock_outline_rounded;
  } else if (enabled) {
    title = 'Fingerprint is on';
    body =
        'You can sign in with your fingerprint on the login screen. You can turn this off any time below.';
    statusBadge = 'ACTIVE';
    headerIcon = Icons.verified_user_outlined;
  } else {
    title = 'Fingerprint login';
    body =
        'Enable fingerprint to skip typing your password on this device. You will confirm with your fingerprint when signing in.';
    statusBadge = 'READY TO ENABLE';
    headerIcon = Icons.fingerprint_rounded;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        elevation: 12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _fingerprintDialogHeader(
              icon: headerIcon,
              badge: statusBadge,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: _fpTitleStyle(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: _fpBodyStyle(),
                  ),
                  const SizedBox(height: 22),
                  if (!hasCreds)
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kFpIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  if (hasCreds && enabled) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        await bio.disableAndClear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Fingerprint login disabled',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.deepOrange.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(Icons.fingerprint, color: Colors.red.shade700),
                      label: Text(
                        'Disable fingerprint ',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  if (hasCreds && !enabled) ...[
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        final ok = await bio.enableWithBiometricPrompt();
                        if (context.mounted && ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Fingerprint login enabled',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.green.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _kFpIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.fingerprint_rounded, size: 22),
                      label: Text(
                        'Enable fingerprint',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

