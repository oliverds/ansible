export DEBIAN_FRONTEND=noninteractive

sed -i "s/#precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  100/" /etc/gai.conf
if [ -f /etc/needrestart/needrestart.conf ]; then
  # Ubuntu 22 has this set to (i)nteractive, but we want (a)utomatic.
  sed -i "s/^#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
fi

# Configure Swap Disk

if [ -f /swapfile ]; then
    echo "Swap exists."
else
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    echo "vm.swappiness=30" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
fi

# Upgrade The Base Packages

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get upgrade -y

# Add A Few PPAs To Stay Current

apt-get install -y --force-yes software-properties-common

# apt-add-repository ppa:fkrull/deadsnakes-python2.7 -y
# apt-add-repository ppa:nginx/mainline -y
# apt-add-repository ppa:ondrej/nginx -y
# apt-add-repository ppa:chris-lea/redis-server -y

apt-add-repository ppa:ondrej/php -y

# Update Package Lists

apt-get update
# Base Packages

add-apt-repository universe -y

apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --force-yes build-essential curl pkg-config fail2ban gcc g++ git libmcrypt4 libpcre3-dev \
make python3 python3-pip sendmail supervisor ufw zip unzip whois zsh ncdu uuid-runtime acl libpng-dev libmagickwand-dev libpcre2-dev cron jq net-tools

MKPASSWD_INSTALLED=$(type mkpasswd &> /dev/null)
if [ $? -ne 0 ]; then
  echo "Failed to install base dependencies."

  exit 1
fi

# Install Python Httpie

pip3 install httpie

# Install AWSCLI

pip3 install awscli awscli-plugin-endpoint

# Disable Password Authentication Over SSH

sed -i "/PasswordAuthentication yes/d" /etc/ssh/sshd_config
echo "" | sudo tee -a /etc/ssh/sshd_config
echo "" | sudo tee -a /etc/ssh/sshd_config
echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config

# Restart SSH

ssh-keygen -A
service ssh restart

# Set The Hostname If Necessary


echo "::hostname::" > /etc/hostname
sed -i 's/127\.0\.0\.1.*localhost/127.0.0.1 ::hostname::.localdomain ::hostname:: localhost/' /etc/hosts
hostname ::hostname::


# Set The Timezone

# ln -sf /usr/share/zoneinfo/UTC /etc/localtime
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Create The Root SSH Directory If Necessary

if [ ! -d /root/.ssh ]
then
  mkdir -p /root/.ssh
  touch /root/.ssh/authorized_keys
fi

# Check Permissions Of /root Directory

chown root:root /root
chown -R root:root /root/.ssh

chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# Setup Forge User

useradd forge
mkdir -p /home/forge/.ssh
mkdir -p /home/forge/.forge
adduser forge sudo

# Setup Bash For Forge User

chsh -s /bin/bash forge
cp /root/.profile /home/forge/.profile
cp /root/.bashrc /home/forge/.bashrc

# Set The Sudo Password For Forge

PASSWORD=$(mkpasswd -m sha-512 ::sudo_password::)
usermod --password $PASSWORD forge

# Authorize Forge's Unique Server Public Key

cat > /root/.ssh/authorized_keys << EOF
# MacBook PRO
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCxc126pJbPs5JbchsEpIW+ChxquLTEfybedxadqo3i4GVuSFHDentWtPZ0kWjBNWyCc9HnxSLnCOkuzfqmRTx3w8zR59+AuZ3YaWs5igx7qrFglvW7MwZ6do85BkWiNFNaMbPM43E9U73yCKWdpiJdiU15ivkdGD36I2NesLYTsjfGr8kvAUgcp80BSIKSb53yJvF08pw/Inge0i/5cCFq/qj9uG8VVQxh0285GczAxc727VfZ+QzfGUz6ZXcyNwkLKBIIzc/mDThs7ESWw87KdBanHH0ba9iagr3KlUEJuQXdFqepOM59TeM9eWlA40rjTNUtrFCNz4CbF49PQ4WL oliver@homestead
# iMac
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIlZwxGtyQz5lTt0vL6wR7lC47kmESJaGYa3A/o04tEL m@oliver.mx

EOF

cp /root/.ssh/authorized_keys /home/forge/.ssh/authorized_keys

# Create The Server SSH Key

ssh-keygen -f /home/forge/.ssh/id_rsa -t rsa -N ''

# Copy Source Control Public Keys Into Known Hosts File

ssh-keyscan -H github.com >> /home/forge/.ssh/known_hosts
ssh-keyscan -H bitbucket.org >> /home/forge/.ssh/known_hosts
ssh-keyscan -H gitlab.com >> /home/forge/.ssh/known_hosts

# Configure Git Settings

