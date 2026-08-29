#!/bin/bash
# SessionStart hook for Claude Code on the web.
#
# This is a pure Go module (module github.com/mantany/netcupcloud, go.mod at
# the repo root). It has no package manager beyond `go`, no lockfile beyond
# go.sum, and no separate lint config -- golangci-lint runs with its
# built-in defaults. What actually blocks a fresh remote container from
# running `go build`/`go vet`/`go test`/`golangci-lint run` is:
#   1. the module cache is empty (no network fetch has ever happened here)
#   2. netcupcloud/session's TestMain calls test.LoadLocalEnvironment(),
#      which log.Fatal()s the whole test binary if
#      netcupcloud/test/local.env is missing -- so with nothing else done,
#      *zero* tests in that package ever run, pass or fail.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}"

# Populate the module cache (go build/vet/test/golangci-lint all need this).
# `go mod download` rather than `go mod tidy`/`vendor`: it only fetches what
# go.sum already pins, so it's safe to rerun and plays well with caching the
# container image after the hook completes.
go mod download

# Warm the build cache too, so the first `go test`/`go vet` in the session
# isn't also the first compile.
go build ./... || true

# README.md step 1 ("Test the package"): copy the example env so
# TestMain's LoadLocalEnvironment() doesn't log.Fatal() before any test in
# netcupcloud/session runs. The placeholder credentials in
# local.env.example are fake (see enablePaidTest = false in
# netcupcloud/test/helper.go), so auth-dependent tests will correctly fail
# against the real netcup API -- that's expected without a real account,
# not a hook problem. Only write it if the developer hasn't supplied their
# own real local.env (never overwrite real credentials).
local_env="netcupcloud/test/local.env"
local_env_example="netcupcloud/test/local.env.example"
if [ ! -f "$local_env" ] && [ -f "$local_env_example" ]; then
  cp "$local_env_example" "$local_env"
fi

echo "Session start hook: go modules downloaded, build cache warmed, test env scaffolded."
