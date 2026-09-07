# Debian → BorgWarehouse: 5-Minute Incremental Backup Setup

This guide documents a complete setup for backing up a local folder from a Debian server to a BorgWarehouse repository using BorgBackup.

The setup provides:

- Backups every **5 minutes**
- Borg deduplication, so unchanged data is not stored repeatedly
- Compression
- Automated backups with `systemd`
- Daily pruning
- Daily compaction
- Logging through the systemd journal
- Unattended operation using a protected Borg passphrase file

The retention policy used in this guide is:

- Keep **all archives from the last 3 days**
- Keep **30 daily archives**
- Keep **3 monthly archives**

The exact prune rule is:

```bash
borg prune \
    --verbose \
    --list \
    --glob-archives 'folder-*' \
    --keep-within 3d \
    --keep-daily 30 \
    --keep-monthly 3 \
    "$REPOSITORY"
```

---

# 1. How Borg incremental backups work

Borg does not create traditional full and incremental backup files.

Each archive represents a complete point-in-time view of the backed-up folder, for example:

```text
folder-2026-09-07_20-00-00
folder-2026-09-07_20-05-00
folder-2026-09-07_20-10-00
folder-2026-09-07_20-15-00
```

Every archive can be restored independently.

Internally, Borg splits data into chunks and deduplicates them. If a large directory changes only slightly between two backups, Borg normally stores and transfers only the new chunks.

At a 5-minute interval, the maximum archive creation rate is:

```text
12 archives/hour
288 archives/day
864 archives/3 days
```

The retention policy later in this guide prevents those archives from accumulating indefinitely.

---

# 2. Architecture

```text
Debian Server
│
├── Local folder
│
├── borg create every 5 minutes
│
├── borg prune once per day
│
└── borg compact once per day
│
└──────────── SSH ────────────► BorgWarehouse Repository
```

Two systemd timers are used:

```text
borg-folder-backup.timer
    └── every 5 minutes
        └── borg create

borg-folder-maintenance.timer
    └── once per day
        ├── borg prune
        └── borg compact
```

---

# 3. Prerequisites

The Debian server must have BorgBackup installed.

Check:

```bash
borg --version
```

This guide was written for a client running:

```text
borg 1.4.0
```

You also need:

- A BorgWarehouse installation
- A repository created in BorgWarehouse
- The repository connection URL shown by BorgWarehouse
- An SSH key authorized for the repository
- The Borg repository passphrase
- Read access to the local folder being backed up

---

# 4. Values used in this guide

Replace the placeholders below with the actual values from your environment.

Example values:

```text
SOURCE=/path/to/local/folder
REPOSITORY=ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY
SSH_KEY=/root/.ssh/borgwarehouse
PASSPHRASE_FILE=/root/.config/borg/passphrase
```

Use the exact repository URL shown in the BorgWarehouse setup instructions. Do not guess the remote repository path.

---

# 5. Create a dedicated SSH key

If the backup needs access to files owned by multiple users, running Borg as `root` is often the simplest option.

Create the SSH directory if necessary:

```bash
sudo mkdir -p /root/.ssh
sudo chmod 700 /root/.ssh
```

Create a dedicated SSH key:

```bash
sudo ssh-keygen \
    -t ed25519 \
    -f /root/.ssh/borgwarehouse \
    -N ''
```

This creates:

```text
/root/.ssh/borgwarehouse
/root/.ssh/borgwarehouse.pub
```

Display the public key:

```bash
sudo cat /root/.ssh/borgwarehouse.pub
```

Add this public key to BorgWarehouse and authorize it for the repository.

Protect the private key:

```bash
sudo chmod 600 /root/.ssh/borgwarehouse
```

---

# 6. Obtain the BorgWarehouse repository URL

Open the repository in BorgWarehouse and use its setup instructions.

The repository URL will resemble:

```text
ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY
```

Use the exact value supplied by BorgWarehouse.

For the rest of this guide:

```bash
REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"
```

---

# 7. Test SSH/Borg connectivity

Set the Borg SSH command:

```bash
export BORG_RSH="ssh -i /root/.ssh/borgwarehouse"
```

Perform an initial Borg operation manually so that the SSH host key can be verified and accepted.

For an initialized repository:

