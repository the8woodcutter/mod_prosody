This module helps operators of other servers notice when there is a problem with their DNS, firewall, port forwarding or other connectivity issue.
If their server manages to establish a connection in yours, but your server can't connect back, this module closes the first connection with an error.
Hopefully that error shows up in the logs on the other end, where the operator can notice and attempt to resolve the issues.

  Prosody version          status
  ------------------------ --------------------------
  trunk as of 2025-12-31   This feature is included
  13.0                     Works
  0.12                     Not tested
