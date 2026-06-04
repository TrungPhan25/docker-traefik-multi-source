-- Grant quyền cho user laravel trên tất cả databases
GRANT ALL PRIVILEGES ON *.* TO 'laravel'@'%';
FLUSH PRIVILEGES;