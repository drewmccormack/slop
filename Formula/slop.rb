class Slop < Formula
  desc "Sloppy. Crappy unix commands that work. (On-device LLM shell helper)"
  homepage "https://github.com/drewmccormack/slop"
  url "https://github.com/drewmccormack/slop.git",
      using:  :git,
      branch: "main"
  version "0.1.0"
  license "MIT"

  depends_on arch: :arm64  # Apple Silicon only
  depends_on macos: :tahoe # macOS 26+: requires Apple FoundationModels

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"

    # The compiled product is named `slop`; install it as `slop-bin` because the
    # user-facing `slop` is a shell alias (it needs call-site `noglob` in zsh,
    # which only an alias can provide).
    bin.install ".build/release/slop" => "slop-bin"

    # The shell wrapper that defines the `slop` alias and evals cd/export in the
    # live shell. Installed to the prefix; sourced by the user (see caveats).
    pkgshare.install "shell/slop.sh"
  end

  def caveats
    <<~EOS
      slop installed the `slop-bin` binary on your PATH.

      To get the `slop` command (with live `cd`, and unquoted globs in zsh),
      add this line to your ~/.zshrc and/or ~/.bashrc:

        source "#{opt_pkgshare}/slop.sh"

      Then open a new shell, or run that line now. Try:

        slop list files here

      Requires Apple Intelligence enabled (System Settings > Apple Intelligence).
    EOS
  end

  test do
    # The binary should exist and exit non-zero with a usage message when given
    # no arguments (it prints usage to stderr). We don't invoke the model here.
    output = shell_output("#{bin}/slop-bin 2>&1", 64)
    assert_match "usage", output
  end
end
