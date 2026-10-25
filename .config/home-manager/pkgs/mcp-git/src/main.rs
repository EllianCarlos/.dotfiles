//! Git MCP server backed by libgit2. Tool names, argument names and descriptions
//! mirror the reference Python `mcp-server-git`.

use chrono::{DateTime, Duration, FixedOffset, Local, NaiveDate, NaiveDateTime, TimeZone};
use git2::{
    build::CheckoutBuilder, BranchType, Delta, Diff, DiffFormat, DiffOptions, ObjectType, Oid,
    Repository, Signature, Status, StatusOptions, Time,
};
use rmcp::{handler::server::router::tool::ToolRouter, handler::server::wrapper::Parameters};
use rmcp::{tool, tool_handler, tool_router, ServerHandler, ServiceExt};
use schemars::JsonSchema;
use serde::Deserialize;
use std::path::{Component, Path, PathBuf};

type Res = Result<String, String>;

fn ge(e: git2::Error) -> String {
    e.message().to_string()
}

fn three() -> u32 {
    3
}

fn ten() -> u32 {
    10
}

#[derive(Deserialize, JsonSchema)]
struct RepoArgs {
    repo_path: String,
}

#[derive(Deserialize, JsonSchema)]
struct DiffArgs {
    repo_path: String,
    #[serde(default = "three")]
    context_lines: u32,
}

#[derive(Deserialize, JsonSchema)]
struct DiffTargetArgs {
    repo_path: String,
    target: String,
    #[serde(default = "three")]
    context_lines: u32,
}

#[derive(Deserialize, JsonSchema)]
struct CommitArgs {
    repo_path: String,
    message: String,
}

#[derive(Deserialize, JsonSchema)]
struct AddArgs {
    repo_path: String,
    #[schemars(length(min = 1))]
    files: Vec<String>,
}

#[derive(Deserialize, JsonSchema)]
struct LogArgs {
    repo_path: String,
    #[serde(default = "ten")]
    max_count: u32,
    /// Start timestamp for filtering commits. Accepts: ISO 8601 format (e.g., '2024-01-15T14:30:25'), relative dates (e.g., '2 weeks ago', 'yesterday'), or absolute dates (e.g., '2024-01-15', 'Jan 15 2024')
    start_timestamp: Option<String>,
    /// End timestamp for filtering commits. Accepts: ISO 8601 format (e.g., '2024-01-15T14:30:25'), relative dates (e.g., '2 weeks ago', 'yesterday'), or absolute dates (e.g., '2024-01-15', 'Jan 15 2024')
    end_timestamp: Option<String>,
}

#[derive(Deserialize, JsonSchema)]
struct CreateBranchArgs {
    repo_path: String,
    branch_name: String,
    base_branch: Option<String>,
}

#[derive(Deserialize, JsonSchema)]
struct CheckoutArgs {
    repo_path: String,
    branch_name: String,
}

#[derive(Deserialize, JsonSchema)]
struct ShowArgs {
    repo_path: String,
    revision: String,
}

#[derive(Deserialize, JsonSchema)]
struct BranchArgs {
    /// The path to the Git repository.
    repo_path: String,
    /// Whether to list local branches ('local'), remote branches ('remote') or all branches('all').
    branch_type: String,
    /// The commit sha that branch should contain. Do not pass anything to this param if no commit sha is specified
    contains: Option<String>,
    /// The commit sha that branch should NOT contain. Do not pass anything to this param if no commit sha is specified
    not_contains: Option<String>,
}

#[derive(Clone)]
struct GitServer {
    /// `--repository`: when set, every `repo_path` must live inside it.
    allowed: Option<PathBuf>,
    tool_router: ToolRouter<Self>,
}

impl GitServer {
    fn open(&self, repo_path: &str) -> Result<Repository, String> {
        if let Some(allowed) = &self.allowed {
            let resolved = Path::new(repo_path)
                .canonicalize()
                .map_err(|_| format!("Invalid path: {repo_path}"))?;
            if !resolved.starts_with(allowed) {
                return Err(format!(
                    "Repository path '{repo_path}' is outside the allowed repository '{}'",
                    allowed.display()
                ));
            }
        }
        Repository::open(repo_path).map_err(ge)
    }
}