```bash
borg list "$REPOSITORY"
```

For a new repository, initialize it as described in the next section.

Verify the SSH host fingerprint before accepting it.

---

# 8. Initialize the Borg repository

If the Borg repository has not yet been initialized with `borg init`, initialize it from the Debian client.

Set:

```bash
export BORG_RSH="ssh -i /root/.ssh/borgwarehouse"
```

Then run:

```bash
borg init \
    --encryption=repokey-blake2 \
    "$REPOSITORY"
```

If BorgWarehouse provides a specific initialization command, use that command instead.

Choose a strong Borg passphrase and store an independent copy in a secure location.

---

# 9. Store the Borg passphrase for unattended backups

Create a protected configuration directory:

```bash
sudo mkdir -p /root/.config/borg
sudo chmod 700 /root/.config/borg
```

Create the passphrase file:

```bash
sudo nano /root/.config/borg/passphrase
```

Put only the Borg repository passphrase in the file.

Protect it:

```bash
sudo chmod 600 /root/.config/borg/passphrase
```

Verify:

```bash
sudo ls -l /root/.config/borg/passphrase
```

The scripts use:

```bash
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"
```

This avoids storing the passphrase directly in a systemd unit or command line.

---

# 10. Create the backup script

Create:

```bash
sudo nano /usr/local/sbin/borg-folder-backup
```

Use:

```bash
#!/bin/bash

set -euo pipefail

SOURCE="/path/to/local/folder"
REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"

export BORG_RSH="ssh \
    -i /root/.ssh/borgwarehouse \
    -o BatchMode=yes \
    -o ServerAliveInterval=10 \
    -o ServerAliveCountMax=30"

export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"

echo "============================================================"
echo "Starting Borg backup"
echo "Date: $(date --iso-8601=seconds)"
echo "Source: ${SOURCE}"
echo "============================================================"

borg create \
    --compression lz4 \
    --stats \
    --show-rc \
    "${REPOSITORY}::folder-{now:%Y-%m-%d_%H-%M-%S}" \
    "${SOURCE}"

BACKUP_RC=$?

echo "============================================================"
echo "Borg backup finished"
echo "Date: $(date --iso-8601=seconds)"
echo "Return code: ${BACKUP_RC}"
echo "============================================================"

exit "${BACKUP_RC}"
```

Replace:

```text
/path/to/local/folder
```

with the folder to back up, and replace the repository URL with the exact BorgWarehouse repository URL.

---

# 11. Protect the backup script

Make it executable and root-only:

```bash
sudo chmod 700 /usr/local/sbin/borg-folder-backup
```

Verify:

```bash
sudo ls -l /usr/local/sbin/borg-folder-backup
```

---

# 12. Test the backup manually

Run:

```bash
sudo /usr/local/sbin/borg-folder-backup
```

A successful run should show Borg statistics.

The important value for incremental storage behavior is:

```text
Deduplicated size
```

This indicates approximately how much new repository data was added by the archive.

---

# 13. List existing archives

Set:

```bash
export BORG_RSH="ssh -i /root/.ssh/borgwarehouse"
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"
REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"
```

List archives:

```bash
borg list "$REPOSITORY"
```

Example:

```text
folder-2026-09-07_22-20-00
folder-2026-09-07_22-25-00
folder-2026-09-07_22-30-00
```

---

# 14. Verify deduplication

Run two backups without changing anything:

```bash
sudo /usr/local/sbin/borg-folder-backup
sudo /usr/local/sbin/borg-folder-backup
```

Then modify or create a small file in the source directory and run another backup:

```bash
sudo /usr/local/sbin/borg-folder-backup
```

The later archives still represent complete restore points, but the deduplicated size should remain small when only a small amount of data changed.

---

# 15. Create the backup systemd service

Create:

```bash
sudo nano /etc/systemd/system/borg-folder-backup.service
```

Use:

```ini
[Unit]
Description=Borg backup to BorgWarehouse
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/borg-folder-backup

Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7

UMask=0077
```

---

# 16. Create the 5-minute backup timer

Create:

```bash
sudo nano /etc/systemd/system/borg-folder-backup.timer
```

Use:

