# Head-to-Head Task-Set (P3.4)

Repo: **G13** (privat, wegen Secrets in History). Stack: Vue 3 + Vite (Frontend), PHP-API.
7 Tasks gemischter Komplexität: **2 trivial · 3 mittel · 2 komplex**.

Jeder Task wird zu einem Story-Issue (ARCHITECT erzeugt ACs). Der `test-author` schreibt je
Story den Acceptance-Contract **genau einmal** — dieser Contract + die CI-Gates sind der
**neutrale Schiedsrichter für BEIDE Arme**. Identische Story-Specs, identische Bewertung.

Die ACs unten sind Seed-Vorgaben; der ARCHITECT verfeinert sie zu INVEST-Stories. Namen folgen
`docs/GLOSSARY.md` von G13 (z. B. `cartTotal`, Cent-Constraint für Beträge).

> **Baseline-Verifikation (2026-08-14).** Das ursprüngliche Task-Set war gegen einen
> idealisierten leeren Shop geschrieben. Der reale G13-Stand implementiert bereits
> Euro-Formatierung (`formatPrice`), Warenkorb-Badge (`totalItems`) und Mengenänderung
> (`updateCartQty`). Diese Tasks wurden durch **genuin fehlende** G13-Lücken ersetzt, damit
> beide Arme aus derselben sauberen Baseline bauen (Fairness-Regel). Jede Lücke unten ist
> gegen den G13-Code verifiziert.

---

## T1 — Gesamtbetrag inkl. MwSt, Cent-genau (trivial)

Reine Funktion `berechneGesamtMitMwSt(zwischensummeCents, mwstSatz)` → Gesamtbetrag in Cent
als Ganzzahl (kaufmännisch gerundet). Behebt eine reale Lücke: `App.vue` zeigt aktuell
`totalWithVat = cartTotal.value` — die MwSt wird ignoriert; zudem ist `vatAmount = cartTotal * 0.07`
ein Float im Cent-Raum (Cent-Constraint-Verletzung).
- AC-1: `berechneGesamtMitMwSt(10000, 0.07)` liefert `10700` (Ganzzahl Cent).
- AC-2: kaufmännische Rundung auf Cent: `berechneGesamtMitMwSt(999, 0.07)` liefert `1069`
  (999 × 1,07 = 1068,93 → 1069), Ergebnis ist immer `Number.isInteger`.
- AC-3: `berechneGesamtMitMwSt(0, 0.07)` liefert `0`.
Einzeldatei-Utility unter `src/utils/`, keine neue Dependency, kein Auth/PII, kein Schema
→ **Fast-Lane-Kandidat** (`track:fast`).

## T2 — Warenkorb-Mengen-Label (trivial)

Reine Funktion `formatWarenkorbLabel(anzahl)` für eine sprachlich korrekte Anzeige.
- AC-1: `formatWarenkorbLabel(0)` liefert `"Warenkorb leer"`.
- AC-2: `formatWarenkorbLabel(1)` liefert `"1 Artikel"`.
- AC-3: `formatWarenkorbLabel(5)` liefert `"5 Artikel"`.
Einzeldatei-Utility, keine neue Dependency → **Fast-Lane-Kandidat**. (G13 hat `totalItems`,
aber keine sprachlich aufbereitete Label-Funktion.)

## T3 — Warenkorb-Persistenz über Reload (mittel)

Der Warenkorb liegt als In-Memory-Singleton (`const cart = ref([])` in `useCart.js`) und geht
bei jedem Reload verloren. Persistenz über `localStorage`, ohne die bestehende API zu brechen.
- AC-1: Nach Hinzufügen von Positionen und einem Reload ist der Warenkorb identisch wiederhergestellt.
- AC-2: Mengenänderung und Entfernen werden persistiert.
- AC-3: Leerer/kaputter `localStorage`-Zustand führt nicht zum Fehler (definierter Fallback auf leer).
- AC-4: Bestehende `useCart`-Rückgabe (`cart`, `addToCart`, …) bleibt unverändert nutzbar.

## T4 — Gutschein-Code (mittel)

Prozentualer Rabatt auf `cartTotal`, Cent-genau, mit Validierung. In G13 nicht vorhanden
(nur Stripe-Vendor-Code, keine eigene Rabattlogik).
- AC-1: gültiger Code `SAVE10` reduziert um 10 % (kaufmännisch gerundet auf Cent).
- AC-2: ungültiger Code → Fehlermeldung, `cartTotal` unverändert.
- AC-3: Rabatt nie negativer Endbetrag; Grenzfall 100 % → `0,00 €`.
- AC-4: nur ein aktiver Gutschein gleichzeitig.

## T5 — Produktfilter nach Kategorie mit Deeplink (mittel)

G13 hat eine Titel-Suche (`filteredProducts`), aber **keinen** Kategorie-Filter und **kein**
Query-Param-Deeplinking. Beides ergänzen, inkl. Leer-Ergebnis-Zustand.
- AC-1: Auswahl einer Kategorie zeigt nur deren Produkte.
- AC-2: Kategorie ohne Produkte → definierter Leer-Zustand (kein Fehler).
- AC-3: Query-Param spiegelt die Auswahl (deep-linkbar, überlebt Reload).

## T6 — Eigener Bestell-Endpoint mit Idempotenz (komplex)

Frontend-Flow + PHP-API-Endpoint `POST /orders`, Validierung, Fehlerpfade, Idempotenz.
Distinkt vom bestehenden Stripe-`checkout.php` (das ist ein Redirect-Flow, kein serverseitig
persistierter, idempotenter Bestell-Endpoint).
- AC-1: gültige Bestellung → 201 + Order-ID; Warenkorb wird geleert.
- AC-2: leerer Warenkorb → 422, keine Order angelegt.
- AC-3: doppeltes Submit mit gleichem Idempotency-Key legt **keine** zweite Order an.
- AC-4: Server-Fehler (5xx) → Warenkorb bleibt erhalten, klare Nutzer-Fehlermeldung.
- AC-5: Beträge serverseitig neu berechnet (Client-Beträge nicht vertraut).

## T7 — Lagerbestand-Reservierung / Überverkauf verhindern (komplex)

Nebenläufige Bestellungen dürfen den Bestand nicht unter 0 treiben. G13 hat nur simple
Stock-Checks im Warenkorb (`product.stock <= 0`), keine Nebenläufigkeitssicherung.
- AC-1: zwei parallele Bestellungen auf das letzte Stück → genau eine erfolgreich, eine abgelehnt.
- AC-2: abgelehnte Bestellung gibt reservierte Menge frei.
- AC-3: Bestand nie negativ (Invariante, auch unter Last).
- AC-4: Reservierung läuft nach Timeout ab und gibt Bestand frei.

---

## Verteilung (Soll)

| Komplexität | Tasks |
|---|---|
| trivial | T1 (Gesamt inkl. MwSt), T2 (Mengen-Label) |
| mittel  | T3 (Persistenz), T4 (Gutschein), T5 (Kategorie-Filter) |
| komplex | T6 (Bestell-Endpoint), T7 (Reservierung) |
