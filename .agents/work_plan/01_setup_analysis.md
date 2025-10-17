# Setup & Analysis Phase

This phase prepares the development environment and analyzes the task requirements in the context of the distributed system.

## 1. Task Understanding

- Parse the task description or issue number provided
- If it's a GitHub issue, use `gh issue view <issue-number>` to review details
- Identify which services will be affected (API Gateway, Inventory, Pricing, or all)
- Note any specific distributed tracing patterns to implement or test

## 2. Environment Setup

### Verify Project State
- Ensure you're on the main branch: `git checkout main`
- Pull latest changes: `git pull origin main`
- Create feature branch: `feature/<task-short-description>` or `fix/<issue-number>-<description>`

### Service Health Check
Run each service to ensure baseline functionality:

#### API Gateway (Python)
```bash
cd api-gateway
pip install -r requirements.txt
python -m pytest tests/ -v  # if tests exist
# Start service: python main.py or uvicorn main:app --reload
```

#### Inventory Service (Java)
```bash
cd inventory-service
./mvnw clean test
# Start service: ./mvnw spring-boot:run
```

#### Pricing Service (Go)
```bash
cd pricing-service
go test ./...
# Start service: go run cmd/server/main.go
```

### Docker Environment
```bash
# Build all services
docker-compose build

# Start all services
docker-compose up -d

# Verify health
docker-compose ps
curl http://localhost:8000/health  # API Gateway
curl http://localhost:8001/health  # Inventory Service
curl http://localhost:8002/health  # Pricing Service
```

## 3. Codebase Analysis

### Service Structure Review
- Review the structure of affected services
- Identify existing patterns for:
  - API endpoint definitions
  - Inter-service communication
  - Error handling
  - Logging and tracing (if any)
  - Database interactions
  - Configuration management

### Communication Patterns
- Analyze how services currently communicate
- Check for:
  - HTTP client configurations
  - Request/response formats
  - Header propagation (especially trace headers)
  - Timeout and retry logic
  - Circuit breaker implementations

### Existing Test Patterns
- Review test structure for each affected service
- Note testing approaches:
  - Unit tests
  - Integration tests
  - End-to-end tests
  - Load testing scripts

## 4. Create Task Documentation

Create `task_work/` directory (add to .gitignore if needed):
```bash
mkdir -p task_work
echo "task_work/" >> .gitignore  # if not already present
```

Create `task_work/task_baseline.md` documenting:
- Current service states (all passing tests)
- Existing endpoints and their behaviors
- Current inter-service communication flows
- Any existing issues or warnings
- Dependencies and their versions

## 5. Requirements Analysis

Document in `task_work/task_requirements.md`:
- Functional requirements
- Non-functional requirements (performance, observability)
- Affected services and components
- New vs modified functionality
- Testing requirements
- Distributed tracing implications

## Key Checks Before Proceeding

- [ ] All services build successfully
- [ ] All existing tests pass
- [ ] Docker environment works
- [ ] Inter-service communication verified
- [ ] Task requirements are clear
- [ ] Feature branch created
- [ ] Baseline documented

## Notes

- Pay special attention to distributed tracing patterns
- Consider how changes affect service dependencies
- Think about failure scenarios and error propagation
- Keep observability in mind (future Datadog integration)