/// Reject values that git would parse as an option.
fn no_flag(what: &str, v: &str) -> Result<(), String> {
    match v.starts_with('-') {
        true => Err(format!("Invalid {what}: '{v}' - cannot start with '-'")),
        false => Ok(()),
    }
}

fn patch(diff: &Diff) -> Result<String, String> {
    let mut out = Vec::new();
    diff.print(DiffFormat::Patch, |_, _, l| {
        if matches!(l.origin(), '+' | '-' | ' ') {
            out.push(l.origin() as u8);
        }
        out.extend_from_slice(l.content());
        true
    })
    .map_err(ge)?;
    Ok(String::from_utf8_lossy(&out).into_owned())
}

fn diff_opts(context_lines: u32) -> DiffOptions {
    let mut o = DiffOptions::new();
    o.context_lines(context_lines);
    o
}

fn head_tree(repo: &Repository) -> Option<git2::Tree<'_>> {
    repo.head().ok()?.peel_to_tree().ok()
}

fn status(repo: &Repository) -> Res {
    let mut head = match repo.head() {
        Ok(h) if repo.head_detached().unwrap_or(false) => {
            let id = h.peel_to_commit().map_err(ge)?.id().to_string();
            format!("HEAD detached at {}", &id[..7])
        }
        Ok(h) => format!("On branch {}", h.shorthand().unwrap_or("HEAD")),
        Err(_) => {
            let name = repo
                .find_reference("HEAD")
                .ok()
                .and_then(|r| r.symbolic_target().ok().flatten().map(str::to_owned));
            format!(
                "On branch {}",
                name.as_deref()
                    .unwrap_or("refs/heads/master")
                    .trim_start_matches("refs/heads/")
            )
        }
    };
    if repo.head().is_err() {
        head.push_str("\n\nNo commits yet");
    }

    let mut opts = StatusOptions::new();
    opts.include_untracked(true)
        .renames_head_to_index(true)
        .renames_index_to_workdir(true);
    let statuses = repo.statuses(Some(&mut opts)).map_err(ge)?;

    let (mut staged, mut unstaged, mut untracked, mut unmerged) = (vec![], vec![], vec![], vec![]);
    let path = |d: Option<git2::DiffDelta>, s: &str| -> String {
        let d = d.unwrap();
        let (old, new) = (
            d.old_file().path().unwrap_or(Path::new("")),
            d.new_file().path().unwrap_or(Path::new("")),
        );
        match d.status() {
            Delta::Renamed => format!("{s}{} -> {}", old.display(), new.display()),
            _ => format!("{s}{}", new.display()),
        }
    };
    for e in statuses.iter() {
        let s = e.status();
        let p = e.path().unwrap_or("?");
        if s.contains(Status::CONFLICTED) {
            unmerged.push(format!("both modified:   {p}"));
            continue;
        }
        for (flag, label) in [
            (Status::INDEX_NEW, "new file:   "),
            (Status::INDEX_MODIFIED, "modified:   "),
            (Status::INDEX_DELETED, "deleted:    "),
            (Status::INDEX_RENAMED, "renamed:    "),
            (Status::INDEX_TYPECHANGE, "typechange: "),
        ] {
            if s.contains(flag) {
                staged.push(path(e.head_to_index(), label));
            }
        }
        for (flag, label) in [
            (Status::WT_MODIFIED, "modified:   "),
            (Status::WT_DELETED, "deleted:    "),
            (Status::WT_RENAMED, "renamed:    "),
            (Status::WT_TYPECHANGE, "typechange: "),
        ] {
            if s.contains(flag) {
                unstaged.push(path(e.index_to_workdir(), label));
            }
        }
        if s.contains(Status::WT_NEW) {
            untracked.push(p.to_string());
        }
    }

    let mut out = head + "\n\n";
    for (title, items) in [
        ("Changes to be committed:", &staged),
        ("Unmerged paths:", &unmerged),
        ("Changes not staged for commit:", &unstaged),
        ("Untracked files:", &untracked),
    ] {
        if !items.is_empty() {
            out += &format!(
                "{title}\n{}\n\n",
                items
                    .iter()
                    .map(|i| format!("\t{i}"))
                    .collect::<Vec<_>>()
                    .join("\n")
            );
        }
    }
    if staged.is_empty() && unstaged.is_empty() && untracked.is_empty() && unmerged.is_empty() {
        out += "nothing to commit, working tree clean\n";
    }
    Ok(out)
}

