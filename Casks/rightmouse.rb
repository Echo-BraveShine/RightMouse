cask "rightmouse" do
  version "0.0.1"
  sha256 "4f9e0dcb9bf9571645127fa2225bd8abc5b7774d9092feea4bc6ce1cd9dc8b53"

  url "https://github.com/Echo-BraveShine/RightMouse/releases/download/v#{version}/RightMouse-#{version}-universal.zip"
  name "RightMouse"
  desc "Add file actions to the Finder context menu"
  homepage "https://github.com/Echo-BraveShine/RightMouse"

  auto_updates true
  depends_on macos: :ventura

  app "RightMouse.app"

  uninstall quit: "dev.ekko.rightmouse"
end
