# A Bash-Based Server Control Daemon

This repository contains the source code for a server control daemon, written in bash. Unlike most server control daemons, it does NOT rely on a web UI even a GUI of any kind. Instead, everything is done via files. SSH is used as the backend to actually communicate with devices.

## How does it work?

There are two folders. The "triggers" folder, which can be thought of as the "input", and the "logs" folder, which can be thought of as the "output". You can create a file in the triggers folder, and the bash daemon will process it, with the output being a log file in the "output" folder.

The format of the file is `[command]_[argument]`. The command is simply the command you want to do. Note that the "command" is not any arbitrary command. It must be specified in the bash file. The current list is:

- wake (via wol command)
- ssh (file content is the actual command you want to run).
- update (needs wrapper script on device and root)
- reboot
- shutdown
- sleep
- snapshot (btrfs)
- scrub (btrfs)
- uptime
- ping
- unlock (not a session unlock; it's a remote luks decryption utility. The file content is the encrypted gpg file containing the password. As a result, you must have the private key on the device you are running the script with).

And the argument can be an ip address for ping, a MAC address (for wake), or a ssh username + ip for everything else.

So, for example, if you wanted to update your server, you can touch the file `update_[username@server ip address]` into the triggers folder. The resulting log will appear in the logs folder when done.

For SSH, you can do `echo [actual command] > ssh_[username@server_ip_address]` to execute that command remotely. Note that you cannot run things interactively.

For LUKS unlock, you can just run `cp [gpg file] [triggers folder]/unlock_[username@server_ip_address]`.

## Execution

To run this script, you do need to specify a valid directory where the script will search in. The directory will be considered your control directory.

## Mappings

You can actually map devices. So, instead of using `[username@server_ip_address]`, you can use a friendlier name instead.

The format is:

```
servername=sshaddress
servername=macaddress
```

Each mapping uses two lines. So for example, if you want to refer to a server using the name "server1", the file will look like this:

```
server1=[username@ip_address]
server1=[mac_address]
```

And obviously, you must grab the information yourself. Name the file "hostnames.txt" in the same directory as where the script points to.

## Email

Yes, this script has email support via msmtp. You can literally email yourself logs and statuses.

The emailer script is provided, but you also must fill out emails.txt.

All it needs to contain is something like this:

```
to [your email]
from [other email, can match the one from whatever msmtp config you have]
```

## But why?

Here's the thing: Most "normal" server administration programs need Web UIs and other open ports. What do those need if you want to access those from the internet? A static IP, a VPN, a Dynamic DNS service, Wireguard, Tailscale, or Zerotier. I did not want to use any of these, as they are either paid or highly complex. Instead, I went with [Syncthing](https://syncthing.net/), which has relays that get around Network Address Translation. I was already using Syncthing for other things, so why not?

Syncthing would sync the entire directory which I specify with the script. If I edit the triggers directory by placing a file, Syncthing will sync it to the "control server", and the bash daemon can process it. Then, when it's deleted and the log file exists, Syncthing syncs the stuff back.

Now, of course it can be any protocol, not just Syncing. Because of how it uses files, it can work with anything. NFS, Samba, even Plan 9 shares.

## How can I make it useful?

Beyond using it with something that can share/sync files, you can also use it with cron. Instead of just having many cron jobs on every server and a cron daemon on every server, what you would have is the "control server" running your cron daemon, and the cron daemon just makes files (for example, it can run "echo [command] > [triggers folder]/ssh_[whatever your server is called]". The bash daemon will see it instantly (as it's local) and process it almost immediately. It's not good for highly time-sensitive tasks, but it's good enough for most cases.

You can also use it for power-saving too when combined with cron. Just put a computer to sleep at a given time, and then wake it up at another time. This script does support both putting a computer to sleep and waking it, and if your computer can Wake-on-LAN from shutdown, the computer supports that too.

## What do you use it for?

Mainly just automatically doing tasks on various computers (all of them are Syncthing nodes) and notifying me if anything's wrong via the email script. However, I do occasionally use it for remote stuff via the internet.

## How can I get it?

Just `git clone` the repo. There aren't really any "releases" in the normal sense, since it's literally a bash script. You really only need bash and some basic core utilities. You also need doas on your servers you are trying to control (feel free to replace it with sudo if you use that instead).


