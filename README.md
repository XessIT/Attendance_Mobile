# Face Recognition Attendance System

A comprehensive Flutter application with PHP backend for employee face recognition attendance management and salary calculation.

## Features

### 🎯 Core Features
- **Employee Registration** - Register employees with face data
- **Face Recognition Attendance** - Mark attendance using face recognition
- **Attendance Management** - Track check-in/check-out times
- **Salary Calculation** - Automatic salary calculation based on attendance
- **Dashboard Analytics** - Real-time statistics and reports
- **Multi-platform Support** - Works on Android, iOS, and Web

### 📱 Flutter App Features
- Modern Material Design UI
- Camera integration for face capture
- Real-time face recognition
- Offline data caching
- Push notifications (planned)
- Biometric authentication (planned)

### 🔧 Backend Features
- RESTful API endpoints
- Secure file upload handling
- Database management
- Face recognition integration
- Comprehensive error handling
- CORS support

## Technology Stack

### Frontend (Flutter)
- **Framework**: Flutter 3.5+
- **State Management**: Provider
- **HTTP Client**: Dio
- **Camera**: camera package
- **Image Processing**: image package
- **UI Components**: Material Design 3
- **Charts**: fl_chart

### Backend (PHP)
- **Language**: PHP 8.0+
- **Database**: MySQL 8.0+
- **Web Server**: Apache/Nginx
- **Face Recognition**: Custom implementation (replaceable with APIs)

## Prerequisites

### For Flutter Development
- Flutter SDK 3.5.4 or higher
- Dart SDK 3.5.4 or higher
- Android Studio / VS Code
- Android SDK (for Android development)
- Xcode (for iOS development, macOS only)

### For Backend Development
- PHP 8.0 or higher
- MySQL 8.0 or higher
- Apache/Nginx web server
- Composer (optional, for dependency management)

## Installation & Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd face_recognization
```

### 2. Flutter App Setup

#### Install Dependencies
```bash
flutter pub get
```

#### Configure API Base URL
Edit `lib/services/api_service.dart` and update the `baseUrl`:
```dart
// For Android emulator
static const String baseUrl = 'http://10.0.2.2/face_recognition_api';

// For physical device (replace with your server IP)
static const String baseUrl = 'http://192.168.1.100/face_recognition_api';

// For web
static const String baseUrl = 'http://localhost/face_recognition_api';
```

#### Run the App
```bash
# For Android
flutter run

# For iOS
flutter run -d ios

# For Web
flutter run -d chrome
```

### 3. Backend Setup

#### Database Setup
1. Create a MySQL database:
```sql
CREATE DATABASE face_recognition_db;
```

2. Import the database schema:
```bash
mysql -u root -p face_recognition_db < backend/database.sql
```

#### Web Server Configuration
1. Copy the `backend` folder to your web server directory:
```bash
# For XAMPP
cp -r backend /opt/lampp/htdocs/face_recognition_api/

# For WAMP
cp -r backend C:/wamp64/www/face_recognition_api/

