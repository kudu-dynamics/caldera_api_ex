#!/bin/sh

# Entrypoint script for use in the Dockerfile.

# Set the REL_DIR variable to point to the release directory containing the
# bin folder that needs to be run.
case "${MIX_ENV}" in
  prod)
    REL_DIR=.
    ;;
  *)
    REL_DIR=./_build/dev/rel/caldera_api
esac

"${REL_DIR}/bin/caldera_api" start
