<?php
require_once 'config.php';

$pdo = getDBConnection();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendError('Method not allowed', 405);
}

try {
    // Get total employees
    $stmt = $pdo->prepare("SELECT COUNT(*) as total FROM employees WHERE is_active = 1");
    $stmt->execute();
    $totalEmployees = $stmt->fetch()['total'];
    
    // Get today's attendance
    $today = date('Y-m-d');
    $stmt = $pdo->prepare("
        SELECT 
            COUNT(*) as total_attendance,
            SUM(CASE WHEN status IN ('present', 'late', 'half-day') THEN 1 ELSE 0 END) as present_today,
            SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent_today,
            SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) as late_today
        FROM attendance 
        WHERE date = ?
    ");
    $stmt->execute([$today]);
    $todayStats = $stmt->fetch();
    
    // Get this month's attendance
    $currentMonth = date('Y-m');
    $stmt = $pdo->prepare("
        SELECT 
            COUNT(DISTINCT employee_id) as active_employees,
            SUM(CASE WHEN status IN ('present', 'late', 'half-day') THEN 1 ELSE 0 END) as total_present,
            SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as total_absent,
            AVG(CASE WHEN status IN ('present', 'late', 'half-day') THEN 1 ELSE 0 END) * 100 as attendance_rate
        FROM attendance 
        WHERE DATE_FORMAT(date, '%Y-%m') = ?
    ");
    $stmt->execute([$currentMonth]);
    $monthStats = $stmt->fetch();
    
    // Get recent attendance records
    $stmt = $pdo->prepare("
        SELECT a.*, e.name as employee_name 
        FROM attendance a 
        LEFT JOIN employees e ON a.employee_id = e.id 
        WHERE a.date = ? 
        ORDER BY a.check_in DESC 
        LIMIT 10
    ");
    $stmt->execute([$today]);
    $recentAttendance = $stmt->fetchAll();
    
    // Get salary statistics for current month
    $currentMonthNum = date('n');
    $currentYear = date('Y');
    $stmt = $pdo->prepare("
        SELECT 
            COUNT(*) as total_salaries,
            SUM(net_salary) as total_payroll,
            SUM(CASE WHEN is_paid = 1 THEN net_salary ELSE 0 END) as total_paid,
            SUM(CASE WHEN is_paid = 0 THEN net_salary ELSE 0 END) as total_pending
        FROM salary 
        WHERE month = ? AND year = ?
    ");
    $stmt->execute([$currentMonthNum, $currentYear]);
    $salaryStats = $stmt->fetch();
    
    // Get employee positions distribution
    $stmt = $pdo->prepare("
        SELECT position, COUNT(*) as count 
        FROM employees 
        WHERE is_active = 1 
        GROUP BY position 
        ORDER BY count DESC
    ");
    $stmt->execute();
    $positionDistribution = $stmt->fetchAll();
    
    // Get attendance trend for last 7 days
    $stmt = $pdo->prepare("
        SELECT 
            date,
            COUNT(*) as total_attendance,
            SUM(CASE WHEN status IN ('present', 'late', 'half-day') THEN 1 ELSE 0 END) as present_count,
            SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent_count
        FROM attendance 
        WHERE date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
        GROUP BY date 
        ORDER BY date DESC
    ");
    $stmt->execute();
    $attendanceTrend = $stmt->fetchAll();
    
    // Compile dashboard data
    $dashboardData = [
        'overview' => [
            'total_employees' => (int)$totalEmployees,
            'present_today' => (int)($todayStats['present_today'] ?? 0),
            'absent_today' => (int)($todayStats['absent_today'] ?? 0),
            'late_today' => (int)($todayStats['late_today'] ?? 0),
            'attendance_rate' => round($monthStats['attendance_rate'] ?? 0, 1),
        ],
        'monthly_stats' => [
            'active_employees' => (int)($monthStats['active_employees'] ?? 0),
            'total_present' => (int)($monthStats['total_present'] ?? 0),
            'total_absent' => (int)($monthStats['total_absent'] ?? 0),
            'attendance_rate' => round($monthStats['attendance_rate'] ?? 0, 1),
        ],
        'salary_stats' => [
            'total_salaries' => (int)($salaryStats['total_salaries'] ?? 0),
            'total_payroll' => (float)($salaryStats['total_payroll'] ?? 0),
            'total_paid' => (float)($salaryStats['total_paid'] ?? 0),
            'total_pending' => (float)($salaryStats['total_pending'] ?? 0),
        ],
        'recent_attendance' => $recentAttendance,
        'position_distribution' => $positionDistribution,
        'attendance_trend' => $attendanceTrend,
    ];
    
    sendSuccess($dashboardData);
    
} catch (Exception $e) {
    sendError('Failed to load dashboard data: ' . $e->getMessage());
}
?> 