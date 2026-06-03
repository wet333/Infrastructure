# Passwordless SSH to your VPS

New servers usually ask for a password on every SSH login. These scripts do the one-time setup: they install **this computer’s** SSH key on the server so **this computer** can log in without a password afterward.

**Important:** Access is granted to **the machine where you run the script** (your laptop, WSL, etc.). It uses the key in that machine’s `~/.ssh/` (default: `id_ed25519`). Another PC will not get passwordless login unless you run a script there too or copy that key manually.

**You need:** server password (or similar) **only while the script runs**. After that, from this machine, you should not need it.

```bash
cd VPS/ssh-key-setup
```

## Which script?

| Situation | Script |
|-----------|--------|
| `ssh root@203.0.113.10` is enough | `setup-passwordless-ssh.sh` |
| You want a short name, e.g. `ssh my-vps` | `setup-passwordless-ssh-with-alias.sh` |

---

## `setup-passwordless-ssh.sh`

**In short:** “Teach the server to recognize **this machine** without a password.”

What it does:

1. Asks for remote user and IP/domain.
2. If this machine has no SSH key yet, offers to create one here.
3. Copies **this machine’s** public key to the server (you enter the server password once).
4. Tests passwordless login from **this machine**.

### Typical example

```bash
./setup-passwordless-ssh.sh
```

```
Remote user: root
Host (IP or domain): 203.0.113.10
(enter the VPS password when prompted)
```

Then **from the same machine**:

```bash
ssh root@203.0.113.10
```

No password.

### Different key on this machine

```bash
./setup-passwordless-ssh.sh -k ~/.ssh/my_vps_key
```

---

## `setup-passwordless-ssh-with-alias.sh`

**In short:** Same as above, plus saves a **nickname** in **this machine’s** `~/.ssh/config` so you skip typing IP and user.

After setting alias `vps-prod` on this machine:

```bash
ssh vps-prod
```

instead of `ssh root@203.0.113.10`.

### Typical example

```bash
./setup-passwordless-ssh-with-alias.sh
```

```
Remote user: root
Host (IP or domain): 203.0.113.10
Alias for this connection: vps-prod
(VPS password once)
```

Then **from this machine**:

```bash
ssh vps-prod
scp file.txt vps-prod:/tmp/
```

Alias: letters, numbers, dots, hyphens, underscores only (`my-vps`, `vps.prod`).

---

## Quick summary

| Script | Result on **this machine** |
|--------|----------------------------|
| `setup-passwordless-ssh.sh` | `ssh user@ip` without password |
| `setup-passwordless-ssh-with-alias.sh` | `ssh your-alias` without password |

Help: `./script-name.sh -h`
