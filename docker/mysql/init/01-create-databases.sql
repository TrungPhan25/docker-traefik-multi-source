-- Tạo database riêng cho mỗi project
CREATE DATABASE IF NOT EXISTS `project_a_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `project_b_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant quyền cho user laravel
GRANT ALL PRIVILEGES ON `project_a_db`.* TO 'laravel'@'%';
GRANT ALL PRIVILEGES ON `project_b_db`.* TO 'laravel'@'%';
FLUSH PRIVILEGES;