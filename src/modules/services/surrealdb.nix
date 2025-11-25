{ pkgs
, lib
, config
, ...
}:

with lib;

let
  cfg = config.services.surrealdb;

  # validate storage backend format
  validatedStorage =
    if
      cfg.storage == "memory"
      || lib.hasPrefix "file://" cfg.storage
      || lib.hasPrefix "rocksdb://" cfg.storage
      || lib.hasPrefix "tikv://" cfg.storage
    then
      cfg.storage
    else
      throw "Invalid storage backend '${cfg.storage}'. Must be 'memory', 'file://path', 'rocksdb://path', or 'tikv://path'";

  # build extra arguments from list
  extraArgsString = lib.concatStringsSep " " cfg.extraArgs;

  startScript = pkgs.writeShellScriptBin "start-surrealdb" ''
    set -euo pipefail

    if [[ ! -d "$SURREALDB_DATA" ]]; then
      mkdir -p "$SURREALDB_DATA"
    fi

    exec ${cfg.package}/bin/surreal start \
      --bind ${cfg.bind}:${toString cfg.port} \
      --log ${cfg.logLevel} \
      --user ${cfg.user} \
      --pass ${cfg.password} \
      ${extraArgsString} \
      ${validatedStorage}
  '';
in
{
  options.services.surrealdb = {
    enable = mkEnableOption "SurrealDB and expose utilities";

    package = mkOption {
      type = types.package;
      description = "Which package of SurrealDB to use";
      default = pkgs.surrealdb;
      defaultText = lib.literalExpression "pkgs.surrealdb";
    };

    bind = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        The IP address to bind to.
      '';
      example = "0.0.0.0";
    };

    port = mkOption {
      type = types.port;
      default = 8000;
      description = ''
        The TCP port to accept connections.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "surrealdb";
      description = ''
        The root username for authentication.
      '';
    };

    password = mkOption {
      type = types.str;
      description = ''
        The root password for authentication.
      '';
    };

    logLevel = mkOption {
      type = types.enum [
        "error"
        "warn"
        "info"
        "debug"
        "trace"
        "full"
      ];
      default = "info";
      description = ''
        The log level for SurrealDB.
      '';
    };

    storage = mkOption {
      type = types.str;
      default = "memory";
      description = ''
        The storage backend to use. Can be 'memory', 'file://path', 'rocksdb://path', or 'tikv://path'.

        Note: For development environments, 'memory' provides the fastest performance but data is not persisted.
        Use 'file://' for persistence with good performance, or 'rocksdb://' for production-like setups.
      '';
      example = lib.literalExpression ''
        "file://''${config.env.DEVENV_STATE}/surrealdb/data.db"
      '';
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Additional command line arguments to pass to surreal start.
      '';
      example = lib.literalExpression ''
        [ "--strict" "--allow-funcs" ]
      '';
    };

    initialDatabases = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of database names to create on first startup.
      '';
      example = lib.literalExpression ''
        [ "myapp" "testdb" ]
      '';
    };

    initialScript = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Initial SurrealQL commands to run during database initialization.
      '';
      example = lib.literalExpression ''
        "DEFINE NAMESPACE myapp; USE NS myapp; DEFINE DATABASE mydb;"
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ cfg.package ];

    env = {
      SURREALDB_DATA = config.env.DEVENV_STATE + "/surrealdb";
      SURREALDB_URL = "http://${cfg.bind}:${toString cfg.port}";
      SURREALDB_USER = cfg.user;
      SURREALDB_PASS = cfg.password;
    };

    processes.surrealdb = {
      exec = "${startScript}/bin/start-surrealdb";
      process-compose.availability.restart = "on_failure";
    };

    # run initial setup script if provided
    scripts.surrealdb-setup = lib.mkIf (cfg.initialScript != null || cfg.initialDatabases != [ ]) (
      pkgs.writeShellScriptBin "surrealdb-setup" ''
        set -euo pipefail

        echo "waiting for surrealdb to be ready..."
        timeout=60
        elapsed=0
        until ${readinessCheck}; do
          if [ $elapsed -ge $timeout ]; then
            echo "error: timed out waiting for surrealdb to start"
            exit 1
          fi
          sleep 1
          elapsed=$((elapsed + 1))
        done

        echo "setting up surrealdb..."

        ${lib.optionalString (cfg.initialDatabases != [ ]) ''
          echo "creating initial databases..."
          ${lib.concatMapStringsSep "\n" (db: ''
            ${cfg.package}/bin/surreal sql --conn http://${cfg.bind}:${toString cfg.port} --user ${cfg.user} --pass ${cfg.password} --query "DEFINE DATABASE IF NOT EXISTS ${db};" || {
              echo "error: failed to create database '${db}'"
              exit 1
            }
          '') cfg.initialDatabases}
        ''}

        ${lib.optionalString (cfg.initialScript != null) ''
          echo "running initial script..."
          echo ${lib.escapeShellArg cfg.initialScript} | ${cfg.package}/bin/surreal sql --conn http://${cfg.bind}:${toString cfg.port} --user ${cfg.user} --pass ${cfg.password} || {
            echo "error: failed to run initial script"
            exit 1
          }
        ''}

        echo "surrealdb setup complete!"
      ''
    );
  };
}
