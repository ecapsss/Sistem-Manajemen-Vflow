use std::net::SocketAddr;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let port = std::env::var("VFLOW_037_GRPC_PORT")
        .ok()
        .and_then(|v| v.parse::<u16>().ok())
        .unwrap_or(0);
    let addr: SocketAddr = format!("127.0.0.1:{port}").parse()?;
    let (mut reporter, service) = tonic_health::server::health_reporter();
    reporter
        .set_service_status("pricing-control", tonic_health::ServingStatus::Serving)
        .await;
    reporter
        .set_service_status("", tonic_health::ServingStatus::Serving)
        .await;
    println!("grpc health server listening on {addr}");
    tonic::transport::Server::builder()
        .add_service(service)
        .serve(addr)
        .await?;
    Ok(())
}
