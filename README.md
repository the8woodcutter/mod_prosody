# mod_prosody - GIT of Prosody Community Modules
## Author: <a href="https://the8woodcutter.vip" target="_blank">The 8 Woodcutter</a>

## Details:
- `mod_prosody` is my GIT, jagged fork, of the Prosody Community Modules which are in the version control form of mercurial, not GIT.
- Included subdirectory `prosody-modules` contents licenced as per itself as is, directly cloned from it's source using:
    - `hg clone https://hg.prosody.im/prosody-modules/ prosody-modules`

### How to Use::
- `git clone https://github.com/the8woodcutter/mod_prosody`
- `cd mod_prosody`
- `cp -r prosody-modules /etc/prosody/`
- `chown -R root:prosody /etc/prosody/prosody-modules`
- _*Make sure to add in your global area of your `prosody.cfg.lua` (or like):*_
    - `plugin_paths = { "/etc/prosody/prosody-modules" }`

### Please Note:
_*This is a guideline, you may have to adapt it how you feel.*_
_*`The Woodcutter`* will not be responsible for ciphered databases with no known keys, or AI bots overwhelming your entire LAN using a reflection DDoS attack from non-existent hosts, or your RAM fusing itself to your motherboard and your PSU exploding.  Be strong out there!  Try XMPP it's super cool!!_
