# Golden Minimal Project — python

Kleinstes lauffähiges Referenzprojekt für die Stack-Matrix (P3.1). Dient als
Fixture: die Guard-/CI-Logik und die test-author/developer-Konventionen müssen
hier identisch greifen wie im node-Pendant.

```yaml
projekt: golden-python
stack: python-fastapi
audit:
  block_ab: high
gates:
  coverage_changed_lines: 90
```

Test-Konvention: Acceptance-Tests unter `tests/acceptance/story_<nr>/*.py`.
