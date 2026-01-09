import os
import json
import base64
import numpy as np
import cv2
import face_recognition
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename
import mysql.connector
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configuration
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '',
    'database': 'attendance'
}

# Create upload folder if it doesn't exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def get_db_connection():
    """Create database connection"""
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        return connection
    except mysql.connector.Error as err:
        logger.error(f"Database connection error: {err}")
        return None

def save_face_encoding(employee_id, face_encoding):
    """Save face encoding to database"""
    try:
        connection = get_db_connection()
        if connection:
            cursor = connection.cursor()
            
            # Convert numpy array to base64 string
            encoding_str = base64.b64encode(face_encoding.tobytes()).decode('utf-8')
            
            # Update employee with face data
            query = "UPDATE employees SET face_data = %s WHERE id = %s"
            cursor.execute(query, (encoding_str, employee_id))
            connection.commit()
            
            cursor.close()
            connection.close()
            return True
    except Exception as e:
        logger.error(f"Error saving face encoding: {e}")
        return False

def get_face_encodings():
    """Get all face encodings from database"""
    try:
        connection = get_db_connection()
        if connection:
            cursor = connection.cursor()
            
            query = "SELECT id, name, face_data FROM employees WHERE face_data IS NOT NULL AND is_active = 1"
            cursor.execute(query)
            results = cursor.fetchall()
            
            encodings = []
            for row in results:
                employee_id, name, face_data = row
                if face_data:
                    # Convert base64 string back to numpy array
                    encoding_bytes = base64.b64decode(face_data)
                    encoding = np.frombuffer(encoding_bytes, dtype=np.float64)
                    encodings.append({
                        'id': employee_id,
                        'name': name,
                        'encoding': encoding
                    })
            
            cursor.close()
            connection.close()
            return encodings
    except Exception as e:
        logger.error(f"Error getting face encodings: {e}")
        return []

def log_face_recognition(employee_id, action, success, confidence=None, error_message=None):
    """Log face recognition attempts"""
    try:
        connection = get_db_connection()
        if connection:
            cursor = connection.cursor()
            
            query = """
                INSERT INTO face_recognition_logs 
                (employee_id, action, success, confidence, error_message, ip_address, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """
            cursor.execute(query, (
                employee_id, action, success, confidence, error_message,
                request.remote_addr, datetime.now()
            ))
            connection.commit()
            
            cursor.close()
            connection.close()
    except Exception as e:
        logger.error(f"Error logging face recognition: {e}")

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'message': 'Face Recognition API is running'})