```ini
[Unit]
Description=Run Borg folder backup every 5 minutes

[Timer]
OnCalendar=*:0/5
Persistent=true
AccuracySec=10s

[Install]
WantedBy=timers.target
```

This schedules the backup at approximately:

```text
00
05
10
15
20
25
30
35
40
45
50
55
```

minutes past each hour.

`Persistent=true` causes systemd to run a missed timer after the server comes back online. It does not recreate every missed 5-minute archive.

---

# 17. Enable the backup timer

Reload systemd:

```bash
sudo systemctl daemon-reload
```

Enable and start the timer:

```bash
sudo systemctl enable --now borg-folder-backup.timer
```

Check it:

```bash
systemctl status borg-folder-backup.timer
```

List the next run:

```bash
systemctl list-timers borg-folder-backup.timer
```

---

# 18. Test the systemd backup service

Trigger it manually:

```bash
sudo systemctl start borg-folder-backup.service
```

Check status:

```bash
systemctl status borg-folder-backup.service
```

View logs:

```bash
journalctl -u borg-folder-backup.service
```

Show recent logs:

```bash
journalctl -u borg-folder-backup.service --since today
```

Follow the log:

```bash
journalctl -u borg-folder-backup.service -f
```

---

# 19. Concurrent backup behavior

Because the backup uses a single systemd oneshot service, systemd will not normally start another instance of that same service while it is still active.

If a backup takes longer than five minutes, this prevents overlapping instances of the same backup service.

Borg also uses repository locking to protect repository consistency.

---

# 20. Retention policy

The retention rule for this setup is:

```bash
borg prune \
    --verbose \
    --list \
    --glob-archives 'folder-*' \
    --keep-within 3d \
    --keep-daily 30 \
    --keep-monthly 3 \
    "$REPOSITORY"
```

This means:

| Retention rule | Effect |
|---|---|
| `--keep-within 3d` | Keep every matching archive created within the last 3 days |
| `--keep-daily 30` | Keep up to 30 daily restore points beyond that |
| `--keep-monthly 3` | Keep up to 3 monthly restore points beyond the more recent retention groups |

Because backups are created every 5 minutes, `--keep-within 3d` keeps up to approximately:

```text
864 recent 5-minute archives
```

before the older archive history is thinned.

There is intentionally no hourly or weekly retention rule in this setup.

---

# 21. Why prune and compact are separate

Borg repository cleanup happens in two steps.

First:

```bash
borg prune
```

removes archives according to the retention policy.

Then:

```bash
borg compact
```

reclaims repository storage no longer referenced by retained archives.

The daily maintenance sequence is therefore:

```text
borg prune
    ↓
borg compact
```

---

# 22. Test pruning with a dry run

Before enabling automatic pruning, test the exact retention rule without deleting anything.

Set:

```bash
export BORG_RSH="ssh \
    -i /root/.ssh/borgwarehouse \
    -o BatchMode=yes"

export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"

REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"
```

Run:

```bash
borg prune \
    --dry-run \
    --verbose \
    --list \
    --glob-archives 'folder-*' \
    --keep-within 3d \
    --keep-daily 30 \
    --keep-monthly 3 \
    "$REPOSITORY"
```

Review the output carefully before running the same rule without `--dry-run`.

---

# 23. Create the daily maintenance script

Create:

```bash
sudo nano /usr/local/sbin/borg-folder-maintenance
```

Use:

```bash
#!/bin/bash

set -euo pipefail

REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"

export BORG_RSH="ssh \
    -i /root/.ssh/borgwarehouse \
    -o BatchMode=yes \
    -o ServerAliveInterval=10 \
    -o ServerAliveCountMax=30"

export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"

echo "============================================================"
echo "Starting Borg maintenance"
echo "Date: $(date --iso-8601=seconds)"
echo "============================================================"

echo
echo "Pruning archives..."
echo

borg prune \
    --verbose \
    --list \
    --glob-archives 'folder-*' \
    --keep-within 3d \
    --keep-daily 30 \
    --keep-monthly 3 \
    "$REPOSITORY"

echo
echo "Compacting repository..."
echo

borg compact \
    --verbose \
    "$REPOSITORY"

echo
echo "============================================================"
echo "Borg maintenance completed"
echo "Date: $(date --iso-8601=seconds)"
echo "============================================================"
```

