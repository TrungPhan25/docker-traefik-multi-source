# Traefik Multi-Source Template

Docker Compose template để chạy nhiều dự án PHP/Laravel trên cùng một máy, sử dụng **Traefik** làm reverse proxy. Mỗi project có domain riêng, Dockerfile riêng, và database riêng.

---

## Kiến trúc tổng quan

```
┌──────────────────────────────────────────────────┐
│                   Traefik v3.1                   │
│            (Reverse Proxy :80)                   │
│            Dashboard :8080                       │
├──────────────┬───────────────┬───────────────────┤
│              │               │                   │
│  project-a   │  project-b    │  pma.localhost     │
│  .localhost   │  .localhost   │  (phpMyAdmin)     │
│  ┌─────────┐ │  ┌─────────┐ │                   │
│  │ nginx-a │ │  │ nginx-b │ │                   │
│  │ app-a   │ │  │ app-b   │ │                   │
│  │(PHP 8.3)│ │  │(PHP 8.3)│ │                   │
│  └─────────┘ │  └─────────┘ │                   │
│              │               │                   │
│         ┌────────────────┐                       │
│         │   MySQL 8.0    │                       │
│         │  (shared DB)   │                       │
│         └────────────────┘                       │
└──────────────────────────────────────────────────┘
```

### Cấu trúc thư mục

```
traefik-multi-source/
├── docker-compose.yml          # Định nghĩa tất cả services
├── .env.example                # Biến môi trường mẫu
├── .gitignore
├── scripts/
│   └── gen-certs.sh            # Script tạo SSL cert local
├── docker/
│   ├── traefik/
│   │   ├── domains.txt         # Danh sách domain cần SSL
│   │   ├── tls.yml             # TLS config cho Traefik
│   │   └── certs/              # Cert được tạo bởi mkcert (git-ignored)
│   │       ├── local.crt
│   │       └── local.key
│   ├── mysql/
│   │   └── init/
│   │       └── 01-create-databases.sql   # Tạo DB cho mỗi project
│   ├── project-a/
│   │   ├── Dockerfile                    # PHP-FPM image config
│   │   ├── default.conf                  # Nginx config (git-ignored)
│   │   └── default.conf.example          # Nginx config mẫu
│   └── project-b/
│       ├── Dockerfile
│       ├── default.conf                  # (git-ignored)
│       └── default.conf.example
└── httpdocs/
    ├── project-a/              # Source code project A (git-ignored)
    └── project-b/              # Source code project B (git-ignored)
```

---

## Yêu cầu

