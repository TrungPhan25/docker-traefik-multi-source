FROM php:8.4-fpm

# ─── System deps + PHP extensions (dev) ─────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl zip unzip vim \
        libpng-dev libonig-dev libxml2-dev libzip-dev libicu-dev \
    && docker-php-ext-install \
        pdo_mysql mbstring exif pcntl bcmath gd zip intl \
    && pecl install redis && docker-php-ext-enable redis \
    && pecl install xdebug && docker-php-ext-enable xdebug \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ─── Composer ──────────────────────────────────────────
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# ─── Node.js 20 (cho Vite/Mix dev) ─────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ─── Xdebug config (dev) ───────────────────────────────
# client_host = host.docker.internal → trỏ về Ubuntu host (cần extra_hosts trong compose)
# VSCode PHP Debug extension listen port 9003 trên Windows → forward qua SSH
RUN { \
        echo "xdebug.mode=develop,debug"; \
        echo "xdebug.start_with_request=trigger"; \
        echo "xdebug.client_host=host.docker.internal"; \
        echo "xdebug.client_port=9003"; \
        echo "xdebug.log=/tmp/xdebug.log"; \
        echo "xdebug.idekey=VSCODE"; \
    } > /usr/local/etc/php/conf.d/xdebug.ini

# ─── PHP dev settings ──────────────────────────────────
RUN { \
        echo "display_errors=On"; \
        echo "display_startup_errors=On"; \
        echo "error_reporting=E_ALL"; \
        echo "memory_limit=512M"; \
        echo "upload_max_filesize=64M"; \
        echo "post_max_size=64M"; \
        echo "opcache.enable=1"; \
        echo "opcache.validate_timestamps=1"; \
        echo "opcache.revalidate_freq=0"; \
    } > /usr/local/etc/php/conf.d/zz-dev.ini

# ─── Non-root user, UID/GID khớp user Ubuntu ──────────
# Build: docker compose build --build-arg UID=$(id -u) --build-arg GID=$(id -g)
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} www \
 && useradd -u ${UID} -ms /bin/bash -g www www

WORKDIR /var/www/src

# KHÔNG COPY source — sẽ bind mount từ Ubuntu host vào lúc runtime.
# Tạo sẵn thư mục để chown đúng owner; bind mount sẽ overlay lên sau.
RUN mkdir -p storage bootstrap/cache \
 && chown -R www:www /var/www/src
USER www

EXPOSE 9000
CMD ["php-fpm"]
