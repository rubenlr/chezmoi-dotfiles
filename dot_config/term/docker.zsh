##
## Testcontainers + Docker (local): align JVM with `docker context`; Ryuk uses VM-side socket
################################################################################
#export TESTCONTAINERS_RYUK_DISABLED=true
#export TESTCONTAINERS_HOST_OVERRIDE=127.0.0.1
# DOCKER_HOST: active context endpoint first (matches `docker info`), then socket scan
# (Colima before Rancher so stale ~/.rd/docker.sock does not beat Colima).
unset DOCKER_HOST
if command -v docker >/dev/null 2>&1; then
  _ctx=$(docker context show 2>/dev/null) || _ctx=
  if [[ -n "${_ctx}" ]]; then
    _ctx_host=$(docker context inspect "${_ctx}" -f '{{.Endpoints.docker.Host}}' 2>/dev/null) || _ctx_host=
    if [[ -n "${_ctx_host}" ]]; then
      export DOCKER_HOST="${_ctx_host}"
    fi
    unset _ctx_host
  fi
  unset _ctx
fi
if [[ -z "${DOCKER_HOST:-}" ]]; then
  for _docker_sock in \
    "${HOME}/.colima/default/docker.sock" \
    "${HOME}/.rd/docker.sock" \
    "${HOME}/.docker/run/docker.sock" \
    "/var/run/docker.sock"
  do
    if [[ -S "${_docker_sock}" ]]; then
      export DOCKER_HOST="unix://${_docker_sock}"
      break
    fi
  done
  unset _docker_sock
fi
# Colima/Rancher: client socket is on macOS; Ryuk must mount /var/run/docker.sock inside the Linux VM.
# Leave unset on Linux/CI and when already using /var/run/docker.sock (Docker Desktop symlink).
unset TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE
if [[ "$(uname -s)" == Darwin ]] && [[ -n "${DOCKER_HOST:-}" ]]; then
  _tc_sock="${DOCKER_HOST#unix://}"
  if [[ -n "${_tc_sock}" && "${_tc_sock}" != "/var/run/docker.sock" ]]; then
    export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock
  fi
  unset _tc_sock
fi
