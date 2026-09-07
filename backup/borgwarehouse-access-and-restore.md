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

---

# 29. Disaster recovery when BorgWarehouse is completely unavailable

This section covers the worst-case recovery scenario:

```text
BorgWarehouse application:    LOST
BorgWarehouse database:       LOST
BorgWarehouse configuration:  LOST
Original Debian client:       LOST

Available:
    Raw BorgWarehouse repository files
    Borg repository passphrase
```

For the setup documented in this guide, the repository was initialized using:

```bash
borg init --encryption=repokey-blake2
```

This is important because with `repokey-blake2`, the encrypted Borg encryption key is stored inside the Borg repository itself.

Therefore, if the raw repository files are intact, you do **not** need a working BorgWarehouse installation to restore the backups.

You need:

```text
1. The complete raw Borg repository directory
2. The Borg repository passphrase
3. A machine with a compatible BorgBackup 1.x installation
```

The SSH key previously used to reach BorgWarehouse is not required when opening a copied repository directly from the local filesystem.

The BorgWarehouse database is also not required to decrypt or restore a Borg repository.

> If the repository used `keyfile` or `keyfile-blake2` encryption instead of `repokey-blake2`, the external Borg key file would also be required. Raw repository files alone would not be sufficient.

---

## 29.1 Where BorgWarehouse stores the raw repositories

BorgWarehouse stores raw Borg repositories in its `repos` storage.

For a bare-metal installation, the standard location is:

```text
/home/borgwarehouse/repos
```

For Docker, this is the storage mounted as the BorgWarehouse:

```text
repos
```

volume.

If BorgWarehouse was configured to use external storage, an individual repository may instead reside on that external filesystem, with BorgWarehouse referring to it from the main repository pool.

The exact original BorgWarehouse directory structure is not important for recovery. What matters is locating the root directory of each Borg repository.

---

## 29.2 Do not work on the only surviving copy

Before doing anything else, make a copy of the surviving BorgWarehouse repository data.

For example, if the recovered storage is mounted read-only at:

```text
/mnt/recovered-borgwarehouse
```

create a working copy:

```bash
mkdir -p /recovery/borg-repositories
```

Then copy the data:

```bash
rsync -aHAX --numeric-ids \
    /mnt/recovered-borgwarehouse/ \
    /recovery/borg-repositories/
```

Keep the original recovered storage untouched if possible.

The recovery layout should therefore be:

```text
Original recovered storage
        │
        └── kept unchanged

Working copy
        │
        └── used for Borg recovery
```

Do not run repair operations against the only surviving copy of the repository.

---

## 29.3 Identify the Borg repository directory

A Borg 1.x repository is a filesystem directory containing files such as:

```text
README
config
data/
hints.*
index.*
```

Depending on its state, lock files or other repository files may also be present.

The most important items are:

```text
config
data/
```

The `config` file contains a repository section resembling:

```ini
[repository]
version = 1
segments_per_dir = 1000
max_segment_size = 524288000
id = <repository-id>
```

The repository ID is intrinsic to the Borg repository and remains the same even if the repository directory is moved to another filesystem or machine.

A BorgWarehouse repository directory might therefore look approximately like:

```text
/recovery/borg-repositories/
└── 4e7f816e/
    ├── README
    ├── config
    ├── data/
    ├── hints.123
    └── index.123
```

The BorgWarehouse directory name itself is not what Borg uses cryptographically. The Borg repository metadata inside the directory identifies the repository.

---

## 29.4 Search automatically for Borg repositories

If you have a large raw BorgWarehouse data tree and do not know which directory contains the repository, search for Borg repository configuration files.

For example:

```bash
find /recovery/borg-repositories \
    -type f \
    -name config \
    -print
```

Then inspect likely candidates:

```bash
cat /recovery/borg-repositories/4e7f816e/config
```

A Borg 1.x repository configuration should contain:

```text
[repository]
```

and an:

```text
id =
```

entry.

A more targeted search is:

```bash
grep -RIl \
    '^\[repository\]$' \
    /recovery/borg-repositories
```

For each result, verify that its parent directory also contains:

```text
data/
```

For example:

```bash
ls -lah /recovery/borg-repositories/4e7f816e
```

---

## 29.5 Install BorgBackup on the recovery machine

On a Debian recovery machine:

```bash
sudo apt update
sudo apt install borgbackup
```

Check the installed version:

```bash
borg --version
```

Because the repository in this guide was created with Borg 1.x, use BorgBackup 1.x for the initial recovery where possible.

