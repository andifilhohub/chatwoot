# Executando o Chatwoot v4 em paralelo a outra instalação

Este guia descreve como instalar esta versão do Chatwoot em um servidor que já possui outra instância em produção, evitando conflitos de diretório, dependências e serviços. A árvore usa Ruby 3.4.4 (veja `.ruby-version`), portanto mantenha as instalações separadas da instância existente que roda Ruby 3.3.3.

## 1. Preparar usuário e diretório dedicados
1. Crie um usuário e grupo exclusivos para a nova instância, por exemplo `chatwootv4`.
2. Crie um diretório distinto, como `/opt/chatwoot-v4`, e conceda propriedade ao novo usuário (`chown chatwootv4:chatwootv4 /opt/chatwoot-v4`).
3. Faça o clone do repositório dentro desse diretório usando o usuário dedicado para impedir que permissões e arquivos se misturem com a instalação antiga.

### Script de instalação automatizada
Para simplificar, um script prepara diretório, Ruby 3.4.4, dependências, banco/Redis e serviços systemd isolados (nomes e portas diferentes da instância antiga).

```bash
wget https://raw.githubusercontent.com/chatwoot/chatwoot/master/deployment/install_chatwoot_v4.sh
chmod +x deployment/install_chatwoot_v4.sh
APP_USER=chatwootv4 APP_DIR=/opt/chatwoot-v4 APP_PORT=4000 sudo ./deployment/install_chatwoot_v4.sh
```

Variáveis úteis: `APP_NAME` (prefixos de serviços systemd), `WEB_SERVICE`/`WORKER_SERVICE`/`TARGET_SERVICE`, `DB_NAME`/`DB_USER`/`DB_PASS`, `REDIS_DB`, `APP_DOMAIN`, `CHATWOOT_BRANCH` e `ENV_FILE`. Ajuste a porta (`APP_PORT`) e o domínio para não colidirem com a instância existente.

## 2. Instalar Ruby 3.4.4 isoladamente
1. Instale Ruby 3.4.4 usando o gerenciador da sua preferência (rbenv/ruby-build ou RVM) sem remover a versão 3.3.3 já instalada.
2. Certifique-se de que o PATH do novo usuário aponte para a árvore Ruby 3.4.4 antes de executar `bundle install`.
3. No diretório `/opt/chatwoot-v4`, instale as dependências com `bundle install --deployment` e `pnpm install --frozen-lockfile`, mantendo os artefatos de cada instância separados.

## 3. Configurar variáveis de ambiente próprias
1. Copie seu arquivo `.env` de produção para `/opt/chatwoot-v4` (por exemplo, `.env.production.local`).
2. Utilize nomes distintos para banco de dados, namespaces de Redis e portas de serviços (PORT, SIDEKIQ_CONCURRENCY, REDIS_NAMESPACE etc.) para que filas e bancos não se choquem com a instância antiga.
3. Ajuste qualquer integração externa (domínios de webhook, SMTP, provedores de login) para apontar para os novos domínios/ports da instância v4.

## 4. Duplicar e renomear unidades systemd
Os arquivos de serviço padrão usam o usuário `chatwoot`, o diretório `/home/chatwoot/chatwoot` e nomes de unidade `chatwoot-web.1.service`, `chatwoot-worker.1.service` e `chatwoot.target`. Para rodar em paralelo:

1. Copie os arquivos de `deployment/` para `/etc/systemd/system/` com novos nomes, por exemplo `chatwoot-v4-web.service`, `chatwoot-v4-worker.service` e `chatwoot-v4.target`.
2. Edite cada arquivo copiado e altere:
   - `User=` para o usuário dedicado (ex.: `chatwootv4`).
   - `WorkingDirectory=` para `/opt/chatwoot-v4`.
   - Variáveis `PATH`, `GEM_HOME` e `GEM_PATH` para apontarem para o Ruby 3.4.4 do novo usuário.
   - Em `PartOf=` e `Wants=`, substitua os nomes originais pelas novas unidades (`chatwoot-v4-web.service`, `chatwoot-v4-worker.service`).
3. Execute `systemctl daemon-reload` e habilite a unidade-alvo: `systemctl enable --now chatwoot-v4.target`.

## 5. Configurar proxy reverso separado
1. Copie `deployment/nginx_chatwoot.conf` para `/etc/nginx/sites-available/chatwoot-v4.conf`.
2. Ajuste `server_name`, upstream e caminhos raiz para apontarem para a porta e o diretório usados pela instância v4.
3. Habilite o novo site (`ln -s /etc/nginx/sites-available/chatwoot-v4.conf /etc/nginx/sites-enabled/`) e reabra o Nginx (`systemctl reload nginx`).

Seguindo estes passos, você mantém as duas versões isoladas em diretórios, serviços e dependências diferentes, evitando qualquer conflito entre a instalação existente e a nova implantação em produção.
