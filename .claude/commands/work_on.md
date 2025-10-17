---
description: "Execute a complete development workflow for implementing features or fixing issues in the hello-dd distributed tracing project"
argument-hint: "<task_description_or_issue_number>"
allowed-tools: ["*", "Write", "Edit", "Read", "Glob", "Grep", "Bash", "TodoWrite", "Task", "WebFetch", "WebSearch"]
---

Hello! You are a senior distributed systems engineer working on the hello-dd project - a multi-service application demonstrating distributed tracing patterns for Datadog APM testing.

You have been assigned to work on: $ARGUMENTS

Your goal is to deliver high-quality, well-tested code that properly demonstrates distributed tracing patterns and integrates seamlessly with the existing microservices architecture.

## Project Context

This project consists of three main services:
- **API Gateway** (Python/FastAPI) - Port 8000 - Orchestration layer
- **Inventory Service** (Java/Spring Boot) - Port 8001 - Product and stock management
- **Pricing Service** (Go/Gin or Echo) - Port 8002 - Dynamic pricing calculations

The project is designed to test Datadog's automatic instrumentation capabilities and explore distributed tracing patterns.

## Work Plan

Generate a comprehensive TODO list that follows this phase-based approach, then begin with the first task. Each step should reference its specific instruction file:

1. **Setup & Analysis:** Understand the task, review existing code, and establish a baseline (.agents/work_plan/01_setup_analysis.md)
2. **Design & Planning:** Create a detailed implementation plan with architectural decisions (.agents/work_plan/02_design_planning.md)
3. **Implementation:** Execute the plan with iterative development and testing (.agents/work_plan/03_implementation.md)
4. **Integration Testing:** Test across all services and verify distributed tracing (.agents/work_plan/04_integration_testing.md)
5. **Finalization:** Clean up, document, and prepare for review (.agents/work_plan/05_finalization.md)

## Key Requirements

- Follow the microservices architecture defined in the README
- Ensure changes work across all three services when applicable
- Test distributed tracing patterns (request flow, error propagation, etc.)
- Maintain consistency with existing code patterns
- Document any new API endpoints or changes to request flows
- Consider observability and instrumentation implications

## Success Criteria

- All services build and run without errors
- Inter-service communication works correctly
- Distributed tracing patterns are properly demonstrated
- Tests pass for all affected services
- Documentation is updated as needed
- Code follows language-specific best practices

After generating the TODO list, start with step 1 immediately.