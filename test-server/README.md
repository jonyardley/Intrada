# Test Server

A simple Rust web server that returns "Hello World".

## Running the Server

1. Make sure you have Rust installed
2. Navigate to the test-server directory
3. Run the server:

```bash
cargo run
```

The server will start on `http://127.0.0.1:3000`

## API Endpoints

### GET /
Returns "Hello World"

## Testing

You can test the endpoint using curl:

```bash
curl http://127.0.0.1:3000/
```

Or simply visit `http://127.0.0.1:3000/` in your browser. 