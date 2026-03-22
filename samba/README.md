# Samba

#### adctl

Front-end to Samba AD DC that combines various tools into a single, consistent interface for managing accounts, Kerberos principals (SPNs), and keytabs, while hiding Samba quirks and enabling fast, scriptable workflows.

__Example:__

```sh
$ adctl account add myserver$ --nfs --cifs
Creating computer account: myserver$
Adding HOST/myserver → myserver$
Adding HOST/myserver.domain.com → myserver$
Adding nfs/myserver → myserver$
Adding nfs/myserver.domain.com → myserver$
Adding cifs/myserver → myserver$
Adding cifs/myserver.domain.com → myserver$

```

```sh
$ adctl account show myserver$
Account: myserver$
Type:    computer
DN:      CN=myserver,CN=Computers,DC=cloudhome,DC=dk
UAC:     4096
KVNO:    2
SPNs:
  HOST/myserver
  HOST/myserver.domain.com
  nfs/myserver
  nfs/myserver.domain.com
  cifs/myserver
  cifs/myserver.domain.com
```

```sh
$ adctl account list
krbtgt               user
Guest                user
AUTH$                user
Administrator        user
myserver$            computer
```

