# Golden Minimal Project — node

Kleinstes lauffähiges Referenzprojekt für die Stack-Matrix (P3.1). Dient als
Fixture: die Guard-/CI-Logik und die test-author/developer-Konventionen müssen
hier identisch greifen wie im python-Pendant.

```yaml
projekt: golden-node
stack: node
audit:
  block_ab: medium   # npm audit → moderate (via read-block-ab.sh --npm)
gates:
  coverage_changed_lines: 90
```

Test-Konvention: Acceptance-Tests unter `tests/acceptance/story_<nr>/*.test.js`.
