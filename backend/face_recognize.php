<?php
require_once 'config.php';

$pdo = getDBConnection();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendError('Method not allowed', 405);
}

// Check if face image was uploaded
if (!isset($_FILES['face_image']) || !is_uploaded_file($_FILES['face_image']['tmp_name'])) {
    sendError('Face image is required');
}

$faceImage = $_FILES['face_image'];

// Validate file
if ($faceImage['size'] > MAX_FILE_SIZE) {
    sendError('File size too large. Maximum size is ' . (MAX_FILE_SIZE / 1024 / 1024) . 'MB');
}

$fileExt = strtolower(pathinfo($faceImage['name'], PATHINFO_EXTENSION));
if (!in_array($fileExt, ALLOWED_EXTENSIONS)) {
    sendError('Invalid file type. Allowed types: ' . implode(', ', ALLOWED_EXTENSIONS));
}

// Upload the image
$uploadedPath = uploadFile($faceImage);
if (!$uploadedPath) {
    sendError('Failed to upload image');
}

try {
    // Perform face recognition
    $recognitionResult = recognizeFace($uploadedPath);
    
    if ($recognitionResult['success']) {
        $employeeId = $recognitionResult['employee_id'];
        $employeeName = $recognitionResult['employee_name'];
        $confidence = $recognitionResult['confidence'];
        
        // Get employee details from database
        $stmt = $pdo->prepare("SELECT * FROM employees WHERE id = ? AND is_active = 1");
        $stmt->execute([$employeeId]);
        $employee = $stmt->fetch();
        
        if (!$employee) {
            sendError('Employee not found or inactive');
        }
        
        // Clean up uploaded file
        unlink($uploadedPath);
        
        sendSuccess([
            'employee_id' => $employeeId,
            'employee_name' => $employeeName,
            'confidence' => $confidence,
            'employee' => $employee
        ], 'Face recognized successfully');
        
    } else {
        // Clean up uploaded file
        unlink($uploadedPath);
        
        sendError($recognitionResult['message'] ?? 'Face not recognized');
    }
    
} catch (Exception $e) {
    // Clean up uploaded file
    if (file_exists($uploadedPath)) {
        unlink($uploadedPath);
    }
    
    sendError('Face recognition failed: ' . $e->getMessage());
}
?> 