<?php
require_once 'config.php';

$pdo = getDBConnection();

$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'GET':
        // Get attendance records with filters
        $employeeId = $_GET['employee_id'] ?? null;
        $startDate = $_GET['start_date'] ?? null;
        $endDate = $_GET['end_date'] ?? null;
        
        $sql = "SELECT a.*, e.name as employee_name FROM attendance a 
                LEFT JOIN employees e ON a.employee_id = e.id 
                WHERE 1=1";
        $params = [];
        
        if ($employeeId) {
            $sql .= " AND a.employee_id = ?";
            $params[] = $employeeId;
        }
        
        if ($startDate) {
            $sql .= " AND a.date >= ?";
            $params[] = $startDate;
        }
        
        if ($endDate) {
            $sql .= " AND a.date <= ?";
            $params[] = $endDate;
        }
        
        $sql .= " ORDER BY a.date DESC, a.check_in DESC";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $attendance = $stmt->fetchAll();
        
        sendSuccess($attendance);
        break;
        
    case 'POST':
        // Mark attendance
        $input = json_decode(file_get_contents('php://input'), true);
        
        // Validate required fields
        if (empty($input['employee_id']) || empty($input['date'])) {
            sendError('Employee ID and date are required');
        }
        
        // Check if employee exists
        $stmt = $pdo->prepare("SELECT id FROM employees WHERE id = ? AND is_active = 1");
        $stmt->execute([$input['employee_id']]);
        if (!$stmt->fetch()) {
            sendError('Employee not found or inactive');
        }
        
        // Check if attendance already exists for this date and employee
        $stmt = $pdo->prepare("SELECT id FROM attendance WHERE employee_id = ? AND date = ?");
        $stmt->execute([$input['employee_id'], $input['date']]);
        if ($stmt->fetch()) {
            sendError('Attendance already exists for this date');
        }
        
        // Insert attendance record
        $stmt = $pdo->prepare("
            INSERT INTO attendance (employee_id, date, check_in, check_out, status, working_hours, notes) 
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ");
        
        $checkIn = $input['check_in'] ?? null;
        $checkOut = $input['check_out'] ?? null;
        $status = $input['status'] ?? 'present';
        $workingHours = $input['working_hours'] ?? null;
        $notes = $input['notes'] ?? null;
        
        $stmt->execute([
            $input['employee_id'],
            $input['date'],
            $checkIn,
            $checkOut,
            $status,
            $workingHours,
            $notes
        ]);
        
        $attendanceId = $pdo->lastInsertId();
        
        // Get created attendance record
        $stmt = $pdo->prepare("
            SELECT a.*, e.name as employee_name FROM attendance a 
            LEFT JOIN employees e ON a.employee_id = e.id 
            WHERE a.id = ?
        ");
        $stmt->execute([$attendanceId]);
        $attendance = $stmt->fetch();
        
        sendSuccess($attendance, 'Attendance marked successfully');
        break;
        
    case 'PUT':
        // Update attendance (for check-out)
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (empty($input['id'])) {
            sendError('Attendance ID is required');
        }
        
        // Check if attendance exists
        $stmt = $pdo->prepare("SELECT * FROM attendance WHERE id = ?");
        $stmt->execute([$input['id']]);
        $existingAttendance = $stmt->fetch();
        
        if (!$existingAttendance) {
            sendError('Attendance record not found', 404);
        }
        
        // Build update query
        $updateFields = [];
        $params = [];
        
        $fields = ['check_in', 'check_out', 'status', 'working_hours', 'notes'];
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
        $sql = "UPDATE attendance SET " . implode(', ', $updateFields) . " WHERE id = ?";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        
        // Get updated attendance record
        $stmt = $pdo->prepare("
            SELECT a.*, e.name as employee_name FROM attendance a 
            LEFT JOIN employees e ON a.employee_id = e.id 
            WHERE a.id = ?
        ");
        $stmt->execute([$input['id']]);
        $attendance = $stmt->fetch();
        
        sendSuccess($attendance, 'Attendance updated successfully');
        break;
        
    default:
        sendError('Method not allowed', 405);
        break;
}
?> 