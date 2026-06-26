#!/bin/sh
cd /server/apps/backend

echo "Running database migrations (auto-runs the seed in src/migration-scripts on first run)..."
npx medusa db:migrate

echo "Starting Medusa development server..."
npm run dev