- Docker & Docker Compose (v2+)
- Các domain `*.localhost` tự động resolve về `127.0.0.1` trên hầu hết OS
- [mkcert](https://github.com/FiloSottile/mkcert) để tạo SSL cert local (cài 1 lần)
  ```bash
  brew install mkcert
  mkcert -install
  ```

---

## Cài đặt ban đầu

```bash
# 1. Clone repository
git clone <repo-url>
cd traefik-multi-source

# 2. Tạo file .env từ mẫu
cp .env.example .env

# 3. Tạo nginx config cho các project có sẵn
cp docker/project-a/default.conf.example docker/project-a/default.conf
cp docker/project-b/default.conf.example docker/project-b/default.conf

# 4. Đặt source code vào httpdocs/
# (clone hoặc copy Laravel project vào)
git clone <project-a-repo> httpdocs/project-a
git clone <project-b-repo> httpdocs/project-b

# 5. Tạo SSL cert local
chmod +x scripts/gen-certs.sh
./scripts/gen-certs.sh

# 6. Thêm domain vào /etc/hosts
sudo sh -c 'echo "127.0.0.1 toby.vn traefik.toby.local pma.localhost" >> /etc/hosts'

# 7. Khởi chạy hạ tầng (Traefik + MySQL + phpMyAdmin)
docker compose --profile infra up -d

# 8. Khởi chạy project cần dùng
docker compose --profile project-a up -d
docker compose --profile project-b up -d
```

---

## Profiles - Cách quản lý services

Template sử dụng **Docker Compose Profiles** để chọn services cần chạy:

| Profile     | Services                   | Mô tả          |
| ----------- | -------------------------- | -------------- |
| `infra`     | traefik, mysql, phpmyadmin | Hạ tầng chung  |
| `project-a` | app-a, nginx-a, mysql      | Project A + DB |
| `project-b` | app-b, nginx-b, mysql      | Project B + DB |

```bash
# Chạy chỉ hạ tầng
docker compose --profile infra up -d

# Chạy 1 project cụ thể (mysql sẽ tự start vì thuộc profile này)
docker compose --profile project-a up -d

# Chạy tất cả
docker compose --profile infra --profile project-a --profile project-b up -d
```

---

## Truy cập

| Service           | URL                          |
| ----------------- | ---------------------------- |
| Project A         | https://toby.vn              |
| Project B         | https://project-b.localhost  |
| phpMyAdmin        | https://pma.localhost        |
| Traefik Dashboard | https://traefik.toby.local   |

> HTTP (`http://`) sẽ tự động redirect sang HTTPS.

---

## Hướng dẫn thêm project mới (ví dụ: `toby.vn`)

### Bước 1: Tạo Dockerfile

Tạo file `docker/toby/Dockerfile`:

```dockerfile
FROM php:8.3-fpm

# System dependencies
RUN apt-get update && apt-get install -y \
    git curl zip unzip libpng-dev libonig-dev libxml2-dev libzip-dev \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Node.js (nếu cần build frontend)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

RUN groupadd -g 1000 www && useradd -u 1000 -ms /bin/bash -g www www
USER www

EXPOSE 9000
CMD ["php-fpm"]
```

### Bước 2: Tạo Nginx config

Tạo file `docker/toby/default.conf.example` và copy thành `default.conf`:

```nginx
server {
    listen 80;
    server_name toby.localhost;
    root /var/www/html/toby/public;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass app-toby:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

> **Lưu ý về routing**: Domain được cấu hình ở **2 nơi**:
>
> - **`default.conf`**: `server_name` và `root` path
> - **`docker-compose.yml`**: Traefik label `traefik.http.routers.<name>.rule=Host(...)`

### Bước 3: Thêm services vào `docker-compose.yml`

Thêm vào trước section `networks`:

```yaml
# ============================================
# TOBY - PHP 8.3
# ============================================
app-toby:
  build:
    context: .
    dockerfile: docker/toby/Dockerfile
  container_name: app-toby
  profiles: ["toby"]
  volumes:
    - ./httpdocs:/var/www/html
  working_dir: /var/www/html
  depends_on:
    mysql:
      condition: service_healthy
  networks:
    - app-network

nginx-toby:
  image: nginx:alpine
  container_name: nginx-toby
  profiles: ["toby"]
  volumes:
    - ./httpdocs:/var/www/html
    - ./docker/toby/default.conf:/etc/nginx/conf.d/default.conf
  depends_on:
    - app-toby
  networks:
    - app-network
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.toby.rule=Host(`toby.localhost`)"
    - "traefik.http.routers.toby.entrypoints=web"
    - "traefik.http.services.toby-svc.loadbalancer.server.port=80"
```

> **Dùng domain thật (vd: `toby.vn`)**:
>
> - Đổi `Host(\`toby.localhost\`)`thành`Host(\`toby.vn\`)`
> - Đổi `server_name` trong `default.conf` thành `toby.vn`
> - Trỏ DNS hoặc thêm vào `/etc/hosts`: `127.0.0.1 toby.vn`

### Bước 4: Thêm database

Cập nhật `docker/mysql/init/01-create-databases.sql`:

```sql
CREATE DATABASE IF NOT EXISTS `toby_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON `toby_db`.* TO 'laravel'@'%';
FLUSH PRIVILEGES;
```

> **Lưu ý**: File init chỉ chạy lần đầu khi MySQL volume chưa tồn tại. Nếu đã có data, cần tạo DB thủ công:
>
> ```bash
> docker exec -it mysql mysql -uroot -prootsecret -e "CREATE DATABASE IF NOT EXISTS toby_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; GRANT ALL PRIVILEGES ON toby_db.* TO 'laravel'@'%'; FLUSH PRIVILEGES;"
> ```

### Bước 5: Thêm profile `mysql` và cập nhật `.gitignore`

Thêm `"toby"` vào `profiles` của service `mysql` trong `docker-compose.yml`:

```yaml
mysql:
  profiles: ["infra", "project-a", "project-b", "toby"]
```

Thêm vào `.gitignore`:

```
httpdocs/toby/
```

### Bước 6: Đặt source code và khởi chạy

```bash
# Clone source
git clone <toby-repo> httpdocs/toby

# Copy nginx config
cp docker/toby/default.conf.example docker/toby/default.conf

# Khởi chạy
docker compose --profile infra --profile toby up -d --build

# Truy cập
# http://toby.localhost (hoặc http://toby.vn nếu dùng domain thật)
```

---

## Các lệnh thường dùng

### Khởi chạy / Dừng

```bash
# Khởi chạy hạ tầng
docker compose --profile infra up -d

# Khởi chạy project cụ thể
docker compose --profile project-a up -d

# Khởi chạy tất cả
docker compose --profile infra --profile project-a --profile project-b up -d

# Dừng tất cả
docker compose --profile infra --profile project-a --profile project-b down

# Dừng 1 project (không ảnh hưởng infra)
docker compose --profile project-a down
```

### Khi cập nhật `Dockerfile`

```bash
# Rebuild image và restart container
docker compose --profile project-a up -d --build

# Rebuild không dùng cache (khi cần cài lại tất cả)
docker compose --profile project-a build --no-cache
docker compose --profile project-a up -d
```

### Khi cập nhật `default.conf` (Nginx config)

```bash
# Chỉ cần restart nginx container (config được mount volume)
docker compose restart nginx-a

# Hoặc restart cụ thể
docker restart nginx-a
```

### Khi đổi domain / route (Traefik label)

Traefik đọc labels lúc container **khởi động**, nên phải recreate container sau khi đổi.

**Ví dụ: đổi domain từ `project-a.localhost` → `toby.vn`**

Bước 1 — Đổi trong `docker-compose.yml`:
```yaml
- "traefik.http.routers.project-a.rule=Host(`toby.vn`)"
```

Bước 2 — Đổi `server_name` trong `docker/project-a/default.conf`:
```nginx
server_name toby.vn;
```

Bước 3 — Thêm domain vào `/etc/hosts` (nếu không dùng DNS thật):
```bash
sudo sh -c 'echo "127.0.0.1 toby.vn" >> /etc/hosts'
```

Bước 4 — Recreate container để Traefik nhận label mới:
```bash
docker compose --profile project-a up -d --force-recreate
```

Bước 5 — Kiểm tra Traefik đã nhận route mới chưa:
```bash
# Xem trên dashboard
open http://localhost:8080

# Hoặc qua API
curl -s http://localhost:8080/api/http/routers | python3 -m json.tool | grep -A3 "project-a"
```

### Khi cập nhật `docker-compose.yml`

```bash
# Recreate containers với config mới
docker compose --profile project-a up -d --force-recreate

# Nếu thêm service mới, cần build
docker compose --profile <new-profile> up -d --build
```

### Khi cập nhật `01-create-databases.sql`

```bash
# File init chỉ chạy khi tạo volume mới. Nếu đã có data:

# Cách 1: Tạo DB thủ công
docker exec -it mysql mysql -uroot -prootsecret -e "CREATE DATABASE IF NOT EXISTS new_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Cách 2: Xóa volume và khởi tạo lại (MẤT TOÀN BỘ DATA!)
docker compose --profile infra down
docker volume rm traefik-multi-source_mysql_data
docker compose --profile infra up -d
```

### Chạy lệnh trong container

```bash
# Chạy composer install trong project
docker exec -it app-a composer install --working-dir=/var/www/html/project-a

# Chạy artisan
docker exec -it app-a php /var/www/html/project-a/artisan migrate

# Chạy npm
docker exec -it app-a npm install --prefix /var/www/html/project-a
docker exec -it app-a npm run build --prefix /var/www/html/project-a

# Vào shell container
docker exec -it app-a bash
```

### Xem logs

```bash
# Xem log tất cả services
docker compose --profile project-a logs -f

# Xem log 1 container
docker logs -f nginx-a
docker logs -f app-a

# Xem log Traefik
docker logs -f traefik
```

### Debug & Kiểm tra

```bash
# Kiểm tra containers đang chạy
docker compose ps

# Kiểm tra Traefik đã nhận route chưa
# Truy cập http://localhost:8080 hoặc:
curl http://localhost:8080/api/http/routers | jq

# Test kết nối từ container
docker exec -it app-a ping mysql
docker exec -it nginx-a curl -I http://localhost
```

---

## Biến môi trường (`.env`)

| Biến             | Mặc định   | Mô tả                      |
| ---------------- | ---------- | -------------------------- |
| DB_ROOT_PASSWORD | rootsecret | Mật khẩu root MySQL        |
| DB_USER          | laravel    | User MySQL cho các project |
| DB_PASSWORD      | secret     | Mật khẩu user MySQL        |

Trong mỗi Laravel project (`httpdocs/<project>/.env`), cấu hình DB:

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=project_a_db
DB_USERNAME=laravel
DB_PASSWORD=secret
```

> **Lưu ý**: `DB_HOST=mysql` (tên container, không phải `localhost` hay `127.0.0.1`)

---

## HTTPS Local

Template sử dụng **mkcert** để tạo SSL cert được trust hoàn toàn trên máy local (không có cảnh báo trình duyệt).

### Cấu trúc HTTPS

```
mkcert -install       ← Cài CA vào hệ thống (1 lần duy nhất)
       │
       ▼
docker/traefik/domains.txt   ← Danh sách domain cần SSL
       │
       ▼
scripts/gen-certs.sh  ← Tạo cert từ danh sách domain
       │
       ▼
docker/traefik/certs/ ← Cert được mount vào Traefik
       │
       ▼
Traefik phục vụ HTTPS cho tất cả services
```

### Quản lý domains SSL

Danh sách domain được lưu trong `docker/traefik/domains.txt`. Hỗ trợ **wildcard** để không phải thêm từng subdomain:

```
toby.vn
*.toby.local
*.localhost
```

Với cấu hình này, mọi subdomain của `*.toby.local` và `*.localhost` đều được HTTPS tự động mà **không cần tạo lại cert**.

### Khi thêm domain mới

```bash
# 1. Thêm domain vào domains.txt (nếu không cover bởi wildcard)
echo "newdomain.com" >> docker/traefik/domains.txt

# 2. Thêm vào /etc/hosts (nếu không dùng DNS thật)
sudo sh -c 'echo "127.0.0.1 newdomain.com" >> /etc/hosts'

# 3. Tạo lại cert và restart Traefik
./scripts/gen-certs.sh
```

> Nếu domain đã được cover bởi wildcard (vd: `blog.toby.local` cover bởi `*.toby.local`), chỉ cần bước 2 và thêm service vào `docker-compose.yml`.

### script gen-certs.sh

```bash
# Tạo cert từ danh sách trong domains.txt
./scripts/gen-certs.sh
```

Script tự động:
- Đọc danh sách domain từ `docker/traefik/domains.txt`
- Chạy `mkcert` để tạo cert
- Restart Traefik để load cert mới

---

## Lưu ý quan trọng

- Source code trong `httpdocs/` **không** được đưa lên git (mỗi project có repo riêng)
- File `.env` chứa thông tin nhạy cảm, chỉ có `.env.example` được commit
- File `default.conf` bị git-ignore, chỉ commit `default.conf.example`
- File `docker/traefik/certs/` bị git-ignore, chỉ commit `domains.txt` và `tls.yml`
- Tất cả project dùng chung volume `./httpdocs` → mỗi project là 1 subfolder
- Traefik dashboard truy cập qua `https://traefik.toby.local` (không expose port 8080)
- MySQL init script (`01-create-databases.sql`) chỉ chạy lần đầu khi volume chưa tồn tại
- Khi dùng domain thật (không phải `*.localhost`), cần cấu hình DNS hoặc `/etc/hosts`
- `mkcert -install` phải chạy **1 lần trên mỗi máy** để trình duyệt trust cert local
