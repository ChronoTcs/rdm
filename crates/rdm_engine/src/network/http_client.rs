use crate::error::{EngineError, Result};
use crate::models::CookieDto;
use reqwest::header::{HeaderMap, HeaderName, HeaderValue, ACCEPT_RANGES, CONTENT_DISPOSITION, CONTENT_LENGTH, RANGE};
use reqwest::Client;
use std::collections::HashMap;
use std::str::FromStr;
use std::time::Duration;

#[derive(Debug, Clone)]
pub struct ProbeMetadata {
    pub content_length: Option<u64>,
    pub accept_ranges: bool,
    pub filename: Option<String>,
    pub http_status: u16,
    pub content_type: Option<String>,
}

pub struct HttpClientWrapper {
    client: Client,
}

impl Default for HttpClientWrapper {
    fn default() -> Self {
        Self::new()
    }
}

impl HttpClientWrapper {
    pub fn new() -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(30))
            .pool_max_idle_per_host(32)
            .tcp_keepalive(Some(Duration::from_secs(60)))
            .build()
            .unwrap_or_default();

        Self { client }
    }

    pub fn build_headers(
        raw_headers: &HashMap<String, String>,
        _cookies: &[CookieDto],
    ) -> HeaderMap {
        let mut headers = HeaderMap::new();
        for (k, v) in raw_headers {
            if let (Ok(name), Ok(val)) = (HeaderName::from_str(k), HeaderValue::from_str(v)) {
                headers.insert(name, val);
            }
        }
        headers
    }

    pub async fn probe_metadata(
        &self,
        url: &str,
        headers: &HashMap<String, String>,
        cookies: &[CookieDto],
    ) -> Result<ProbeMetadata> {
        let mut req_headers = Self::build_headers(headers, cookies);
        // Request bytes=0-0 to test Range support and fetch metadata
        req_headers.insert(RANGE, HeaderValue::from_static("bytes=0-0"));

        let res = self
            .client
            .get(url)
            .headers(req_headers)
            .send()
            .await
            .map_err(|e| EngineError::Network(e.to_string()))?;

        let status = res.status().as_u16();
        if status == 403 || status == 410 {
            return Err(EngineError::UrlExpired(status));
        }

        let resp_headers = res.headers();

        // Check accept ranges
        let accept_ranges = if let Some(val) = resp_headers.get(ACCEPT_RANGES) {
            val.to_str().unwrap_or("").to_lowercase().contains("bytes")
        } else {
            status == 206
        };

        // Parse content length from Content-Range or Content-Length
        let mut content_length = None;
        if let Some(cr) = resp_headers.get("content-range") {
            if let Ok(cr_str) = cr.to_str() {
                // e.g. "bytes 0-0/12345678"
                if let Some(slash_idx) = cr_str.rfind('/') {
                    let total_str = &cr_str[slash_idx + 1..].trim();
                    if let Ok(total) = total_str.parse::<u64>() {
                        content_length = Some(total);
                    }
                }
            }
        }

        if content_length.is_none() {
            if let Some(cl) = resp_headers.get(CONTENT_LENGTH) {
                if let Ok(cl_str) = cl.to_str() {
                    if let Ok(len) = cl_str.parse::<u64>() {
                        if status != 206 {
                            content_length = Some(len);
                        }
                    }
                }
            }
        }

        // Parse filename from Content-Disposition
        let mut filename = None;
        if let Some(cd) = resp_headers.get(CONTENT_DISPOSITION) {
            if let Ok(cd_str) = cd.to_str() {
                if let Some(name_idx) = cd_str.find("filename=") {
                    let raw = &cd_str[name_idx + 9..];
                    let clean = raw.trim_matches(|c| c == '"' || c == '\'' || c == ' ');
                    if !clean.is_empty() {
                        filename = Some(clean.to_string());
                    }
                }
            }
        }

        // Fallback filename from URL
        if filename.is_none() {
            if let Ok(parsed_url) = reqwest::Url::parse(url) {
                if let Some(mut segments) = parsed_url.path_segments() {
                    if let Some(last) = segments.next_back() {
                        if !last.is_empty() && last.contains('.') {
                            filename = Some(last.to_string());
                        }
                    }
                }
            }
        }

        let content_type = resp_headers
            .get("content-type")
            .and_then(|ct| ct.to_str().ok().map(|s| s.to_string()));

        Ok(ProbeMetadata {
            content_length,
            accept_ranges,
            filename,
            http_status: status,
            content_type,
        })
    }

    pub fn client(&self) -> &Client {
        &self.client
    }
}
