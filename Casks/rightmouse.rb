cask "rightmouse" do
  version "0.0.2"
  sha256 "879741320eda493fc51e746962e336e4ba1020890a138e5bc416c8c4553a5cd3"

  url "https://github.com/Echo-BraveShine/RightMouse/releases/download/v#{version}/RightMouse-#{version}-universal.zip"
  name "RightMouse"
  desc "Add file actions to the Finder context menu"
  homepage "https://github.com/Echo-BraveShine/RightMouse"

  auto_updates true
  depends_on macos: :ventura

  app "RightMouse.app"

  uninstall quit: "dev.ekko.rightmouse"
end
