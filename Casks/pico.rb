# Homebrew cask. Publish it from a tap repo named `homebrew-tap`, then users run:
#   brew install --cask <github-user>/tap/pico
# Update `version`, `sha256` (from build/sha256.txt) and the GitHub user on each release.
cask "pico" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE"

  url "https://github.com/GITHUB_USER/pico/releases/download/v#{version}/Pico-#{version}.dmg"
  name "Pico"
  desc "Tiny AI popup for selected text: fix, translate and flip scripts for Indian languages"
  homepage "https://github.com/GITHUB_USER/pico"

  depends_on macos: ">= :sonoma"

  app "Pico.app"

  # The app is ad-hoc signed (not notarized), so clear the quarantine flag on install.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Pico.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/Pico",
    "~/Library/Preferences/app.pico.mac.plist",
  ]
end