fn has_staged_changes(repo: &Repository) -> Result<bool, String> {
    if repo.path().join("MERGE_HEAD").exists() {
        return Ok(true);
    }
    let mut index = repo.index().map_err(ge)?;
    match head_tree(repo) {
        Some(t) => Ok(index.write_tree().map_err(ge)? != t.id()),
        None => Ok(!index.is_empty()),
    }
}

fn commit(repo: &Repository, message: &str) -> Res {
    if !has_staged_changes(repo)? {
        return Err(
            "No changes staged for commit. Use git_add to stage changes first; \
                    git_status shows what is currently staged."
                .into(),
        );
    }
    let sig = repo.signature().map_err(ge)?;
    let tree = repo
        .find_tree(repo.index().map_err(ge)?.write_tree().map_err(ge)?)
        .map_err(ge)?;
    let mut parents = repo
        .head()
        .ok()
        .and_then(|h| h.peel_to_commit().ok())
        .into_iter()
        .collect::<Vec<_>>();
    let merging = repo.path().join("MERGE_HEAD");
    if let Ok(heads) = std::fs::read_to_string(&merging) {
        for sha in heads.split_whitespace() {
            parents.push(
                repo.find_commit(Oid::from_str(sha).map_err(ge)?)
                    .map_err(ge)?,
            );
        }
    }
    let refs: Vec<_> = parents.iter().collect();
    let id = repo
        .commit(Some("HEAD"), &sig, &sig, message, &tree, &refs)
        .map_err(ge)?;
    if merging.exists() {
        repo.cleanup_state().map_err(ge)?;
    }
    Ok(format!("Changes committed successfully with hash {id}"))
}

/// Pathspec relative to the working tree, rejecting anything that escapes it.
fn worktree_spec(root: &Path, f: &str) -> Result<String, String> {
    let p = Path::new(f);
    let rel = match p.is_absolute() {
        true => p
            .strip_prefix(root)
            .map_err(|_| format!("Path '{f}' is outside the repository '{}'", root.display()))?,
        false => p,
    };
    let mut depth = 0i32;
    for c in rel.components() {
        match c {
            Component::ParentDir => depth -= 1,
            Component::Normal(_) => depth += 1,
            _ => {}
        }
        if depth < 0 {
            return Err(format!(
                "Path '{f}' is outside the repository '{}'",
                root.display()
            ));
        }
    }
    Ok(match rel.as_os_str().to_str() {
        Some("." | "") => "*".into(),
        _ => rel.to_string_lossy().into_owned(),
    })
}

fn add(repo: &Repository, files: &[String]) -> Res {
    if files.is_empty() {
        return Err(
            "No files provided to stage. Pass one or more paths, or ['.'] to stage everything."
                .into(),
        );
    }
    let root = repo
        .workdir()
        .ok_or("Repository has no working tree")?
        .canonicalize()
        .map_err(|e| e.to_string())?;
    let specs = files
        .iter()
        .map(|f| worktree_spec(&root, f))
        .collect::<Result<Vec<_>, _>>()?;
    let mut index = repo.index().map_err(ge)?;
    let before = index.write_tree().ok();
    index
        .add_all(&specs, git2::IndexAddOption::DEFAULT, None)
        .map_err(ge)?;
    index.update_all(&specs, None).map_err(ge)?; // also stages deletions
    index.write().map_err(ge)?;
    if index.write_tree().ok() == before {
        return Ok(
            "No changes were staged: the given paths had nothing new to stage. \
                   git_status shows what is modified or untracked."
                .into(),
        );
    }
    Ok("Files staged successfully".into())
}

fn reset(repo: &Repository) -> Res {
    let mut index = repo.index().map_err(ge)?;
    match head_tree(repo) {
        Some(t) => index.read_tree(&t).map_err(ge)?,
        None => index.clear().map_err(ge)?,
    }
    index.write().map_err(ge)?;
    Ok("All staged changes reset".into())
}

