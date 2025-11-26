#!/usr/bin/env bash

# Install Chatwoot v4 alongside an existing deployment without conflicts.
# Default variables can be overridden via environment exports before running.

set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
  echo "[erro] execute este script como root" >&2
  exit 1
fi

APP_USER=${APP_USER:-chatwootv4}
APP_GROUP=${APP_GROUP:-$APP_USER}
APP_NAME=${APP_NAME:-chatwoot-v4}
APP_DIR=${APP_DIR:-/opt/chatwoot-v4}
RUBY_VERSION=${RUBY_VERSION:-3.4.4}
NODE_MAJOR=${NODE_MAJOR:-20}
CHATWOOT_REPO=${CHATWOOT_REPO:-https://github.com/chatwoot/chatwoot.git}
CHATWOOT_BRANCH=${CHATWOOT_BRANCH:-master}
ENV_FILE=${ENV_FILE:-$APP_DIR/.env.production}
WEB_SERVICE=${WEB_SERVICE:-$APP_NAME-web.service}
WORKER_SERVICE=${WORKER_SERVICE:-$APP_NAME-worker.service}
TARGET_SERVICE=${TARGET_SERVICE:-$APP_NAME.target}
APP_PORT=${APP_PORT:-4000}
DB_NAME=${DB_NAME:-chatwoot_v4}
DB_USER=${DB_USER:-chatwootv4}
DB_PASS=${DB_PASS:-$(openssl rand -hex 12)}
REDIS_DB=${REDIS_DB:-2}
APP_DOMAIN=${APP_DOMAIN:-chatwoot-v4.example.com}
RBENV_ROOT="/home/$APP_USER/.rbenv"

as_app_user() {
  sudo -u "$APP_USER" -H bash -lc "$1"
}

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends \
    ca-certificates curl git gnupg build-essential libssl-dev libreadline-dev zlib1g-dev \
    libpq-dev imagemagick postgresql postgresql-contrib redis-server \
    libyaml-dev libffi-dev libgdbm-dev libncurses5-dev libgmp-dev pkg-config
}

install_node() {
  if ! command -v node >/dev/null 2>&1 || [[ $(node -v | sed 's/^v//;s/\..*//') -ne $NODE_MAJOR ]]; then
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -
    apt-get install -y nodejs
  fi
  corepack enable
  corepack prepare pnpm@latest --activate
}

create_user_and_dir() {
  if ! id "$APP_USER" >/dev/null 2>&1; then
    adduser --system --group --home "/home/$APP_USER" "$APP_USER"
  fi
  mkdir -p "$APP_DIR"
  chown -R "$APP_USER:$APP_GROUP" "$APP_DIR"
}

setup_rbenv_and_ruby() {
  if [[ ! -d "$RBENV_ROOT" ]]; then
    as_app_user "git clone https://github.com/rbenv/rbenv.git '$RBENV_ROOT'"
    as_app_user "git clone https://github.com/rbenv/ruby-build.git '$RBENV_ROOT/plugins/ruby-build'"
  fi
  as_app_user "export RBENV_ROOT='$RBENV_ROOT'; export PATH='$RBENV_ROOT/bin:$PATH'; eval \"\$(rbenv init - bash)\"; rbenv install -s '$RUBY_VERSION'; rbenv global '$RUBY_VERSION'"
}

clone_repo() {
  if [[ ! -d "$APP_DIR/.git" ]]; then
    as_app_user "git clone --branch '$CHATWOOT_BRANCH' '$CHATWOOT_REPO' '$APP_DIR'"
  else
    as_app_user "cd '$APP_DIR' && git fetch --all && git checkout '$CHATWOOT_BRANCH' && git pull"
  fi
}

install_ruby_deps() {
  as_app_user "export RBENV_ROOT='$RBENV_ROOT'; export PATH='$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH'; eval \"\$(rbenv init - bash)\"; cd '$APP_DIR'; gem install bundler -v '~>2.5' --no-document; bundle config set deployment 'true'; bundle config set without 'development test'; bundle install"
}

