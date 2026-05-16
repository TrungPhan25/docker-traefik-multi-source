# Traefik Multi-Source Template

Docker Compose template để chạy nhiều dự án PHP/Laravel trên cùng một máy, sử dụng **Traefik** làm reverse proxy.

## Kiến trúc

```
┌─────────────────────────────────────────────┐
│                  Traefik                    │
│          (Reverse Proxy :80)               │
│          Dashboard :8080                    │
├──────────────┬──────────────────────────────┤
│              │                              │
│  project-a.localhost    project-b.localhost  │
│  ┌─────────────────┐   ┌─────────────────┐ │
│  │    nginx-a       │   │    nginx-b       │ │
│  │    app-a (8.2)   │   │    app-b (8.3)   │ │
│  └─────────────────┘   └─────────────────┘ │
│              │                              │
│         ┌────────────┐                      │
│         │   MySQL 8   │                     │
│         └────────────┘                      │
│         pma.localhost                       │
└─────────────────────────────────────────────┘
```

## Yêu cầu

- Docker & Docker Compose

## Cài đặt

1. Clone repository:
   ```bash
   git clone <repo-url>
   cd traefik-multi-source
   ```

2. Tạo file `.env`:
   ```bash
   cp .env.example .env
   ```

3. Clone/đặt source code các project vào:
   ```
   httpdocs/project-a/   # Laravel project (PHP 8.2)
   httpdocs/project-b/   # Laravel project (PHP 8.3)
   ```

4. Khởi chạy:
   ```bash
   docker compose up -d
   ```

## Truy cập

| Service     | URL                          |
|-------------|------------------------------|
| Project A   | http://project-a.localhost    |
| Project B   | http://project-b.localhost    |
| phpMyAdmin  | http://pma.localhost          |
| Traefik     | http://localhost:8080         |

## Thêm project mới

1. Tạo `docker/project-c/Dockerfile` và `docker/project-c/default.conf`
2. Thêm service `app-c` và `nginx-c` vào `docker-compose.yml`
3. Đặt source code vào `httpdocs/project-c/`
4. Cập nhật `.gitignore` để ignore `httpdocs/project-c/`

## Lưu ý

- Source code trong `httpdocs/` **không** được đưa lên git (mỗi project có repo riêng).
- File `.env` chứa thông tin nhạy cảm, chỉ có `.env.example` được commit.
