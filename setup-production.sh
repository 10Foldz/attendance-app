#!/bin/bash

echo "Starting production setup..."

# Create .env from .env.example if it doesn't exist
if [ ! -f .env ]; then
    echo ".env file not found. Creating from .env.example..."
    cp .env.example .env
    # Remove any existing DB settings (commented or not)
    sed -i '/^#\?DB_CONNECTION=/d' .env
    sed -i '/^#\?DB_HOST=/d' .env
    sed -i '/^#\?DB_PORT=/d' .env
    sed -i '/^#\?DB_DATABASE=/d' .env
    sed -i '/^#\?DB_USERNAME=/d' .env
    sed -i '/^#\?DB_PASSWORD=/d' .env
    # Add correct DB settings at the end
    echo "DB_CONNECTION=mysql" >> .env
    echo "DB_HOST=${DB_HOST}" >> .env
    echo "DB_PORT=${DB_PORT}" >> .env
    echo "DB_DATABASE=${DB_DATABASE}" >> .env
    echo "DB_USERNAME=${DB_USERNAME}" >> .env
    echo "DB_PASSWORD=${DB_PASSWORD}" >> .env
    # Add CALENDARIFIC_API_KEY if not present
    if ! grep -q '^CALENDARIFIC_API_KEY=' .env; then
        echo -e "\nCALENDARIFIC_API_KEY=${CALENDARIFIC_API_KEY}" >> .env
    fi
    echo ".env file created and configured."
fi

# Check PHP version
echo "Checking PHP version..."
php_version=$(php -r "echo PHP_VERSION_ID;")
if [ "$php_version" -lt 80200 ]; then
    echo "Error: PHP 8.2 or higher is required. Current version: $(php -r 'echo PHP_VERSION;')"
    exit 1
fi

# Check required PHP extensions
echo "Checking required PHP extensions..."
required_extensions=("pdo" "pdo_mysql" "mbstring" "xml" "zip" "gd" "curl")
for ext in "${required_extensions[@]}"; do
    if ! php -m | grep -q "$ext"; then
        echo "Error: PHP extension '$ext' is not installed or enabled."
        exit 1
    fi
done

echo "Installing Composer dependencies..."
composer install --no-dev --optimize-autoloader

echo "Generating application key..."
php artisan key:generate

echo "Running database migrations..."
php artisan migrate --force

echo "Optimizing Laravel..."
php artisan optimize
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Install and build frontend assets
if [ -f package.json ]; then
    echo "Installing NPM dependencies..."
    npm install --production

    echo "Building frontend assets..."
    npm run build
fi

# Set up scheduled task for holidays:fetch
echo "Setting up scheduled task for holidays:fetch..."
echo "0 0 1 1 * php /var/www/html/artisan holidays:fetch \$(date +%Y)" >> /etc/crontab 