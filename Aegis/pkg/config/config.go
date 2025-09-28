package config

type Config struct {
ConfigDir string yaml:"config_dir"
LogDir string yaml:"log_dir"
BackupScriptsDir string yaml:"backup_scripts_dir"
CronDir string yaml:"cron_dir"
TempDir string yaml:"temp_dir"
BackupRoot string yaml:"backup_root"
MonitoringDir string yaml:"monitoring_dir"

text
    Backend  *BackendConfig  `yaml:"backend"`
    Provider *ProviderConfig `yaml:"provider"`
    Jobs     []*JobConfig    `yaml:"jobs"`
    Monitoring *MonitoringConfig `yaml:"monitoring"`
    Scheduling *SchedulingConfig `yaml:"scheduling"`
    Retention *RetentionConfig `yaml:"retention"`
}

type BackendConfig struct {
Type string yaml:"type"
}

type ProviderConfig struct {
Type string yaml:"type"
}

type JobConfig struct {
Type string yaml:"type"
}

type MonitoringConfig struct {
EnablePrometheus bool yaml:"enable_prometheus"
EnableEmailAlerts bool yaml:"enable_email_alerts"
EnableSlackAlerts bool yaml:"enable_slack_alerts"
AlertEmail string yaml:"alert_email"
SMTPServer string yaml:"smtp_server"
SMTPPort int yaml:"smtp_port"
SlackWebhook string yaml:"slack_webhook"
}

type SchedulingConfig struct {
CronSchedule string yaml:"cron_schedule"
}

type RetentionConfig struct {
Hourly int yaml:"retain_hourly"
Daily int yaml:"retain_daily"
Weekly int yaml:"retain_weekly"
Monthly int yaml:"retain_monthly"
}