/// Seconds since the epoch for ISO 8601, relative ("2 weeks ago") or absolute ("Jan 15 2024") dates.
fn parse_timestamp(s: &str) -> Result<i64, String> {
    let s = s.trim();
    let local = |n: NaiveDateTime| {
        Local
            .from_local_datetime(&n)
            .earliest()
            .map(|d| d.timestamp())
    };
    if let Ok(d) = DateTime::parse_from_rfc3339(s) {
        return Ok(d.timestamp());
    }
    for f in [
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%dT%H:%M",
        "%Y-%m-%d %H:%M",
    ] {
        if let Some(t) = NaiveDateTime::parse_from_str(s, f).ok().and_then(local) {
            return Ok(t);
        }
    }
    for f in [
        "%Y-%m-%d", "%b %d %Y", "%B %d %Y", "%d %b %Y", "%d %B %Y", "%Y/%m/%d",
    ] {
        if let Some(t) = NaiveDate::parse_from_str(s, f)
            .ok()
            .and_then(|d| local(d.and_hms_opt(0, 0, 0)?))
        {
            return Ok(t);
        }
    }
    let now = Local::now();
    let lower = s.to_lowercase();
    let words: Vec<&str> = lower.split_whitespace().collect();
    let back = match words.as_slice() {
        ["now"] => Duration::zero(),
        ["today"] => Duration::seconds(
            now.timestamp() - local(now.date_naive().and_hms_opt(0, 0, 0).unwrap()).unwrap_or(0),
        ),
        ["yesterday"] => Duration::days(1),
        [n, unit, "ago"] => {
            let n: i64 = n.parse().map_err(|_| format!("Invalid timestamp: '{s}'"))?;
            match unit.trim_end_matches('s') {
                "second" => Duration::seconds(n),
                "minute" => Duration::minutes(n),
                "hour" => Duration::hours(n),
                "day" => Duration::days(n),
                "week" => Duration::weeks(n),
                "month" => Duration::days(30 * n),
                "year" => Duration::days(365 * n),
                _ => return Err(format!("Invalid timestamp: '{s}'")),
            }
        }
        _ => return Err(format!("Invalid timestamp: '{s}'")),
    };
    Ok((now - back).timestamp())
}

fn fmt_time(t: Time, pattern: &str) -> String {
    let off =
        FixedOffset::east_opt(t.offset_minutes() * 60).unwrap_or(FixedOffset::east_opt(0).unwrap());
    off.timestamp_opt(t.seconds(), 0)
        .single()
        .map(|d| d.format(pattern).to_string())
        .unwrap_or_default()
}

fn log(repo: &Repository, max: u32, start: Option<&str>, end: Option<&str>) -> Res {
    let since = start
        .filter(|s| !s.is_empty())
        .map(|s| no_flag("start_timestamp", s).and_then(|_| parse_timestamp(s)))
        .transpose()?;
    let until = end
        .filter(|s| !s.is_empty())
        .map(|s| no_flag("end_timestamp", s).and_then(|_| parse_timestamp(s)))
        .transpose()?;
    let mut walk = repo.revwalk().map_err(ge)?;
    walk.push_head().map_err(ge)?;
    walk.set_sorting(git2::Sort::TIME).map_err(ge)?;
    let mut entries = Vec::new();
    for oid in walk {
        let c = repo.find_commit(oid.map_err(ge)?).map_err(ge)?;
        let t = c.time().seconds();
        if since.is_some_and(|s| t < s) || until.is_some_and(|u| t > u) {
            continue;
        }
        let a = c.author();
        entries.push(format!(
            "Commit: {}\nAuthor: {}\nDate: {}\nMessage: {}\n",
            c.id(),
            a.name().unwrap_or(""),
            fmt_time(a.when(), "%Y-%m-%d %H:%M:%S%:z"),
            c.message().unwrap_or("")
        ));
        if entries.len() >= max as usize {
            break;
        }
    }
    Ok("Commit history:\n".to_string() + &entries.join("\n"))
}

