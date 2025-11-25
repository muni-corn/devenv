{ config, ... }:

{
  services.surrealdb = {
    enable = true;
    port = 8000;
    # set custom credentials for security
    user = "admin";
    password = "devenv-secure-password";

    # use file-based storage for persistence
    storage = "file://${config.env.DEVENV_STATE}/surrealdb/data.db";

    # create initial databases
    initialDatabases = [
      "myapp"
      "test"
    ];

    # set up basic schema
    initialScript = ''
      USE NS myapp DB mydb;
      DEFINE TABLE user SCHEMAFULL;
      DEFINE FIELD name ON user TYPE string;
      DEFINE FIELD email ON user TYPE string ASSERT string::is::email($value);
      DEFINE FIELD created_at ON user TYPE datetime DEFAULT time::now();
    '';
  };

  # add some example scripts
  scripts = {
    surrealdb-shell = ''
      echo "connecting to surrealdb..."
      surreal sql --conn $SURREALDB_URL --user $SURREALDB_USER --pass $SURREALDB_PASS
    '';

    surrealdb-info = ''
      echo "surrealdb connection info:"
      echo "url: $SURREALDB_URL"
      echo "user: $SURREALDB_USER"
      echo "data directory: $SURREALDB_DATA"
    '';
  };

  enterShell = ''
    echo "surrealdb is running on $SURREALDB_URL"
    echo "use 'surrealdb-shell' to connect to the database"
    echo "use 'surrealdb-info' to see connection details"
  '';
}
