cask "rightmouse" do
  version "0.0.3"
  sha256 "ec2029de0f10455d695fb10aaf2cd0211831005b650e66dc4f8f6b864e8ccae0"

  url "https://github.com/Echo-BraveShine/RightMouse/releases/download/v#{version}/RightMouse-#{version}-universal.zip"
  name "RightMouse"
  desc "Add file actions to the Finder context menu"
  homepage "https://github.com/Echo-BraveShine/RightMouse"

  auto_updates true
  depends_on macos: :ventura

  app "RightMouse.app"

  uninstall quit: "dev.ekko.rightmouse"
end
