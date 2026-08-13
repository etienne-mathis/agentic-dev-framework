# Head-to-Head Task-Set (P3.4)

Repo: **G13** (privat, wegen Secrets in History). Stack: Vue 3 + Vite (Frontend), PHP-API.
7 Tasks gemischter Komplexität: **2 trivial · 3 mittel · 2 komplex**.

Jeder Task wird zu einem Story-Issue (ARCHITECT erzeugt ACs). Der `test-author` schreibt je
Story den Acceptance-Contract **genau einmal** — dieser Contract + die CI-Gates sind der
**neutrale Schiedsrichter für BEIDE Arme**. Identische Story-Specs, identische Bewertung.

Die ACs unten sind Seed-Vorgaben; der ARCHITECT verfeinert sie zu INVEST-Stories. Namen folgen
`docs/GLOSSARY.md` von G13 (z. B. `cartTotal`, Cent-Constraint für Beträge).

---

## T1 — Euro-Formatierung (trivial)

Einheitlicher Helper `formatEuro(cents)` → String wie `"12,90 €"`.
- AC-1: `formatEuro(1290)` liefert `"12,90 €"`.
- AC-2: `formatEuro(0)` liefert `"0,00 €"`.
- AC-3: negative Cent-Werte liefern ein führendes `-` (`formatEuro(-500)` → `"-5,00 €"`).
Einzeldatei-Utility, keine neue Dependency → **Fast-Lane-Kandidat** (`track:fast`).

## T2 — Warenkorb-Badge Artikelanzahl (trivial)

Computed `cartItemCount` = Summe der Mengen; Badge im Header.
- AC-1: leerer Warenkorb → Badge zeigt `0` (oder ist ausgeblendet, je Konvention).
- AC-2: zwei Positionen mit Menge 2 und 3 → Badge zeigt `5`.
- AC-3: Mengenänderung aktualisiert das Badge reaktiv.
**Fast-Lane-Kandidat**.

## T3 — Menge im Warenkorb ändern (mittel)

Increment/Decrement je Position mit Min/Max und Persistenz.
- AC-1: Decrement unter 1 entfernt die Position nicht automatisch, bleibt bei 1 (oder klar definiert).
- AC-2: Increment über verfügbaren Bestand wird auf den Bestand begrenzt.
- AC-3: `cartTotal` wird Cent-genau neu berechnet.
- AC-4: Zustand überlebt einen Reload (Persistenz).

## T4 — Gutschein-Code (mittel)

Prozentualer Rabatt auf `cartTotal`, Cent-genau, mit Validierung.
- AC-1: gültiger Code `SAVE10` reduziert um 10 % (kaufmännisch gerundet auf Cent).
- AC-2: ungültiger Code → Fehlermeldung, `cartTotal` unverändert.
- AC-3: Rabatt nie negativer Endbetrag; Grenzfall 100 % → `0,00 €`.
- AC-4: nur ein aktiver Gutschein gleichzeitig.

## T5 — Produktfilter nach Kategorie (mittel)

Filter über Query-Param, inkl. Leer-Ergebnis-Zustand.
- AC-1: Auswahl einer Kategorie zeigt nur deren Produkte.
- AC-2: Kategorie ohne Produkte → definierter Leer-Zustand (kein Fehler).
- AC-3: Query-Param spiegelt die Auswahl (deep-linkbar, überlebt Reload).

## T6 — Checkout-Flow mit Bestell-Endpoint (komplex)

Frontend-Flow + PHP-API-Endpoint `POST /orders`, Validierung, Fehlerpfade, Idempotenz.
- AC-1: gültige Bestellung → 201 + Order-ID; Warenkorb wird geleert.
- AC-2: leerer Warenkorb → 422, keine Order angelegt.
- AC-3: doppeltes Submit mit gleicher Idempotency-Key legt **keine** zweite Order an.
- AC-4: Server-Fehler (5xx) → Warenkorb bleibt erhalten, klare Nutzer-Fehlermeldung.
- AC-5: Beträge serverseitig neu berechnet (Client-Beträge nicht vertraut).

## T7 — Lagerbestand-Reservierung / Überverkauf verhindern (komplex)

Nebenläufige Bestellungen dürfen den Bestand nicht unter 0 treiben.
- AC-1: zwei parallele Bestellungen auf das letzte Stück → genau eine erfolgreich, eine abgelehnt.
- AC-2: abgelehnte Bestellung gibt reservierte Menge frei.
- AC-3: Bestand nie negativ (Invariante, auch unter Last).
- AC-4: Reservierung läuft nach Timeout ab und gibt Bestand frei.

---

## Verteilung (Soll)

| Komplexität | Tasks |
|---|---|
| trivial | T1, T2 |
| mittel  | T3, T4, T5 |
| komplex | T6, T7 |
