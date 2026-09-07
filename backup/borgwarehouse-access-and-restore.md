# Accessing and Restoring BorgWarehouse Backups

This guide explains how to access backups created with BorgBackup on a Debian server and stored in BorgWarehouse.

It assumes the backup setup uses:

- BorgBackup 1.x
- A BorgWarehouse repository accessed over SSH
- A dedicated SSH key
- A Borg repository passphrase
- Archive names such as:

```text
folder-2026-09-07_22-20-00
folder-2026-09-07_22-25-00
folder-2026-09-07_22-30-00
```

The examples use these placeholders:

```text
REPOSITORY=ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY
SSH_KEY=/root/.ssh/borgwarehouse
PASSPHRASE_FILE=/root/.config/borg/passphrase
```

Replace them with the actual values used by your backup setup.

---

# 1. Prepare the Borg environment

Before accessing the repository, configure Borg to use the correct SSH key and passphrase.

Run:

```bash
export BORG_RSH="ssh -i /root/.ssh/borgwarehouse"
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"
export REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"
```

You can now use:

```bash
"$REPOSITORY"
```

in the commands below instead of repeatedly typing the full BorgWarehouse repository URL.

---

# 2. Verify access to the repository

Check that Borg can reach the repository:

```bash
borg info "$REPOSITORY"
```

If successful, Borg will display repository information.

If access fails, check:

- Network connectivity to BorgWarehouse
- The SSH key
- The repository URL
- The Borg passphrase
- Whether the SSH public key is still authorized for the repository in BorgWarehouse

---

# 3. List all available backups

List all archives:

```bash
borg list "$REPOSITORY"
```

Example:

```text
folder-2026-09-07_22-20-00
folder-2026-09-07_22-25-00
folder-2026-09-07_22-30-00
folder-2026-09-07_22-35-00
```

Each archive represents one complete point-in-time backup.

---

# 4. Show details about an archive

To inspect archive metadata:

```bash
borg info \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

This shows information such as:

- Archive creation time
- Number of files
- Original size
- Compressed size
- Deduplicated size
- Archive fingerprint

---

# 5. List files inside an archive

To inspect the contents of a backup without restoring anything:

```bash
borg list \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

If the original source folder was:

```text
/srv/data
```

the archived paths will normally appear without the leading slash:

```text
srv/data
srv/data/file1.txt
srv/data/documents
srv/data/documents/report.pdf
```

This archived path is what must be used when restoring individual files.

---

# 6. Search for a file in an archive

You can combine `borg list` with `grep`.

For example:

```bash
borg list \
    "${REPOSITORY}::folder-2026-09-07_22-30-00" \
    | grep report.pdf
```

Or search case-insensitively:

```bash
borg list \
    "${REPOSITORY}::folder-2026-09-07_22-30-00" \
    | grep -i report
```

---

# 7. Restore a single file

It is safest to restore files into a temporary directory first.

Create a restore directory:

```bash
mkdir -p /tmp/borg-restore
cd /tmp/borg-restore
```

Suppose the file inside the archive is:

```text
srv/data/documents/report.pdf
```

Restore it with:

```bash
borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-30-00" \
    srv/data/documents/report.pdf
```

The restored file will appear at:

```text
/tmp/borg-restore/srv/data/documents/report.pdf
```

You can inspect it before copying it back to the production location.

---

# 8. Restore a directory

Suppose you want to restore:

```text
srv/data/documents
```

Create a temporary restore location:

```bash
mkdir -p /tmp/borg-restore
cd /tmp/borg-restore
```

Then run:

```bash
borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-30-00" \
    srv/data/documents
```

The restored directory will be:

```text
/tmp/borg-restore/srv/data/documents
```

---

# 9. Restore an entire backup

To extract the entire archive:

```bash
mkdir -p /tmp/borg-restore
cd /tmp/borg-restore
```

Then:

```bash
borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

If the original source was:

```text
/srv/data
```

the restored copy will normally appear under:

```text
/tmp/borg-restore/srv/data
```

This is safer than extracting directly into `/`, because it avoids overwriting current files unexpectedly.

---

# 10. Restore back to the original location

A safe recovery workflow is:

```text
Borg archive
    ↓
Temporary restore directory
    ↓
Verify files
    ↓
Copy selected data back to production
```

For example:

```bash
mkdir -p /tmp/borg-restore
cd /tmp/borg-restore

borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

Inspect:

```bash
ls -lah /tmp/borg-restore/srv/data
```

Then copy files back as required.

For example:

```bash
cp -a \
    /tmp/borg-restore/srv/data/documents/report.pdf \
    /srv/data/documents/
```

For a directory:

```bash
cp -a \
    /tmp/borg-restore/srv/data/documents/. \
    /srv/data/documents/
```

Be careful when copying over live production data.

---

# 11. Browse a backup by mounting it

Borg can mount a repository or archive as a filesystem using FUSE.

This can be very convenient when you want to browse backups interactively.

First ensure FUSE support is available.

On Debian:

