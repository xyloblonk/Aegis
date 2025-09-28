package main

import (
"github.com/xyloblonk/aegis/pkg/setup"
)

func main() {
s := setup.NewSetup()
s.Run()
}

type Setup struct {
ConfigDir string
LogDir string
BackupScriptsDir string
CronDir string
TempDir string
BackupRoot string
MonitoringDir string

text
    Providers        map[string]string
    BackupJobs       map[string]string
    BackendConfigs   map[string]string

    CurrentStep      int
    TotalSteps       int

    SelectedBackend  string
    SelectedProvider string

}
