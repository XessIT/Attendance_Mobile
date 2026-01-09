-- =====================================================
-- Face Recognition Attendance System Database Setup
-- =====================================================

-- Create database
CREATE DATABASE IF NOT EXISTS face_recognition_db;
USE face_recognition_db;

-- =====================================================
-- 1. EMPLOYEES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    department VARCHAR(50),
    position VARCHAR(50),
    salary DECIMAL(10,2),
    date_joined DATE,
    face_encoding TEXT, -- For storing face encoding as JSON or string
    photo_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for better performance
    INDEX idx_email (email),
    INDEX idx_position (position),
    INDEX idx_created_at (created_at)
);

-- =====================================================
-- 2. ATTENDANCE TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS attendance (
    id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    date DATE NOT NULL,
    check_in_time TIME,
    check_out_time TIME,
    status ENUM('Present', 'Absent', 'Late', 'On Leave') DEFAULT 'Present',
    face_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key constraint
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Unique constraint to prevent duplicate attendance for same employee on same date
    UNIQUE KEY unique_employee_date (employee_id, date),
    
    -- Indexes for better performance
    INDEX idx_employee_id (employee_id),
    INDEX idx_date (date),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);

-- =====================================================
-- 3. SALARY TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS salary (
    id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    month VARCHAR(7) NOT NULL, -- Format: YYYY-MM
    base_salary DECIMAL(10,2) NOT NULL,
    bonus DECIMAL(10,2) DEFAULT 0,
    deductions DECIMAL(10,2) DEFAULT 0,
    net_salary DECIMAL(10,2) NOT NULL,
    paid BOOLEAN DEFAULT FALSE,
    paid_at DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key constraint
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Unique constraint to prevent duplicate salary for same employee in same month
    UNIQUE KEY unique_employee_month (employee_id, month),
    
    -- Indexes for better performance
    INDEX idx_employee_id (employee_id),
    INDEX idx_month (month),
    INDEX idx_is_paid (paid)
);

-- =====================================================
-- 4. FACE RECOGNITION LOGS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS face_recognition_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT,
    action ENUM('register', 'recognize') NOT NULL,
    image_path VARCHAR(500),
    confidence DECIMAL(5,4),
    success TINYINT(1) DEFAULT 0,
    error_message TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key constraint
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL,
    
    -- Indexes for better performance
    INDEX idx_employee_id (employee_id),
    INDEX idx_action (action),
    INDEX idx_success (success),
    INDEX idx_created_at (created_at)
);

-- =====================================================
-- 5. SETTINGS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS settings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes for better performance
    INDEX idx_setting_key (setting_key)
);

-- =====================================================
-- 6. DEPARTMENTS TABLE (Optional - for better organization)
-- =====================================================
CREATE TABLE IF NOT EXISTS departments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    manager_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Foreign key constraint
    FOREIGN KEY (manager_id) REFERENCES employees(id) ON DELETE SET NULL,
    
    -- Indexes
    INDEX idx_name (name),
    INDEX idx_manager_id (manager_id)
);

-- =====================================================
-- 7. LEAVE REQUESTS TABLE (Optional - for leave management)
-- =====================================================
CREATE TABLE IF NOT EXISTS leave_requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    status ENUM('Pending', 'Approved', 'Rejected') DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Foreign key constraints
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Indexes
    INDEX idx_employee_id (employee_id),
    INDEX idx_start_date (start_date),
    INDEX idx_end_date (end_date)
);

-- =====================================================
-- INSERT DEFAULT SETTINGS
-- =====================================================
INSERT INTO settings (setting_key, setting_value, description) VALUES
('company_name', 'Face Recognition Attendance System', 'Company name'),
('working_hours_start', '09:00', 'Default working hours start time'),
('working_hours_end', '17:00', 'Default working hours end time'),
('late_threshold_minutes', '30', 'Minutes after start time to consider as late'),
('face_recognition_threshold', '0.8', 'Minimum confidence threshold for face recognition'),
('max_upload_size_mb', '5', 'Maximum file upload size in MB'),
('allowed_image_types', 'jpg,jpeg,png', 'Allowed image file types'),
('attendance_grace_period', '15', 'Grace period in minutes for late attendance'),
('overtime_rate', '1.5', 'Overtime pay rate multiplier'),
('holiday_pay_rate', '2.0', 'Holiday pay rate multiplier'),
('weekend_pay_rate', '1.5', 'Weekend pay rate multiplier'),
('monthly_working_days', '22', 'Standard working days per month'),
('daily_working_hours', '8', 'Standard working hours per day'),
('break_time_minutes', '60', 'Break time in minutes per day'),
('system_timezone', 'UTC', 'System timezone for date/time calculations');

-- =====================================================
-- INSERT SAMPLE DEPARTMENTS
-- =====================================================
INSERT INTO departments (name, description) VALUES
('Information Technology', 'IT and Software Development'),
('Human Resources', 'HR and Personnel Management'),
('Finance', 'Accounting and Financial Management'),
('Marketing', 'Marketing and Sales'),
('Operations', 'General Operations and Administration');