@app.route('/register-face', methods=['POST'])
def register_face():
    """Register a new face for an employee"""
    try:
        # Check if employee_id is provided
        employee_id = request.form.get('employee_id')
        if not employee_id:
            return jsonify({'success': False, 'error': 'Employee ID is required'}), 400
        
        # Check if image is provided
        if 'image' not in request.files:
            return jsonify({'success': False, 'error': 'No image file provided'}), 400
        
        file = request.files['image']
        if file.filename == '':
            return jsonify({'success': False, 'error': 'No image file selected'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'success': False, 'error': 'Invalid file type. Only PNG, JPG, JPEG allowed'}), 400
        
        # Check file size
        file.seek(0, 2)  # Seek to end
        file_size = file.tell()
        file.seek(0)  # Reset to beginning
        
        if file_size > MAX_FILE_SIZE:
            return jsonify({'success': False, 'error': 'File size too large. Maximum 5MB allowed'}), 400
        
        # Read and process image
        image_data = file.read()
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            return jsonify({'success': False, 'error': 'Invalid image file'}), 400
        
        # Convert BGR to RGB
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # Detect faces
        face_locations = face_recognition.face_locations(rgb_image)
        
        if not face_locations:
            return jsonify({'success': False, 'error': 'No face detected in the image'}), 400
        
        if len(face_locations) > 1:
            return jsonify({'success': False, 'error': 'Multiple faces detected. Please use an image with only one face'}), 400
        
        # Extract face encoding
        face_encodings = face_recognition.face_encodings(rgb_image, face_locations)
        
        if not face_encodings:
            return jsonify({'success': False, 'error': 'Could not extract face features'}), 400
        
        face_encoding = face_encodings[0]
        
        # Save face encoding to database
        if save_face_encoding(employee_id, face_encoding):
            # Log successful registration
            log_face_recognition(employee_id, 'register', True, 1.0)
            
            return jsonify({
                'success': True,
                'message': 'Face registered successfully',
                'employee_id': employee_id
            })
        else:
            return jsonify({'success': False, 'error': 'Failed to save face data'}), 500
            
    except Exception as e:
        logger.error(f"Error in register_face: {e}")
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@app.route('/recognize-face', methods=['POST'])
def recognize_face():
    """Recognize a face and return employee information"""
    try:
        # Check if image is provided
        if 'image' not in request.files:
            return jsonify({'success': False, 'error': 'No image file provided'}), 400
        
        file = request.files['image']
        if file.filename == '':
            return jsonify({'success': False, 'error': 'No image file selected'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'success': False, 'error': 'Invalid file type. Only PNG, JPG, JPEG allowed'}), 400
        
        # Check file size
        file.seek(0, 2)
        file_size = file.tell()
        file.seek(0)
        
        if file_size > MAX_FILE_SIZE:
            return jsonify({'success': False, 'error': 'File size too large. Maximum 5MB allowed'}), 400
        
        # Read and process image
        image_data = file.read()
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            return jsonify({'success': False, 'error': 'Invalid image file'}), 400
        
        # Convert BGR to RGB
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # Detect faces
        face_locations = face_recognition.face_locations(rgb_image)
        
        if not face_locations:
            return jsonify({'success': False, 'error': 'No face detected in the image'}), 400
        
        if len(face_locations) > 1:
            return jsonify({'success': False, 'error': 'Multiple faces detected. Please use an image with only one face'}), 400
        
        # Extract face encoding
        face_encodings = face_recognition.face_encodings(rgb_image, face_locations)
        
        if not face_encodings:
            return jsonify({'success': False, 'error': 'Could not extract face features'}), 400
        
        unknown_face_encoding = face_encodings[0]
        
        # Get all registered face encodings
        registered_faces = get_face_encodings()
        
        if not registered_faces:
            return jsonify({'success': False, 'error': 'No registered faces found'}), 404
        
        # Compare with registered faces
        best_match = None
        best_confidence = 0.0
        threshold = 0.6  # Minimum confidence threshold
        
        for registered_face in registered_faces:
            # Calculate face distance (lower is better)
            face_distance = face_recognition.face_distance([registered_face['encoding']], unknown_face_encoding)[0]
            
            # Convert distance to confidence (0-1 scale)
            confidence = 1 - face_distance
            
            if confidence > best_confidence and confidence >= threshold:
                best_confidence = confidence
                best_match = registered_face
        
        if best_match:
            # Log successful recognition
            log_face_recognition(best_match['id'], 'recognize', True, best_confidence)
            
            return jsonify({
                'success': True,
                'employee': {
                    'id': best_match['id'],
                    'name': best_match['name']
                },
                'confidence': round(best_confidence, 4)
            })
        else:
            # Log failed recognition
            log_face_recognition(None, 'recognize', False, 0.0, 'No match found')
            
            return jsonify({
                'success': False,
                'error': 'Face not recognized. Please register first.'
            }), 404
            
    except Exception as e:
        logger.error(f"Error in recognize_face: {e}")
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@app.route('/get-employee/<int:employee_id>', methods=['GET'])
def get_employee(employee_id):
    """Get employee information"""
    try:
        connection = get_db_connection()
        if connection:
            cursor = connection.cursor(dictionary=True)
            
            query = "SELECT id, name, email, phone, position, salary FROM employees WHERE id = %s AND is_active = 1"
            cursor.execute(query, (employee_id,))
            employee = cursor.fetchone()
            
            cursor.close()
            connection.close()
            
            if employee:
                return jsonify({'success': True, 'employee': employee})
            else:
                return jsonify({'success': False, 'error': 'Employee not found'}), 404
        else:
            return jsonify({'success': False, 'error': 'Database connection failed'}), 500
            
    except Exception as e:
        logger.error(f"Error in get_employee: {e}")
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@app.route('/list-employees', methods=['GET'])
def list_employees():
    """List all active employees"""
    try:
        connection = get_db_connection()
        if connection:
            cursor = connection.cursor(dictionary=True)
            
            query = "SELECT id, name, email, phone, position, salary, face_data IS NOT NULL as has_face FROM employees WHERE is_active = 1"
            cursor.execute(query)
            employees = cursor.fetchall()
            
            cursor.close()
            connection.close()
            
            return jsonify({'success': True, 'employees': employees})
        else:
            return jsonify({'success': False, 'error': 'Database connection failed'}), 500
            
    except Exception as e:
        logger.error(f"Error in list_employees: {e}")
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

if __name__ == '__main__':
    print("Starting Face Recognition API...")
    print("Make sure you have installed all requirements: pip install -r requirements.txt")
    print("API will be available at: http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=True) 