```bash
sudo apt install fuse3
```

Create a mount point:

```bash
sudo mkdir -p /mnt/borg
```

Mount the entire repository:

```bash
borg mount \
    "$REPOSITORY" \
    /mnt/borg
```

You can now browse archives as directories:

```bash
ls -lah /mnt/borg
```

Example:

```text
folder-2026-09-07_22-20-00
folder-2026-09-07_22-25-00
folder-2026-09-07_22-30-00
```

Browse one archive:

```bash
cd /mnt/borg/folder-2026-09-07_22-30-00
```

If the original source was `/srv/data`:

```bash
cd srv/data
```

You can now inspect and copy files normally.

For example:

```bash
cp \
    /mnt/borg/folder-2026-09-07_22-30-00/srv/data/documents/report.pdf \
    /tmp/
```

---

# 12. Mount only one archive

Instead of mounting the whole repository, mount a specific archive:

```bash
borg mount \
    "${REPOSITORY}::folder-2026-09-07_22-30-00" \
    /mnt/borg
```

Then browse:

```bash
ls -lah /mnt/borg
```

If the source was `/srv/data`:

```bash
ls -lah /mnt/borg/srv/data
```

---

# 13. Unmount a Borg backup

When finished browsing, leave the mount point:

```bash
cd /
```

Then unmount:

```bash
borg umount /mnt/borg
```

If necessary, you can also use:

```bash
fusermount3 -u /mnt/borg
```

---

# 14. Access the backups as root

If the repository credentials are stored under `/root`, the easiest way to access the backups is:

```bash
sudo -i
```

Then configure:

```bash
export BORG_RSH="ssh -i /root/.ssh/borgwarehouse"
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"
export REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"
```

Now you can run:

```bash
borg list "$REPOSITORY"
```

and the other commands in this guide.

---

# 15. Useful helper aliases

For temporary convenience in a root shell:

```bash
export BORG_RSH="ssh -i /root/.ssh/borgwarehouse"
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"
export REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"
```

Then common commands become:

```bash
borg list "$REPOSITORY"
```

```bash
borg info "$REPOSITORY"
```

```bash
borg mount "$REPOSITORY" /mnt/borg
```

---

# 16. Find the newest archive

List archives in reverse order:

```bash
borg list "$REPOSITORY" | tail
```

With archive names that include sortable timestamps, the newest archive will usually be the last matching entry.

For example:

```bash
borg list "$REPOSITORY" \
    | grep '^folder-' \
    | tail -n 1
```

Example result:

```text
folder-2026-09-07_23-30-00
```

---

# 17. List only backup archive names

If the repository contains other archives, filter the list:

```bash
borg list "$REPOSITORY" \
    | grep '^folder-'
```

This matches the archive naming scheme used by the backup script:

```text
folder-YYYY-MM-DD_HH-MM-SS
```

---

# 18. Compare multiple backup points manually

A convenient approach is to mount the whole repository:

```bash
borg mount "$REPOSITORY" /mnt/borg
```

Then compare two versions.

For example:

```bash
diff -u \
    /mnt/borg/folder-2026-09-07_22-30-00/srv/data/example.txt \
    /mnt/borg/folder-2026-09-07_23-00-00/srv/data/example.txt
```

Or compare directories recursively:

```bash
diff -r \
    /mnt/borg/folder-2026-09-07_22-30-00/srv/data/documents \
    /mnt/borg/folder-2026-09-07_23-00-00/srv/data/documents
```

Unmount afterward:

```bash
borg umount /mnt/borg
```

---

# 19. Access backups from another Debian machine

If the original Debian server is lost, the backups can still be accessed from another machine.

Install BorgBackup:

```bash
sudo apt update
sudo apt install borgbackup
```

You need:

- The BorgWarehouse repository URL
- An SSH private key authorized to access the repository
- The Borg repository passphrase
- Network access to BorgWarehouse

Place the SSH key, for example:

```text
/root/.ssh/borgwarehouse
```

Protect it:

```bash
sudo chmod 600 /root/.ssh/borgwarehouse
```

Create the Borg passphrase file:

```bash
sudo mkdir -p /root/.config/borg
sudo chmod 700 /root/.config/borg
sudo nano /root/.config/borg/passphrase
sudo chmod 600 /root/.config/borg/passphrase
```

Then configure:

```bash
export BORG_RSH="ssh -i /root/.ssh/borgwarehouse"
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"
export REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"
```

Test:

```bash
borg list "$REPOSITORY"
```

You can then restore or mount archives normally.

---

# 20. Access backups if you do not have the original SSH key

If the original client SSH key is lost, but you still control BorgWarehouse:

1. Generate a new SSH key on the recovery machine.
2. Add its public key to BorgWarehouse.
3. Authorize that key for the repository.
4. Use the repository URL and Borg passphrase to access the repository.

Generate:

```bash
sudo ssh-keygen \
    -t ed25519 \
    -f /root/.ssh/borgwarehouse \
    -N ''
```

Display:

```bash
sudo cat /root/.ssh/borgwarehouse.pub
```

Add that public key to BorgWarehouse.

Then:

```bash
export BORG_RSH="ssh -i /root/.ssh/borgwarehouse"
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"
```

Access:

```bash
borg list "$REPOSITORY"
```

---

# 21. What is required for disaster recovery

For reliable recovery from another machine, keep independent copies of:

- BorgWarehouse URL or hostname
- Repository connection URL
- Borg repository passphrase
- BorgWarehouse administrative access
- SSH recovery credentials, or the ability to register a new SSH key
- This documentation

Do not store all of this only on the server being backed up.

---

# 22. Check repository integrity

To verify the repository:

```bash
borg check "$REPOSITORY"
```

Repository checks can be resource-intensive.

For a large repository, run them during a maintenance window rather than during peak usage.

---

# 23. Test archive extraction without writing files

You can test archive readability using Borg's dry-run extraction mode:

```bash
borg extract \
    --dry-run \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

This reads through the archive without extracting the files to disk.

It is useful as part of periodic restore testing.

---

# 24. Common access errors

## SSH permission denied

Example:

```text
Permission denied (publickey)
```

Check:

```bash
ls -l /root/.ssh/borgwarehouse
```

The key should normally be:

```text
-rw------- root root
```

Fix:

```bash
chmod 600 /root/.ssh/borgwarehouse
```

Also verify that the matching public key is authorized in BorgWarehouse.

---

## Repository not found

Verify the exact BorgWarehouse repository URL.

Do not manually guess the repository path.

Use the repository connection information supplied by BorgWarehouse.

---

## Wrong passphrase

Check:

```bash
cat /root/.config/borg/passphrase
```

Then verify:

```bash
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"
```

Retry:

```bash
borg list "$REPOSITORY"
```

---

## SSH host key prompt

If an unattended command stops because the server host key has not yet been accepted, establish the connection manually once.

For example:

```bash
borg list "$REPOSITORY"
```

Verify the fingerprint before accepting it.

---

## Borg mount fails

Ensure FUSE is installed:

```bash
sudo apt install fuse3
```

Check:

```bash
ls -l /dev/fuse
```

Then try again:

```bash
borg mount "$REPOSITORY" /mnt/borg
```

---

# 25. Recommended restore workflow

For a normal accidental deletion or file rollback:

```text
1. List archives
2. Choose the required timestamp
3. List the archive contents
4. Restore into /tmp/borg-restore
5. Verify the restored data
6. Copy only the required files back into production
```

Commands:

```bash
borg list "$REPOSITORY"
```

```bash
borg list \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

```bash
mkdir -p /tmp/borg-restore
cd /tmp/borg-restore
```

```bash
borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-30-00" \
    srv/data/path/to/file
```

Verify, then copy it back.

---

# 26. Recommended browsing workflow

For interactive browsing:

```bash
sudo mkdir -p /mnt/borg
```

```bash
borg mount "$REPOSITORY" /mnt/borg
```

Then:

```bash
ls /mnt/borg
```

Browse the selected archive:

```bash
cd /mnt/borg/folder-2026-09-07_22-30-00
```

Copy whatever is required.

When finished:

```bash
cd /
borg umount /mnt/borg
```

This is often the most convenient way to access historical versions of files.

---

# 27. Quick reference

## Set environment

```bash
export BORG_RSH="ssh -i /root/.ssh/borgwarehouse"
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"
export REPOSITORY="ssh://borgwarehouse@backup.example.com:22/./YOUR_REPOSITORY"
```

## List backups

```bash
borg list "$REPOSITORY"
```

## Show archive contents

```bash
borg list \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

## Show archive information

```bash
borg info \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

## Restore one file

```bash
mkdir -p /tmp/borg-restore
cd /tmp/borg-restore

borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-30-00" \
    srv/data/path/to/file
```

## Restore entire archive

```bash
mkdir -p /tmp/borg-restore
cd /tmp/borg-restore

borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

## Mount all backups

```bash
sudo mkdir -p /mnt/borg

borg mount \
    "$REPOSITORY" \
    /mnt/borg
```

## Unmount

```bash
borg umount /mnt/borg
```

## Check repository

```bash
borg check "$REPOSITORY"
```

## Test archive readability

```bash
borg extract \
    --dry-run \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

---

# 28. Recovery checklist

For a full disaster recovery:

```text
[ ] Install BorgBackup
[ ] Obtain BorgWarehouse repository URL
[ ] Configure an authorized SSH key
[ ] Obtain the Borg repository passphrase
[ ] Set BORG_RSH
[ ] Set BORG_PASSCOMMAND
[ ] Set REPOSITORY
[ ] Run borg list
[ ] Select the required archive
[ ] Restore into a temporary directory
[ ] Verify the restored data
[ ] Copy required data back into production
```

The most important command to verify recovery access is:

```bash
borg list "$REPOSITORY"
```

If that works and the repository passphrase is correct, you can inspect, mount, and restore the available Borg archives.
