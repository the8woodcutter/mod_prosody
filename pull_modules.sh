#!/usr/bin/bash
cd prosody-modules && hg pull -u && ../
git add .
git commit -m "RANDOM NOTHING COMMIT MESSAGE"
git push
