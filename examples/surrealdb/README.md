# Example using SurrealDB service in devenv

This example shows how to use the SurrealDB service in your development environment.

## Basic usage

```nix
{
  services.surrealdb = {
    enable = true;
    port = 8000;
    # always set custom credentials for security
    user = "admin";
    password = "your-secure-password";
  };
}
```

## Advanced configuration

```nix
{
  services.surrealdb = {
    enable = true;
    
    # network configuration
    bind = "0.0.0.0";
    port = 8000;
    
    # authentication (never use default credentials!)
    user = "admin";
    password = "secret-password";
    
    # logging
    logLevel = "debug";
    
    # storage backend
    storage = "file://${config.env.DEVENV_STATE}/surrealdb/data.db";
    
    # additional arguments (as list)
    extraArgs = [ "--strict" "--allow-funcs" ];
    
    # initial databases to create
    initialDatabases = [ "myapp" "testdb" ];
    
    # initial setup script
    initialScript = ''
      DEFINE NAMESPACE myapp;
      USE NS myapp;
      DEFINE DATABASE mydb;
      DEFINE TABLE user SCHEMAFULL;
      DEFINE FIELD name ON user TYPE string;
      DEFINE FIELD email ON user TYPE string ASSERT string::is::email($value);
    '';
  };
}
```

## Storage backends

SurrealDB supports multiple storage backends with different tradeoffs:

- `memory` - fastest performance, no persistence (data lost on restart)
  - best for: quick tests, temporary data, CI environments
- `file://path` - good performance, persisted to disk
  - best for: development, small to medium datasets
- `rocksdb://path` - production-grade performance, advanced features
  - best for: production-like testing, larger datasets

Example configurations:

```nix
# in-memory (fastest, not persisted)
services.surrealdb.storage = "memory";

# file-based (persisted, good performance)
services.surrealdb.storage = "file://${config.env.DEVENV_STATE}/surrealdb/data.db";

# rocksdb (persisted, best performance)
services.surrealdb.storage = "rocksdb://${config.env.DEVENV_STATE}/surrealdb/rocksdb";
```

## Environment variables

When the SurrealDB service is enabled, the following environment variables are available:

- `SURREALDB_URL`: The connection URL (e.g., `http://127.0.0.1:8000`)
- `SURREALDB_USER`: The configured username
- `SURREALDB_PASS`: The configured password
- `SURREALDB_DATA`: The data directory path

## Using the SurrealDB CLI

You can interact with SurrealDB using the provided CLI:

```bash
# Connect to the database
surreal sql --conn $SURREALDB_URL --user $SURREALDB_USER --pass $SURREALDB_PASS

# Create a namespace and database
surreal sql --conn $SURREALDB_URL --user $SURREALDB_USER --pass $SURREALDB_PASS --query "CREATE mynamespace; USE NS mynamespace; CREATE mydatabase;"

# Run a query file
surreal sql --conn $SURREALDB_URL --user $SURREALDB_USER --pass $SURREALDB_PASS --file queries.surql
```

## Integration with applications

Your applications can connect to SurrealDB using the provided environment variables:

```javascript
// Example in Node.js
const db = new Surreal(`${process.env.SURREALDB_URL}/rpc`);
await db.signin({
  user: process.env.SURREALDB_USER,
  pass: process.env.SURREALDB_PASS,
});
```

## Health checks

The service includes a health check that verifies SurrealDB is responding to queries. The service will automatically restart if it becomes unhealthy.