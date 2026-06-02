cask("deck") do
  version("1.11")
  sha256("0000000000000000000000000000000000000000000000000000000000000000")

  url("https://github.com/douinc/deck/releases/download/v#{version}/Deck-#{version}.dmg")
  name("Deck")
  desc("Presentation remote control - Mac receiver for iOS Deck app")
  homepage("https://github.com/douinc/deck")

  livecheck do
    url(:url)
    strategy(:github_latest)
  end

  depends_on(macos: ">= :sonoma")

  app("Deck.app")

  postflight do
    # Open Accessibility privacy pane so user can grant permission
    system_command(
      "/usr/bin/open",
      args: ["x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"],
      sudo: false
    )
  end

  zap(
    trash: [
      "~/Library/Preferences/com.dou.clicker-mac.plist",
      "~/Library/Application Support/Deck"
    ]
  )
end