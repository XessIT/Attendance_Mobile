<?php
// Database configuration
define('DB_HOST', 'localhost');
define('DB_USER', 'root');
define('DB_PASSWORD', '');
define('DB_NAME', 'attendance');

// Face recognition API configuration
define('FACE_API_URL', 'https://api.face-api.com'); // Replace with your face recognition API
define('FACE_API_KEY', 'your_api_key_here');

// Application configuration
define('UPLOAD_DIR', 'uploads/faces/');
define('MAX_FILE_SIZE', 5 * 1024 * 1024); // 5MB
define('ALLOWED_EXTENSIONS', ['jpg', 'jpeg', 'png']);

// CORS headers
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Database connection function
function getDBConnection() {
    try {
        $pdo = new PDO(
            "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
            DB_USER,
            DB_PASSWORD
        );
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        return $pdo;
    } catch (PDOException $e) {
        // echo json_encode(['error' => 'Database connection failed: ' . $e->getMessage()]);
        exit;
    }
}

// Response helper functions
function sendResponse($data, $statusCode = 200) {
    http_response_code($statusCode);
     echo json_encode($data);
    exit();
}

function sendError($message, $statusCode = 400) {
    sendResponse(['error' => $message], $statusCode);
}

function sendSuccess($data, $message = 'Success', $statusCode = 200) {
    sendResponse(['success' => true, 'message' => $message, 'data' => $data], $statusCode);
}

// File upload helper function
function uploadFile($file, $directory = UPLOAD_DIR) {
    if (!isset($file['tmp_name']) || !is_uploaded_file($file['tmp_name'])) {
        return false;
    }

    $fileName = $file['name'];
    $fileSize = $file['size'];
    $fileTmp = $file['tmp_name'];
    $fileExt = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));

    // Validate file size
    if ($fileSize > MAX_FILE_SIZE) {
        return false;
    }

    // Validate file extension
    if (!in_array($fileExt, ALLOWED_EXTENSIONS)) {
        return false;
    }

    // Create directory if it doesn't exist
    if (!is_dir($directory)) {
        mkdir($directory, 0755, true);
    }

    // Generate unique filename
    $newFileName = uniqid() . '.' . $fileExt;
    $filePath = $directory . $newFileName;

    // Move uploaded file
    if (move_uploaded_file($fileTmp, $filePath)) {
        return $filePath;
    }

    return false;
}

// Face recognition helper function (placeholder - replace with actual API)
function recognizeFace($imagePath) {
    // This is a placeholder implementation
    // Replace with actual face recognition API integration
    
    // For demo purposes, return a mock response
    $employees = [
        ['id' => 1, 'name' => 'John Doe', 'confidence' => 0.95],
        ['id' => 2, 'name' => 'Jane Smith', 'confidence' => 0.92],
        ['id' => 3, 'name' => 'Mike Johnson', 'confidence' => 0.88],
    ];
    
    // Simulate face recognition
    $randomEmployee = $employees[array_rand($employees)];
    $confidence = $randomEmployee['confidence'] + (rand(-10, 10) / 100);
    
    if ($confidence > 0.8) {
        return [
            'success' => true,
            'employee_id' => $randomEmployee['id'],
            'employee_name' => $randomEmployee['name'],
            'confidence' => $confidence
        ];
    } else {
        return [
            'success' => false,
            'message' => 'Face not recognized'
        ];
    }
}

// Face registration helper function (placeholder - replace with actual API)
function registerFace($imagePath, $employeeId) {
    // This is a placeholder implementation
    // Replace with actual face recognition API integration
    
    // For demo purposes, return success
    return [
        'success' => true,
        'face_data' => 'face_features_' . $employeeId . '_' . time(),
        'message' => 'Face registered successfully'
    ];
}
?> 