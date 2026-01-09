<?php
require_once 'config.php';

$pdo = getDBConnection();

$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'GET':
        // Get salary records with filters
        $employeeId = $_GET['employee_id'] ?? null;
        $month = $_GET['month'] ?? null;
        $year = $_GET['year'] ?? null;
        
        $sql = "SELECT s.*, e.name as employee_name FROM salary s 
                LEFT JOIN employees e ON s.employee_id = e.id 
                WHERE 1=1";
        $params = [];
        
        if ($employeeId) {
            $sql .= " AND s.employee_id = ?";
            $params[] = $employeeId;
        }
        
        if ($month) {
            $sql .= " AND s.month = ?";
            $params[] = $month;
        }
        
        if ($year) {
            $sql .= " AND s.year = ?";
            $params[] = $year;
        }
        
        $sql .= " ORDER BY s.year DESC, s.month DESC";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $salaries = $stmt->fetchAll();
        
        sendSuccess($salaries);
        break;
        
    case 'POST':
        // Calculate salary for employee
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (empty($input['employee_id']) || empty($input['month']) || empty($input['year'])) {
            sendError('Employee ID, month, and year are required');
        }
        
        $employeeId = $input['employee_id'];
        $month = $input['month'];
        $year = $input['year'];
        
        // Check if employee exists
        $stmt = $pdo->prepare("SELECT * FROM employees WHERE id = ? AND is_active = 1");
        $stmt->execute([$employeeId]);
        $employee = $stmt->fetch();
        
        if (!$employee) {
            sendError('Employee not found or inactive');
        }
        
        // Check if salary already exists for this month/year
        $stmt = $pdo->prepare("SELECT id FROM salary WHERE employee_id = ? AND month = ? AND year = ?");
        $stmt->execute([$employeeId, $month, $year]);
        if ($stmt->fetch()) {
            sendError('Salary already calculated for this month');
        }
        
        // Get attendance data for the month
        $startDate = "$year-" . str_pad($month, 2, '0', STR_PAD_LEFT) . "-01";
        $endDate = date('Y-m-t', strtotime($startDate));
        
        $stmt = $pdo->prepare("
            SELECT 
                COUNT(*) as total_days,
                SUM(CASE WHEN status IN ('present', 'late', 'half-day') THEN 1 ELSE 0 END) as present_days,
                SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent_days,
                SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) as late_days,
                SUM(CASE WHEN status = 'half-day' THEN 1 ELSE 0 END) as half_days,
                SUM(COALESCE(working_hours, 0)) as total_working_hours
            FROM attendance 
            WHERE employee_id = ? AND date BETWEEN ? AND ?
        ");
        $stmt->execute([$employeeId, $startDate, $endDate]);
        $attendanceStats = $stmt->fetch();
        
        // Calculate salary
        $baseSalary = $employee['salary'];
        $totalDays = $attendanceStats['total_days'] ?? 0;
        $presentDays = $attendanceStats['present_days'] ?? 0;
        $absentDays = $attendanceStats['absent_days'] ?? 0;
        $lateDays = $attendanceStats['late_days'] ?? 0;
        $halfDays = $attendanceStats['half_days'] ?? 0;
        $totalWorkingHours = $attendanceStats['total_working_hours'] ?? 0;
        
        $dailySalary = $baseSalary / 30; // Assuming 30 days per month
        $presentDaySalary = $presentDays * $dailySalary;
        $lateDaySalary = $lateDays * ($dailySalary * 0.8); // 20% deduction for late
        $halfDaySalary = $halfDays * ($dailySalary * 0.5); // 50% for half day
        
        $deductions = $input['deductions'] ?? 0;
        $allowances = $input['allowances'] ?? 0;
        
        $grossSalary = $presentDaySalary + $lateDaySalary + $halfDaySalary + $allowances;
        $netSalary = $grossSalary - $deductions;
        
        // Insert salary record
        $stmt = $pdo->prepare("
            INSERT INTO salary (
                employee_id, month, year, base_salary, total_days, present_days, 
                absent_days, late_days, half_days, total_working_hours, 
                deductions, allowances, net_salary, is_paid
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
        ");
        
        $stmt->execute([
            $employeeId, $month, $year, $baseSalary, $totalDays, $presentDays,
            $absentDays, $lateDays, $halfDays, $totalWorkingHours,
            $deductions, $allowances, $netSalary
        ]);
        
        $salaryId = $pdo->lastInsertId();
        
        // Get created salary record
        $stmt = $pdo->prepare("
            SELECT s.*, e.name as employee_name FROM salary s 
            LEFT JOIN employees e ON s.employee_id = e.id 
            WHERE s.id = ?
        ");
        $stmt->execute([$salaryId]);
        $salary = $stmt->fetch();
        
        sendSuccess($salary, 'Salary calculated successfully');
        break;
        
    case 'PUT':
        // Update salary (mark as paid)
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (empty($input['id'])) {
            sendError('Salary ID is required');
        }
        
        // Check if salary exists
        $stmt = $pdo->prepare("SELECT * FROM salary WHERE id = ?");
        $stmt->execute([$input['id']]);
        $existingSalary = $stmt->fetch();
        
        if (!$existingSalary) {
            sendError('Salary record not found', 404);
        }
        
        // Build update query
        $updateFields = [];
        $params = [];
        
        $fields = ['is_paid', 'paid_date', 'deductions', 'allowances', 'net_salary'];
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
        $sql = "UPDATE salary SET " . implode(', ', $updateFields) . " WHERE id = ?";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        
        // Get updated salary record
        $stmt = $pdo->prepare("
            SELECT s.*, e.name as employee_name FROM salary s 
            LEFT JOIN employees e ON s.employee_id = e.id 
            WHERE s.id = ?
        ");
        $stmt->execute([$input['id']]);
        $salary = $stmt->fetch();
        
        sendSuccess($salary, 'Salary updated successfully');
        break;
        
    default:
        sendError('Method not allowed', 405);
        break;
}
?> 