-- =====================================================
-- INSERT SAMPLE EMPLOYEES
-- =====================================================
INSERT INTO employees (name, email, phone, position, salary, date_joined, face_encoding) VALUES
('John Doe', 'john.doe@company.com', '+1234567890', 'Software Developer', 5000.00, '2024-01-01', 'sample_face_encoding_1'),
('Jane Smith', 'jane.smith@company.com', '+1234567891', 'Project Manager', 6000.00, '2024-02-01', 'sample_face_encoding_2'),
('Mike Johnson', 'mike.johnson@company.com', '+1234567892', 'UI/UX Designer', 4500.00, '2024-03-01', 'sample_face_encoding_3'),
('Sarah Wilson', 'sarah.wilson@company.com', '+1234567893', 'QA Engineer', 4800.00, '2024-04-01', 'sample_face_encoding_4'),
('David Brown', 'david.brown@company.com', '+1234567894', 'DevOps Engineer', 5500.00, '2024-05-01', 'sample_face_encoding_5'),
('Emily Davis', 'emily.davis@company.com', '+1234567895', 'HR Manager', 5200.00, '2024-06-01', 'sample_face_encoding_6'),
('Robert Wilson', 'robert.wilson@company.com', '+1234567896', 'Accountant', 4800.00, '2024-07-01', 'sample_face_encoding_7'),
('Lisa Anderson', 'lisa.anderson@company.com', '+1234567897', 'Marketing Specialist', 4200.00, '2024-08-01', 'sample_face_encoding_8'),
('James Taylor', 'james.taylor@company.com', '+1234567898', 'Operations Manager', 5800.00, '2024-09-01', 'sample_face_encoding_9'),
('Maria Garcia', 'maria.garcia@company.com', '+1234567899', 'Administrative Assistant', 3800.00, '2024-10-01', 'sample_face_encoding_10');

-- =====================================================
-- INSERT SAMPLE ATTENDANCE RECORDS
-- =====================================================
INSERT INTO attendance (employee_id, date, check_in_time, check_out_time, status, face_verified) VALUES
-- Today's attendance
(1, CURDATE(), '09:00:00', '17:00:00', 'Present', TRUE),
(2, CURDATE(), '09:15:00', '17:30:00', 'Late', TRUE),
(3, CURDATE(), '08:45:00', '17:15:00', 'Present', TRUE),
(4, CURDATE(), '09:00:00', '13:00:00', 'Present', TRUE),
(5, CURDATE(), NULL, NULL, 'Absent', FALSE),
(6, CURDATE(), '08:55:00', '17:05:00', 'Present', TRUE),
(7, CURDATE(), '09:20:00', '17:20:00', 'Late', TRUE),
(8, CURDATE(), '09:05:00', '17:10:00', 'Present', TRUE),
(9, CURDATE(), '08:50:00', '17:25:00', 'Present', TRUE),
(10, CURDATE(), '09:10:00', '17:15:00', 'Late', TRUE);

-- =====================================================
-- INSERT SAMPLE SALARY RECORDS
-- =====================================================
INSERT INTO salary (employee_id, month, base_salary, net_salary) VALUES
(1, CONCAT(YEAR(CURDATE()), '-', LPAD(MONTH(CURDATE()), 2, '0')), 5000.00, 4833.33),
(2, CONCAT(YEAR(CURDATE()), '-', LPAD(MONTH(CURDATE()), 2, '0')), 6000.00, 5200.00),
(3, CONCAT(YEAR(CURDATE()), '-', LPAD(MONTH(CURDATE()), 2, '0')), 4500.00, 4350.00),
(4, CONCAT(YEAR(CURDATE()), '-', LPAD(MONTH(CURDATE()), 2, '0')), 4800.00, 4200.00),
(5, CONCAT(YEAR(CURDATE()), '-', LPAD(MONTH(CURDATE()), 2, '0')), 5500.00, 4250.00),
(6, CONCAT(YEAR(CURDATE()), '-', LPAD(MONTH(CURDATE()), 2, '0')), 5200.00, 5026.67),
(7, CONCAT(YEAR(CURDATE()), '-', LPAD(MONTH(CURDATE()), 2, '0')), 4800.00, 4160.00),
(8, CONCAT(YEAR(CURDATE()), '-', LPAD(MONTH(CURDATE()), 2, '0')), 4200.00, 4060.00),
(9, CONCAT(YEAR(CURDATE()), '-', LPAD(MONTH(CURDATE()), 2, '0')), 5800.00, 5606.67),
(10, CONCAT(YEAR(CURDATE()), '-', LPAD(MONTH(CURDATE()), 2, '0')), 3800.00, 3293.33);

-- =====================================================
-- CREATE VIEWS FOR COMMON QUERIES
-- =====================================================

