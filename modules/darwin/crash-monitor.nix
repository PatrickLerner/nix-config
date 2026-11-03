{ pkgs, ... }:

let
  dir = "/Library/Logs/crash-monitor";

  # Kernel counters every 10s, top open-file and memory holders every minute.
  # Debugs the recurring decmpfs ENFILE SIGBUS (launchd panic / loginwindow logout).
  sampler = pkgs.writeScript "crash-monitor" ''
    #!/bin/bash
    mkdir -p ${dir}
    chmod 755 ${dir}
    chmod 644 ${dir}/*.log 2>/dev/null
    f="${dir}/$(date +%F).log"
    s() { /usr/sbin/sysctl -n "$1" 2>/dev/null; }
    swap=$(s vm.swapusage | sed -E 's/.*used = ([0-9.]+M).*/\1/')
    procs=$(/usr/bin/top -l 1 -n 0 | sed -nE 's/^Processes: ([0-9]+) total.* ([0-9]+) threads.*/procs=\1 threads=\2/p')

    echo "$(date '+%F %T') vn=$(s kern.num_vnodes) vn_free=$(s kern.free_vnodes)" \
      "vn_recycled=$(s kern.num_recycledvnodes) vn_new=$(s vfs.vnstats.num_newvnode_calls)" \
      "files=$(s kern.num_files) $procs" \
      "pressure=$(s kern.memorystatus_vm_pressure_level) free_pages=$(s vm.page_free_count)" \
      "compressor=$(s vm.compressor_bytes_used) swap=$swap" >> "$f"

    if [ $(( $(date +%s) / 10 % 6 )) -eq 0 ]; then
      {
        echo "$(date '+%F %T') top_fds:"
        /usr/sbin/lsof -n -P -Fpcf 2>/dev/null | awk '
          /^p/ { pid = substr($0, 2) }
          /^c/ { cmd[pid] = substr($0, 2) }
          /^f/ { n[pid]++ }
          END { for (p in n) print n[p], p, cmd[p] }' | sort -rn | head -8 | sed 's/^/  /'
        echo "$(date '+%F %T') top_mem:"
        /usr/bin/top -l 1 -o mem -n 8 -stats pid,command,mem | tail -8 | sed 's/^/  /'
      } >> "$f"
      find ${dir} -name '*.log' -mtime +14 -delete
    fi
  '';
in
{
  launchd.daemons.crash-monitor = {
    serviceConfig = {
      Label = "com.patrick.crash-monitor";
      # See portless-proxy.nix: wait for the Nix volume at boot.
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/bin/wait4path '${sampler}' && exec '${sampler}'"
      ];
      StartInterval = 10;
      # 022, so the logs stay readable without sudo.
      Umask = 18;
      RunAtLoad = true;
      StandardErrorPath = "${dir}/stderr.log";
    };
  };
}
