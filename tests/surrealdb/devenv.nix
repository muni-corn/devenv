{ pkgs, ... }:
{
  services.surrealdb = {
    enable = true;
    port = 8000;
    # use non-default credentials for testing
    user = "testuser";
    password = "testpass123";

    # use memory storage for testing
    storage = "memory";

    # create a test database
    initialDatabases = [ "testdb" ];

    # simple initial setup
    initialScript = ''
      USE NS testdb DB test;
      DEFINE TABLE test SCHEMAFULL;
      DEFINE FIELD name ON test TYPE string;
    '';
  };

  scripts.surrealdb-test = ''
    echo "testing surrealdb connection..."
    
    # test connection and basic query
    ${pkgs.surrealdb}/bin/surreal sql \
      --conn http://127.0.0.1:8000 \
      --user testuser \
      --pass testpass123 \
      --query "INFO FOR DB;" 2>/dev/null || {
        echo "failed to connect to surrealdb"
        exit 1
      }
    
    echo "surrealdb is running and accessible!"
  '';

  scripts.surrealdb-query = ''
    ${pkgs.surrealdb}/bin/surreal sql \
      --conn http://127.0.0.1:8000 \
      --user testuser \
      --pass testpass123 \
      --query "$1"
  '';
}