---

# 24. Protect the maintenance script

Make it executable and root-only:

```bash
sudo chmod 700 /usr/local/sbin/borg-folder-maintenance
```

Verify:

```bash
sudo ls -l /usr/local/sbin/borg-folder-maintenance
```

---

# 25. Test maintenance manually

After verifying the dry-run output:

```bash
sudo /usr/local/sbin/borg-folder-maintenance
```

Then inspect the archive list:

```bash
export BORG_RSH="ssh -i /root/.ssh/borgwarehouse"
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"

borg list "$REPOSITORY"
```

---

# 26. Create the daily maintenance service

Create:

```bash
sudo nano /etc/systemd/system/borg-folder-maintenance.service
```

Use:

```ini
[Unit]
Description=Borg prune and compact
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/borg-folder-maintenance

Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7

UMask=0077
```

---

# 27. Create the daily maintenance timer

Create:

```bash
sudo nano /etc/systemd/system/borg-folder-maintenance.timer
```

For example, run maintenance daily at 03:30:

```ini
[Unit]
Description=Daily Borg prune and compact

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
RandomizedDelaySec=10m

[Install]
WantedBy=timers.target
```

With `RandomizedDelaySec=10m`, the job can start up to ten minutes after 03:30.

If you need exactly 03:30, remove:

```ini
RandomizedDelaySec=10m
```

---

# 28. Enable the maintenance timer

Reload systemd:

```bash
sudo systemctl daemon-reload
```

Enable and start the maintenance timer:

```bash
sudo systemctl enable --now borg-folder-maintenance.timer
```

Check:

```bash
systemctl status borg-folder-maintenance.timer
```

Show both Borg timers:

```bash
systemctl list-timers 'borg-*'
```

---

# 29. View maintenance logs

All maintenance logs:

```bash
journalctl -u borg-folder-maintenance.service
```

Today's maintenance logs:

```bash
journalctl \
    -u borg-folder-maintenance.service \
    --since today
```

Follow live:

```bash
journalctl \
    -u borg-folder-maintenance.service \
    -f
```

---

# 30. Useful monitoring commands

Check the backup timer:

```bash
systemctl status borg-folder-backup.timer
```

Check the maintenance timer:

```bash
systemctl status borg-folder-maintenance.timer
```

Show all Borg-related timers:

```bash
systemctl list-timers 'borg-*'
```

Show failed systemd units:

```bash
systemctl --failed
```

Show recent backup runs:

```bash
journalctl \
    -u borg-folder-backup.service \
    --since "1 hour ago"
```

Show recent maintenance runs:

```bash
journalctl \
    -u borg-folder-maintenance.service \
    --since "2 days ago"
```

---

# 31. Inspect repository archives

Set:

```bash
export BORG_RSH="ssh -i /root/.ssh/borgwarehouse"
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"

REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"
```

List archives:

```bash
borg list "$REPOSITORY"
```

Show repository information:

```bash
borg info "$REPOSITORY"
```

Show information about one archive:

```bash
borg info \
    "${REPOSITORY}::folder-2026-09-07_22-20-00"
```

---

# 32. Browse archive contents

List files in an archive:

```bash
borg list \
    "${REPOSITORY}::folder-2026-09-07_22-20-00"
```

If the source path is:

```text
/srv/data
```

Borg will normally store it without the leading slash:

```text
srv/data
srv/data/file1
srv/data/subdirectory/file2
```

---

# 33. Restore an entire archive

Create a temporary restore directory:

```bash
mkdir -p /tmp/borg-restore
cd /tmp/borg-restore
```

Extract:

```bash
borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-20-00"
```

If the source was `/srv/data`, the restored path will normally be:

```text
/tmp/borg-restore/srv/data
```

This makes it possible to inspect restored files before copying them back into production.

---

# 34. Restore a specific file or folder

First find the archive path:

```bash
borg list \
    "${REPOSITORY}::folder-2026-09-07_22-20-00"
```

For example, restore:

```text
srv/data/example.txt
```

with:

```bash
mkdir -p /tmp/borg-restore
cd /tmp/borg-restore

borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-20-00" \
    srv/data/example.txt
```

The restored file appears at:

```text
/tmp/borg-restore/srv/data/example.txt
```