-- View for employee attendance summary
CREATE OR REPLACE VIEW employee_attendance_summary AS
SELECT 
    e.id,
    e.name,
    e.email,
    e.position,
    e.salary,
    COUNT(a.id) as total_attendance_records,
    SUM(CASE WHEN a.status IN ('Present', 'Late', 'On Leave') THEN 1 ELSE 0 END) as present_days,
    SUM(CASE WHEN a.status = 'Absent' THEN 1 ELSE 0 END) as absent_days,
    SUM(CASE WHEN a.status = 'Late' THEN 1 ELSE 0 END) as late_days,
    SUM(COALESCE(a.check_out_time, '00:00:00') - COALESCE(a.check_in_time, '00:00:00')) as total_working_hours,
    ROUND(
        (SUM(CASE WHEN a.status IN ('Present', 'Late', 'On Leave') THEN 1 ELSE 0 END) / COUNT(a.id)) * 100, 2
    ) as attendance_percentage
FROM employees e
LEFT JOIN attendance a ON e.id = a.employee_id
WHERE e.is_active = 1
GROUP BY e.id, e.name, e.email, e.position, e.salary;

-- View for monthly attendance summary
CREATE OR REPLACE VIEW monthly_attendance_summary AS
SELECT 
    YEAR(a.date) as year,
    MONTH(a.date) as month,
    COUNT(DISTINCT a.employee_id) as total_employees,
    COUNT(a.id) as total_attendance_records,
    SUM(CASE WHEN a.status IN ('Present', 'Late', 'On Leave') THEN 1 ELSE 0 END) as present_days,
    SUM(CASE WHEN a.status = 'Absent' THEN 1 ELSE 0 END) as absent_days,
    SUM(CASE WHEN a.status = 'Late' THEN 1 ELSE 0 END) as late_days,
    SUM(COALESCE(a.check_out_time, '00:00:00') - COALESCE(a.check_in_time, '00:00:00')) as total_working_hours,
    ROUND(
        (SUM(CASE WHEN a.status IN ('Present', 'Late', 'On Leave') THEN 1 ELSE 0 END) / COUNT(a.id)) * 100, 2
    ) as attendance_percentage
FROM attendance a
GROUP BY YEAR(a.date), MONTH(a.date)
ORDER BY year DESC, month DESC;

-- View for today's attendance
CREATE OR REPLACE VIEW today_attendance AS
SELECT 
    a.id,
    a.employee_id,
    e.name as employee_name,
    e.email,
    e.position,
    a.date,
    a.check_in_time,
    a.check_out_time,
    a.status,
    a.face_verified
FROM attendance a
JOIN employees e ON a.employee_id = e.id
WHERE a.date = CURDATE()
ORDER BY a.check_in_time ASC;

-- =====================================================
-- CREATE STORED PROCEDURES
-- =====================================================

-- Procedure to calculate monthly salary
DELIMITER //
CREATE PROCEDURE CalculateMonthlySalary(
    IN p_employee_id INT,
    IN p_month VARCHAR(7)
)
BEGIN
    DECLARE v_base_salary DECIMAL(10,2);
    DECLARE v_total_working_hours DECIMAL(6,2);
    DECLARE v_net_salary DECIMAL(10,2);
    
    -- Get employee base salary
    SELECT salary INTO v_base_salary FROM employees WHERE id = p_employee_id;
    
    -- Get attendance statistics
    SELECT 
        SUM(COALESCE(check_out_time, '00:00:00') - COALESCE(check_in_time, '00:00:00')) as total_working_hours
    INTO v_total_working_hours
    FROM attendance 
    WHERE employee_id = p_employee_id 
    AND month = p_month;
    
    -- Calculate net salary
    SET v_net_salary = v_base_salary + (v_total_working_hours * 10); -- Assuming hourly rate of $10
    
    -- Insert or update salary record
    INSERT INTO salary (
        employee_id, month, base_salary, net_salary
    ) VALUES (
        p_employee_id, p_month, v_base_salary, v_net_salary
    ) ON DUPLICATE KEY UPDATE
        base_salary = v_base_salary,
        net_salary = v_net_salary,
        updated_at = CURRENT_TIMESTAMP;
        
    SELECT 'Salary calculated successfully' as message;
END //
DELIMITER ;

-- =====================================================
-- CREATE TRIGGERS
-- =====================================================

-- Trigger to update employee updated_at timestamp
DELIMITER //
CREATE TRIGGER update_employee_timestamp
BEFORE UPDATE ON employees
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END //
DELIMITER ;

-- Trigger to update attendance updated_at timestamp
DELIMITER //
CREATE TRIGGER update_attendance_timestamp
BEFORE UPDATE ON attendance
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END //
DELIMITER ;

-- Trigger to update salary updated_at timestamp
DELIMITER //
CREATE TRIGGER update_salary_timestamp
BEFORE UPDATE ON salary
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END //
DELIMITER ;

-- =====================================================
-- FINAL SETUP MESSAGES
-- =====================================================
SELECT 'Database setup completed successfully!' as status;
SELECT COUNT(*) as total_employees FROM employees;
SELECT COUNT(*) as total_attendance_records FROM attendance;
SELECT COUNT(*) as total_salary_records FROM salary;
SELECT COUNT(*) as total_settings FROM settings; 