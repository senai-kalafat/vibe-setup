# Stack Profilleri

Vibe-setup'ın **tek stack-bağımlı katmanı**. Çekirdek mantık dil-bağımsız; bu tablo sadece "hangi komut"
boşluğunu doldurur. Kanonik kaynak `scaffold.sh::detect_profile` — burası onun insan-okur dökümü.

`scaffold.sh profile [DIR]` çalıştır → tespit edilen profili makine-okur basar (9 profil alanı + ayrıca
engine'in `VIBE_VERSION`'ı; sürüm/upgrade için bkz [SKILL.md](SKILL.md) `## Upgrade akışı`).

## Tablo

`fmt-scope` = hook fmt davranışı. `staged` → fmt dosya listesi alır, **sadece staged** kontrol edilir (blocking).
`repo` → araç bütün-proje çalışır → scope edilemez, hook'ta **advisory** (CI zorlasın).

| Stack | Tespit (manifest) | fmt (check) | lint | test | build | SRC_RE | test deseni | fmt-scope |
|---|---|---|---|---|---|---|---|---|
| go | `go.mod` | `gofmt -l` | `go vet ./...` | `go test ./...` | `go build ./...` | `\.go$` | `*_test.go` | staged |
| node | `package.json` | `npx --no-install prettier --check` | `npx --no-install eslint .` | `npm test` | `npm run build` | `\.(js\|ts\|jsx\|tsx)$` | `*.test.*` | staged |
| node (biome) | `package.json` + `biome.json(c)` | `npx --no-install @biomejs/biome check` | (check kapsar) | `npm test` | `npm run build` | `\.(js\|ts\|jsx\|tsx)$` | `*.test.*` | staged |
| python | `pyproject.toml`/`setup.py`/`requirements.txt` | `ruff format --check` | `ruff check .` | `pytest` | — | `\.py$` | `test_*.py` | staged |
| java (maven) | `pom.xml` | `mvn spotless:check` | — | `mvn test` | `mvn package` | `\.java$` | `*Test.java` | repo |
| java (gradle) | `build.gradle` | `./gradlew spotlessCheck` | — | `./gradlew test` | `./gradlew build` | `\.java$` | `*Test.java` | repo |
| kotlin | `build.gradle.kts` | `./gradlew ktlintCheck` | — | `./gradlew test` | `./gradlew build` | `\.(kt\|kts)$` | `*Test.kt` | repo |
| rust | `Cargo.toml` | `cargo fmt --check` | `cargo clippy` | `cargo test` | `cargo build` | `\.rs$` | `*_test.rs` | repo |
| ruby | `Gemfile` | `rubocop` | `rubocop` | `rspec` | — | `\.rb$` | `*_spec.rb` | staged |
| dotnet | `*.csproj`/`*.sln` | `dotnet format --verify-no-changes` | — | `dotnet test` | `dotnet build` | `\.cs$` | `*Tests.cs` | repo |
| php | `composer.json` | `php-cs-fixer fix --dry-run` | `phpstan analyse` | `phpunit` | — | `\.php$` | `*Test.php` | staged |
| swift | `Package.swift` | `swiftformat --lint` | `swiftlint` | `swift test` | `swift build` | `\.swift$` | `*Tests.swift` | staged |
| elixir | `mix.exs` | `mix format --check-formatted` | `mix credo` | `mix test` | `mix compile` | `\.(ex\|exs)$` | `*_test.exs` | staged |
| shell | `*.sh` (manifest yok) | `shfmt -d` | `shellcheck` | `bash tests/run.sh` | — | `\.sh$` | `*_test.sh` | staged |
| unknown | — | — | — | — | — | — | — | — |

## Notlar

- **MODULE_DIR.** Manifest kökte olmayabilir (ör. `src/`, `app/`, `backend/`). Script depth-3'e kadar arar;
  proje artefaktları (CLAUDE.md, docs/, hook) **kökte**, stack komutları/testler **MODULE_DIR**'de. Komutlar
  MODULE_DIR'den çalıştırılmalı (skill, gerekirse hook'a `cd <module>` ekler).
- **fmt = check modu** (yazmaz). `fmt-scope=staged` ise sadece staged dosyalar → eski formatsız dosyalar
  temiz commit'i bloklamaz. `fmt-scope=repo` araçları (spotless/gradle/cargo/dotnet) advisory; asıl kapı CI.
- **Tool kurulu değilse** hook fmt/lint'i sessizce atlar (`command -v` kontrolü). `npx --no-install` paket
  yoksa sessizce başarısız olur (asılmaz).
- **node biome:** `biome.json(c)` varsa prettier/eslint yerine `biome check` (fmt+lint tek araç).
- **kotlin vs java (gradle):** `build.gradle.kts` → kotlin, `build.gradle` (groovy) → java. Karma repo'da
  (ikisi de var) kts önce eşleşir → kotlin; java-ağırlıklıysa komutları elle düzelt.
- **lint `—`** olanlar advisory bile çalışmaz (ekosistemde standart araç yok / opsiyonel).
- **shell:** manifest yoksa (`*.sh` var) — test konvansiyonu `tests/*_test.sh` + bağımsız `tests/run.sh` runner.
- **Bilinmeyen stack:** profil yok → skill kullanıcıya komutları sorar, bu tabloya yeni satır olarak eklenebilir.
- **Yeni stack eklemek:** `scaffold.sh::detect_profile`'a bir `printf` satırı (9 alan: son alan `FMT_FILE_OK`)
  + bu tabloya bir satır. Kanonik kaynak script; bu tablo onun insan-okur dökümü (senkron tut).
