//! Suggest a commit subject and body from the latest changes using a local
//! Ollama model. Any failure prints nothing and exits 0 so shell integrations
//! (zsh-autosuggestions) never error noisily.
//!
//! Usage: ai-commit <subject|message|warm> [--cached]
//!   subject   one line, at most 72 chars
//!   message   subject, blank line, wrapped body
//!   warm      generate and cache in the background-friendly way (no output)
//!   --cached  never call the model; exit 1 on a cache miss

use git2::{DiffFormat, DiffStatsFormat, ObjectType, Oid, Repository};
use serde_json::{json, Value};
use std::{env, fs, path::PathBuf, time::Duration};

const MAX_DIFF: usize = 8000;
const SUBJECT_MAX: usize = 72;
const WRAP: usize = 72;

struct Changes {
    diff: String,
    stat: String,
    log: String,
}

fn changes(repo: &Repository) -> Option<Changes> {
    let head = repo.head().ok().and_then(|h| h.peel_to_tree().ok());
    let mut diff = repo.diff_tree_to_index(head.as_ref(), None, None).ok()?;
    if diff.deltas().len() == 0 {
        diff = repo.diff_index_to_workdir(None, None).ok()?;
    }
    if diff.deltas().len() == 0 {
        return None;
    }
    let mut patch = Vec::new();
    diff.print(DiffFormat::Patch, |_, _, l| {
        if matches!(l.origin(), '+' | '-' | ' ') {
            patch.push(l.origin() as u8);
        }
        patch.extend_from_slice(l.content());
        true
    })
    .ok()?;
    let stat = diff.stats().ok()?.to_buf(DiffStatsFormat::SHORT, 80).ok()?;
    let mut walk = repo.revwalk().ok()?;
    let log = match walk.push_head() {
        Ok(()) => walk
            .take(8)
            .filter_map(|id| repo.find_commit(id.ok()?).ok())
            .map(|c| c.summary().unwrap_or("").to_string())
            .collect::<Vec<_>>()
            .join("\n"),
        Err(_) => String::new(),
    };
    Some(Changes {
        diff: String::from_utf8_lossy(&patch).into_owned(),
        stat: stat.as_str().unwrap_or("").to_string(),
        log,
    })
}

fn truncate(s: &str, max: usize) -> &str {
    let mut end = max.min(s.len());
    while !s.is_char_boundary(end) {
        end -= 1;
    }
    &s[..end]
}

fn cache_path(repo: &Repository, c: &Changes) -> Option<PathBuf> {
    let root = repo.workdir()?.to_string_lossy().into_owned();
    let key = Oid::hash_object(ObjectType::Blob, format!("{root}\0{}", c.diff).as_bytes()).ok()?;
    let base = env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|h| PathBuf::from(h).join(".cache")))?;
    Some(base.join("ai-commit").join(format!("{key}.json")))
}

fn clean_subject(s: &str) -> String {
    let s = s.lines().next().unwrap_or("").replace(['"', '`'], "");
    truncate(s.trim(), SUBJECT_MAX).trim_end().to_string()
}

fn wrap(text: &str) -> String {
    let mut out = Vec::new();
    for line in text.lines().map(str::trim_end).filter(|l| !l.trim().is_empty()) {
        let indent = if line.trim_start().starts_with("- ") { "  " } else { "" };
        let mut cur = String::new();
        for word in line.split_whitespace() {
            if !cur.is_empty() && cur.len() + 1 + word.len() > WRAP {
                out.push(std::mem::replace(&mut cur, indent.to_string()));
            } else if !cur.is_empty() {
                cur.push(' ');
            }
            cur.push_str(word);
        }
        out.push(cur);
    }
    out.join("\n")
}

fn infer(c: &Changes) -> Option<Value> {
    let url = env::var("AI_COMMIT_OLLAMA_URL").unwrap_or_else(|_| "http://localhost:11434".into());
    let model = env::var("AI_COMMIT_MODEL").unwrap_or_else(|_| "qwen2.5-coder:3b".into());
    let prompt = format!(
        "Recent commit subjects in this repo (follow their style):\n{}\n\nChanged files:\n{}\n\nDiff:\n{}\n\n\
         Write a commit message for this change. Reply with JSON: {{\"subject\": ..., \"body\": ...}}. \
         subject is one line of at most {SUBJECT_MAX} characters, imperative mood, no trailing period. \
         body is 1 to 4 short lines (bullets starting with \"- \" are fine) explaining what changed and why. \
         Plain text only, no markdown fences, no quotes around values.",
        c.log,
        c.stat,
        truncate(&c.diff, MAX_DIFF)
    );
    let req = json!({
        "model": model, "prompt": prompt, "stream": false, "format": "json",
        "options": {"temperature": 0.2, "num_predict": 300}
    });
    let resp: Value = ureq::post(&format!("{}/api/generate", url.trim_end_matches('/')))
        .timeout(Duration::from_secs(60))
        .send_json(req)
        .ok()?
        .into_json()
        .ok()?;
    let out: Value = serde_json::from_str(resp["response"].as_str()?).ok()?;
    let subject = clean_subject(out["subject"].as_str()?);
    let body = match &out["body"] {
        Value::String(s) => s.clone(),
        Value::Array(a) => a
            .iter()
            .filter_map(Value::as_str)
            .map(|l| if l.starts_with("- ") { l.to_string() } else { format!("- {l}") })
            .collect::<Vec<_>>()
            .join("\n"),
        _ => String::new(),
    };
    (!subject.is_empty()).then(|| json!({"subject": subject, "body": wrap(&body)}))
}

/// Returns the cached suggestion, generating it unless `cached_only`.
fn suggestion(cached_only: bool) -> Option<Value> {
    let repo = Repository::discover(".").ok()?;
    let c = changes(&repo)?;
    let path = cache_path(&repo, &c)?;
    if let Some(v) = fs::read_to_string(&path).ok().and_then(|s| serde_json::from_str(&s).ok()) {
        return Some(v);
    }
    if cached_only {
        return None;
    }
    let dir = path.parent()?;
    fs::create_dir_all(dir).ok()?;
    // Single-flight: a fresh lock means another run is already inferring.
    let lock = path.with_extension("lock");
    let stale = fs::metadata(&lock)
        .and_then(|m| m.modified())
        .ok()
        .and_then(|t| t.elapsed().ok())
        .is_some_and(|age| age > Duration::from_secs(120));
    if stale {
        let _ = fs::remove_file(&lock);
    }
    fs::OpenOptions::new().write(true).create_new(true).open(&lock).ok()?;
    let v = infer(&c);
    if let Some(v) = &v {
        let tmp = path.with_extension("tmp");
        if fs::write(&tmp, v.to_string()).is_ok() {
            let _ = fs::rename(&tmp, &path);
        }
    }
    let _ = fs::remove_file(&lock);
    v
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let cached = args.iter().any(|a| a == "--cached");
    let mode = args.iter().find(|a| !a.starts_with("--")).map(String::as_str);
    let Some(mode @ ("subject" | "message" | "warm")) = mode else {
        eprintln!("usage: ai-commit <subject|message|warm> [--cached]");
        std::process::exit(2);
    };
    let Some(v) = suggestion(cached && mode != "warm") else {
        std::process::exit(if cached { 1 } else { 0 });
    };
    let subject = v["subject"].as_str().unwrap_or("");
    let body = v["body"].as_str().unwrap_or("");
    match mode {
        "subject" => println!("{subject}"),
        "message" if body.is_empty() => println!("{subject}"),
        "message" => println!("{subject}\n\n{body}"),
        _ => {}
    }
}
