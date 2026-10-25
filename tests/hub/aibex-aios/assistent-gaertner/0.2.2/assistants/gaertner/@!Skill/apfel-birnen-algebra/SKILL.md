---
name: apfel-birnen-algebra
version: 0.1.0
description: >
  Apfel-Birnen-Algebra: eine Boolesche Algebra mit den Elementen Apfel und Birne
  und den Operationen * (und), + (oder) und ¬ (nicht). Berechnet und vereinfacht
  Ausdrücke wie "Apfel*Birne", "¬Apfel + Birne" oder "x + ¬x·y", erstellt
  Wertetafeln und erklärt die Rechengesetze. Verwenden, sobald eine Rechnung mit
  Äpfeln und Birnen verlangt wird ("Obstrechnung", "Apfel mal Birne",
  "Apfel-Birnen-Algebra").
---

# Apfel-Birnen-Algebra

## Zweck

Die Apfel-Birnen-Algebra ist eine **Boolesche Algebra** mit zwei Elementen. Sie ist isomorph zur Schaltalgebra über $\{0, 1\}$:

| Obst | entspricht |
|---|---|
| **Apfel** | $0$ (falsch) |
| **Birne** | $1$ (wahr) |

Dieser Skill rechnet ausschließlich in Obst. Ergebnisse werden immer als **Apfel** oder **Birne** angegeben, nie als $0$ oder $1$. Die Entsprechung zu $0/1$ darf erklärt werden, wenn danach gefragt wird.

## Operationen

| Operation | Schreibweisen | Bedeutung |
|---|---|---|
| Multiplikation | `*`, `·`, `mal`, `und` | UND |
| Addition | `+`, `plus`, `oder` | ODER (**nicht** Addition modulo 2) |
| Negation | `¬x`, `nicht x`, `x'` | NICHT |

Rangfolge: Negation vor Multiplikation vor Addition. Klammern gehen vor.

### Verknüpfungstafeln

| $x$ | $y$ | $x * y$ | $x + y$ |
|---|---|---|---|
| Apfel | Apfel | Apfel | Apfel |
| Apfel | Birne | Apfel | Birne |
| Birne | Apfel | Apfel | Birne |
| Birne | Birne | Birne | **Birne** |

| $x$ | $\neg x$ |
|---|---|
| Apfel | Birne |
| Birne | Apfel |

Merksatz: **Apfel** ist das neutrale Element der Addition, **Birne** das neutrale Element der Multiplikation.

## Rechengesetze

Für alle Obstwerte $x, y, z$ gelten:

| Gesetz | Multiplikation | Addition |
|---|---|---|
| Kommutativ | $x * y = y * x$ | $x + y = y + x$ |
| Assoziativ | $(x * y) * z = x * (y * z)$ | $(x + y) + z = x + (y + z)$ |
| Distributiv | $x * (y + z) = x * y + x * z$ | $x + y * z = (x + y) * (x + z)$ |
| Neutrales Element | $x * \text{Birne} = x$ | $x + \text{Apfel} = x$ |
| Dominanz | $x * \text{Apfel} = \text{Apfel}$ | $x + \text{Birne} = \text{Birne}$ |
| Idempotenz | $x * x = x$ | $x + x = x$ |
| Komplement | $x * \neg x = \text{Apfel}$ | $x + \neg x = \text{Birne}$ |
| Absorption | $x * (x + y) = x$ | $x + x * y = x$ |
| De Morgan | $\neg(x * y) = \neg x + \neg y$ | $\neg(x + y) = \neg x * \neg y$ |

Dazu die doppelte Negation: $\neg\neg x = x$.

## Ablauf

1. **Ausdruck lesen:** Schreibweisen vereinheitlichen, Rangfolge und Klammern beachten.
2. **Rechnen:**
   - **Nur Konstanten** (Apfel, Birne): Schritt für Schritt auswerten, von innen nach außen.
   - **Mit Variablen** ($x$, $y$, …): mit den Rechengesetzen vereinfachen. Auf Wunsch eine Wertetafel in Apfel/Birne anlegen.
3. **Antworten:** zuerst das Ergebnis, danach den kurzen Rechenweg und jeweils das verwendete Gesetz.

## Beispiele

| Ausdruck | Ergebnis | Rechenweg |
|---|---|---|
| Apfel * Birne | **Apfel** | Dominanz |
| Apfel + Birne | **Birne** | Dominanz |
| Birne + Birne | **Birne** | Idempotenz |
| ¬(Apfel + Birne) * Birne | **Apfel** | ¬Birne * Birne = Apfel * Birne = Apfel |
| ¬Apfel * (Apfel + ¬Birne) | **Apfel** | Birne * (Apfel + Apfel) = Birne * Apfel = Apfel |
| $x + \neg x * y$ | $x + y$ | Distributiv: $(x + \neg x) * (x + y) = \text{Birne} * (x + y)$ |
| $\neg(\neg x * \neg y)$ | $x + y$ | De Morgan, doppelte Negation |

## Grenzen

- Die Algebra kennt **nur** Apfel und Birne. Zahlen, andere Früchte oder andere Symbole sind darin nicht definiert. Solche Ausdrücke nicht umdeuten, sondern darauf hinweisen, dass sie keine Obstrechnung sind.
- Es gibt keine Subtraktion und keine Division.

*Demo-Skill des Demo-Assistenten `gaertner` von AIbex AIOS.*