# For MAMP
cp -r backend /Applications/MAMP/htdocs/face_recognition_api/
```

2. Configure database connection in `backend/config.php`:
```php
define('DB_HOST', 'localhost');
define('DB_NAME', 'face_recognition_db');
define('DB_USER', 'your_username');
define('DB_PASS', 'your_password');
```

3. Set proper permissions:
```bash
chmod 755 backend/
chmod 644 backend/*.php
mkdir backend/uploads
chmod 777 backend/uploads
```

#### Face Recognition API Integration
The current implementation includes placeholder functions for face recognition. To integrate with a real face recognition service:

1. **Option 1: Google Cloud Vision API**
```php
// In config.php, add your API key
define('GOOGLE_CLOUD_API_KEY', 'your_api_key_here');
```

2. **Option 2: Azure Face API**
```php
// In config.php, add your endpoint and key
define('AZURE_FACE_ENDPOINT', 'your_endpoint_here');
define('AZURE_FACE_KEY', 'your_key_here');
```

3. **Option 3: AWS Rekognition**
```php
// In config.php, add your credentials
define('AWS_ACCESS_KEY', 'your_access_key');
define('AWS_SECRET_KEY', 'your_secret_key');
define('AWS_REGION', 'us-east-1');
```

## API Endpoints

### Employees
- `GET /employees.php` - Get all employees
- `GET /employees.php?id={id}` - Get specific employee
- `POST /employees.php` - Create new employee
- `PUT /employees.php` - Update employee
- `DELETE /employees.php` - Delete employee

### Attendance
- `GET /attendance.php` - Get attendance records
- `POST /attendance.php` - Mark attendance
- `PUT /attendance.php` - Update attendance

### Face Recognition
- `POST /face_register.php` - Register employee face
- `POST /face_recognize.php` - Recognize face for attendance

### Salary
- `GET /salary.php` - Get salary records
- `POST /salary.php` - Calculate salary
- `PUT /salary.php` - Update salary (mark as paid)

### Dashboard
- `GET /dashboard.php` - Get dashboard statistics

## Usage Guide

### 1. Employee Registration
1. Navigate to Employees tab
2. Tap the + button
3. Fill in employee details
4. Capture face image
5. Submit registration

### 2. Marking Attendance
1. Navigate to Dashboard
2. Tap "Mark Attendance"
3. Position face in camera frame
4. Tap "Capture & Recognize"
5. Attendance will be automatically marked

### 3. Viewing Reports
1. Navigate to Attendance tab
2. Select date range and employee
3. View attendance statistics
4. Export data (planned feature)

### 4. Salary Management
1. Navigate to Salary tab
2. Select month and year
3. View calculated salaries
4. Mark salaries as paid

## Configuration

### Environment Variables
Create a `.env` file in the backend directory:
```env
DB_HOST=localhost
DB_NAME=face_recognition_db
DB_USER=root
DB_PASS=your_password
FACE_API_KEY=your_face_recognition_api_key
UPLOAD_MAX_SIZE=5242880
```

### App Configuration
Edit `lib/utils/constants.dart` for app-specific settings:
```dart
class AppConstants {
  static const String appName = 'Face Recognition Attendance';
  static const String companyName = 'Your Company Name';
  static const Duration sessionTimeout = Duration(hours: 8);
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
}
```

## Security Considerations

### Data Protection
- All sensitive data is encrypted
- Face data is stored securely
- API endpoints are protected
- Input validation on all forms

### Access Control
- Role-based access (planned)
- Session management
- API rate limiting (planned)

## Troubleshooting

### Common Issues

#### 1. Camera Not Working
```bash
# Check camera permissions
flutter doctor
# Ensure camera permissions are granted in app settings
```

#### 2. API Connection Failed
```bash
# Check if backend is running
curl http://localhost/face_recognition_api/employees.php

# Verify database connection
php backend/test_connection.php
```

#### 3. Face Recognition Not Working
- Ensure proper lighting
- Check image quality
- Verify API keys are configured
- Check network connectivity

### Debug Mode
Enable debug mode in `lib/main.dart`:
```dart
void main() {
  debugPrint = (String? message, {int? wrapWidth}) {
    print('DEBUG: $message');
  };
  runApp(const MyApp());
}
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue on GitHub
- Email: support@yourcompany.com
- Documentation: [Wiki Link]

## Roadmap

### Version 2.0 (Planned)
- [ ] Push notifications
- [ ] Biometric authentication
- [ ] Advanced analytics
- [ ] Multi-language support
- [ ] Offline mode
- [ ] Export functionality

### Version 3.0 (Future)
- [ ] AI-powered attendance insights
- [ ] Integration with HR systems
- [ ] Mobile app for employees
- [ ] Advanced reporting
- [ ] Cloud deployment options

---

**Note**: This is a demo implementation. For production use, please:
1. Implement proper face recognition APIs
2. Add comprehensive security measures
3. Set up proper backup systems
4. Configure monitoring and logging
5. Perform thorough testing