install_js_deps() {
  as_app_user "cd '$APP_DIR'; pnpm install --frozen-lockfile"
}

prepare_env_file() {
  if [[ ! -f "$ENV_FILE" ]]; then
    cat <<EOF_ENV > "$ENV_FILE"
RAILS_ENV=production
NODE_ENV=production
PORT=$APP_PORT
FRONTEND_URL=https://$APP_DOMAIN
CW_HOST=https://$APP_DOMAIN
SECRET_KEY_BASE=
DATABASE_URL=postgres://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME
REDIS_URL=redis://localhost:6379/$REDIS_DB
REDIS_NAMESPACE=${APP_NAME//-/_}
RAILS_LOG_TO_STDOUT=true
MAILER_SENDER=Chatwoot <$APP_NAME@$APP_DOMAIN>
EOF_ENV
    chown "$APP_USER:$APP_GROUP" "$ENV_FILE"
  fi
}

prepare_database() {
  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    sudo -u postgres psql -c "CREATE ROLE \"$DB_USER\" WITH LOGIN PASSWORD '$DB_PASS';"
  fi
  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
    sudo -u postgres psql -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
  fi
}

populate_secret_and_assets() {
  as_app_user "export RBENV_ROOT='$RBENV_ROOT'; export PATH='$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH'; eval \"\$(rbenv init - bash)\"; cd '$APP_DIR'; set -a; source '$ENV_FILE'; set +a; if [[ -z \"$SECRET_KEY_BASE\" ]]; then SECRET_KEY_BASE=$(bundle exec rails secret); perl -pi -e 's/^SECRET_KEY_BASE=.*/SECRET_KEY_BASE='\"\$SECRET_KEY_BASE\"'/' '$ENV_FILE'; fi; bundle exec rails db:prepare; bundle exec rails assets:precompile"
}

install_systemd_units() {
  local path_exports="RBENV_ROOT=$RBENV_ROOT PATH=$RBENV_ROOT/bin:$RBENV_ROOT/shims:/usr/local/bin:/usr/bin"
  cat <<EOF_SERVICE > "/etc/systemd/system/$WEB_SERVICE"
[Unit]
Description=Chatwoot v4 web (${APP_NAME})
After=network.target
PartOf=$TARGET_SERVICE

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_DIR
Environment=$path_exports
EnvironmentFile=$ENV_FILE
ExecStart=/bin/bash -lc 'export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"; eval "$(rbenv init - bash)"; bundle exec puma -C config/puma.rb'
Restart=always

[Install]
WantedBy=$TARGET_SERVICE
EOF_SERVICE

  cat <<EOF_SERVICE > "/etc/systemd/system/$WORKER_SERVICE"
[Unit]
Description=Chatwoot v4 worker (${APP_NAME})
After=network.target redis-server.service
PartOf=$TARGET_SERVICE

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_DIR
Environment=$path_exports
EnvironmentFile=$ENV_FILE
ExecStart=/bin/bash -lc 'export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"; eval "$(rbenv init - bash)"; bundle exec sidekiq -C config/sidekiq.yml'
Restart=always

[Install]
WantedBy=$TARGET_SERVICE
EOF_SERVICE

  cat <<EOF_TARGET > "/etc/systemd/system/$TARGET_SERVICE"
[Unit]
Description=Chatwoot v4 stack (${APP_NAME})
Requires=$WEB_SERVICE $WORKER_SERVICE
EOF_TARGET

  systemctl daemon-reload
  systemctl enable --now "$TARGET_SERVICE"
}

install_packages
install_node
create_user_and_dir
clone_repo
setup_rbenv_and_ruby
install_ruby_deps
install_js_deps
prepare_env_file
prepare_database
populate_secret_and_assets
install_systemd_units

echo "Instalação concluída. Ajuste $ENV_FILE conforme necessário e verifique os serviços: $TARGET_SERVICE"