For example:

```text
borg 1.4.x
```

Avoid changing or migrating the repository until you have successfully listed and restored the data.

---

## 29.6 Open the raw repository directly

Assume you have identified this directory as the repository:

```text
/recovery/borg-repositories/4e7f816e
```

Set:

```bash
export REPOSITORY="/recovery/borg-repositories/4e7f816e"
```

Because the repository is now local, do **not** use the old BorgWarehouse SSH repository URL.

You no longer need:

```text
BORG_RSH
```

for this recovery.

The local repository path itself is enough:

```bash
borg info "$REPOSITORY"
```

or:

```bash
borg list "$REPOSITORY"
```

Borg will ask for the repository passphrase unless it is supplied through another supported mechanism.

---

## 29.7 Supply the Borg passphrase

For an interactive disaster recovery, the safest simple option is to allow Borg to prompt for the passphrase:

```bash
borg list "$REPOSITORY"
```

Enter the original Borg passphrase when requested.

Alternatively, create a temporary protected passphrase file:

```bash
mkdir -p /root/.config/borg
chmod 700 /root/.config/borg
nano /root/.config/borg/passphrase
chmod 600 /root/.config/borg/passphrase
```

Then:

```bash
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"
```

Now run:

```bash
borg list "$REPOSITORY"
```

Do not leave recovery passphrases in insecure shell scripts or world-readable files.

---

## 29.8 Why the raw repository is enough with repokey-blake2

The documented setup uses:

```text
repokey-blake2
```

With this mode, Borg stores the encrypted repository key inside the repository.

Conceptually:

```text
Raw Borg repository
│
├── repository data
├── repository metadata
└── encrypted Borg key
          │
          └── unlocked by the Borg passphrase
```

Therefore the recovery chain is:

```text
Raw repository
    +
Borg passphrase
    ↓
Borg can decrypt the repository
    ↓
Archives can be listed
    ↓
Files can be restored
```

You do not need:

```text
BorgWarehouse web application
BorgWarehouse database
BorgWarehouse SSH configuration
Original BorgWarehouse repository alias
Original backup client cache
Original backup client's SSH key
```

to read a complete local copy of a `repokey-blake2` repository.

---

## 29.9 What happens if the original Borg client configuration is gone

The original client may previously have contained:

```text
~/.config/borg/security/
~/.cache/borg/
```

Losing those directories does not normally prevent restoring a `repokey` repository.

When Borg accesses the repository from a new machine, it may create new local cache/security information or display repository security warnings.

Read such warnings carefully and confirm that you are opening the expected recovered repository.

For a disaster-recovery operation, the critical secrets are the repository encryption key and passphrase. With `repokey-blake2`, the encrypted key is inside the repository.

---

## 29.10 First test: list the archives

Once the repository and passphrase are available:

```bash
export REPOSITORY="/recovery/borg-repositories/4e7f816e"
```

Then:

```bash
borg list "$REPOSITORY"
```

A successful result might look like:

```text
folder-2026-09-05_12-00-00
folder-2026-09-05_12-05-00
folder-2026-09-06_18-30-00
folder-2026-09-07_22-30-00
```

At this point, the BorgWarehouse application is irrelevant to restoration. Borg is reading the repository directly.

---

## 29.11 Check repository information

Run:

```bash
borg info "$REPOSITORY"
```

This verifies that Borg recognizes the directory as a repository and can access its encrypted metadata.

You can also inspect a particular archive:

```bash
borg info \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

---

## 29.12 Check the recovered repository

Before doing a large restoration, run a repository check:

```bash
borg check "$REPOSITORY"
```

If the repository is large, this may take significant time and perform substantial disk I/O.

If the raw repository was recovered from damaged storage, work from a copied repository and preserve the original raw recovery source.

Do not immediately use destructive repair options simply because a normal check reports a problem.

---

## 29.13 Test archive readability without restoring

Choose an archive:

```text
folder-2026-09-07_22-30-00
```

Run:

```bash
borg extract \
    --dry-run \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

This verifies that Borg can walk through the archive contents without writing the restored files to disk.

---

## 29.14 Restore files from the raw repository

Create a destination:

```bash
mkdir -p /recovery/restored
cd /recovery/restored
```

List the archive:

```bash
borg list \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

Restore the whole archive:

```bash
borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

If the original backup source was:

```text
/srv/data
```

the restored data will normally appear as:

```text
/recovery/restored/srv/data
```

---

## 29.15 Restore only one file

First find the archived path:

