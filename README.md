# mod_prosody - GIT of Prosody Community Modules
## Author: The Woodcutter
### Included subdirectory `prosody-modules` contents licenced as per itself as is, directly cloned from it's source: ` hg clone https://hg.prosody.im/prosody-modules/ prosody-modules`

### Details:
`mod_prosody` is my GIT, jagged fork, of the Prosody Community Modules which are in the version control form of mercurial, not GIT.

#### How to Use::
- `git clone https://github.com/the8woodcutter/mod_prosody`
- `cd mod_prosody`
- `cp -r prosody-modules /etc/prosody/`
- `chown -R root:prosody /etc/prosody/prosody-modules`
- Make sure to add in your global area of your prosody.cfg.lua (or like):
    - `plugin_paths = { "/etc/prosody/prosody-modules" }`

#### Please Note:
__this is a guideline, you may have to adapt it how you feel.__
__The Woodcutter will not be responsible for ciphered databases with no known keys, or AI bots overwhelming your entire LAN using a reflection DDoS attack from non-existent hosts, or your RAM soldering itself to your motherboard and your PSU exploding.  Be strong out there!  Try XMPP it's super cool!!__