---

# 35. Optional exclusions

You can exclude paths from `borg create`.

Example:

```bash
borg create \
    --compression lz4 \
    --stats \
    --show-rc \
    --exclude "${SOURCE}/cache" \
    --exclude "${SOURCE}/tmp" \
    "${REPOSITORY}::folder-{now:%Y-%m-%d_%H-%M-%S}" \
    "${SOURCE}"
```

You can also use patterns, for example:

```bash
--exclude '*.tmp'
```

Test exclusions carefully so that important files are not omitted.

---

# 36. Live databases and frequently changing files

Backing up ordinary files while they are being modified is generally fine, but live databases require additional care.

Examples include:

- PostgreSQL
- MariaDB/MySQL
- SQLite during active writes
- VM disk images
- Application database files

For application-consistent backups, prefer a workflow such as:

```text
database dump
    ↓
local backup directory
    ↓
Borg backup
```

or use an application/filesystem snapshot mechanism suitable for the data being protected.

---

# 37. BorgWarehouse append-only mode

BorgWarehouse can provide append-only protection for a repository.

This can be useful against ransomware or a compromised backup client because the client is restricted from permanently deleting existing repository data.

However, normal retention requires deletion of old data.

A maintenance sequence such as:

```text
borg prune
borg compact
```

must be allowed to remove unused repository data in order to reclaim space.

If append-only mode is enabled in BorgWarehouse, verify the intended cleanup process before relying on the automated maintenance job.

Do not assume that pruning and compaction can reclaim disk space while server-side append-only restrictions are active.

---

# 38. Repository checks

Run repository checks periodically, for example:

```bash
borg check "$REPOSITORY"
```

Repository checks can be I/O-intensive, especially for large repositories, so they should not run every five minutes.

A weekly or monthly check may be appropriate depending on repository size and operational requirements.

---

# 39. Test restores regularly

A backup should be considered usable only after restore testing.

Periodically:

1. Select a recent archive.
2. Restore some files to a temporary directory.
3. Verify file contents.
4. Verify permissions and ownership where relevant.

Example:

```bash
mkdir -p /tmp/borg-restore-test
cd /tmp/borg-restore-test
```

Then:

```bash
borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-20-00" \
    srv/data/some-important-file
```

After verification:

```bash
rm -rf /tmp/borg-restore-test
```

---

# 40. Protect backup credentials

The Debian server stores:

```text
/root/.ssh/borgwarehouse
/root/.config/borg/passphrase
```

Recommended permissions:

```bash
chmod 700 /root/.ssh
chmod 600 /root/.ssh/borgwarehouse

chmod 700 /root/.config/borg
chmod 600 /root/.config/borg/passphrase
```

Do not put the Borg passphrase in:

- Git repositories
- shell history
- Docker Compose files
- world-readable environment files
- scripts readable by unprivileged users

---

# 41. Keep independent recovery information

Do not let the Debian server be the only place containing information required to restore the backup.

Keep secure independent copies of:

- The Borg repository URL
- The Borg passphrase
- Relevant Borg key/recovery information
- BorgWarehouse administrative credentials
- This recovery documentation

A password manager or another appropriately protected offline location is suitable.

---

# 42. Final file layout

After setup, the important files are:

```text
/root/
├── .ssh/
│   ├── borgwarehouse
│   └── borgwarehouse.pub
│
└── .config/
    └── borg/
        └── passphrase

/usr/local/sbin/
├── borg-folder-backup
└── borg-folder-maintenance

/etc/systemd/system/
├── borg-folder-backup.service
├── borg-folder-backup.timer
├── borg-folder-maintenance.service
└── borg-folder-maintenance.timer
```

---

# 43. Complete backup script

`/usr/local/sbin/borg-folder-backup`:

