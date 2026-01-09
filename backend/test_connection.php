<?php
require_once 'config.php';

// echo "<h1>Face Recognition API - Connection Test</h1>";

// Test database connection
// echo "<h2>Database Connection Test</h2>";
try {
    $pdo = getDBConnection();
    // echo "✅ Database connection successful<br>";
    
    // Test query
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM employees");
    $result = $stmt->fetch();
    // echo "✅ Database query successful. Total employees: " . $result['count'] . "<br>";
    
} catch (Exception $e) {
    // echo "❌ Database connection failed: " . $e->getMessage() . "<br>";
}

// Test file upload directory
// echo "<h2>File Upload Test</h2>";
$uploadDir = UPLOAD_DIR;
if (is_dir($uploadDir)) {
    // echo "✅ Upload directory exists: $uploadDir<br>";
} else {
    // echo "❌ Upload directory missing: $uploadDir<br>";
    if (mkdir($uploadDir, 0755, true)) {
        // echo "✅ Created upload directory<br>";
    } else {
        // echo "❌ Failed to create upload directory<br>";
    }
}

// Test file permissions
if (is_writable($uploadDir)) {
    // echo "✅ Upload directory is writable<br>";
} else {
    // echo "❌ Upload directory is not writable<br>";
}

// Test API endpoints
// echo "<h2>API Endpoints Test</h2>";
$endpoints = [
    'employees.php' => 'GET',
    'attendance.php' => 'GET',
    'dashboard.php' => 'GET'
];

foreach ($endpoints as $endpoint => $method) {
    $url = "http://" . $_SERVER['HTTP_HOST'] . dirname($_SERVER['REQUEST_URI']) . "/$endpoint";
    $context = stream_context_create([
        'http' => [
            'method' => $method,
            'timeout' => 5
        ]
    ]);
    
    $response = @file_get_contents($url, false, $context);
    if ($response !== false) {
        // echo "✅ $endpoint ($method) - Working<br>";
    } else {
        // echo "❌ $endpoint ($method) - Failed<br>";
    }
}

// System information
// echo "<h2>System Information</h2>";
echo "PHP Version: " . phpversion() . "<br>";
echo "Server: " . $_SERVER['SERVER_SOFTWARE'] . "<br>";
echo "Upload Max Size: " . ini_get('upload_max_filesize') . "<br>";
echo "Post Max Size: " . ini_get('post_max_size') . "<br>";
echo "Memory Limit: " . ini_get('memory_limit') . "<br>";

// Required PHP extensions
// echo "<h2>Required Extensions</h2>";
$required_extensions = ['pdo', 'pdo_mysql', 'json', 'fileinfo'];
foreach ($required_extensions as $ext) {
    if (extension_loaded($ext)) {
        // echo "✅ $ext extension loaded<br>";
    } else {
        // echo "❌ $ext extension missing<br>";
    }
}

// echo "<h2>Configuration</h2>";
echo "Database Host: " . DB_HOST . "<br>";
echo "Database Name: " . DB_NAME . "<br>";
echo "Upload Directory: " . UPLOAD_DIR . "<br>";
echo "Max File Size: " . (MAX_FILE_SIZE / 1024 / 1024) . "MB<br>";
echo "Allowed Extensions: " . implode(', ', ALLOWED_EXTENSIONS) . "<br>";

// echo "<h2>Test Complete</h2>";
echo "If all tests pass, your API is ready to use!<br>";
echo "If any tests fail, please check the configuration and try again.<br>";
?> 