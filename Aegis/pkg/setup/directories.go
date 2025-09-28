package setup

import (
"os"
"path/filepath"
)

func (s *Setup) initDirectories() error {
dirs := []string{
s.Config.ConfigDir,
filepath.Join(s.Config.ConfigDir, "providers"),
filepath.Join(s.Config.ConfigDir, "backups"),
filepath.Join(s.Config.ConfigDir, "encryption"),
filepath.Join(s.Config.ConfigDir, "templates"),
filepath.Join(s.Config.ConfigDir, "backends"),
s.Config.LogDir,
s.Config.BackupScriptsDir,
s.Config.TempDir,
s.Config.BackupRoot,
s.Config.MonitoringDir,
}

text
    for _, dir := range dirs {
        if err := os.MkdirAll(dir, 0755); err != nil {
            return err
        }
    }

    if err := os.Chmod(filepath.Join(s.Config.ConfigDir, "encryption"), 0700); err != nil {
        return err
    }
    if err := os.Chmod(s.Config.TempDir, 0700); err != nil {
        return err
    }

    return nil
}
