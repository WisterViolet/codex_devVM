# codex_devVM

OpenAI Codex用Archlinux VM環境

## Requirements

- incus
- cdrtools
- squid
- sudo

CPU Virtualization, KVMが利用可能である必要あり
```bash
test -e /dev/kvm && echo "KVM available"
```

パッケージをインストール

```bash
pacman -S --needed \
    incus \
    cdrtools \
    squid
```

Incusの有効化

```bash
systemctl enable --now incu.socket
usermod -aG incus-admin "$USER"
incus admin init --minimal
```

認証情報ボリュームの作成

```bash
incus storage list # `default`があることを確認
incus storage volume create default codex-auth
```

## Usage

VMの作成

```bash
./scripts/setup-network.sh
./scripts/create.sh
```

VMの起動確認

```bash
incus list codex-dev-vm
```

Codexの起動

```bash
incus exec codex-dev-vm -- su - dev
cd /workspace
codex
```

