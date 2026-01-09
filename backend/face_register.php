<?php
require_once 'config.php';

$pdo = getDBConnection();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendError('Method not allowed', 405);
}

// Check if employee ID and face image were provided
if (empty($_POST['employee_id'])) {
    sendError('Employee ID is required');
}

if (!isset($_FILES['face_image']) || !is_uploaded_file($_FILES['face_image']['tmp_name'])) {
    sendError('Face image is required');
}

$employeeId = $_POST['employee_id'];
$faceImage = $_FILES['face_image'];

// Validate employee exists
$stmt = $pdo->prepare("SELECT * FROM employees WHERE id = ? AND is_active = 1");
$stmt->execute([$employeeId]);
$employee = $stmt->fetch();

if (!$employee) {
    sendError('Employee not found or inactive');
}

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
    // Perform face registration
    $registrationResult = registerFace($uploadedPath, $employeeId);
    
    if ($registrationResult['success']) {
        $faceData = $registrationResult['face_data'];
        
        // Update employee with face data
        $stmt = $pdo->prepare("UPDATE employees SET face_data = ? WHERE id = ?");
        $stmt->execute([$faceData, $employeeId]);
        
        // Clean up uploaded file
        unlink($uploadedPath);
        
        sendSuccess([
            'employee_id' => $employeeId,
            'face_data' => $faceData,
            'message' => $registrationResult['message']
        ], 'Face registered successfully');
        
    } else {
        // Clean up uploaded file
        unlink($uploadedPath);
        
        sendError($registrationResult['message'] ?? 'Face registration failed');
    }
    
} catch (Exception $e) {
    // Clean up uploaded file
    if (file_exists($uploadedPath)) {
        unlink($uploadedPath);
    }
    
    sendError('Face registration failed: ' . $e->getMessage());
}
?> 