# ─────────────────────────────────────────────────────────────────────────────
# Medusa monorepo — Docker & maintenance commands
#
# Quick start:
#   make up            # start the whole stack (postgres, redis, backend, store)
#   make logs          # follow all logs
#   make down          # stop everything (DATA IS KEPT)
#   make upgrade       # upgrade Medusa to the latest stable version
#
# Run `make` or `make help` to list every target.
# ─────────────────────────────────────────────────────────────────────────────

# Override on the command line, e.g.  make upgrade VERSION=2.17.1
VERSION ?=
EMAIL   ?= admin@medusa-test.com
PASSWORD ?= supersecret
BACKEND  := medusa_backend

.DEFAULT_GOAL := help
.PHONY: help up down restart build rebuild logs logs-backend logs-store ps \
        migrate seed admin shell upgrade clean reset

help: ## List all available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# ── Lifecycle ────────────────────────────────────────────────────────────────
up: ## Start the full stack in the background
	docker compose up -d

down: ## Stop & remove containers (named volumes / DB are KEPT)
	docker compose down

restart: ## Restart all running containers
	docker compose restart

build: ## Build images without starting
	docker compose build

rebuild: ## Rebuild images, recreate containers, renew node_modules volumes (keeps DB)
	docker compose up --build --force-recreate --renew-anon-volumes -d

# ── Observability ────────────────────────────────────────────────────────────
logs: ## Follow logs for all services
	docker compose logs -f

logs-backend: ## Follow backend (Medusa) logs only
	docker compose logs -f medusa

logs-store: ## Follow storefront logs only
	docker compose logs -f storefront

ps: ## Show container status
	docker compose ps

shell: ## Open a shell inside the backend container
	docker exec -it $(BACKEND) sh

# ── Database ─────────────────────────────────────────────────────────────────
migrate: ## Run Medusa DB migrations inside the backend container
	docker exec $(BACKEND) npx medusa db:migrate

seed: ## Seed the database (backend must be running)
	docker exec $(BACKEND) npm run seed

admin: ## Create an admin user:  make admin EMAIL=you@x.com PASSWORD=secret
	docker exec $(BACKEND) npx medusa user -e $(EMAIL) -p $(PASSWORD)

# ── Upgrade ──────────────────────────────────────────────────────────────────
# Bumps every core @medusajs/* package (the 2.x line) in both workspaces to a
# target version, refreshes the pnpm lockfile, then rebuilds the stack.
# Leaves packages on a different line (e.g. @medusajs/ui 4.x) untouched.
#   make upgrade              # latest stable (npm "latest" tag)
#   make upgrade VERSION=2.17.1
upgrade: ## Upgrade Medusa to VERSION (default: latest stable) + rebuild
	@V="$(VERSION)"; \
	if [ -z "$$V" ]; then echo "Resolving latest stable..."; V=$$(npm view @medusajs/medusa version); fi; \
	echo "==> Upgrading Medusa to $$V"; \
	for f in apps/backend/package.json apps/storefront/package.json; do \
	  echo "==> $$f"; \
	  node -e 'const fs=require("fs");const f=process.argv[1],t=process.argv[2];const p=JSON.parse(fs.readFileSync(f));for(const s of ["dependencies","devDependencies"]){const d=p[s]||{};for(const n of Object.keys(d)){if(n.startsWith("@medusajs/")&&/^\^?2\./.test(d[n])&&d[n]!==t){console.log("      "+n+": "+d[n]+" -> "+t);d[n]=t;}}}fs.writeFileSync(f,JSON.stringify(p,null,2)+"\n");' "$$f" "$$V"; \
	done; \
	echo "==> Refreshing lockfile (pnpm install)"; pnpm install; \
	echo "==> Rebuilding stack"; $(MAKE) rebuild; \
	echo "==> Done. Migrations run on boot — follow with: make logs-backend"

# ── Cleanup ──────────────────────────────────────────────────────────────────
clean: ## Stop containers and remove anonymous volumes (DB is KEPT)
	docker compose down --remove-orphans
	docker compose rm -fsv 2>/dev/null || true

reset: ## DANGER: stop everything and DELETE all volumes incl. the database
	docker compose down -v
