#!/usr/bin/env python3
"""Generate the Homebrew cask for a packaged RightMouse release."""
from hashlib import file_digest
from pathlib import Path
import re
import sys

archive = Path(sys.argv[1])
match = re.fullmatch(r"RightMouse-([0-9]+\.[0-9]+\.[0-9]+)-universal\.zip", archive.name)
if match is None:
    raise SystemExit("Expected RightMouse-MAJOR.MINOR.PATCH-universal.zip")

with archive.open("rb") as stream:
    checksum = file_digest(stream, "sha256").hexdigest()

print(f'''cask "rightmouse" do
  version "{match[1]}"
  sha256 "{checksum}"

  url "https://github.com/Echo-BraveShine/RightMouse/releases/download/v#{{version}}/RightMouse-#{{version}}-universal.zip"
  name "RightMouse"
  desc "Add file actions to the Finder context menu"
  homepage "https://github.com/Echo-BraveShine/RightMouse"

  auto_updates true
  depends_on macos: :ventura

  app "RightMouse.app"

  uninstall quit: "dev.ekko.rightmouse"
end''')
