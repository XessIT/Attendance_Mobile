/// Reusable validation utility class for form validation
class ValidationUtils {
  /// Validates if a field is not empty
  static String? validateRequired(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates mobile number (10 digits)
  static String? validateMobileNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your mobile number';
    }
    
    // Remove all whitespace and check if it's exactly 10 digits
    final cleanedValue = value.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{10}$').hasMatch(cleanedValue)) {
      return 'Please enter a valid 10-digit mobile number';
    }
    
    return null;
  }

  /// Validates email address
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  /// Validates password with minimum length
  static String? validatePassword(String? value, {int minLength = 6}) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your password';
    }
    
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    
    return null;
  }

  /// Validates password with strength requirements
  static String? validateStrongPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your password';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    
    return null;
  }

  /// Validates name (letters and spaces only)
  static String? validateName(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return '$fieldName can only contain letters and spaces';
    }
    
    return null;
  }

  /// Validates phone number (flexible format)
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }
    
    // Remove common phone number characters
    final cleanedValue = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Check if it's 10-15 digits (international format)
    if (!RegExp(r'^\d{10,15}$').hasMatch(cleanedValue)) {
      return 'Please enter a valid phone number';
    }
    
    return null;
  }

  /// Validates numeric value
  static String? validateNumeric(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (double.tryParse(value.trim()) == null) {
      return '$fieldName must be a valid number';
    }
    
    return null;
  }

  /// Validates positive number
  static String? validatePositiveNumber(String? value, {String fieldName = 'This field'}) {
    final numericError = validateNumeric(value, fieldName: fieldName);
    if (numericError != null) {
      return numericError;
    }
    
    final num = double.parse(value!.trim());
    if (num <= 0) {
      return '$fieldName must be greater than 0';
    }
    
    return null;
  }

  /// Validates URL
  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a URL';
    }
    
    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );
    
    if (!urlRegex.hasMatch(value.trim())) {
      return 'Please enter a valid URL';
    }
    
    return null;
  }

  /// Validates date (must be in the past)
  static String? validatePastDate(String? value, {String fieldName = 'Date'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    try {
      final date = DateTime.parse(value.trim());
      if (date.isAfter(DateTime.now())) {
        return '$fieldName must be in the past';
      }
    } catch (e) {
      return 'Please enter a valid date';
    }
    
    return null;
  }

  /// Validates date (must be in the future)
  static String? validateFutureDate(String? value, {String fieldName = 'Date'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    try {
      final date = DateTime.parse(value.trim());
      if (date.isBefore(DateTime.now())) {
        return '$fieldName must be in the future';
      }
    } catch (e) {
      return 'Please enter a valid date';
    }
    
    return null;
  }

  /// Validates minimum length
  static String? validateMinLength(String? value, int minLength, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (value.trim().length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    
    return null;
  }

  /// Validates maximum length
  static String? validateMaxLength(String? value, int maxLength, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (value.trim().length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }
    
    return null;
  }

  /// Validates length range
  static String? validateLength(String? value, int minLength, int maxLength, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    final length = value.trim().length;
    if (length < minLength || length > maxLength) {
      return '$fieldName must be between $minLength and $maxLength characters';
    }
    
    return null;
  }

  /// Validates confirmation (e.g., password confirmation)
  static String? validateConfirmation(String? value, String? originalValue, {String fieldName = 'Confirmation'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (value.trim() != originalValue?.trim()) {
      return '$fieldName does not match';
    }
    
    return null;
  }

  /// Validates username (alphanumeric and underscore only)
  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a username';
    }
    
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    
    return null;
  }

  /// Validates PIN (exactly 4 or 6 digits)
  static String? validatePin(String? value, {int length = 4}) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a PIN';
    }
    
    if (!RegExp(r'^\d{' + length.toString() + r'}$').hasMatch(value.trim())) {
      return 'PIN must be exactly $length digits';
    }
    
    return null;
  }

  /// Validates OTP (exactly 6 digits)
  static String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the OTP';
    }
    
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'OTP must be exactly 6 digits';
    }
    
    return null;
  }
}
