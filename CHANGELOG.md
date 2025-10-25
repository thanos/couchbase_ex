# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of CouchbaseEx Elixir client
- High-performance Zig server backend for Couchbase operations
- Comprehensive CRUD operations (get, set, insert, replace, upsert, delete)
- N1QL query support with parameterized queries
- Subdocument operations (lookup_in, mutate_in)
- Health and diagnostics (ping, diagnostics)
- Connection management with configurable timeouts and pool sizes
- Robust error handling with custom error types
- Comprehensive configuration system with environment variable support
- Complete test suite with unit and integration tests
- Hex.pm package metadata and documentation

### Features

#### Core Client API
- `CouchbaseEx.connect/0` - Connect using configuration
- `CouchbaseEx.connect/1` - Connect with options override
- `CouchbaseEx.connect/4` - Connect with explicit parameters
- `CouchbaseEx.close/1` - Close client connection

#### CRUD Operations
- `CouchbaseEx.get/2` - Retrieve documents by key
- `CouchbaseEx.set/3` - Store documents with optional expiry and durability
- `CouchbaseEx.insert/3` - Insert new documents (fails if exists)
- `CouchbaseEx.replace/3` - Replace existing documents
- `CouchbaseEx.upsert/3` - Insert or update documents
- `CouchbaseEx.delete/2` - Delete documents by key
- `CouchbaseEx.exists/2` - Check if document exists

#### Query Operations
- `CouchbaseEx.query/2` - Execute N1QL queries
- `CouchbaseEx.query/3` - Execute parameterized N1QL queries

#### Subdocument Operations
- `CouchbaseEx.lookup_in/3` - Perform subdocument lookups
- `CouchbaseEx.mutate_in/3` - Perform subdocument mutations

#### Health and Diagnostics
- `CouchbaseEx.ping/1` - Ping cluster services
- `CouchbaseEx.diagnostics/1` - Get cluster diagnostics

#### Configuration System
- Environment variable configuration support
- `.env` file support with `dotenvy` library
- Environment-specific `.env` files (`.env.dev`, `.env.test`, `.env.prod`)
- Local override files (`.env.{environment}.local`)
- Runtime configuration with `config/runtime.exs`
- Development configuration with `config/dev.exs`
- Test configuration with `config/test.exs`
- Production configuration with `config/prod.exs`
- Programmatic configuration override

#### Error Handling
- Custom `CouchbaseEx.Error` struct with detailed error information
- Error conversion from Zig server responses
- Retry logic with exponential backoff
- Comprehensive error types and messages

#### Testing
- Unit tests for all core functionality (73 tests)
- Integration tests for Couchbase server operations (14 tests)
- Test organization with proper tagging
- Mock support with Mox for unit testing
- Test aliases for different test types

### Technical Details

#### Architecture
- Elixir Port-based communication with Zig server
- GenServer-based PortManager for process lifecycle management
- Asynchronous command processing with request/response correlation
- JSON-based message protocol between Elixir and Zig

#### Zig Server
- High-performance Couchbase operations in Zig
- Command-line argument parsing for connection configuration
- JSON message processing and response generation
- Comprehensive error handling and reporting

#### Configuration Options
- Connection string validation
- Username and password authentication
- Bucket selection
- Timeout configuration (operation, connection, query)
- Pool size configuration
- Durability settings
- Expiry settings

#### Dependencies
- `jason` - JSON encoding/decoding
- `mox` - Mocking for tests (test only)
- `ex_doc` - Documentation generation (dev only)
- `dialyxir` - Static analysis (dev only)
- `credo` - Code analysis (dev only)
- `sobelow` - Security analysis (dev only)
- `quokka` - Test coverage (dev only)

### Environment Variables
- `COUCHBASE_HOST` - Couchbase connection string
- `COUCHBASE_USER` - Username for authentication
- `COUCHBASE_PASSWORD` - Password for authentication
- `COUCHBASE_BUCKET` - Default bucket name
- `COUCHBASE_TIMEOUT` - Default operation timeout
- `COUCHBASE_CONNECTION_TIMEOUT` - Connection establishment timeout
- `COUCHBASE_QUERY_TIMEOUT` - N1QL query timeout
- `COUCHBASE_OPERATION_TIMEOUT` - Individual operation timeout
- `COUCHBASE_POOL_SIZE` - Connection pool size
- `COUCHBASE_ZIG_SERVER_PATH` - Path to Zig server executable
- `COUCHBASE_BUILD_ZIG_SERVER_ON_STARTUP` - Whether to build Zig server on startup

### Configuration Files
- `config/config.exs` - Base configuration
- `config/runtime.exs` - Runtime configuration with env vars
- `config/dev.exs` - Development configuration
- `config/test.exs` - Test configuration
- `config/prod.exs` - Production configuration

### Test Commands
- `mix test.unit` - Run unit tests only
- `mix test.integration` - Run integration tests only
- `mix test.all` - Run all tests
- `mix lint` - Run code quality checks

### Documentation
- Comprehensive README with usage examples
- API documentation with ExDoc
- Inline code documentation
- Configuration examples
- Error handling guide

## [0.1.0] - 2024-01-XX

### Added
- Initial release
- Basic Couchbase client functionality
- Zig server integration
- Configuration system
- Test suite
- Documentation

---

## Development Notes

### Building the Zig Server
The Zig server is built automatically during compilation or can be built manually:

```bash
# Build Zig server
./priv/build_zig_server.sh

# Or use Mix task
mix build_zig_server
```

### Testing
```bash
# Run unit tests (no external dependencies)
MIX_ENV=test mix test.unit

# Run integration tests (requires Couchbase server)
MIX_ENV=test mix test.integration

# Run all tests
MIX_ENV=test mix test.all
```

### Configuration
The client supports multiple configuration methods:

1. **Environment Variables** (recommended for production)
2. **Configuration Files** (recommended for development)
3. **Programmatic Override** (for dynamic configuration)

### Error Handling
All operations return `{:ok, result}` or `{:error, CouchbaseEx.Error.t()}` tuples. The Error struct includes:
- `reason` - Error type (atom)
- `message` - Human-readable error message
- `details` - Additional error details (map)

### Performance
The Zig server provides high-performance Couchbase operations with:
- Minimal memory overhead
- Fast JSON processing
- Efficient connection pooling
- Low-latency operations

### Security
- Secure credential handling
- Input validation
- Error message sanitization
- No credential logging
