# call PDM functionality to activate venv
function pdm-activate
  eval (pdm venv activate "$argv[1]")
end

set default_venv_name .venv

function create_venv
    if set -q argv[1]; and test -n $argv[1]
      set mise_source_env $argv[1]
    else
      set mise_source_env 3.10
      echo "WARNING: No source mise environment specified, using $mise_source_env"
    end
  
    if set -q argv[2]; and test -n $argv[2]
      set virtual_env $argv[2]
    else
      set virtual_env $default_venv_name
      echo "WARNING: No virtual environment specified, using $virtual_env"
    end

    set create_venv_command "mise exec python@$mise_source_env -- uv venv $virtual_env"
    echo $create_venv_command
    eval $create_venv_command
end

function activate_venv
  if set -q argv[1]; and test -n $argv[1]
    set virtual_env $argv[1]
  else
    set virtual_env $default_venv_name
    echo "WARNING: No virtual environment specified, using $virtual_env"
  end
  source $virtual_env/bin/activate.fish
end

alias cv="create_venv"
alias av="activate_venv"

alias uvp="uv pip install"

function install_ipykernel -d "Install ipykernel for currently-activated venv. Optionally specify kernel name and kernel display name"
  set current_directory (basename $PWD)
  if set -q argv[1]; and test -n $argv[1]
    set kernel_name $argv[1]
    set kernel_name_supplied true
  else
    set kernel_name temp.$current_directory
    echo "WARNING: No kernel name specified, using $kernel_name"
    set kernel_name_supplied false
  end
  
  if set -q argv[2]; and test -n $argv[2]
    set kernel_display_name $argv[2]
  else if test $kernel_name_supplied
    set kernel_display_name $kernel_name
  else
    set kernel_display_name temp/$current_directory
  end
  
  set command "python -m ipykernel install --user --name $kernel_name --display-name $kernel_display_name"
  echo $command
  eval $command
end


# depends on twine and pdm
function twine-upload
  set -l repository $argv[1]
  if test -z "$repository"
      set repository test-buildfeed
      echo "WARNING: No repository specified, using $repository"
  end
  set -l build_version $argv[2]
  # if no version set, get version from pdm
  if test -z "$build_version"
      echo "WARNING: No version specified, getting current version from pdm"
      set build_version (pdm show --version)
  end
  set build_str "dist/*$build_version*"
  echo "Uploading $build_str to $repository"
  twine upload $build_str -r $repository
end

alias flake8 "flake8 --exclude .venv,.git,__pycache__,build,dist --max-line-length 120" # workaround for global flake8 config