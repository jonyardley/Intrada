use axum::{Router, response::Html, routing::get};
use std::net::SocketAddr;

async fn hello_world() -> Html<&'static str> {
    Html("<h1>Hello, World!</h1>")
}

async fn hello_json() -> &'static str {
    "Hello, World!"
}

#[tokio::main]
async fn main() {
    // Build our application with routes
    let app = Router::new()
        .route("/", get(hello_world))
        .route("/hello", get(hello_json));

    // Use PORT environment variable or default to 3000 for local development
    let port = std::env::var("PORT")
        .unwrap_or_else(|_| "3000".to_string())
        .parse::<u16>()
        .expect("PORT must be a valid number");

    // Run our app with hyper, listening globally on the configured port
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    println!("Server running on http://0.0.0.0:{port}");
    axum::serve(listener, app).await.unwrap();
}