fn create_branch(repo: &Repository, name: &str, base: Option<&str>) -> Res {
    no_flag("branch name", name)?;
    let (commit, base_name) =
        match base.filter(|b| !b.is_empty()) {
            Some(b) => {
                no_flag("base branch", b)?;
                let obj = repo.revparse_single(b).map_err(ge)?;
                (obj.peel_to_commit().map_err(ge)?, b.to_string())
            }
            None if repo.head_detached().unwrap_or(false) => return Err(
                "HEAD is detached, so there is no current branch to branch from; pass base_branch"
                    .into(),
            ),
            None => {
                let head = repo.head().map_err(ge)?;
                (
                    head.peel_to_commit().map_err(ge)?,
                    head.shorthand().unwrap_or("HEAD").to_string(),
                )
            }
        };
    if repo.find_branch(name, BranchType::Local).is_ok() {
        return Err(format!(
            "Cannot create branch '{name}': refs/heads/{name} already exists"
        ));
    }
    repo.branch(name, &commit, false).map_err(ge)?;
    Ok(format!("Created branch '{name}' from '{base_name}'"))
}

fn checkout(repo: &Repository, name: &str) -> Res {
    no_flag("branch name", name)?;
    let (obj, reference) = repo.revparse_ext(name).map_err(ge)?;
    repo.checkout_tree(&obj, Some(CheckoutBuilder::new().safe()))
        .map_err(ge)?;
    match reference
        .as_ref()
        .filter(|r| r.is_branch())
        .and_then(|r| r.name().ok())
    {
        Some(refname) => {
            repo.set_head(refname).map_err(ge)?;
            Ok(format!(
                "Switched to branch '{}'",
                refname.trim_start_matches("refs/heads/")
            ))
        }
        None => {
            let id = obj.peel_to_commit().map_err(ge)?.id();
            repo.set_head_detached(id).map_err(ge)?;
            Ok(format!("HEAD is now detached at {}", &id.to_string()[..7]))
        }
    }
}

fn show(repo: &Repository, revision: &str) -> Res {
    no_flag("revision", revision)?;
    let obj = repo.revparse_single(revision).map_err(ge)?;
    match obj.kind() {
        Some(ObjectType::Blob) => {
            Ok(String::from_utf8_lossy(obj.as_blob().unwrap().content()).into_owned())
        }
        Some(ObjectType::Tree) => Ok(obj
            .as_tree()
            .unwrap()
            .iter()
            .map(|e| match e.kind() {
                Some(ObjectType::Tree) => format!("{}/", e.name().unwrap_or("")),
                _ => e.name().unwrap_or("").to_string(),
            })
            .collect::<Vec<_>>()
            .join("\n")),
        _ => {
            let c = obj.peel_to_commit().map_err(ge)?;
            let a: Signature = c.author();
            let msg: String = c
                .message()
                .unwrap_or("")
                .trim_end_matches('\n')
                .lines()
                .map(|l| format!("    {l}\n"))
                .collect();
            let mut out = format!(
                "commit {}\nAuthor: {} <{}>\nDate:   {}\n\n{msg}",
                c.id(),
                a.name().unwrap_or(""),
                a.email().unwrap_or(""),
                fmt_time(a.when(), "%Y-%m-%d %H:%M:%S %z"),
            );
            let parent = c.parent(0).ok().map(|p| p.tree()).transpose().map_err(ge)?;
            let diff = repo
                .diff_tree_to_tree(parent.as_ref(), Some(&c.tree().map_err(ge)?), None)
                .map_err(ge)?;
            out += "\n";
            out += &patch(&diff)?;
            Ok(out)
        }
    }
}

