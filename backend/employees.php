<?php
require_once 'config.php';

$pdo = getDBConnection();

$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'GET':
        // Get all employees or specific employee
        $id = $_GET['id'] ?? null;
        
        if ($id) {
            // Get specific employee
            $stmt = $pdo->prepare("SELECT * FROM employees WHERE id = ?");
            $stmt->execute([$id]);
            $employee = $stmt->fetch();
            
            if ($employee) {
                sendSuccess($employee);
            } else {
                sendError('Employee not found', 404);
            }
        } else {
            // Get all employees
            $stmt = $pdo->prepare("SELECT * FROM employees ORDER BY created_at DESC");
            $stmt->execute();
            $employees = $stmt->fetchAll();
            
            sendSuccess($employees);
        }
        break;
        
    case 'POST':
        // Create new employee
        $input = json_decode(file_get_contents('php://input'), true);
        
        // Validate required fields
        $requiredFields = ['name', 'email', 'phone', 'position', 'salary'];
        foreach ($requiredFields as $field) {
            if (empty($input[$field])) {
                sendError("Missing required field: $field");
            }
        }
        
        // Validate email format
        if (!filter_var($input['email'], FILTER_VALIDATE_EMAIL)) {
            sendError('Invalid email format');
        }
        
        // Check if email already exists
        $stmt = $pdo->prepare("SELECT id FROM employees WHERE email = ?");
        $stmt->execute([$input['email']]);
        if ($stmt->fetch()) {
            sendError('Email already exists');
        }
        
        // Insert new employee
        $stmt = $pdo->prepare("
            INSERT INTO employees (name, email, phone, position, salary, face_data, created_at, is_active) 
            VALUES (?, ?, ?, ?, ?, ?, NOW(), 1)
        ");
        
        $stmt->execute([
            $input['name'],
            $input['email'],
            $input['phone'],
            $input['position'],
            $input['salary'],
            $input['face_data'] ?? ''
        ]);
        
        $employeeId = $pdo->lastInsertId();
        
        // Get created employee
        $stmt = $pdo->prepare("SELECT * FROM employees WHERE id = ?");
        $stmt->execute([$employeeId]);
        $employee = $stmt->fetch();
        
        sendSuccess($employee, 'Employee created successfully', 201);
        break;
        
    case 'PUT':
        // Update employee
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (empty($input['id'])) {
            sendError('Employee ID is required');
        }
        
        // Check if employee exists
        $stmt = $pdo->prepare("SELECT id FROM employees WHERE id = ?");
        $stmt->execute([$input['id']]);
        if (!$stmt->fetch()) {
            sendError('Employee not found', 404);
        }
        
        // Build update query
        $updateFields = [];
        $params = [];
        
        $fields = ['name', 'email', 'phone', 'position', 'salary', 'face_data', 'is_active'];
        foreach ($fields as $field) {
            if (isset($input[$field])) {
                $updateFields[] = "$field = ?";
                $params[] = $input[$field];
            }
        }
        
        if (empty($updateFields)) {
            sendError('No fields to update');
        }
        
        $params[] = $input['id'];
        $sql = "UPDATE employees SET " . implode(', ', $updateFields) . " WHERE id = ?";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        
        // Get updated employee
        $stmt = $pdo->prepare("SELECT * FROM employees WHERE id = ?");
        $stmt->execute([$input['id']]);
        $employee = $stmt->fetch();
        
        sendSuccess($employee, 'Employee updated successfully');
        break;
        
    case 'DELETE':
        // Delete employee
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (empty($input['id'])) {
            sendError('Employee ID is required');
        }
        
        // Check if employee exists
        $stmt = $pdo->prepare("SELECT id FROM employees WHERE id = ?");
        $stmt->execute([$input['id']]);
        if (!$stmt->fetch()) {
            sendError('Employee not found', 404);
        }
        
        // Delete employee (soft delete by setting is_active = 0)
        $stmt = $pdo->prepare("UPDATE employees SET is_active = 0 WHERE id = ?");
        $stmt->execute([$input['id']]);
        
        sendSuccess(null, 'Employee deleted successfully');
        break;
        
    default:
        sendError('Method not allowed', 405);
        break;
}
?> 