```bash
borg list \
    "${REPOSITORY}::folder-2026-09-07_22-30-00" \
    | grep 'report.pdf'
```

Suppose the path is:

```text
srv/data/documents/report.pdf
```

Restore it:

```bash
cd /recovery/restored

borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-30-00" \
    srv/data/documents/report.pdf
```

The result will be:

```text
/recovery/restored/srv/data/documents/report.pdf
```

---

## 29.16 Mount the recovered raw repository

If FUSE is available, you can browse the raw repository interactively.

Install FUSE support:

```bash
sudo apt install fuse3
```

Create a mount point:

```bash
mkdir -p /mnt/borg-recovery
```

Mount:

```bash
borg mount \
    "$REPOSITORY" \
    /mnt/borg-recovery
```

List archives:

```bash
ls -lah /mnt/borg-recovery
```

Browse one archive:

```bash
cd /mnt/borg-recovery/folder-2026-09-07_22-30-00
```

When finished:

```bash
cd /
borg umount /mnt/borg-recovery
```

---

## 29.17 Multiple raw BorgWarehouse repositories

If BorgWarehouse contained several repositories, the recovered `repos` directory might contain multiple repository directories.

For example:

```text
/recovery/borg-repositories/
├── 4e7f816e/
│   ├── config
│   └── data/
│
├── a13d920f/
│   ├── config
│   └── data/
│
└── d7c31284/
    ├── config
    └── data/
```

Without the BorgWarehouse database, friendly aliases may be gone.

That does not prevent recovery.

Test each repository independently:

```bash
borg list /recovery/borg-repositories/4e7f816e
```

```bash
borg list /recovery/borg-repositories/a13d920f
```

```bash
borg list /recovery/borg-repositories/d7c31284
```

The archive names and contents should make it possible to determine which repository corresponds to which original server or dataset.

You can also read the repository ID:

```bash
borg config \
    /recovery/borg-repositories/4e7f816e \
    id
```

---

## 29.18 External-storage BorgWarehouse repositories

BorgWarehouse can place individual repositories on external storage.

In that case, the main BorgWarehouse `repos` directory may have contained a link or reference to storage mounted elsewhere.

If the central BorgWarehouse filesystem is gone but the external storage survived, search that external storage directly for Borg repositories.

For example:

```bash
find /mnt/backup-storage \
    -type f \
    -name config \
    -print
```

Then inspect likely candidates for:

```text
[repository]
```

and confirm that their parent directory contains:

```text
data/
```

Once found, access them directly with a local Borg path:

```bash
export REPOSITORY="/mnt/backup-storage/path/to/repository"

borg list "$REPOSITORY"
```

The repository does not have to be located at its original BorgWarehouse path in order to be read by Borg.

---

## 29.19 If Borg reports a stale lock

A repository copied after a crash may contain stale lock information.

First make sure no other Borg process is accessing the working copy.

Check:

```bash
ps aux | grep '[b]org'
```

If you are certain the recovered working copy is not in use elsewhere, Borg provides:

```bash
borg break-lock "$REPOSITORY"
```

Use this only after confirming that no Borg process is legitimately using that repository copy.

Do not use `break-lock` casually on a live repository shared by another Borg client.

---

## 29.20 If `borg check` reports corruption

The safest order is:

```text
1. Stop modifying the repository
2. Preserve the original raw files
3. Create another working copy
4. Run normal borg check
5. Determine the extent of corruption
6. Attempt repair only against a disposable working copy
```

Do not start with a destructive repair command against the sole surviving repository.

For example:

```bash
rsync -aHAX --numeric-ids \
    /recovery/borg-repositories/4e7f816e/ \
    /recovery/borg-repositories/4e7f816e-repair-copy/
```

Then investigate the copied repository:

```bash
borg check \
    /recovery/borg-repositories/4e7f816e-repair-copy
```

If advanced repair becomes necessary, consult the Borg documentation matching the exact Borg version before proceeding.

---

## 29.21 If you have the raw repository but not the passphrase

For the setup in this guide:

```text
Encryption mode: repokey-blake2
```

the Borg key stored in the repository is encrypted with the passphrase.

Therefore:

```text
Raw repository + correct passphrase = recoverable

Raw repository without passphrase = encrypted data cannot normally be restored
```

The BorgWarehouse application or database does not contain a magic replacement for the Borg encryption passphrase.

This is why the passphrase must be backed up separately from the server and BorgWarehouse installation.

---

## 29.22 If the repository used keyfile encryption

This guide originally specifies:

