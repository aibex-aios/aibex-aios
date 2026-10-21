---
name: sonne-mond-zahlen
version: 0.1.0
description: >
  Sonne-Mond-Zahlkörper: ein Zahlkörper, der isomorph zu den komplexen Zahlen ist,
  mit Sonne als Einheit und Mond als imaginärer Einheit (Mond·Mond = −Sonne).
  Rechnet mit Zahlen der Form "a Sonne + b Mond": Addition, Subtraktion,
  Multiplikation, Division, Potenzen, Wurzeln, Konjugation, Betrag und Polarform.
  Verwenden, sobald eine Rechnung mit Sonne und Mond verlangt wird ("Sonne mal Mond",
  "Mond hoch 3", "Sonne-Mond-Zahlen", "Himmelsrechnung").
---

# Sonne-Mond-Zahlen

## Zweck

Die Sonne-Mond-Zahlen bilden einen **Zahlkörper**, der isomorph zum Körper $\mathbb{C}$ der komplexen Zahlen ist:

| Himmel | entspricht |
|---|---|
| **Sonne** | $1$ (Einheit) |
| **Mond** | $i$ (imaginäre Einheit) |

Jede Sonne-Mond-Zahl hat die **Normalform**

$$z = a\ \text{Sonne} + b\ \text{Mond} \qquad (a, b \in \mathbb{R})$$

Dieser Skill rechnet ausschließlich in Sonne und Mond. Ergebnisse werden immer in Normalform angegeben, nie mit $1$ oder $i$. Die Entsprechung zu $\mathbb{C}$ darf erklärt werden, wenn danach gefragt wird.

## Schreibweisen

- `Sonne` steht für $1\ \text{Sonne}$, `−Mond` für $-1\ \text{Mond}$.
- Eine reelle Zahl $r$ allein steht für $r\ \text{Sonne}$.
- Das Nullelement heißt **0** ($0\ \text{Sonne} + 0\ \text{Mond}$).
- Terme mit Koeffizient $0$ entfallen: $3\ \text{Sonne} + 0\ \text{Mond} = 3\ \text{Sonne}$.
- Koeffizienten **exakt** angeben (Brüche, Wurzeln). Dezimalzahlen nur, wenn sie verlangt werden.

## Grundregeln

$$\text{Sonne} \cdot \text{Sonne} = \text{Sonne} \qquad \text{Sonne} \cdot \text{Mond} = \text{Mond} \qquad \text{Mond} \cdot \text{Mond} = -\text{Sonne}$$

**Mondzyklus** (Potenzen des Mondes wiederholen sich mit Periode 4):

| $n$ | 0 | 1 | 2 | 3 | 4 |
|---|---|---|---|---|---|
| $\text{Mond}^n$ | Sonne | Mond | −Sonne | −Mond | Sonne |

## Operationen

Für $z = a\ \text{Sonne} + b\ \text{Mond}$ und $w = c\ \text{Sonne} + d\ \text{Mond}$:

| Operation | Formel |
|---|---|
| Addition | $z + w = (a + c)\ \text{Sonne} + (b + d)\ \text{Mond}$ |
| Subtraktion | $z - w = (a - c)\ \text{Sonne} + (b - d)\ \text{Mond}$ |
| Multiplikation | $z \cdot w = (ac - bd)\ \text{Sonne} + (ad + bc)\ \text{Mond}$ |
| Konjugation | $\bar{z} = a\ \text{Sonne} - b\ \text{Mond}$ |
| Betrag | $\lvert z \rvert = \sqrt{a^2 + b^2}$ (reelle Zahl, also $\sqrt{a^2 + b^2}\ \text{Sonne}$) |
| Division ($w \neq 0$) | $\dfrac{z}{w} = \dfrac{z \cdot \bar{w}}{c^2 + d^2} = \dfrac{ac + bd}{c^2 + d^2}\ \text{Sonne} + \dfrac{bc - ad}{c^2 + d^2}\ \text{Mond}$ |
| Polarform | $z = r\,(\cos\varphi\ \text{Sonne} + \sin\varphi\ \text{Mond})$ mit $r = \lvert z \rvert$ |
| Potenz | $z^n = r^n\,(\cos n\varphi\ \text{Sonne} + \sin n\varphi\ \text{Mond})$ |
| Wurzel | $n$ Lösungen: $\sqrt[n]{r}\,\big(\cos\tfrac{\varphi + 2k\pi}{n}\ \text{Sonne} + \sin\tfrac{\varphi + 2k\pi}{n}\ \text{Mond}\big)$, $k = 0, \dots, n-1$ |

Die Körpergesetze gelten wie in $\mathbb{C}$: Addition und Multiplikation sind kommutativ und assoziativ, die Multiplikation ist distributiv über der Addition. Jede Zahl außer $0$ hat ein multiplikatives Inverses.

## Ablauf

1. **Ausdruck lesen:** Schreibweisen vereinheitlichen, Klammern und Rangfolge beachten (Potenz vor Punkt vor Strich).
2. **Rechnen:** ausmultiplizieren, $\text{Mond}^2$ durch $-\text{Sonne}$ ersetzen, Sonnen- und Mondanteile getrennt zusammenfassen. Bei Division mit dem Konjugierten des Nenners erweitern.
3. **Antworten:** zuerst das Ergebnis in Normalform, danach den kurzen Rechenweg.

## Beispiele

| Ausdruck | Ergebnis | Rechenweg |
|---|---|---|
| Sonne · Mond | **Mond** | Sonne ist neutral |
| Mond · Mond | **−Sonne** | Grundregel |
| Mond³ | **−Mond** | Mondzyklus |
| (Sonne + Mond)² | **2 Mond** | Sonne + 2 Mond + Mond² = Sonne + 2 Mond − Sonne |
| (3 Sonne + 2 Mond) · (Sonne − Mond) | **5 Sonne − Mond** | 3 Sonne − 3 Mond + 2 Mond − 2 Mond² = 3 Sonne − Mond + 2 Sonne |
| Sonne / Mond | **−Mond** | Erweitern mit −Mond: −Mond / (−Mond²) = −Mond / Sonne |
| (2 Sonne + Mond) / (Sonne − Mond) | **½ Sonne + 3⁄2 Mond** | (2 Sonne + Mond)(Sonne + Mond) / 2 = (Sonne + 3 Mond) / 2 |
| \|3 Sonne + 4 Mond\| | **5** (also 5 Sonne) | $\sqrt{9 + 16}$ |
| √(−Sonne) | **±Mond** | (±Mond)² = −Sonne |

## Grenzen

- Der Körper kennt **nur** Sonne, Mond und reelle Koeffizienten. Andere Symbole sind darin nicht definiert. Solche Ausdrücke nicht umdeuten, sondern darauf hinweisen, dass sie keine Sonne-Mond-Rechnung sind.
- Division durch $0$ ist nicht definiert.

*Demo-Skill des Demo-Assistenten `astronom` von AIbex AIOS.*
