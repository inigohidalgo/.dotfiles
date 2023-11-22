# call PDM functionality to activate venv
function pdm-activate
  eval (pdm venv activate "$argv[1]")
end

function create_venv
    if set -q $argv[1]; and test -n $argv[1]
      set conda_source_env $argv[1]
    else
      set conda_source_env py310
      echo "WARNING: No source conda environment specified, using $conda_source_env"
    end
  
    if set -q argv[2]; and test -n $argv[2]
      set virtual_env $argv[2]
    else
      set virtual_env .venv
      echo "WARNING: No virtual environment specified, using $virtual_env"
    end

    set create_venv_command "conda run -n $conda_source_env python -m venv $virtual_env"
    echo $create_venv_command
    eval $create_venv_command
end

function activate_venv
    set virtual_env .venv
    argparse -n activate_venv 'virtual_env=' -- $argv
    source $virtual_env/bin/activate.fish
end


function install_ipykernel_pwd
  set current_directory (basename $PWD)
  set command "python -m ipykernel install --user --name temp.$current_directory --display-name temp/$current_directory"
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
  