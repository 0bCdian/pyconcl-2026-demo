# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Slidev for the talk deck (the user's choice). The live demo surfaces already exist: the arena (`arena/`, FastAPI + static HTML) and Grafana (kube-prometheus-stack in GKE).

## Users

People attending the talk at PyCon Chile 2026: Python developers at an intermediate level (the talk is tagged Intermedio, Contenedores, Despliegue) who already ship Python in containers. In person on November 14 in Santiago, 16:45–17:15, watching a projector and tapping on their phones during the demo; online on November 15. The talk is in Spanish.

## Product Purpose

A 30-minute talk, "Misma app, dos resultados distintos: Buenas prácticas para desplegar Python en contenedores". The same `app.py` is deployed two ways, with identical Kubernetes manifests; only the image and how the process starts differ. The deck prepares and frames a live demo in which the audience's own orders show what each deployment loses. Success: attendees leave knowing which practices matter most, by measured impact, and can apply them the next week.

## Positioning

Every claim is a measurement from this repository, reproducible with its scripts, against a fair setup (same code, same manifest, same resources, same load). The audience generates real traffic from their phones and sees the difference live, instead of being told about it.

## Operating Context

- Projected in a conference room; the presenter switches between the deck, the arena screen (`/screen`) and Grafana during the demo.
- About 10–12 of the 30 minutes are live demo: the arena with the audience's phones, a traffic peak at ~550 rps per version, and a deploy (orders charged without confirmation).
- The deck carries the narrative before and after each live moment and must still stand on its own if the network or cluster fails.

## Capabilities and Constraints

- Order of the practices: by measured impact. Workers sized to the container's CPU, then `exec`/signals, then no DEBUG in production, slim image, precompiled bytecode, and non-root user (security, not performance).
- Numbers come only from README.md and CHECKLIST.md measurements; nothing is invented or rounded into a stronger claim. Measurements from a single run are labeled as such.
- Known limits stay in the talk: past ~650 rps the good version also collapses; the 1 GiB memory event only stalls the bad version's deploy.
- Undecided: speaker contact details, final Q&A time, and the PyCon Chile 2026 visual assets (none are in the repository).

## Brand Commitments

PyCon Chile 2026: event name, date and the official talk title. No employer branding.

## Evidence on Hand

- README.md: result tables (Podman and GKE), the per-practice ranking, processes per pod, and the code lessons.
- CHECKLIST.md: the practices checklist.
- Grafana screenshots of the stress ramps and the arena screenshots produced during testing (currently in the session scratchpad, to be copied into the deck's assets).
- No PyCon Chile logo, speaker photo, or audience quotes exist in the repository; none are to be fabricated.

## Product Principles

1. Prove, don't claim: each slide's number has a source in the repository.
2. Fairness is the thesis: same `app.py`, same manifest, same resources, same load.
3. The demo is the protagonist; slides set it up and pay it off.
4. Honest about limits, including where the good version fails.
5. Every practice ends in a concrete change the attendee can make.
