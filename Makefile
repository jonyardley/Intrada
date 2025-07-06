# Appwrite Environment Management
.PHONY: help setup teardown start stop logs clean test verify setup-crux

# Default target
help:
	@echo "Appwrite Environment Management"
	@echo ""
	@echo "Available commands:"
	@echo "  setup     - Complete setup from scratch (teardown + start + configure)"
	@echo "  teardown  - Completely remove all containers, volumes, and config"
	@echo "  start     - Start Appwrite services"
	@echo "  stop      - Stop Appwrite services"
	@echo "  logs      - View Appwrite logs"
	@echo "  clean     - Clean up Docker resources"
	@echo "  test      - Run tests against Appwrite"
	@echo "  verify    - Verify Appwrite setup"
	@echo "  status    - Show current status"\n	@echo "  setup-crux - Setup Crux dependency for local development"\n	@echo "  setup-crux - Setup Crux dependency for local development"

# Complete setup from scratch
setup:
	@echo "🦀 Setting up Crux dependency first..."\n	@./scripts/setup-crux.sh\n	@./scripts/setup-appwrite-complete.sh

# Completely tear down environment
teardown:
	@echo "🧹 Tearing down Appwrite environment..."
	@./scripts/teardown-local-appwrite.sh

# Start Appwrite services
start:
	@echo "🚀 Starting Appwrite services..."
	@docker compose up -d
	@echo "⏳ Waiting for services to be ready..."
	@timeout 120 bash -c 'until curl -s http://localhost/v1/health > /dev/null 2>&1; do sleep 2; done' || (echo "❌ Services failed to start"; exit 1)
	@echo "✅ Appwrite services started!"

# Stop Appwrite services
stop:
	@echo "🛑 Stopping Appwrite services..."
	@docker compose down

# View logs
logs:
	@docker compose logs -f

# Clean up Docker resources
clean:
	@echo "🧹 Cleaning up Docker resources..."
	@docker system prune -f
	@docker volume prune -f

# Run tests
test:
	@echo "🧪 Running tests..."
	@if [ ! -f .env.local ]; then \
		echo "❌ .env.local not found. Run 'make setup' first."; \
		exit 1; \
	fi
	@source .env.local && echo "Testing connection..." && \
	curl -s -H "X-Appwrite-Project: $$APPWRITE_PROJECT_ID" \
		-H "X-Appwrite-Key: $$APPWRITE_API_KEY" \
		"$$APPWRITE_ENDPOINT/databases" | jq . > /dev/null && \
	echo "✅ Connection test passed!"

# Verify setup
verify:
	@echo "🔍 Verifying setup..."
	@if [ ! -f .env.local ]; then \
		echo "❌ .env.local not found. Run 'make setup' first."; \
		exit 1; \
	fi
	@source .env.local && echo "Checking database..." && \
	curl -s -H "X-Appwrite-Project: $$APPWRITE_PROJECT_ID" \
		-H "X-Appwrite-Key: $$APPWRITE_API_KEY" \
		"$$APPWRITE_ENDPOINT/databases" | jq '.databases | length' | grep -q "1" && \
	echo "✅ Database verification passed!"

# Show current status
status:
	@echo "📊 Current Status:"
	@echo "  Docker containers:"
	@docker ps --format "    {{.Names}}: {{.Status}}" | grep appwrite || echo "    No Appwrite containers running"
	@echo ""
	@if [ -f .env.local ]; then \
		echo "  Environment: ✅ Configured (.env.local exists)"; \
		source .env.local && echo "  Project ID: $$APPWRITE_PROJECT_ID"; \
		echo "  Database ID: $$APPWRITE_DATABASE_ID"; \
	else \
		echo "  Environment: ❌ Not configured"; \
	fi
	@echo ""
	@echo "  Console: http://localhost/console"
	@echo "  API: http://localhost/v1"

# Development helpers
dev-setup: setup
	@echo "🔧 Setting up development environment..."
	@cd infrastructure && cargo build --bin appwrite_cli --features cli
	@echo "✅ Development setup complete!"

dev-deploy:
	@echo "🚀 Deploying schema..."
	@cd infrastructure && ../target/debug/appwrite_cli deploy \
		--database-id intrada_db \
		--database-name "Intrada Database" \
		--environment dev
	@echo "✅ Schema deployed!"

# CI/CD helpers
ci-setup:
	@echo "🏗️ Setting up CI environment..."
	@docker compose up -d
	@timeout 120 bash -c 'until curl -s http://localhost/v1/health > /dev/null 2>&1; do sleep 2; done'
	@cd infrastructure && cargo build --bin appwrite_cli --features cli --release
	@echo "✅ CI setup complete!"

ci-cleanup:
	@echo "🧹 Cleaning up CI environment..."
	@docker compose down -v
	@docker system prune -f
	@echo "✅ CI cleanup complete!"\n\n# Setup Crux dependency for local development\nsetup-crux:\n	@echo "🦀 Setting up Crux dependency..."\n	@./scripts/setup-crux.sh\n	@echo "✅ Crux setup complete!" 