# Aegis

**Aegis** is a comprehensive backup automation framework for Linux servers.  
It delivers **secure, encrypted, retention-aware, and cloud-ready** backups with minimal setup.  

Designed for **sysadmins, DevOps engineers, and hosting providers**, Aegis provides reliability, auditability, and strong security guarantees in one streamlined solution.

## ✨ Features

- **Interactive Guided Setup**
  - Step-by-step wizard for providers, sources, encryption, and retention.
  - Input validation and sensible defaults for reduced misconfiguration.

- **Multi-Provider Cloud Support**
  - Amazon S3  
  - Backblaze B2  
  - Google Cloud Storage  
  - Wasabi  
  - DigitalOcean Spaces  
  - MinIO  
  - FTP / FTPS  
  - SFTP  

- **Flexible Backup Sources**
  - Files & directories (with exclusions)
  - MySQL / MariaDB databases
  - PostgreSQL databases
  - Docker volumes
  - System configuration snapshots

- **Enterprise-Grade Encryption**
  - AES-256-CBC with PBKDF2 key derivation
  - Automatic key generation & rotation support
  - Encrypted staging before upload

- **Scheduling & Retention**
  - Cron-based automation
  - Configurable hourly, daily, weekly, monthly retention
  - Automated pruning to minimize storage cost

- **Comprehensive Logging**
  - Timestamped logs per backup run
  - Separate cron and retention logs
  - Clear error reporting and audit trails

- **Extensible Architecture**
  - Modular scripts
  - Easy provider extensions
  - Supports hybrid local + cloud workflows

---

## 📦 Installation

Clone the repository and launch the installer:

```bash
git clone https://github.com/xyloblonk/aegis.git
cd aegis
sudo ./aegis.sh
````

The guided setup will configure:

* Provider credentials
* Backup sources
* Encryption options
* Scheduling & retention

## ⚙️ Configuration

Configuration is stored in structured directories:

* **`/etc/backup-automator/`**

  * Provider credentials
  * Retention policy
  * Encryption keys
* **`/usr/local/bin/backup-scripts/`**

  * Generated scripts (`run_backup.sh`, `upload_backup.sh`, etc.)
* **`/var/log/backup-automator/`**

  * Logs of backup jobs, pruning, and cron runs
* **`/backups/`**

  * Temporary staging of backup archives before upload

You can re-run the setup at any time to adjust configuration.

## 🔐 Security

* All backups can be encrypted at rest with **AES-256-CBC**.
* Encryption keys are stored under `/etc/backup-automator/encryption/key.bin` with restrictive permissions.
* Aegis enforces:

  * **Least privilege file ownership**
  * **Secure defaults for cloud provider authentication**
  * **Logging for audit compliance**

⚠️ **Important:** If you lose the encryption key, your backups cannot be recovered. Store it securely in a password manager or hardware vault.

## 🗓 Scheduling & Retention

Backups are run via cron jobs:

* **Backup execution:** `/etc/cron.d/backup-automator`
* **Pruning & cleanup:** Daily at 01:00 AM

Example retention policy (`/etc/backup-automator/retention.conf`):

```ini
RETAIN_HOURLY=24
RETAIN_DAILY=7
RETAIN_WEEKLY=4
RETAIN_MONTHLY=12
```

This ensures recent backups are preserved while controlling storage growth.

## 🚀 Usage

Trigger a manual backup job:

```bash
sudo /usr/local/bin/backup-scripts/run_backup.sh default
```

View logs:

```bash
tail -f /var/log/backup-automator/backup.log
```

List backups available in staging:

```bash
ls /backups/
```

## 🛠 Recovery

To restore from a backup:

1. Retrieve the archive from your configured cloud provider.
2. Decrypt (if encrypted):

   ```bash
   openssl enc -d -aes-256-cbc -in backup.tar.gz.enc -out backup.tar.gz -pass file:/etc/backup-automator/encryption/key.bin
   ```
3. Extract:

   ```bash
   tar -xzf backup.tar.gz -C /restore/path
   ```
4. Import databases or mount configs as needed.

(A guided restore utility is on the roadmap.)

## 📊 Roadmap

* [ ] Incremental & differential backups
* [ ] Borg/Restic backend integration
* [ ] Restore automation script
* [ ] Parallelized uploads for large archives
* [ ] Alerting and monitoring hooks (Prometheus, Grafana)
* [ ] Web UI for management and reporting

## 🏗 Architecture Overview

Aegis is composed of:

* **Setup wizard (`aegis.sh`)**
  Collects provider credentials, sets up configs, schedules jobs.

* **Backup execution scripts**
  Handle staging, encryption, compression, and provider uploads.

* **Retention engine**
  Applies retention policies across local staging and cloud provider storage.

* **Logging system**
  Generates structured logs for every stage of the process.

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit changes with clear messages
4. Submit a pull request with detailed notes

Please also ensure:

* Code is POSIX-compliant shell where possible
* New features are documented in the README
* Scripts pass linting with `shellcheck`

## 📜 License

Aegis is released under the **MIT License**.
You are free to use, modify, and distribute, provided proper attribution is maintained.
