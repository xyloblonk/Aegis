# 🛠 Aegis

## 📌 Project Overview
Aegis is a backup system designed to support multiple backends and cloud providers.  
The goal of this dev branch is to **migrate the legacy shell script into a modular, maintainable Go application** while preserving its interactive setup, script generation capabilities, and system portability.

# Current Functionality
- Use the Script within the Script folder, `/scripts/` is production
- `/Aegis` (Go) is marked as in Dev

The Go application will provide:
- A fully interactive CLI (`aegis`) for initial setup and management.
- A daemon (`aegisd`) to handle scheduled backups, monitoring, and alerts.
- Modular, testable code organized by concern.
- Persistent configuration using YAML.
- Ability to generate shell scripts or execute commands directly via Go.

## 🎯 Project Goals
1. Convert the existing monolithic shell script into a structured Go codebase.
2. Maintain interactive CLI and daemon functionality.
3. Implement modular architecture:
   - Backup backends (Borg, Restic, Traditional)
   - Cloud providers (S3, GCS, B2, etc.)
   - Backup jobs and scheduling
   - Monitoring and alerts
   - Retention policies
4. Persist configuration using YAML for portability and maintainability.
5. Use Go templates and execution wrappers to generate or run scripts reliably.
6. Ensure the application is maintainable, extensible, and portable across Linux distributions.

---

## 🛠 Tools & Libraries
**Programming Language:** Go 1.21 (modules enabled)

**Core Libraries:**
- `os`, `os/exec` – filesystem and command execution
- `path/filepath` – directory/file operations
- `bufio`, `fmt`, `log` – CLI input/output and logging
- `text/template` – shell script generation
- `encoding/json` / `gopkg.in/yaml.v3` – configuration serialization

**CLI / UX:**
- `github.com/manifoldco/promptui` – interactive prompts
- `github.com/fatih/color` – terminal colors for better UX

**Testing:**
- Go’s standard `testing` package
- Unit tests for backends, providers, and setup steps

**Utilities:**
- Custom execution wrappers in `pkg/utils/exec.go` for robust system commands

## 📁 Current Folder Structure

```
Aegis/
├── cmd/  
│   ├── aegis/        # CLI entry point  
│   └── aegisd/       # Daemon entry point  
├── configs/          # Persistent configuration files  
├── docs/             # Documentation, architecture diagrams  
├── internal/         # Internal tools (installer, web)  
│   ├── installer/  
│   └── web/  
├── pkg/  
│   ├── api/  
│   ├── backends/     # borg, restic, traditional  
│   ├── config/       # configuration structs & YAML handling  
│   ├── crypto/  
│   ├── jobs/  
│   ├── logging/  
│   ├── monitoring/  
│   ├── providers/    # s3, gcs, b2  
│   ├── setup/        # setup steps: directories, dependencies, backends, providers, etc.  
│   ├── storage/  
│   └── utils/        # exec wrappers, helpers  
├── scripts/          # helper shell scripts (install, migration, dev tools)  
└── tests/            # unit and integration tests  
```

## 🛠 Planned Setup Steps (pkg/setup)
1. **Header & Introduction** – display welcome message and instructions.  
2. **Directory Initialization** – create all necessary directories (config, logs, scripts, temp).  
3. **Dependency Check** – verify required binaries and packages (Borg, Restic, cloud CLI tools).  
4. **Backend Installation** – install or verify backup backends.  
5. **Backend Selection** – allow user to select primary backup backend.  
6. **Backend Configuration** – configure repository paths, encryption, credentials.  
7. **Provider Selection** – interactive selection of cloud provider.  
8. **Provider Configuration** – credentials, buckets, endpoints.  
9. **Backup Sources Configuration** – files, databases (MySQL, PostgreSQL), Docker volumes, system directories.  
10. **Monitoring Setup** – configure alerting, email, or logging integration.  
11. **Scheduling Setup** – configure cron or daemon scheduling for automated backups.  
12. **Retention Policy** – define backup rotation, pruning rules, and retention periods.  
13. **Script Generation** – use templates to generate main backup, upload, restore, monitoring, and cron scripts.  
14. **Finalization** – save configuration to YAML, test backup, display setup summary.

Each step is implemented as a **dedicated Go function** in `pkg/setup` for modularity and testability.

## 🗺 Roadmap
**Phase 1 – Structure & Core Setup**
- Define `Setup` struct and `Config` struct.
- Implement directory and dependency checks.
- Implement modular setup steps with skeleton functions.
- Add logging and basic CLI output.

**Phase 2 – Backends & Providers**
- Implement Borg, Restic, Traditional backends.
- Implement S3, GCS, B2 provider integrations.
- Unit tests for backends and provider configurations.

**Phase 3 – Backup Jobs & Scheduling**
- Implement backup job definitions (`pkg/jobs`).
- Cron job generation and daemon support (`aegisd`).
- Implement retention policies and cleanup.

**Phase 4 – Monitoring & Alerts**
- Setup monitoring hooks (`pkg/monitoring`).
- Logging and alerting integration.

**Phase 5 – Testing & Documentation**
- Unit tests for all modules.
- End-to-end test of setup, backup, and restore.
- Generate professional documentation (`docs/`).

**Phase 6 – Optimization & Refactoring**
- Remove unused shell dependencies.
- Optimize performance and error handling.
- Prepare for stable release.

## 💡 Considerations & Plans
- Replacing shell scripts entirely with Go daemons for more control.
- Support for multiple simultaneous backup backends.
- Support for multiple providers per backend.
- Web UI and API for management.
- Integrate encryption and key management in Go rather than shell.
- Make all paths, credentials, and options configurable through YAML.

## 🚀 Development Guidelines
- Branch per feature or setup step; merge into `dev` after review.
- Follow modular architecture: each concern (setup, backend, provider, monitoring) in its own package.
- Keep CLI interactions testable and decoupled from actual execution.
- Use Go’s `log` package consistently for structured logging.
- Maintain cross-distro Linux compatibility (Ubuntu, Debian, CentOS).
- Document all changes in `docs/` and update README with new features.

## 📌 Notes
- Application must run as root due to `/etc`, `/var` directory writes.  
- All shell script generation uses Go `text/template` for safety and maintainability.  
- Interactive CLI is optional for automated setups using pre-defined YAML configuration.

## ✅ Summary
This dev branch is focused on **stepwise migration** from a large legacy shell script into a **well-structured Go application**.  
The roadmap ensures modular, maintainable code while preserving all current functionality with clear paths for expansion, monitoring, and future UI/API integration.
