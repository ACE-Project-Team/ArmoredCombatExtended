# Scenario: `ace.<layer>.<area>.<result>`

Title: [plain-English description]

Why it matters: [what a player is trying to do and why a failure is out of scope]

Check type: [smoke | static | registry | behavior | compatibility | lifecycle | regression | system | performance]

Layer: [offline | native | headless]
Runner: [python | luajit | gluatest | headless]
Dependencies: [none or named mounts]
Timeout: [seconds]

## Given

- [small, visible setup]

## When

- [one named player-facing action per step]

## Then

- [the useful result]
- [no runtime error, hang, or leaked entity]

## Core-function cases, when applicable

- Normal input: [the expected result]
- Invalid input: [the safe rejection or early return]
- Boundary input: [the edge value that matters]
- Side effect/delegation: [the hook, callback, cache, or helper that must/ must not run]

Failure output should name the scenario, the failed step, the expected result, and the observed result.
