{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

pkgs.buildFHSEnv {
  name = "yocto-fhs-env";

  targetPkgs = pkgs: with pkgs; [
    # Core toolchains & build systems
    gcc
    binutils
    gnumake
    cmake
    meson
    ninja
    pkg-config
    libtool
    autoconf
    automake
    bison
    flex
    m4
    patch
    diffutils
    diffstat

    # Python runtime and Yocto-specific host packages
    (python3.withPackages (ps: with ps; [
      jinja2
      pexpect
      gitpython
      pip
      setuptools
    ]))

    # Source control and Qualcomm repo tool
    git
    git-repo
    git-lfs
    openssh
    cacert

    # Compression and archives
    gnutar
    gzip
    bzip2
    xz
    zstd
    lz4
    cpio
    unzip
    zip

    # Core POSIX and host utilities
    bashInteractive
    coreutils
    findutils
    gawk
    gnused
    gnugrep
    which
    file
    socat
    chrpath
    texinfo
    newt # provides whiptail
    util-linux
    iputils
    hostname
    procps
    psmisc
    vim
    wget
    curl
    rsync

    # System development libraries & headers
    glibc
    glibcLocales
    libxcrypt
    ncurses
    zlib
    openssl
    libxml2
    glib
    rpcsvc-proto

    # Graphics, Wayland, and X11 dependencies for host tools
    mesa
    libGL
    libGLU
    SDL
    libx11
    libxext
    libxrender
    libxcb
    xterm

    # Perl packages required by Yocto / OpenEmbedded
    perl
    perlPackages.XMLSimple
  ];

  multiPkgs = pkgs: with pkgs; [
    zlib
    glibc
    libxcrypt
  ];

  extraOutputsToInstall = [ "dev" ];

  extraBuildCommands = ''
    # Yocto HOSTTOOLS expects lz4c (legacy symlink to lz4)
    ln -sf lz4 $out/usr/bin/lz4c

    # Ensure libcrypt compatibility symlinks exist
    ln -sf libcrypt.so $out/usr/lib/libcrypt.so.1 2>/dev/null || true
    ln -sf libcrypt.so $out/usr/lib64/libcrypt.so.1 2>/dev/null || true

    # Dummy direnv in /usr/local/bin to prevent host direnv from modifying FHS environment
    mkdir -p $out/usr/local/bin
    cat > $out/usr/local/bin/direnv << 'EOF'
#!/bin/sh
exit 0
EOF
    chmod +x $out/usr/local/bin/direnv
  '';

  profile = ''
    # Environment identifier
    export IN_YOCTO_FHS=1

    # Disable direnv inside FHS to prevent environment poisoning
    export DIRENV_DIR=""
    export DIRENV_FILE=""
    _direnv_hook() { return 0; }
    export -f _direnv_hook 2>/dev/null || true
    if [[ -n "''${PROMPT_COMMAND:-}" ]]; then
      PROMPT_COMMAND="$(echo "$PROMPT_COMMAND" | sed -e 's/_direnv_hook;//g' -e 's/;\?_direnv_hook//g')"
    fi

    # Enforce UTF-8 locale strictly required by BitBake
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    export LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive"

    # Ensure bash is used as the shell
    export SHELL=/bin/bash

    # Standard FHS search paths
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

    # Mark current and sub repositories as safe for git
    git config --global --add safe.directory "*" 2>/dev/null || true
  '';

  runScript = "bash";
}
