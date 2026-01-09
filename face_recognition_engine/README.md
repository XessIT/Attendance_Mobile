# Face Recognition Engine

A complete face recognition system built with Python, OpenCV, and face_recognition library. This engine provides REST API endpoints for face registration and recognition, integrated with MySQL database.

## 🚀 Features

- **Face Registration**: Register employee faces with automatic feature extraction
- **Face Recognition**: Real-time face recognition with confidence scoring
- **Database Integration**: MySQL database for storing face encodings and logs
- **REST API**: Flask-based API for easy integration with Flutter app
- **Logging**: Comprehensive logging of all face recognition attempts
- **Error Handling**: Robust error handling and validation

## 📋 Prerequisites

- Python 3.7 or higher
- MySQL/MariaDB server
- Webcam or camera for testing

## 🛠️ Installation

### 1. Clone or Download the Project
```bash
# Navigate to the face_recognition_engine directory
cd face_recognition_engine
```

### 2. Install Python Dependencies
```bash
pip install -r requirements.txt
```

### 3. Database Setup
1. Create MySQL database using the provided `database_setup.sql`
2. Update database configuration in `face_recognition_api.py`:

```python
DB_CONFIG = {
    'host': 'localhost',
    'user': 'your_username',
    'password': 'your_password',
    'database': 'face_recognition_db'
}
```

### 4. Start the Server
```bash
# Option 1: Use the startup script (recommended)
python start_server.py

# Option 2: Run directly
python face_recognition_api.py
```

## 📡 API Endpoints

### Health Check
```
GET /health
```
Returns server status and health information.

### Register Face
```
POST /register-face
```
Register a new face for an employee.

**Parameters:**
- `employee_id` (form data): Employee ID
- `image` (file): Face image (PNG, JPG, JPEG)

**Response:**
```json
{
    "success": true,
    "message": "Face registered successfully",
    "employee_id": 1
}
```

### Recognize Face
```
POST /recognize-face
```
Recognize a face and return employee information.

**Parameters:**
- `image` (file): Face image to recognize

**Response:**
```json
{
    "success": true,
    "employee": {
        "id": 1,
        "name": "John Doe"
    },
    "confidence": 0.85
}
```

### Get Employee
```
GET /get-employee/<employee_id>
```
Get employee information by ID.

### List Employees
```
GET /list-employees
```
List all active employees with face registration status.

## 🔧 Configuration

### Face Recognition Settings
- **Confidence Threshold**: 0.6 (60% minimum confidence for recognition)
- **Max File Size**: 5MB
- **Allowed Formats**: PNG, JPG, JPEG

### Database Tables Used
- `employees`: Employee information and face data
- `face_recognition_logs`: Recognition attempt logs

## 📱 Integration with Flutter

Update your Flutter app's `face_recognition_service.dart` to use the local API:

```dart
class FaceRecognitionService {
  static const String baseUrl = 'http://localhost:5000';
  
  // Register face
  static Future<bool> registerFace(int employeeId, File imageFile) async {
    // Implementation using local API
  }
  
  // Recognize face
  static Future<Map<String, dynamic>?> recognizeFace(File imageFile) async {
    // Implementation using local API
  }
}
```

## 🧪 Testing

### Test Face Registration
```bash
curl -X POST -F "employee_id=1" -F "image=@test_face.jpg" http://localhost:5000/register-face
```

### Test Face Recognition
```bash
curl -X POST -F "image=@test_face.jpg" http://localhost:5000/recognize-face
```

### Test Health Check
```bash
curl http://localhost:5000/health
```

## 📊 Performance Tips

1. **Image Quality**: Use high-quality, well-lit images for better recognition
2. **Face Detection**: Ensure only one face is visible in registration images
3. **Database Indexing**: The database includes proper indexes for performance
4. **Memory Usage**: Face encodings are stored efficiently in the database

## 🔍 Troubleshooting

### Common Issues

1. **"No face detected" Error**
   - Ensure the image contains a clear, front-facing face
   - Check image quality and lighting
   - Verify image format (PNG, JPG, JPEG)

2. **Database Connection Error**
   - Verify MySQL server is running
   - Check database credentials in configuration
   - Ensure database and tables exist

3. **Import Errors**
   - Install all requirements: `pip install -r requirements.txt`
   - Check Python version (3.7+ required)

4. **Port Already in Use**
   - Change port in `face_recognition_api.py`
   - Kill existing process using port 5000

### Debug Mode
Enable debug mode for detailed error messages:
```python
app.run(host='0.0.0.0', port=5000, debug=True)
```

## 📈 Monitoring

The system logs all face recognition attempts to the `face_recognition_logs` table:
- Registration attempts
- Recognition attempts (successful and failed)
- Confidence scores
- Error messages
- IP addresses and timestamps

## 🔒 Security Considerations

1. **Input Validation**: All inputs are validated and sanitized
2. **File Size Limits**: Maximum file size enforced
3. **File Type Validation**: Only allowed image formats accepted
4. **Error Logging**: Comprehensive error logging without exposing sensitive data

## 📝 License

This project is part of the Face Recognition Attendance System.

## 🤝 Support

For issues and questions:
1. Check the troubleshooting section
2. Review error logs in the database
3. Verify all prerequisites are met
4. Test with sample images first 