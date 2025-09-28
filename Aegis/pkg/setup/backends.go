package setup

import (
"github.com/manifoldco/promptui"
)

import (
"github.com/xyloblonk/aegis/pkg/utils"
"os/exec"
)

func (s *Setup) selectBackupBackend() error {
backends := map[string]string{
"traditional": "Traditional (tar/gzip)",
"borg": "BorgBackup (Deduplicating)",
"restic": "Restic (Encrypted Deduplication)",
}

func (s *Setup) installBackupBackends() error {
if _, err := exec.LookPath("borg"); err != nil {
if err := utils.RunCommand("apt-get", "install", "-y", "borgbackup"); err != nil {
return err
}
}

text
    if _, err := exec.LookPath("restic"); err != nil {
        if err := utils.RunCommand("wget", "-q", "https://github.com/restic/restic/releases/latest/download/restic_linux_amd64.bz2"); err != nil {
            return err
        }
        if err := utils.RunCommand("bzip2", "-d", "restic_linux_amd64.bz2"); err != nil {
            return err
        }
        if err := utils.RunCommand("chmod", "+x", "restic_linux_amd64"); err != nil {
            return err
        }
        if err := utils.RunCommand("mv", "restic_linux_amd64", "/usr/local/bin/restic"); err != nil {
            return err
        }
    }

    return nil
}

func (s *Setup) selectBackupBackend() error {
backends := map[string]string{
"traditional": "Traditional (tar/gzip)",
"borg": "BorgBackup (Deduplicating)",
"restic": "Restic (Encrypted Deduplication)",
}

func (s *Setup) configureBackend() error {
switch s.Config.Backend.Type {
case "borg":
return s.configureBorgBackend()
case "restic":
return s.configureResticBackend()
case "traditional":
return s.configureTraditionalBackend()
}
return nil
}

func (s *Setup) configureBorgBackend() error {
return nil
}

text
    var items []string
    for _, v := range backends {
        items = append(items, v)
    }

    prompt := promptui.Select{
        Label: "Choose your backup backend",
        Items: items,
    }

    _, result, err := prompt.Run()
    if err != nil {
        return err
    }

    for k, v := range backends {
        if v == result {
            s.Config.Backend = &config.BackendConfig{Type: k}
            break
        }
    }

    return nil
}

text
    var items []string
    for _, v := range backends {
        items = append(items, v)
    }

    prompt := promptui.Select{
        Label: "Choose your backup backend",
        Items: items,
    }

    _, result, err := prompt.Run()
    if err != nil {
        return err
    }

    for k, v := range backends {
        if v == result {
            s.Config.Backend = &config.BackendConfig{Type: k}
            break
        }
    }

    return nil
}
