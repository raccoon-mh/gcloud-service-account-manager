# gcloud-service-account-manager


## install gcloud 
[OFFICIAL DOCS LINK](https://cloud.google.com/sdk/docs/install?hl=ko)

```bash
# RECOMMAND HOME DIR
cd
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz

# FOR UPDATE INSTALL PATH
./google-cloud-sdk/install.sh

# REQUIRE LOGIN
./google-cloud-sdk/bin/gcloud init

# check login status : below step always require login
gcloud auth list
gcloud config set account [ACCOUNT_EMAIL]
```

```bash
# check install status
$ gcloud version

    Google Cloud SDK 531.0.0
    bq 2.1.20
    bundled-python3-unix 3.12.9
    core 2025.07.18
    gcloud-crc32c 1.0.0
    gsutil 5.35
```

## 1_INIT.sh
필요한 환경 구성을 생성합니다.

```bash
scripts/1_init.sh
```
