class Mindmeld < Formula
  desc     "Continuity engine for an agent-fed knowledge base"
  homepage "https://github.com/aschreifels/homebrew-mindmeld"
  # 0.0.1-test, not v0.0.1-test: Homebrew's version field is the package's
  # own identity and feeds upgrade comparison, and `brew style` rejects a
  # leading "v" there (FormulaAudit/Version). The git tag and the release
  # asset filenames are a separate namespace and keep the "v" they were built
  # with — hence two tokens rather than one.
  version  "0.0.1-test"
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
      url "https://github.com/aschreifels/homebrew-mindmeld/releases/download/v0.0.1-test/mindmeld_v0.0.1-test_darwin_arm64.tar.gz"
      sha256 "332abd6574de42df260dab804c72738633a04d8ccae369a78956f9ea348927b6"
    end
    on_intel do
      url "https://github.com/aschreifels/homebrew-mindmeld/releases/download/v0.0.1-test/mindmeld_v0.0.1-test_darwin_amd64.tar.gz"
      sha256 "716e787f8b96dbbe2e2fbd7f6c324fab9c8f88b2b512efba3be657db8cccb013"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/aschreifels/homebrew-mindmeld/releases/download/v0.0.1-test/mindmeld_v0.0.1-test_linux_arm64.tar.gz"
      sha256 "50dc7ee398ca302a853e86a90a184e4a01568d4d2267f34a5370826c8ea8fa39"
    end
    on_intel do
      url "https://github.com/aschreifels/homebrew-mindmeld/releases/download/v0.0.1-test/mindmeld_v0.0.1-test_linux_amd64.tar.gz"
      sha256 "0265e1b60796814dc5f7f5b832dfba8a6dec04d8204ac2daca902a669935a53c"
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
    # `init` symlinks the pulse hook out of it.
    libexec.install "skills", "templates", "bases", "kb-scaffold",
                     "hooks", "mindmeld.toml.example"
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
