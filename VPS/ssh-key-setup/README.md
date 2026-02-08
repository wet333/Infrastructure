# SSH key setup

Scripts to set up passwordless SSH access to VPS or other servers.

## setup-passwordless-ssh.sh

Establishes passwordless SSH login by copying your local public key to the remote server.

### Usage

```bash
./setup-passwordless-ssh.sh
```

You will be prompted for:

- **Remote user** – e.g. `root`, `ubuntu`, `deploy`
- **Host** – IP address or domain, e.g. `192.168.1.1` or `vps.example.com`

The script will then ask for the remote user’s **password** (or other auth) to install your public key. If you don’t have an SSH key yet, it will offer to generate one (`~/.ssh/id_ed25519`).

### Options

- `-k PATH`, `--key PATH` – Use a specific key (default: `~/.ssh/id_ed25519`)
- `-h`, `--help` – Show help

### Requirements

- `ssh`, `ssh-keygen` (and preferably `ssh-copy-id`) on the local machine
- Password or other authentication to log in to the remote host once

### Example

```bash
cd VPS/ssh-key-setup
./setup-passwordless-ssh.sh
# Remote user: root
# Host (IP or domain): 203.0.113.10
# (enter password when prompted)
# Success. You can now: ssh root@203.0.113.10
```

## setup-passwordless-ssh-with-alias.sh

Same as above, plus it asks for an **alias** and adds a `Host` block to `~/.ssh/config` so you can connect with `ssh <alias>`.

### Usage

```bash
./setup-passwordless-ssh-with-alias.sh
```

You will be prompted for:

- **Remote user** – e.g. `root`, `ubuntu`, `deploy`
- **Host (IP or domain)** – e.g. `192.168.1.1` or `vps.example.com`
- **Alias** – short name for the connection (letters, numbers, dots, hyphens, underscores only, e.g. `myserver`, `vps-prod`)

The script then asks for the remote **password**, installs your key, and appends to `~/.ssh/config`:

```
Host <alias>
    HostName <host>
    User <user>
    IdentityFile ~/.ssh/id_ed25519
```

### Options

- `-k PATH`, `--key PATH` – Use a specific key (default: `~/.ssh/id_ed25519`)
- `-h`, `--help` – Show help

### Example

```bash
./setup-passwordless-ssh-with-alias.sh
# Remote user: root
# Host (IP or domain): 203.0.113.10
# Alias for this connection: vps1
# (enter password when prompted)
# Success. Connect with: ssh vps1
```