```bash
#!/bin/bash

set -euo pipefail

SOURCE="/path/to/local/folder"
REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"

export BORG_RSH="ssh \
    -i /root/.ssh/borgwarehouse \
    -o BatchMode=yes \
    -o ServerAliveInterval=10 \
    -o ServerAliveCountMax=30"

export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"

echo "============================================================"
echo "Starting Borg backup"
echo "Date: $(date --iso-8601=seconds)"
echo "Source: ${SOURCE}"
echo "============================================================"

borg create \
    --compression lz4 \
    --stats \
    --show-rc \
    "${REPOSITORY}::folder-{now:%Y-%m-%d_%H-%M-%S}" \
    "${SOURCE}"

BACKUP_RC=$?

echo "============================================================"
echo "Borg backup finished"
echo "Date: $(date --iso-8601=seconds)"
echo "Return code: ${BACKUP_RC}"
echo "============================================================"

exit "${BACKUP_RC}"
```

---

# 44. Complete maintenance script

`/usr/local/sbin/borg-folder-maintenance`:

```bash
#!/bin/bash

set -euo pipefail

REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"

export BORG_RSH="ssh \
    -i /root/.ssh/borgwarehouse \
    -o BatchMode=yes \
    -o ServerAliveInterval=10 \
    -o ServerAliveCountMax=30"

export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"

echo "============================================================"
echo "Starting Borg maintenance"
echo "Date: $(date --iso-8601=seconds)"
echo "============================================================"

borg prune \
    --verbose \
    --list \
    --glob-archives 'folder-*' \
    --keep-within 3d \
    --keep-daily 30 \
    --keep-monthly 3 \
    "$REPOSITORY"

borg compact \
    --verbose \
    "$REPOSITORY"

echo "============================================================"
echo "Borg maintenance completed"
echo "Date: $(date --iso-8601=seconds)"
echo "============================================================"
```

---

# 45. Complete systemd configuration

## `/etc/systemd/system/borg-folder-backup.service`

```ini
[Unit]
Description=Borg backup to BorgWarehouse
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/borg-folder-backup

Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7

UMask=0077
```

## `/etc/systemd/system/borg-folder-backup.timer`

```ini
[Unit]
Description=Run Borg folder backup every 5 minutes

[Timer]
OnCalendar=*:0/5
Persistent=true
AccuracySec=10s

[Install]
WantedBy=timers.target
```

## `/etc/systemd/system/borg-folder-maintenance.service`

```ini
[Unit]
Description=Borg prune and compact
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/borg-folder-maintenance

Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7

UMask=0077
```

## `/etc/systemd/system/borg-folder-maintenance.timer`

```ini
[Unit]
Description=Daily Borg prune and compact

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
RandomizedDelaySec=10m

[Install]
WantedBy=timers.target
```

---

# 46. Activate the complete setup

Reload systemd:

```bash
sudo systemctl daemon-reload
```

Enable the backup timer:

```bash
sudo systemctl enable --now borg-folder-backup.timer
```

Enable the maintenance timer:

```bash
sudo systemctl enable --now borg-folder-maintenance.timer
```

Verify both:

```bash
systemctl list-timers 'borg-*'
```

Run a backup immediately:

```bash
sudo systemctl start borg-folder-backup.service
```

Check its log:

```bash
journalctl \
    -u borg-folder-backup.service \
    -n 100 \
    --no-pager
```

Before allowing the first real prune, verify the retention rule with:

```bash
borg prune \
    --dry-run \
    --verbose \
    --list \
    --glob-archives 'folder-*' \
    --keep-within 3d \
    --keep-daily 30 \
    --keep-monthly 3 \
    "$REPOSITORY"
```

---

# 47. Final configuration summary

```text
Source:
    Local folder on Debian

Destination:
    BorgWarehouse repository over SSH

Backup interval:
    Every 5 minutes

Backup command:
    borg create

Compression:
    LZ4

Retention:
    Keep all archives for 3 days
    Keep 30 daily archives
    Keep 3 monthly archives

Prune rule:
    --keep-within 3d
    --keep-daily 30
    --keep-monthly 3

Maintenance:
    Daily

Maintenance sequence:
    borg prune
    borg compact

Scheduling:
    systemd

Logging:
    systemd journal

Authentication:
    Dedicated SSH key

Encryption:
    Borg repokey-blake2

Passphrase:
    Root-only passphrase file
```

Useful operational commands:

```bash
systemctl list-timers 'borg-*'
```

```bash
journalctl -u borg-folder-backup.service
```

```bash
journalctl -u borg-folder-maintenance.service
```

```bash
borg list "$REPOSITORY"
```

Most importantly, test actual restores periodically.
