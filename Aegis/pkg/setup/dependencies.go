package setup

import (
"github.com/xyloblonk/aegis/pkg/utils"
"os/exec"
)

func (s *Setup) checkDependencies() error {
deps := []string{"curl", "tar", "gzip", "openssl", "jq", "crontab", "parallel"}
for _, dep := range deps {
if _, err := exec.LookPath(dep); err != nil {
if err := utils.RunCommand("apt-get", "install", "-y", dep); err != nil {
return err
}
}
}

text
    if _, err := exec.LookPath("aws"); err != nil {
        if err := utils.RunCommand("apt-get", "install", "-y", "awscli"); err != nil {
            return err
        }
    }

    return nil
}