```text
repokey-blake2
```

so this subsection normally does not apply.

However, if a different repository was initialized with:

```text
keyfile
```

or:

```text
keyfile-blake2
```

the encryption key is stored outside the repository, normally in the Borg client configuration.

In that case you require both:

```text
Raw Borg repository
+
Borg key file
+
Key passphrase
```

A raw keyfile-encrypted repository by itself is not sufficient.

This is one reason `repokey-blake2` is convenient for disaster recovery when the passphrase is securely stored elsewhere.

---

## 29.23 Recommended full disaster-recovery procedure

Assume everything except the raw BorgWarehouse storage has been lost.

### Step 1 — Attach the surviving storage

Mount it read-only if possible:

```text
/mnt/recovered-borgwarehouse
```

### Step 2 — Create a working copy

```bash
mkdir -p /recovery/borg-repositories

rsync -aHAX --numeric-ids \
    /mnt/recovered-borgwarehouse/ \
    /recovery/borg-repositories/
```

### Step 3 — Find Borg repository roots

```bash
grep -RIl \
    '^\[repository\]$' \
    /recovery/borg-repositories
```

Confirm each candidate contains:

```text
config
data/
```

### Step 4 — Install Borg 1.x

```bash
sudo apt update
sudo apt install borgbackup
```

Check:

```bash
borg --version
```

### Step 5 — Select the repository

For example:

```bash
export REPOSITORY="/recovery/borg-repositories/4e7f816e"
```

### Step 6 — Supply the original Borg passphrase

Either enter it interactively when Borg asks or securely configure:

```bash
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"
```

### Step 7 — List archives

```bash
borg list "$REPOSITORY"
```

### Step 8 — Check repository access

```bash
borg info "$REPOSITORY"
```

Optionally:

```bash
borg check "$REPOSITORY"
```

### Step 9 — Test one archive

```bash
borg extract \
    --dry-run \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

### Step 10 — Restore to a new directory

```bash
mkdir -p /recovery/restored
cd /recovery/restored

borg extract \
    "${REPOSITORY}::folder-2026-09-07_22-30-00"
```

### Step 11 — Verify the restored data

For example:

```bash
ls -lah /recovery/restored
```

Check important files before putting anything back into production.

---

## 29.24 Minimal emergency cheat sheet

If you know the raw repository directory and have the passphrase, the essential recovery can be as short as:

```bash
sudo apt install borgbackup
```

```bash
export REPOSITORY="/path/to/raw/borg/repository"
```

```bash
borg list "$REPOSITORY"
```

Enter the repository passphrase.

Then:

```bash
mkdir -p /recovery/restored
cd /recovery/restored
```

```bash
borg extract \
    "${REPOSITORY}::folder-YYYY-MM-DD_HH-MM-SS"
```

That is the fundamental disaster-recovery path.

BorgWarehouse itself does not have to be running.

---

# 30. Raw-repository recovery checklist

```text
[ ] Preserve the original recovered BorgWarehouse files
[ ] Create a working copy
[ ] Locate the Borg repository root
[ ] Confirm the directory contains config and data/
[ ] Install a compatible BorgBackup 1.x client
[ ] Use the repository as a local filesystem path
[ ] Obtain the original Borg passphrase
[ ] Run borg list
[ ] Run borg info
[ ] Optionally run borg check
[ ] Test an archive with borg extract --dry-run
[ ] Restore into a separate recovery directory
[ ] Verify restored files before returning them to production
```

For the `repokey-blake2` configuration documented in this guide, the core disaster-recovery requirement is:

```text
COMPLETE RAW BORG REPOSITORY
            +
      BORG PASSPHRASE
            ↓
       RESTORABLE DATA
```

## References

- BorgWarehouse documentation: raw repositories are stored in the `repos` storage; bare-metal installations use `/home/borgwarehouse/repos`, while Docker uses the `repos` volume:
  https://borgwarehouse.com/docs/admin-manual/external-storage/

- BorgWarehouse documentation for repository import and raw Borg repository placement:
  https://borgwarehouse.com/docs/admin-manual/import-old-repo/

- BorgBackup 1.x repository structure:
  https://borgbackup.readthedocs.io/en/1.4.4/internals/data-structures.html

- BorgBackup encryption documentation: `repokey` and `repokey-blake2` store the encrypted key inside the repository:
  https://borgbackup.readthedocs.io/en/stable/usage/init.html

- BorgBackup FAQ regarding client security information and key storage:
  https://borgbackup.readthedocs.io/en/stable/faq.html

