# rtm_deploy
Remotely deploy AMD software updates

## Usage

### rtm_deploy.sh 

`rtm_deploy.sh [-h] [-d] [-E|-e] [-R|r] [-s hh:mm|+m|now] -a amdaddress -f deployfile [-u user] [-p password | -i identfile]`

**Help**

`-h` Usage help.

`-d` Verbose debug logging for the script itself and SCP/SSH.



**Required parameters**

`-a address` AMD to deploy to, supports IP addresses and FQDNs. Required.

`-f deployfile` Full path to upgrade.bin file to copy and execute on AMD. Required.



**Authentication**

These are all optional, if none are specified script will try your logged on users private keys automatically, then fallback to the script default user/password.

`-u user` with root or sudo rights to copy and execute upgrade file. Default root.

`-p password` for user. Default greenmouse.

`-i identfile` SSH private key identity file.


`-p` and `-i` are exclusive, `-i` takes precedence as it is more secure.


*Note:* this is all Linux OS credentials, not DCRUM/CSS credentials.



**Post copy execution**

`-e` Execute upgrade once copied. Default.

`-E` DO NOT Execute upgrade once copied. Use this if you're wanting to copy a non-upgrade package.



**Post upgrade reboot**

These have no effect if exeuction is disabled with `-E`

`-r` Reboot after upgrade complete. Default.

`-R` DO NOT reboot after upgrade completes.

`-s` Reboot schedule 'hh:mm' 24hr clock, '+m' m minutes from now, or 'now'. Default 'now'. (No effect with `-R`)



e.g.

`-s now` will reboot as soon as the upgrade package is done, this is the default behaviour.

`-s +15` will reboot 15 minutes after upgrade package is done.

`-s 23:59` will postpone reboot until 23:59 (AMD time).



**Returns**

Return code `0` indicates success, `1` indicates failure, printed messages indicate failure.



## Dependencies

- bash
- scp
- ssh
- sshpass (only if you want to use regular passwords for authentication).



No additional dependencies requried and nothing to install/configure on the AMD.



## Tested Platform

- CentOS 7
- RHEL 7



