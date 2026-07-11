# Domain Sözlüğü

vibe-setup'a özgü jargon. Koddan çıkarılması zor terimler burada; mimari için
[architecture/overview.md](../architecture/overview.md).

| Terim | Anlam |
|---|---|
| **Deterministik kat** | `scaffold.sh` — saf bash motor: tespit, agnostik iskelet, komut substitüsyonu. Çıktısı her çalıştırmada aynı. |
| **Akıllı kat** | SKILL.md akışı — LLM repoyu okuyup stack-bağımlı içeriği (CLAUDE.md prose, test, deny yolları) üretir. |
| **Agnostik iskelet** | Dile bağlı olmayan, `init`'in düşürdüğü boilerplate (AGENTS.md, docs/, hook, şablonlar). Her stack'te aynı. |
| **Stack** | Tespit edilen ekosistem: go / node / python / java / rust / ruby / php / dotnet / shell / unknown. |
| **Profil** | `scaffold.sh profile` çıktısı — 9 alan: STACK, MODULE_DIR, FMT, LINT, TEST, BUILD, SRC_RE, TEST_FIND, FMT_FILE_OK. |
| **MODULE_DIR** | Stack manifest'inin (go.mod, package.json…) bulunduğu dizin. Kökte olmayabilir; script depth-3 arar. Komutlar buradan çalışır; proje artefaktları kökte. |
| **FMT_FILE_OK** | Profilin son alanı. `1` = fmt dosya listesi alır → hook sadece staged dosyaları kontrol eder (blocking). `0` = fmt bütün-proje → hook advisory (CI zorlasın). |
| **fmt-scope** | FMT_FILE_OK'in insan-okur karşılığı: `staged` (go/node/python/ruby/php/shell) vs `repo` (java/rust/dotnet). |
| **audit** | Hazırlık denetimi — ✅/❌/— tablosu + makine-okur `SCORE=N/M` footer. |
| **init** | Eksik agnostik iskeletleri düşürür. Var olanı **asla ezmez** (SKIP). Idempotent. |
| **init-cursor** | Cursor kural dosyalarını ekler (`.cursor/rules/project.mdc` + `.cursorrules` → CLAUDE.md'ye yönlendirir). |
| **Ticket-key** | Commit konu satırı formatı: 3 BÜYÜK harf + '-' + ≤4 hane (ör. `VAN-3195`). `.githooks/commit-msg` zorlar; merge/revert/fixup/squash muaf. |
| **doc-sync** | pre-commit kontrolü: kaynak değişti ama doküman (docs/ + README/CLAUDE/AGENTS) değişmediyse uyarır. Default advisory; `STRICT_DOCS=1` → blocking. |
| **advisory / blocking** | Hook kapısı bloklamaz (uyarı, exit 0) / bloklar (exit 1). Gürültülü/repo-geneli kapılar advisory; staged-scope kapılar blocking. |
| **BEFORE / AFTER skoru** | Skill audit'i akış başında ve sonunda çalıştırıp `SCORE=N/M`'leri kıyaslar (uyumluluk tablosu). |
| **Token-bombası yolları** | settings.json `permissions.deny`'a eklenen büyük üretilmiş/vendor asset'leri (derlenmiş bundle, swagger, dist/) — agent okuyup bağlamı patlatmasın. |
| **Pointer-style CLAUDE.md** | İçerik dökmek yerine docs'a yönlendiren CLAUDE.md → token tasarrufu, tembel yükleme. |
| **VIBE_VERSION** | Engine'in tamsayı şema sürümü (`scaffold.sh`). Bir managed template/migration değişince +1. plugin.json semver'inden ayrı; upgrade/migration anahtarı. |
| **upgrade** | Zaten kurulu repoyu yeni sürüme taşıyan komut. sha-drift'e göre: UPDATE (dokunulmamış→regen), ADD (eksik), CONFLICT (elle düzenlenmiş→ezme yok). |
| **Manifest (`.vibe-setup.json`)** | Repo köküne yazılan sürüm kaydı: `vibeVersion`, stack, her managed dosya için `{ v, sha }`. jq-suz parse edilir; lockfile gibi tool-managed. |
| **Stamp** | Üretilen dosyaya gömülen `vibe-setup:vN (managed)` marker'ı. İnsan sinyali + manifestsiz sürüm tespiti. settings.json (JSON) hariç. |
| **managed dosya** | Engine'in ürettiği agnostik dosya (`managed_paths`). İçeriği `render_artifact`'ta tek-kaynak. |
| **synced / seed** | managed sınıfları. **synced**: engine sürdürür, template drift → UPDATE/CONFLICT (AGENTS/ADR/pre-commit/commit-msg). **seed**: bir kez düşer, sonra kullanıcının, drift normal (settings.json/.gitmessage/docs-README/PR). |
| **UPDATE / ADD / CONFLICT** | upgrade raporu sınıfları. UPDATE = dokunulmamış→otomatik regen; ADD = eksik; CONFLICT = elle düzenlenmiş → engine ezmez, LLM 3-yönlü merge eder. |
| **Migration** | Dosya-dışı, sıralı, idempotent, probe-guarded dönüşüm (`run_migrations`) — alan rename / mevcut dosyaya satır ekleme gibi. Dosya-template değişimi UPDATE yoluyla gider. |