fn branch(
    repo: &Repository,
    kind: &str,
    contains: Option<&str>,
    not_contains: Option<&str>,
) -> Res {
    let resolve = |what: &str, v: Option<&str>| -> Result<Option<Oid>, String> {
        let Some(v) = v.filter(|v| !v.is_empty()) else {
            return Ok(None);
        };
        no_flag(what, v)?;
        Ok(Some(
            repo.revparse_single(v)
                .and_then(|o| o.peel_to_commit())
                .map_err(ge)?
                .id(),
        ))
    };
    let (want, unwanted) = (
        resolve("contains value", contains)?,
        resolve("not_contains value", not_contains)?,
    );
    let kinds: &[(BranchType, &str)] = match kind {
        "local" => &[(BranchType::Local, "")],
        "remote" => &[(BranchType::Remote, "")],
        "all" => &[(BranchType::Local, ""), (BranchType::Remote, "remotes/")],
        _ => return Err(format!("Invalid branch type: {kind}")),
    };
    let has = |tip: Oid, c: Oid| tip == c || repo.graph_descendant_of(tip, c).unwrap_or(false);
    let mut lines = Vec::new();
    for (ty, prefix) in kinds {
        let mut group = Vec::new();
        for b in repo.branches(Some(*ty)).map_err(ge)? {
            let (b, _) = b.map_err(ge)?;
            let name = b.name().map_err(ge)?.unwrap_or("").to_string();
            let tip = b
                .get()
                .resolve()
                .map_err(ge)?
                .peel_to_commit()
                .map_err(ge)?
                .id();
            if want.is_some_and(|c| !has(tip, c)) || unwanted.is_some_and(|c| has(tip, c)) {
                continue;
            }
            let line = match b.get().symbolic_target().ok().flatten() {
                Some(t) => format!(
                    "  {prefix}{name} -> {}",
                    t.trim_start_matches("refs/remotes/")
                ),
                None if b.is_head() => format!("* {name}"),
                None => format!("  {prefix}{name}"),
            };
            group.push((name, line));
        }
        group.sort();
        lines.extend(group.into_iter().map(|(_, l)| l));
    }
    if matches!(kind, "local" | "all")
        && want.is_none()
        && unwanted.is_none()
        && repo.head_detached().unwrap_or(false)
    {
        let id = repo
            .head()
            .and_then(|h| h.peel_to_commit())
            .map_err(ge)?
            .id()
            .to_string();
        lines.insert(0, format!("* (HEAD detached at {})", &id[..7]));
    }
    Ok(lines.join("\n") + if lines.is_empty() { "" } else { "\n" })
}

