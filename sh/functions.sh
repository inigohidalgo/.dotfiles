# call PDM functionality to activate venv.
# If no arg is supplied, return default pdm venv (usually `.venv/`)
function pdm-activate(){
  eval $(pdm venv activate "$1")
}

# load envfile in arg1, if not supplied, defaults to ".env"
function dotenv(){
  local envfile="${1:-.env}"
  set -a; source $envfile; set +a
}

function load_aa_env(){
  env_script="$HOME/.config/.global-env/env.sh"
  [ -f "$env_script" ] && \
  . "$env_script"
}