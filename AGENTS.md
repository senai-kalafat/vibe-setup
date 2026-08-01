<!-- vibe-setup:v8 (managed) -->
# Agent Guide

Bu projenin tek doğruluk kaynağı **CLAUDE.md**'dir.

- **AGENTS.md standardını izleyen ajanlar** (Codex, Kimi Code, vb.) bu dosyayı doğrudan okur →
  [CLAUDE.md](CLAUDE.md)'ye bakın.
- **Kendi context dosyası olan araçlar** ayrı pointer kullanır: Cursor → `.cursor/rules/`,
  Gemini CLI → `GEMINI.md` (ikisi de CLAUDE.md'ye yönlendirir/import eder).
- **Çıktı modu:** bu repoda caveman modu (seviye `full`) zorunludur — aktif değilse `/caveman full`
  çalıştır. Kod, commit mesajı ve PR metni normal yazılır.

Ek doküman: [docs/](docs/).
