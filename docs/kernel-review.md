# Kernel patch review (b4, lei)

This repo installs two tools for reading and reviewing Linux kernel mail from `lore.kernel.org` and other public-inbox archives: `b4` and `public-inbox` (which provides the `lei` command). `delta` is installed too, for readable diffs. See `.config/home-manager/home.nix`, in the "Linux kernel review" section.

## b4 — fetch and review kernel patch series

`b4` pulls patch series straight from lore.kernel.org (or any public-inbox archive) by message ID.

1. Find a thread on lore.kernel.org and copy its message ID.
2. Fetch the series into an mbox file:
   ```
   b4 am <message-id>
   ```
   This command builds an applicable mbox, in the correct patch order, ready for `git am`.
3. Apply the series to a local branch:
   ```
   git am <output>.mbox
   ```
4. Review a series in the interactive TUI, with `delta` for readable diffs:
   ```
   b4 shazam <message-id>   # fetch + apply in one step
   b4 diff <message-id>     # show the diff, piped through delta
   ```
5. Send a formal review reply, with `Reviewed-by` or comments, straight from the mbox:
   ```
   b4 send
   ```

Set `git config b4.midmask` and `send.from` once, so `b4` can build correct in-reply-to headers for review replies.

## lei — search and pull mail from public-inbox archives

`lei` is a local search and mail-pull tool for public-inbox archives, like the kernel mailing lists.

1. Add a public-inbox source (a one-time step per list):
   ```
   lei add-external https://lore.kernel.org/all/
   ```
2. Search across the archive:
   ```
   lei q -o /tmp/results.mbox 'subject:"btrfs" AND d:2026-08-01..'
   ```
   The `q` command supports free text, `d:` for date range, `s:` for subject, `f:` for the from field.
3. Follow a thread and its full context:
   ```
   lei q -t <message-id>
   ```
4. Set up a saved search, so new matching mail arrives without a re-run:
   ```
   lei q --save-as my-search 'dfn:mm/*.c AND some_function'
   ```
   Run `lei up my-search` later, to refresh it.

## A practical review loop

1. Use `lei q` to find the thread you want to review.
2. Use `b4 am <message-id>` to pull the series into an mbox.
3. Run `git am` on a scratch branch, then read the diff through `delta`.
4. Build and test the change.
5. Use `b4 send` to reply with your review.

**Note:** `lei` only reads and searches; it does not send mail. `b4 send` composes and sends the review reply, and it needs an SMTP identity set in `git config` first.
