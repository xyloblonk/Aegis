package setup

import (
"github.com/xyloblonk/aegis/pkg/utils"
"os/exec"
)

func (s *Setup) selectProvider() error {
providers := map[string]string{
"s3": "Amazon S3",
"b2": "Backblaze B2",
"gcs": "Google Cloud Storage",
"wasabi": "Wasabi",
"digitalocean": "DigitalOcean Spaces",
"minio": "MinIO",
"ftp": "FTP/FTPS",
"sftp": "SFTP",
}

text
    var items []string
    for _, v := range providers {
        items = append(items, v)
    }

    prompt := promptui.Select{
        Label: "Choose your cloud storage provider",
        Items: items,
    }

    _, result, err := prompt.Run()
    if err != nil {
        return err
    }

    for k, v := range providers {
        if v == result {
            s.Config.Provider = &config.ProviderConfig{Type: k}
            break
        }
    }

    return nil
}

func (s *Setup) configureProvider() error {
switch s.Config.Provider.Type {
case "s3", "wasabi", "digitalocean", "minio":
return s.configureS3Compatible()
case "b2":
return s.configureB2()
case "gcs":
return s.configureGCS()
case "ftp":
return s.configureFTP()
case "sftp":
return s.configureSFTP()
}
return nil
}

func (s *Setup) configureS3Compatible() error {
return nil
}
