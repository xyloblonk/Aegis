package utils

import (
"os/exec"
"strings"
)

func RunCommand(name string, arg ...string) error {
cmd := exec.Command(name, arg...)
return cmd.Run()
}

func RunCommandOutput(name string, arg ...string) (string, error) {
cmd := exec.Command(name, arg...)
output, err := cmd.Output()
return strings.TrimSpace(string(output)), err
}
