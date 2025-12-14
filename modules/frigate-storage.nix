# Frigate storage: mergerfs + sync script + cron
{ config, lib, pkgs, ... }:

let
  # Script frigate-sync en Python
  frigate-sync = pkgs.writeScriptBin "frigate-sync" ''
    #!${pkgs.python3}/bin/python3
    """
    Frigate Storage Sync Script (v4.2 - NixOS)
    Syncs old files from SSD cache to NAS
    """

    import os
    import sys
    import time
    import logging
    import subprocess
    import fcntl
    from pathlib import Path
    import tempfile

    # Configuration
    CONFIG = {
        "SSD_PATH": Path("/mnt/ssd/frigate"),
        "TRUENAS_MOUNT": Path("/mnt/truenas/frigate"),
        "LOG_DIR": Path("/var/log/frigate"),
        "SYNC_LOG": Path("/var/log/frigate/sync.log"),
        "SYNC_LOCK": Path("/var/run/frigate-sync.lock"),
        "MAX_FILE_AGE": 24,  # hours
    }

    def setup_logging():
        CONFIG["LOG_DIR"].mkdir(parents=True, exist_ok=True)
        logging.basicConfig(
            level=logging.INFO,
            format='[%(asctime)s] %(levelname)s: %(message)s',
            handlers=[
                logging.FileHandler(CONFIG["SYNC_LOG"]),
                logging.StreamHandler(sys.stdout)
            ]
        )

    def find_old_files(src_dir: Path, max_age_hours: int) -> tuple:
        max_age_minutes = max_age_hours * 60
        temp_file = tempfile.NamedTemporaryFile(delete=False, mode='w', dir='/tmp', prefix='frigate_sync_')
        find_cmd = f"find . -type f -mmin +{max_age_minutes}"
        try:
            subprocess.run(
                find_cmd, shell=True, check=True, cwd=src_dir,
                stdout=temp_file, stderr=subprocess.PIPE, text=True
            )
            temp_file.close()
            file_count, total_size = 0, 0
            with open(temp_file.name, 'r') as f:
                for line in f:
                    relative_path = line.strip().lstrip('./')
                    file_path = src_dir / relative_path
                    if file_path.exists():
                        file_count += 1
                        total_size += file_path.stat().st_size
            if file_count > 0:
                logging.info(f"Found {file_count} files to transfer.")
            return temp_file.name, file_count
        except subprocess.CalledProcessError as e:
            logging.error(f"'find' command failed: {e.stderr}")
            os.unlink(temp_file.name)
            raise

    def sync_directory(src_dir: Path, dest_dir: Path, files_list_path: str, file_count: int):
        if file_count == 0:
            if os.path.exists(files_list_path): os.unlink(files_list_path)
            logging.info(f"No files to transfer in {src_dir.name}.")
            return

        dest_dir.mkdir(parents=True, exist_ok=True)

        rsync_cmd = [
            '${pkgs.rsync}/bin/rsync', '--archive', '--no-owner', '--no-group', '--info=progress2',
            '--files-from=' + files_list_path, '--prune-empty-dirs', '--remove-source-files',
            str(src_dir) + '/', str(dest_dir) + '/'
        ]

        try:
            result = subprocess.run(rsync_cmd, timeout=3600, capture_output=True, text=True, check=False)

            if result.returncode == 0:
                logging.info(f"Sync completed successfully for {src_dir.name}")
            elif result.returncode in [23, 24]:
                logging.warning(f"Sync completed with warnings for {src_dir.name} (code {result.returncode})")
            else:
                logging.error(f"Rsync failed for {src_dir.name} (code {result.returncode})")
                if result.stderr:
                    logging.error(f"Rsync stderr: {result.stderr.strip()}")
                raise subprocess.CalledProcessError(result.returncode, rsync_cmd)

            for dirpath, _, _ in os.walk(str(src_dir), topdown=False):
                try:
                    if not os.listdir(dirpath):
                        os.rmdir(dirpath)
                except OSError:
                    pass

        except subprocess.TimeoutExpired:
            logging.error(f"Rsync timeout for {src_dir.name} after 1 hour")
            raise
        finally:
            if os.path.exists(files_list_path):
                os.unlink(files_list_path)

    def main():
        setup_logging()
        lock_file = open(CONFIG["SYNC_LOCK"], 'w')
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except IOError:
            logging.error("Another sync process is running. Aborting.")
            return 1

        exit_code = 0
        try:
            logging.info("--- Starting Frigate Sync Process ---")
            if not CONFIG["TRUENAS_MOUNT"].is_mount():
                logging.error(f"NAS not mounted at {CONFIG['TRUENAS_MOUNT']}. Aborting.")
                return 1

            for subdir in ['clips', 'recordings', 'exports']:
                src_dir = CONFIG["SSD_PATH"] / subdir
                if not src_dir.exists():
                    logging.info(f"Directory {src_dir} does not exist, skipping.")
                    continue

                logging.info(f"--- Processing directory: {subdir} ---")
                files_list_path, file_count = find_old_files(src_dir, CONFIG["MAX_FILE_AGE"])
                sync_directory(src_dir, CONFIG["TRUENAS_MOUNT"] / subdir, files_list_path, file_count)

            logging.info("--- Sync process completed successfully ---")
        except Exception as e:
            logging.error(f"An unexpected error occurred: {e}", exc_info=True)
            exit_code = 1
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
            lock_file.close()

        return exit_code

    if __name__ == "__main__":
        sys.exit(main())
  '';
in
{
  # Packages nécessaires
  environment.systemPackages = with pkgs; [
    mergerfs
    rsync
  ];

  # Créer les dossiers
  systemd.tmpfiles.rules = [
    "d /mnt/ssd/frigate 0755 frigate dockerservices -"
    "d /mnt/ssd/frigate/clips 0755 frigate dockerservices -"
    "d /mnt/ssd/frigate/recordings 0755 frigate dockerservices -"
    "d /mnt/ssd/frigate/exports 0755 frigate dockerservices -"
    "d /mnt/frigate_union 0755 frigate dockerservices -"
    "d /var/log/frigate 0755 root root -"
  ];

  # Utilisateur et groupe frigate
  users.users.frigate = {
    isSystemUser = true;
    group = "dockerservices";
    uid = 1001;
  };

  users.groups.dockerservices = {
    gid = 1001;
  };

  # Mount mergerfs
  fileSystems."/mnt/frigate_union" = {
    device = "/mnt/ssd/frigate:/mnt/truenas/frigate";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "cache.files=off"
      "dropcacheonclose=true"
      "category.create=ff"
      "nonempty"
      "fsname=frigate_union"
      "minfreespace=10G"
      "async_read=false"
      "posix_acl=false"
      "xattr=passthrough"
    ];
  };

  # Script frigate-sync dans le PATH
  environment.systemPackages = [ frigate-sync ];

  # Cron job - sync à 1h du matin
  services.cron = {
    enable = true;
    systemCronJobs = [
      "0 1 * * * root ${frigate-sync}/bin/frigate-sync > /var/log/frigate-sync.log 2>&1"
    ];
  };
}
