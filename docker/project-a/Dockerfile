FROM php:8.3-fpm

# System dependencies
RUN apt-get update && apt-get install -y \
    git curl zip unzip libpng-dev libonig-dev libxml2-dev libzip-dev \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Node.js & npm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Xdebug
RUN pecl install xdebug && docker-php-ext-enable xdebug

# Working directory
WORKDIR /var/www/html

# User permission
RUN groupadd -g 1000 www && useradd -u 1000 -ms /bin/bash -g www www
USER www

EXPOSE 9000
CMD ["php-fpm"]