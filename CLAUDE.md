# CLAUDE.md

## Objective

This project must be maintained with a professional approach, prioritizing:

- readability,
- maintainability,
- simplicity,
- decoupling,
- and ease of evolution.

---

# Development Principles

## Architecture and Design

- Always follow SOLID principles.
- Apply Clean Code practices in every new implementation.
- Prioritize simple solutions following the KISS principle.
- Avoid accidental complexity and unnecessary abstractions.
- Favor composition over inheritance whenever possible.
- Keep responsibilities clearly separated and well defined.

---

# Code Conventions

## Naming

- Do not abbreviate variable, function, class, constant, or property names.
- Names must clearly express their intent.
- Avoid generic names such as:
  - data
  - value
  - temp
  - manager
  - utils

### Examples

Correct:

[vala]
offset = 5
label = "eof"
draw_canvas()
[/vala]

Incorrect:

[vala]
cp_ox = 0
l = "eof"
d_canv()
[/vala]

---

# Documentation

- All functions must include brief and clear documentation written in Spanish.
- Documentation must summarize the responsibility of the function.
- Document parameters and return values whenever relevant.
- Avoid redundant comments that merely repeat the code literally.

### Example

[vala]

```
/**
 * Cotas arquitectónicas en el EXTERIOR de cada segmento:
 *   – Líneas de extensión desde los extremos del segmento hacia afuera
 *   – Línea de cota paralela al segmento (a OFF1 px de la pared)
 *   – Flechas rellenas en ambos extremos de la cota
 *   – Etiqueta de medida (a OFF1+OFF2 px de la pared)
 */
private void paint_segment_labels(Cairo.Context cr)
{
  //
}
```

[/vala]

---

# Interface and Events

- Use the Observer pattern to decouple interface events from application logic.
- The interface must not contain business logic.
- UI events must delegate behavior to classes responsible for application logic.
- Avoid direct coupling between visual components and services.

---

# Code Quality

- Write small functions with a single responsibility.
- Avoid functions with multiple levels of abstraction.
- Minimize side effects whenever possible.
- Avoid logic duplication.
- Use comments only when they provide context that the code itself cannot clearly express.

---

# GTK / Vala Specific Rules

- Keep widgets decoupled from services and business logic.
- Centralize signals and events using Observer or EventBus patterns.
- Avoid complex logic inside GTK callbacks.
- Clearly separate presentation, state, and application logic.

---

# Change Verification

Before finalizing any change:

1. Verify that the project compiles correctly.
2. Check that there are no typing or linting errors.
3. Ensure that the changes do not break existing functionality.
4. Run tests if they exist.

Never consider a change complete without performing these checks.

---

# Restrictions

- Do not introduce unnecessary dependencies.
- Do not use temporary hacks.
- Do not silence errors without explicit justification.
- Do not mix presentation logic with business logic.
