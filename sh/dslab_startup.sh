dslab_startup() {
    sudo /home/jovyan/system_setup/install-packages.sh
    load_aa_env
    code_tunnel start
}