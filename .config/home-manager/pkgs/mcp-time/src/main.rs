//! Time MCP server: `get_current_time` and `convert_time` over IANA timezones.
//! Tool names, argument names and output shape mirror the reference Python server.

use chrono::{DateTime, NaiveTime, Offset, TimeZone, Utc};
use chrono_tz::{OffsetComponents, Tz};
use rmcp::{
    handler::server::wrapper::Parameters, tool, tool_handler, tool_router, ServerHandler,
    ServiceExt,
};
use schemars::JsonSchema;
use serde::Deserialize;
use serde_json::{json, Value};

#[derive(Deserialize, JsonSchema)]
struct CurrentTimeArgs {
    /// IANA timezone name
    timezone: String,
}

#[derive(Deserialize, JsonSchema)]
struct ConvertTimeArgs {
    /// Source IANA timezone name
    source_timezone: String,
    /// Time to convert in 24-hour format (HH:MM)
    time: String,
    /// Target IANA timezone name
    target_timezone: String,
}

#[derive(Clone)]
struct TimeServer {
    tool_router: rmcp::handler::server::router::tool::ToolRouter<Self>,
}

fn parse_tz(name: &str) -> Result<Tz, String> {
    if name.is_empty() {
        return Err("Missing required argument".into());
    }
    name.parse()
        .map_err(|_| format!("Invalid timezone: No time zone found with key {name}"))
}

fn describe(name: &str, dt: DateTime<Tz>) -> Value {
    json!({
        "timezone": name,
        "datetime": dt.format("%Y-%m-%dT%H:%M:%S%:z").to_string(),
        "day_of_week": dt.format("%A").to_string(),
        "is_dst": !dt.offset().dst_offset().is_zero(),
    })
}

#[tool_router]
impl TimeServer {
    #[tool(
        name = "get_current_time",
        description = "Get current time in a specific timezone",
        annotations(
            read_only_hint = true,
            destructive_hint = false,
            idempotent_hint = true,
            open_world_hint = false
        )
    )]
    fn get_current_time(
        &self,
        Parameters(a): Parameters<CurrentTimeArgs>,
    ) -> Result<String, String> {
        let tz = parse_tz(&a.timezone)?;
        Ok(describe(&a.timezone, Utc::now().with_timezone(&tz)).to_string())
    }

    #[tool(
        name = "convert_time",
        description = "Convert time between timezones",
        annotations(
            read_only_hint = true,
            destructive_hint = false,
            idempotent_hint = true,
            open_world_hint = false
        )
    )]
    fn convert_time(&self, Parameters(a): Parameters<ConvertTimeArgs>) -> Result<String, String> {
        let src = parse_tz(&a.source_timezone)?;
        let dst = parse_tz(&a.target_timezone)?;
        let t = NaiveTime::parse_from_str(&a.time, "%H:%M")
            .map_err(|_| "Invalid time format. Expected HH:MM [24-hour format]".to_string())?;

        let date = Utc::now().with_timezone(&src).date_naive();
        // Ambiguous (clock fall-back) times resolve to the earlier instant, like Python's fold=0.
        let source = src
            .from_local_datetime(&date.and_time(t))
            .earliest()
            .ok_or_else(|| {
                format!(
                    "Invalid time: {} does not exist in {} on {date} (skipped by a clock change)",
                    a.time, a.source_timezone
                )
            })?;
        let target = source.with_timezone(&dst);

        let hours = (target.offset().fix().local_minus_utc()
            - source.offset().fix().local_minus_utc()) as f64
            / 3600.0;
        let diff = if hours.fract() == 0.0 {
            format!("{hours:+.1}h")
        } else {
            format!("{:+.2}", hours)
                .trim_end_matches('0')
                .trim_end_matches('.')
                .to_string()
                + "h"
        };

        Ok(json!({
            "source": describe(&a.source_timezone, source),
            "target": describe(&a.target_timezone, target),
            "time_difference": diff,
        })
        .to_string())
    }
}

#[tool_handler(router = self.tool_router, name = "mcp-time")]
impl ServerHandler for TimeServer {}

/// `--local-timezone <tz>` / `--local-timezone=<tz>`, else the system zone, else UTC.
fn local_timezone() -> Result<String, String> {
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        let value = match arg.strip_prefix("--local-timezone=") {
            Some(v) => Some(v.to_string()),
            None if arg == "--local-timezone" => args.next(),
            None => continue,
        };
        let v = value.unwrap_or_default();
        return match v.parse::<Tz>() {
            Ok(_) => Ok(v),
            Err(_) => Err(format!(
                "Error: invalid --local-timezone {v:?}: not a known IANA timezone name"
            )),
        };
    }
    Ok(iana_time_zone::get_timezone()
        .ok()
        .filter(|z| z.parse::<Tz>().is_ok())
        .unwrap_or_else(|| "UTC".into()))
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let local = local_timezone()?;
    let mut tool_router = TimeServer::tool_router();
    // Name the local timezone in the argument descriptions so models can default to it.
    let fallback = |which: &str| {
        format!("Use '{local}' as local timezone if no {which}timezone provided by the user.")
    };
    for (tool, field, text) in [
        (
            "get_current_time",
            "timezone",
            format!(
                "IANA timezone name (e.g., 'America/New_York', 'Europe/London'). {}",
                fallback("")
            ),
        ),
        (
            "convert_time",
            "source_timezone",
            format!(
                "Source IANA timezone name (e.g., 'America/New_York', 'Europe/London'). {}",
                fallback("source ")
            ),
        ),
        (
            "convert_time",
            "target_timezone",
            format!(
                "Target IANA timezone name (e.g., 'Asia/Tokyo', 'America/San_Francisco'). {}",
                fallback("target ")
            ),
        ),
    ] {
        if let Some(route) = tool_router.map.get_mut(tool) {
            let mut schema = (*route.attr.input_schema).clone();
            schema["properties"][field]["description"] = text.into();
            route.attr.input_schema = std::sync::Arc::new(schema);
        }
    }
    let server = TimeServer { tool_router };
    server
        .serve(rmcp::transport::stdio())
        .await?
        .waiting()
        .await?;
    Ok(())
}
