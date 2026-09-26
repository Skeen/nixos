# Mobile NixOS stage-1 task (mruby), see ./hardware.nix.
#
# Stage-1 starts `systemd-udevd --daemon` and immediately runs
# `udevadm trigger`, which can fire before udevd listens, so the coldplug
# events are lost and no /dev/disk/by-* links appear. This re-runs coldplug.
# Stage-1 runs one ready task per loop in name order and nothing waits on
# this task, so it only gets a turn once nothing else can run (e.g. every
# task waiting on a missing device); on a good boot it may never run.
class Tasks::UDevRetrigger < SingletonTask
  def initialize()
    add_dependency(:Task, Tasks::UDev.instance)
  end

  def run()
    sleep(0.5)
    System.run("udevadm", "trigger", "--action=add")
    System.run("udevadm", "settle")
  end
end
