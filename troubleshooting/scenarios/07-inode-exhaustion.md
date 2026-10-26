# 07 — Inode exhaustion: "No space left on device" with 99% free

Date: 2026-10-26 · Time to resolve: ~15 min · Detected by: drill (break/01-disk.sh)

## Symptom
echo hi > /mnt/labdata/test.txt → bash: /mnt/labdata/test.txt: No space left on device.
df -h /mnt/labdata shows 1% used, 170M available.

## Investigation
1. df -h /mnt/labdata — plenty of bytes free, so the error message is misleading at first glance.
2. df -i /mnt/labdata — 128 128 0 100%: every inode on the filesystem is in use.
3. find /mnt/labdata -xdev -type f | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn | head
   — 114 files in a single hidden directory /mnt/labdata/.cache/sessions/.

Dead end: first ran the write as a regular user and got Permission denied — even with sudo the redirect is opened by the unprivileged shell. Switched to sudo -i and got the real error.

## Root cause
The filesystem ran out of inodes, not bytes. A session cache wrote hundreds of tiny files;
the filesystem was created with a very small inode table (mkfs.ext4 -N 128), so it hit the
limit while almost all space was still free.

## Fix
rm -rf /mnt/labdata/.cache/sessions → --verify passed.
This is a workaround: the cache will fill up again unless rotated.

## Prevention / detection
- Alert on inodes, not only bytes: node_exporter exposes node_filesystem_files_free
  and node_filesystem_files; add a rule like
  node_filesystem_files_free / node_filesystem_files * 100 < 10.
- Size the inode table for the workload when creating the filesystem (mkfs -N / -i);
  cache and session directories need many inodes, not many bytes.
- Rotate or expire session files (tmpfiles.d / cron with find -mtime).

## Lessons
- "No space left on device" means bytes OR inodes; df -h and df -i are both step one.
- Hidden directories are where this lives — find with -xdev, not ls.
- sudo cmd > file does not sudo the redirect.

