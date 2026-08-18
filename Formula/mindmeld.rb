class Mindmeld < Formula
  desc     "Continuity engine for an agent-fed knowledge base"
  homepage "https://github.com/aschreifels/homebrew-mindmeld"
  # 0.3.1, not v0.3.1: Homebrew's version field is the package's
  # own identity and feeds upgrade comparison, and `brew style` rejects a
  # leading "v" there (FormulaAudit/Version). The git tag and the release
  # asset filenames are a separate namespace and keep the "v" they were built
  # with — hence two tokens rather than one.
  version  "0.3.1"
  license  "Apache-2.0"

  # git:     `init` clones/pulls the knowledge base with it.
  # ripgrep: the sweep and several other organs shell out to `rg`.
  # yq:      mindmeld.toml is read through it.
  #
  # Declared before the platform blocks below because `brew style` wants that
  # order (FormulaAudit/ComponentsOrder).
  depends_on "git"
  depends_on "ripgrep"
  depends_on "yq"
  # Deliberately NOT depends_on "qmd": no Homebrew formula exists for qmd.
  # preflight already has a doc-pointer branch for a missing qmd — it
  # points the user at manual install instructions instead of failing the
  # whole install — and that stays the story for brew users too.

  # Four artifacts, one per platform `make dist` builds. Each `url` points
  # at that version's GitHub release on the tap repo; each `sha256` is the
  # matching line from dist/checksums.txt. Homebrew picks exactly one of
  # these four blocks per install, based on the running machine.
  on_macos do
    on_arm do
      url "https://github.com/aschreifels/homebrew-mindmeld/releases/download/v0.3.1/mindmeld_v0.3.1_darwin_arm64.tar.gz"
      sha256 "152eb6be23dc4085e5d430a51c22680a57825f633716fe75f143c355e3c11af3"
    end
    on_intel do
      url "https://github.com/aschreifels/homebrew-mindmeld/releases/download/v0.3.1/mindmeld_v0.3.1_darwin_amd64.tar.gz"
      sha256 "bc16f869d7599a46b040664d811ff3cb6d8fe26607b26b910ecddbaf8e08d93f"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/aschreifels/homebrew-mindmeld/releases/download/v0.3.1/mindmeld_v0.3.1_linux_arm64.tar.gz"
      sha256 "0a4ae46110baa91cd67d848641f7eda64247838c8dc5e8d6da91308c3676505f"
    end
    on_intel do
      url "https://github.com/aschreifels/homebrew-mindmeld/releases/download/v0.3.1/mindmeld_v0.3.1_linux_amd64.tar.gz"
      sha256 "43b469397be6b1027a99c214f8a742e4d0c2baa1fc79a565ba0f90215150e20f"
    end
  end

  def install
    bin.install "bin/mindmeld"

    # The content ring, installed as one tree so the asset resolver's
    # keg candidate (<exe>/../libexec) finds every marker together.
    # skills, templates, bases, kb-scaffold, and mindmeld.toml.example are
    # the five paths the resolver requires as a set — ship four of them and
    # every command that resolves the ring fails its own marker check on a
    # brand-new install. hooks/ isn't itself a marker, but ships because
    # `init` symlinks the pulse hook out of it. docs/ isn't a marker either,
    # but ships because `mindmeld docs`/`docs install` read it straight off
    # the ring, same as hooks/.
    libexec.install "skills", "templates", "bases", "kb-scaffold",
                     "hooks", "docs", "mindmeld.toml.example"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mindmeld --version")

    # `doctor` exits nonzero against a virgin HOME by design — there's no
    # knowledge base yet for it to find, so a fresh `brew test` failing on
    # exit code alone would be a false negative. Assert the provenance line
    # instead: the honest positive signal from this install is "the binary
    # resolved its content ring as a managed (brew) install," not "the
    # command exited zero."
    assert_match "managed", shell_output("#{bin}/mindmeld doctor 2>&1", 1)
  end
end
