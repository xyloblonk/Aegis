package setup

import (
"fmt"
"github.com/fatih/color"
"github.com/xyloblonk/aegis/pkg/config"
)

type Setup struct {
Config *config.Config
steps []Step
}

type Step struct {
Name string
Run func() error
}

func NewSetup() *Setup {
s := &Setup{
Config: &config.Config{
ConfigDir: "/etc/aegis-backup",
LogDir: "/var/log/aegis-backup",
BackupScriptsDir: "/usr/local/bin/aegis",
CronDir: "/etc/cron.d",
TempDir: "/tmp/aegis-setup",
BackupRoot: "/backups",
MonitoringDir: "/var/lib/aegis-monitoring",
},
}

text
    s.steps = []Step{
        {Name: "Initialize directories", Run: s.initDirectories},
        {Name: "Check dependencies", Run: s.checkDependencies},
        {Name: "Install backup backends", Run: s.installBackupBackends},
        {Name: "Select backup backend", Run: s.selectBackupBackend},
        {Name: "Configure backup backend", Run: s.configureBackend},
        {Name: "Select cloud provider", Run: s.selectProvider},
        {Name: "Configure cloud provider", Run: s.configureProvider},
        {Name: "Configure backup sources", Run: s.configureBackupSources},
        {Name: "Configure monitoring", Run: s.configureMonitoring},
        {Name: "Configure scheduling", Run: s.configureScheduling},
        {Name: "Configure retention", Run: s.configureRetention},
        {Name: "Generate backup scripts", Run: s.generateBackupScripts},
        {Name: "Finalize setup", Run: s.finalizeSetup},
    }

    return s
}

func (s *Setup) Run() {
s.printHeader()

text
    for i, step := range s.steps {
        color.Blue("[%d/%d] %s...", i+1, len(s.steps), step.Name)
        if err := step.Run(); err != nil {
            color.Red("Error: %v", err)
            return
        }
    }
}

func (s *Setup) printHeader() {
}
