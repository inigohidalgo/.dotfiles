# call PDM functionality to activate venv
function pdm-activate
  eval (pdm venv activate "$argv[1]")
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
  