#[tool_router]
impl GitServer {
    #[tool(
        name = "git_status",
        description = "Shows the working tree status",
        annotations(
            read_only_hint = true,
            destructive_hint = false,
            idempotent_hint = true,
            open_world_hint = false
        )
    )]
    fn git_status(&self, Parameters(a): Parameters<RepoArgs>) -> Res {
        Ok(format!(
            "Repository status:\n{}",
            status(&self.open(&a.repo_path)?)?
        ))
    }

    #[tool(
        name = "git_diff_unstaged",
        description = "Shows changes in the working directory that are not yet staged",
        annotations(
            read_only_hint = true,
            destructive_hint = false,
            idempotent_hint = true,
            open_world_hint = false
        )
    )]
    fn git_diff_unstaged(&self, Parameters(a): Parameters<DiffArgs>) -> Res {
        let repo = self.open(&a.repo_path)?;
        let diff = repo
            .diff_index_to_workdir(None, Some(&mut diff_opts(a.context_lines)))
            .map_err(ge)?;
        Ok(format!("Unstaged changes:\n{}", patch(&diff)?))
    }

    #[tool(
        name = "git_diff_staged",
        description = "Shows changes that are staged for commit",
        annotations(
            read_only_hint = true,
            destructive_hint = false,
            idempotent_hint = true,
            open_world_hint = false
        )
    )]
    fn git_diff_staged(&self, Parameters(a): Parameters<DiffArgs>) -> Res {
        let repo = self.open(&a.repo_path)?;
        let diff = repo
            .diff_tree_to_index(
                head_tree(&repo).as_ref(),
                None,
                Some(&mut diff_opts(a.context_lines)),
            )
            .map_err(ge)?;
        Ok(format!("Staged changes:\n{}", patch(&diff)?))
    }

    #[tool(
        name = "git_diff",
        description = "Shows differences between branches or commits",
        annotations(
            read_only_hint = true,
            destructive_hint = false,
            idempotent_hint = true,
            open_world_hint = false
        )
    )]
    fn git_diff(&self, Parameters(a): Parameters<DiffTargetArgs>) -> Res {
        no_flag("target", &a.target)?;
        let repo = self.open(&a.repo_path)?;
        let tree = repo
            .revparse_single(&a.target)
            .and_then(|o| o.peel_to_tree())
            .map_err(ge)?;
        let diff = repo
            .diff_tree_to_workdir_with_index(Some(&tree), Some(&mut diff_opts(a.context_lines)))
            .map_err(ge)?;
        Ok(format!("Diff with {}:\n{}", a.target, patch(&diff)?))
    }

    #[tool(
        name = "git_commit",
        description = "Records changes to the repository",
        annotations(
            read_only_hint = false,
            destructive_hint = false,
            idempotent_hint = false,
            open_world_hint = false
        )
    )]
    fn git_commit(&self, Parameters(a): Parameters<CommitArgs>) -> Res {
        commit(&self.open(&a.repo_path)?, &a.message)
    }

    #[tool(
        name = "git_add",
        description = "Adds file contents to the staging area",
        annotations(
            read_only_hint = false,
            destructive_hint = false,
            idempotent_hint = true,
            open_world_hint = false
        )
    )]
    fn git_add(&self, Parameters(a): Parameters<AddArgs>) -> Res {
        add(&self.open(&a.repo_path)?, &a.files)
    }

    #[tool(
        name = "git_reset",
        description = "Unstages all staged changes",
        annotations(
            read_only_hint = false,
            destructive_hint = true,
            idempotent_hint = true,
            open_world_hint = false
        )
    )]
    fn git_reset(&self, Parameters(a): Parameters<RepoArgs>) -> Res {
        reset(&self.open(&a.repo_path)?)
    }

    #[tool(
        name = "git_log",
        description = "Shows the commit logs",
        annotations(
            read_only_hint = true,
            destructive_hint = false,
            idempotent_hint = true,
            open_world_hint = false
        )
    )]
    fn git_log(&self, Parameters(a): Parameters<LogArgs>) -> Res {
        log(
            &self.open(&a.repo_path)?,
            a.max_count,
            a.start_timestamp.as_deref(),
            a.end_timestamp.as_deref(),
        )
    }

    #[tool(
        name = "git_create_branch",
        description = "Creates a new branch from an optional base branch",
        annotations(
            read_only_hint = false,
            destructive_hint = false,
            idempotent_hint = false,
            open_world_hint = false
        )
    )]
    fn git_create_branch(&self, Parameters(a): Parameters<CreateBranchArgs>) -> Res {
        create_branch(
            &self.open(&a.repo_path)?,
            &a.branch_name,
            a.base_branch.as_deref(),
        )
    }

    #[tool(
        name = "git_checkout",
        description = "Switches branches",
        annotations(
            read_only_hint = false,
            destructive_hint = false,
            idempotent_hint = false,
            open_world_hint = false
        )
    )]
    fn git_checkout(&self, Parameters(a): Parameters<CheckoutArgs>) -> Res {
        checkout(&self.open(&a.repo_path)?, &a.branch_name)
    }

    #[tool(
        name = "git_show",
        description = "Shows the contents of a commit, or of a file or directory given as <revision>:<path>",
        annotations(
            read_only_hint = true,
            destructive_hint = false,
            idempotent_hint = true,
            open_world_hint = false
        )
    )]
    fn git_show(&self, Parameters(a): Parameters<ShowArgs>) -> Res {
        show(&self.open(&a.repo_path)?, &a.revision)
    }

    #[tool(
        name = "git_branch",
        description = "List Git branches",
        annotations(
            read_only_hint = true,
            destructive_hint = false,
            idempotent_hint = true,
            open_world_hint = false
        )
    )]
    fn git_branch(&self, Parameters(a): Parameters<BranchArgs>) -> Res {
        branch(
            &self.open(&a.repo_path)?,
            &a.branch_type,
            a.contains.as_deref(),
            a.not_contains.as_deref(),
        )
    }
}

#[tool_handler(router = self.tool_router, name = "mcp-git")]
impl ServerHandler for GitServer {}

/// `--repository <path>` / `--repository=<path>`, resolved to its working-tree root.
fn allowed_repository() -> Result<Option<PathBuf>, String> {
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        let value = match arg.strip_prefix("--repository=") {
            Some(v) => v.to_string(),
            None if arg == "--repository" => args.next().ok_or("--repository requires a value")?,
            None => continue,
        };
        if !Path::new(&value).exists() {
            return Err(format!("{value} does not exist"));
        }
        let repo = Repository::discover(&value)
            .map_err(|_| format!("{value} is not a valid Git repository"))?;
        let root = repo.workdir().ok_or("repository has no working tree")?;
        return root.canonicalize().map(Some).map_err(|e| e.to_string());
    }
    Ok(None)
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let allowed = allowed_repository()?;
    let server = GitServer {
        allowed,
        tool_router: GitServer::tool_router(),
    };
    server
        .serve(rmcp::transport::stdio())
        .await?
        .waiting()
        .await?;
    Ok(())
}