git config --global user.name "Oliver"
git config --global user.email "forge@oli.fastmail.com"

# Setup Forge Home Directory Permissions

chown -R forge:forge /home/forge
chmod -R 755 /home/forge
chmod 700 /home/forge/.ssh/id_rsa
chmod 600 /home/forge/.ssh/authorized_keys

# Setup UFW Firewall

ufw allow 22
ufw allow 80
ufw allow 443


ufw --force enable

# Allow FPM Restart

echo "forge ALL=NOPASSWD: /usr/sbin/service php8.2-fpm reload" > /etc/sudoers.d/php-fpm

# Allow Supervisor Reload

echo "forge ALL=NOPASSWD: /usr/bin/supervisorctl *" >> /etc/sudoers.d/supervisor

    #
# REQUIRES:
#       - server (the forge server instance)
#

# Install Base PHP Packages

apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --force-yes \
php8.2-fpm php8.2-cli php8.2-dev \
php8.2-pgsql php8.2-sqlite3 php8.2-gd php8.2-curl \
php8.2-imap php8.2-mysql php8.2-mbstring \
php8.2-xml php8.2-zip php8.2-bcmath php8.2-soap \
php8.2-intl php8.2-readline php8.2-gmp \
php8.2-redis php8.2-memcached php8.2-msgpack php8.2-igbinary php8.2-swoole

# Install Composer Package Manager

if [ ! -f /usr/local/bin/composer ]; then
  curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

echo "forge ALL=(root) NOPASSWD: /usr/local/bin/composer self-update*" > /etc/sudoers.d/composer
fi

# Misc. PHP CLI Configuration

sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/8.2/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/8.2/cli/php.ini
sudo sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/8.2/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/8.2/cli/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/8.2/cli/php.ini

# Misc. PHP FPM Configuration

sudo sed -i "s/display_errors = .*/display_errors = Off/" /etc/php/8.2/fpm/php.ini


# Ensure Imagick Is Available

echo "Configuring Imagick"

apt-get install -y --force-yes libmagickwand-dev
echo "extension=imagick.so" > /etc/php/8.2/mods-available/imagick.ini
yes '' | apt install php8.2-imagick


# Optimize FPM Processes

sed -i "s/^pm.max_children.*=.*/pm.max_children = 20/" /etc/php/8.2/fpm/pool.d/www.conf

# Ensure Sudoers Is Up To Date

LINE="ALL=NOPASSWD: /usr/sbin/service php8.2-fpm reload"
FILE="/etc/sudoers.d/php-fpm"
grep -q -- "^forge $LINE" "$FILE" || echo "forge $LINE" >> "$FILE"

# Configure Sessions Directory Permissions

chmod 733 /var/lib/php/sessions
chmod +t /var/lib/php/sessions

# Write Systemd File For Linode





    update-alternatives --set php /usr/bin/php8.2

# Install Caddy
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy

# Tweak Some PHP-FPM Settings

sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/8.2/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = Off/" /etc/php/8.2/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/8.2/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/8.2/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/8.2/fpm/php.ini

# Configure FPM Pool Settings

sed -i "s/^user = www-data/user = forge/" /etc/php/8.2/fpm/pool.d/www.conf
sed -i "s/^group = www-data/group = forge/" /etc/php/8.2/fpm/pool.d/www.conf
sed -i "s/;listen\.owner.*/listen.owner = forge/" /etc/php/8.2/fpm/pool.d/www.conf
sed -i "s/;listen\.group.*/listen.group = forge/" /etc/php/8.2/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/8.2/fpm/pool.d/www.conf
sed -i "s/;request_terminate_timeout.*/request_terminate_timeout = 60/" /etc/php/8.2/fpm/pool.d/www.conf


curl --silent --location https://deb.nodesource.com/setup_18.x | bash -

apt-get update

sudo apt-get install -y --force-yes nodejs

npm install -g pm2
npm install -g gulp
npm install -g yarn



# Install Litestream

wget https://github.com/benbjohnson/litestream/releases/download/v0.3.9/litestream-v0.3.9-linux-amd64.deb
dpkg -i litestream-v0.3.9-linux-amd64.deb
systemctl enable litestream
systemctl start litestream


# Configure Supervisor Autostart

systemctl enable supervisor.service
service supervisor start

# Disable protected_regular

sudo sed -i "s/fs.protected_regular = .*/fs.protected_regular = 0/" /usr/lib/sysctl.d/99-protect-links.conf

sysctl --system

# Setup Unattended Security Upgrades

apt-get install -y --force-yes unattended-upgrades

cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "Ubuntu jammy-security";
};
Unattended-Upgrade::Package-Blacklist {
    //
};
EOF

cat > /etc/apt/apt.conf.d/10periodic << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

touch /root/.forge-provisioned
