# AWS Lambda Runtime EOL Review — dan-sullivan.co.uk

**Date:** 2026-09-23
**Scope:** the two Lambda functions declared in *this* repository.
**Status:** review only — no code, Terraform or AWS state was changed while producing this document.

---

## 1. Summary of the two EOL runtimes

Both functions are live and both sit on runtimes that AWS deprecated years ago.

| Function | Declared in | Runtime | Deprecated | Blast radius if broken |
| --- | --- | --- | --- | --- |
| `serve_dscouk` | `terraform/lambda.tf:6` | `python3.6` | 18 Jul 2022 | `/` default origin + `/lambda*` pages |
| `edge_redirect` | `terraform/core/core.tf:225` | `nodejs6.10` | 12 Aug 2019 | **every request** to dan-sullivan.co.uk |

### 1.1 `serve_dscouk` (python3.6)

```hcl
# terraform/lambda.tf
resource "aws_lambda_function" "serve_dscouk" {
  function_name    = "serve_dscouk${terraform.workspace == "default" ? "" : "_${terraform.workspace}"}"
  handler          = "serve_dscouk.handler"
  runtime          = "python3.6"          # <-- line 6
  filename         = "zips/serve_dscouk.zip"
  source_code_hash = "${base64sha256(file("zips/serve_dscouk.zip"))}"
  role             = "${data.terraform_remote_state.dscouk_core.lambda_exec_role}"
}
```

**What it drives.** API Gateway REST API `l4h19v2rfa`, stage `production`, resource `/dscouk/{proxy+}` (`terraform/api.tf`), fronted by CloudFront. In `terraform/core/core.tf` the API Gateway domain is origin `dscouk-lambda-prod`, which is used by **both** the `default_cache_behavior` (`core.tf:303`) and the `/lambda*` cache behaviour (`core.tf:329`). A second origin `dscouk-lambda-dev` serves the `/pr*/pr*/lambda*` PR-preview behaviour off the same function family.

**Why it is live.** ~407 invocations in the prior 14 days through the `production` stage — this is real viewer traffic, not a leftover.

**What the code needs from the runtime.** `terraform/serve_dscouk.py` is 31 lines of pure stdlib: a dict lookup, `str.split`, `open(...).read()`, and a bare `except`. No third-party packages, no `requirements.txt`, no layers, no compiled extensions. It reads a prebuilt `dist/` tree that is zipped alongside it (`grunt exec:zip_lambda_dscouk`) and resolved relative to the task root at `/var/task`. Nothing here is version-sensitive beyond "is Python 3".

### 1.2 `edge_redirect` (nodejs6.10)

```hcl
# terraform/core/core.tf
resource "aws_lambda_function" "edge_redirect" {
  function_name    = "edge_redirect"
  handler          = "index.handler"
  runtime          = "nodejs6.10"         # <-- line 225
  filename         = "${data.archive_file.edge_redirect.output_path}"
  source_code_hash = "${data.archive_file.edge_redirect.output_base64sha256}"
  role             = "${aws_iam_role.lambda_exec_role_edge_lambda.arn}"
  publish          = true
  provider         = "aws.us-east-1"
}
```

**What it drives.** It is attached as a **viewer-request** Lambda@Edge association on the `default_cache_behavior` of the CloudFront distribution (`terraform/core/core.tf:320-323`), referencing `aws_lambda_function.edge_redirect.qualified_arn`. `terraform/core/edge_redirect.js` randomly 307-redirects the site root to `/lambda/index.html` or `/s3/index.html` — the "same page served by different methods" demo the README describes.

**Why it is live.** A viewer-request association on the default behaviour runs on **every uncached and cached request** that matches that behaviour, including every hit on the bare domain. This is the highest-traffic and highest-risk of the two, and it is on a runtime that has been dead since 2019.

---

## 2. Recommended fix — concrete code changes

### 2.1 `serve_dscouk`: `python3.6` → `python3.13`

**Change** `terraform/lambda.tf` line 6:

```diff
-  runtime          = "python3.6"
+  runtime          = "python3.13"
```

**Why `python3.13`.** It is on Amazon Linux 2023 with a projected deprecation date of **30 Jun 2029** — the longest runway of the currently supported Python runtimes alongside `python3.14`. `python3.13` is the conservative pick: it has been GA in Lambda long enough to be boring, whereas `python3.14` is newer. Do **not** pick `python3.8`/`3.9`/`3.10`/`3.11` — 3.8 and 3.9 are already deprecated, 3.10 deprecates 31 Oct 2026, and 3.11 is Amazon Linux 2 which goes EOL 30 Jun 2026.

**Handler compatibility.** No code change required. Specifically checked:

- The handler is already Python 3 syntax (`print()` as a function, no `unicode`/`iteritems`).
- Only stdlib builtins are used: `open`, `read`, `dict`, `str.split`, `str.join`.
- The handler signature `handler(event, context)` is unchanged across all Python runtimes.
- The file-path resolution (`open("dist/" + ...)` relative to CWD) still resolves to `/var/task/dist/...` on AL2023.
- One pre-existing quirk carries over unchanged: `open(..., "r")` is text mode, so a request for a binary asset through this Lambda raises `UnicodeDecodeError`, is swallowed by the bare `except`, and returns the 404 page. That is today's behaviour on `python3.6` too — it is not a regression, and it is not in the path for `/favicon.ico`, which CloudFront serves from the `dscouk-s3-favicon` S3 origin.

**Deploy path this touches.**

- The zip is built by `grunt exec:zip_lambda_dscouk` (`Gruntfile.js:129`), which writes `terraform/zips/serve_dscouk.zip` containing `./dist` plus `serve_dscouk.py`. Nothing in that task is runtime-aware — no change needed.
- `source_code_hash = "${base64sha256(file("zips/serve_dscouk.zip"))}"` (`terraform/lambda.tf:8`) is recomputed from the freshly built zip on every CI run, so a code update accompanies the config update on the same apply. Both `UpdateFunctionCode` and `UpdateFunctionConfiguration` will fire.
- CI runs this automatically: `.circleci/config.yml:32-35` runs `grunt lambda`, `grunt exec:zip_lambda_dscouk`, then `terraform init && terraform plan && terraform apply` in `terraform/` on master. **This root module is the only one CI applies** — see §3.
- Nothing else in the repo references `python3.6`; verify with `grep -rn "python3\.6" .` before and after.

### 2.2 `edge_redirect`: `nodejs6.10` → `nodejs22.x`

**Change** `terraform/core/core.tf` line 225:

```diff
-  runtime          = "nodejs6.10"
+  runtime          = "nodejs22.x"
```

**Why `nodejs22.x` and not `nodejs24.x`.** Lambda@Edge supports "the latest versions of Node.js and Python runtimes", and both `nodejs22.x` and `nodejs24.x` are available at the edge. The deciding factor is the handler style:

> Starting with the Node.js 24 runtime, Lambda no longer supports the callback-based handler signature for asynchronous operations.

`terraform/core/edge_redirect.js` is callback-style:

```js
exports.handler = (event, context, callback) => { ... callback(null, response); };
```

On `nodejs24.x` that handler would never return a response — every viewer request on the default behaviour would fail. `nodejs22.x` still supports the callback signature, so the runtime bump is a **one-line change with zero code risk**, which is what you want on a function that is in the path for 100% of site traffic. `nodejs22.x` has a projected deprecation date of **30 Apr 2027**.

**Optional — `nodejs24.x` instead (runway to 30 Apr 2028).** If you would rather not revisit this in 2027, it requires rewriting the handler to async/await *in the same change*:

```js
'use strict';

exports.handler = async (event) => {
    const redirects = [
      '/lambda/index.html',
      '/s3/index.html'
    ];

    const redirect_url = redirects[Math.floor(Math.random() * redirects.length)];
    return {
        status: '307',
        statusDescription: 'Temporary Redirect',
        headers: {
            location: [{
                key: 'Location',
                value: 'https://dan-sullivan.co.uk' + redirect_url,
            }],
        },
    };
};
```

...paired with `runtime = "nodejs24.x"`. This is a correct and small change, but it changes two variables at once on the riskiest function in the stack. **Recommendation: take `nodejs22.x` now, and treat the async rewrite + `nodejs24.x` as a separate, later change** once the first one is confirmed good.

**Other compatibility notes for the Node bump.**

- **CommonJS vs ESM.** `exports.handler` is CommonJS. The zip contains only `index.js` and no `package.json` (see the `archive_file` below), so there is no `"type": "module"` to flip it to ESM. `exports.handler` remains valid on `nodejs22.x`.
- **AWS SDK.** Node 18+ runtimes ship SDK v3 only, not v2. `edge_redirect.js` imports nothing at all, so this is a non-issue.
- **Lambda@Edge feature restrictions** that the current config already satisfies and must keep satisfying: function must live in **us-east-1** (`provider = "aws.us-east-1"` — correct), the execution role must be assumable by both `lambda.amazonaws.com` and `edgelambda.amazonaws.com` (`aws_iam_role.lambda_exec_role_edge_lambda`, `core.tf:181-200` — correct), no environment variables, no layers, no VPC, x86_64 only, and CloudFront must reference a **numbered version**, not `$LATEST` or an alias.

**Deploy path this touches.**

- The zip is built in-repo by the `archive_file` data source (`terraform/core/core.tf:212-219`), which inlines `edge_redirect.js` as `index.js`. `source_code_hash` is `data.archive_file.edge_redirect.output_base64sha256`. If you only change `runtime`, the hash does **not** change and Terraform issues a config-only update. If you also rewrite the JS (the `nodejs24.x` option), the hash changes too and both code and config update.
- `publish = true` means any update publishes a **new numbered version**, so `qualified_arn` changes, so the `lambda_function_association` on the CloudFront distribution changes, so **the distribution itself is updated and must re-propagate** (typically 5–15 minutes) and the new function replicates to edge locations. This is the single most consequential part of the change — see §3.
- The old function version cannot be deleted until CloudFront has finished removing its replicas; Terraform does not try to delete old versions here, so this should not bite, but do not manually prune versions.

### 2.3 Verification commands (read-only, safe to run first)

```bash
# Confirm current live runtimes and the version CloudFront actually points at
aws lambda get-function-configuration --region eu-west-2 --function-name serve_dscouk \
  --query '{Runtime:Runtime,LastModified:LastModified,Handler:Handler}'
aws lambda list-versions-by-function --region us-east-1 --function-name edge_redirect \
  --query 'Versions[].{Version:Version,Runtime:Runtime}'
aws cloudfront get-distribution-config --id <DIST_ID> \
  --query 'DistributionConfig.DefaultCacheBehavior.LambdaFunctionAssociations'

# Nothing else in the repo pins the old runtimes
grep -rn "python3\.6\|nodejs6\.10" --exclude-dir=.git --exclude-dir=node_modules .
```

---

## 3. How to apply the fix: Terraform source vs. AWS CLI

**Recommendation: change the runtime in the Terraform source for both functions, and make Terraform the thing that applies it — but validate the toolchain first, and treat the two functions as two separate changes, landed in order.**

### 3.1 Why not "just use the AWS CLI"

For `serve_dscouk` the CLI would work but would immediately drift: the next master merge runs `terraform apply` (`.circleci/config.yml:35`) and pushes `runtime = "python3.6"` straight back onto the live function. So the `.tf` edit is mandatory regardless; doing the CLI call *as well* is at most a sequencing aid, not an alternative.

For `edge_redirect` the CLI shortcut **does not actually fix live traffic at all**. `aws lambda update-function-configuration --runtime nodejs22.x` changes `$LATEST` only. CloudFront is associated with an immutable numbered version, and Lambda@Edge explicitly forbids `$LATEST` and aliases. To fix the live path by hand you would need to update `$LATEST`, `publish-version`, then `get-distribution-config` / `update-distribution` to repoint the association — i.e. hand-rolling exactly what Terraform already does in one step, while introducing state drift into `prod/terraform_core.state`. Terraform is the *safer* option here, not the riskier one.

### 3.2 The real risk: the 2018-era toolchain

`.circleci/images/Dockerfile` pins **Terraform 0.10.6** on `circleci/node:7.10` with python2 `awscli`. Neither `terraform/main.tf` nor `terraform/core/core.tf` constrains the AWS provider version (only `required_version = ">= 0.10.1"`), and Terraform 0.10 predates the dependency lock file, so `terraform init` resolves whatever provider it can still negotiate.

The concrete hazard: **AWS provider versions of that era validated `runtime` against a hard-coded allow-list.** A provider that only knows `nodejs6.10` / `python3.6` / `java8` / `python2.7` will reject `python3.13` and `nodejs22.x` at plan time with an "expected runtime to be one of [...]" error. This is a *plan-time* failure, so it is loud and harmless — but it is the most likely reason the straightforward change does not work first time.

**So, before editing anything, the follow-on agent must establish:**

1. What provider version `terraform init` actually resolves in the CI image (`terraform providers`, or inspect `.terraform/plugins/`).
2. Whether a `terraform plan` with the new runtime string is accepted.

**Then pick a branch:**

- **If plan accepts the new runtimes** → land the `.tf` changes and apply via the normal path. This is the clean outcome.
- **If plan rejects them** → do not attempt to upgrade Terraform 0.10.6 as part of this fix. Modernising the toolchain (0.10 → 0.11 → 0.12 syntax migration → current, plus replacing `circleci/node:7.10` and python2 awscli) is a multi-day project and the EOL runtimes should not wait for it. In that case:
  - Apply the runtime change with the AWS CLI (for `edge_redirect`: `update-function-configuration` → `publish-version` → `update-distribution` to repoint the association).
  - **Still commit the `.tf` edits**, with a comment noting they were applied out-of-band, so the source of truth matches reality and nobody reverts it.
  - Expect a `terraform plan` diff afterwards until the provider is modern enough to represent the new value; document that in the commit message.

### 3.3 Order of operations, and the one-way doors

**Land `serve_dscouk` first, then `edge_redirect` separately.** Never both in one change — if the site breaks you want to know which function did it.

1. **`serve_dscouk`** — lower risk. It rides the existing CI pipeline (`terraform/` root module). Blast radius is the `/lambda*` pages and the default origin; responses are cached (`default_ttl` 3600, `max_ttl` 86400) so viewers may not notice immediately, which cuts both ways. Verify with `curl -sI https://dan-sullivan.co.uk/lambda/index.html` and by checking CloudWatch logs for the function.
2. **`edge_redirect`** — higher risk, and **CI does not deploy it**. `.circleci/config.yml` only ever `cd`s into `terraform/`; the `terraform/core/` module is applied manually. So this one requires a deliberate local `terraform init && terraform plan && terraform apply` in `terraform/core/` against `prod/terraform_core.state`. Read the plan carefully: expect exactly one `aws_lambda_function.edge_redirect` in-place update and one `aws_cloudfront_distribution.dscouk` in-place update (the changed `qualified_arn`). **If the plan shows the distribution being replaced rather than updated, stop** — that would mean downtime and a new distribution domain name.
3. After the edge apply, wait for the distribution to reach `Deployed`, then verify the root redirect end to end:
   ```bash
   curl -sI https://dan-sullivan.co.uk/ | head -5   # expect 307 + Location to /lambda/ or /s3/
   ```
   A broken Lambda@Edge function surfaces as **HTTP 502** on every request, with logs in CloudWatch in the *edge region nearest the requester*, not us-east-1 — check `eu-west-1`/`eu-west-2` log groups named `/aws/lambda/us-east-1.edge_redirect`.

**One-way doors — call these out loudly:**

- **You cannot roll back to `python3.6` or `nodejs6.10`.** AWS blocks function *update* on `python3.6` as of 29 Aug 2022 and on `nodejs6.10` as of 12 Aug 2019. Once the runtime moves forward, moving it back will be rejected. Rollback means **fix forward** on a supported runtime, not `git revert`.
- The same blocking rule means a *code-only* update to either function may already be rejected by Lambda today. If a `terraform apply` on `serve_dscouk` has been failing at `UpdateFunctionCode`, that is why — and the fix is to change the runtime, either in the same apply or via `aws lambda update-function-configuration --runtime python3.13` first to unblock it.
- For `edge_redirect`, `git revert` on the `.tf` is not a rollback either: it would publish *another* new version and trigger *another* distribution propagation. If the edge function misbehaves, the fastest true rollback is to repoint the CloudFront `lambda_function_association` at the previous known-good version ARN — note that ARN down before you apply.

---

## 4. Out of scope: other Python 3.8 Lambdas in the account

The AWS account also contains `zappa1-dev`, `zappa-django1-djangotest1dev` and `gethunts-dev`, all on `python3.8` (itself deprecated since 14 Oct 2024). **These belong to a different project and are not managed by this repository** — nothing in `terraform/` or `terraform/core/` declares them, and they are not reachable from this site's CloudFront distribution.

They are a real EOL exposure, but they are *someone else's ticket*. A follow-on agent working from this document should not touch them, and should not be surprised to see them in a Trusted Advisor or Health Dashboard "deprecated runtimes" list alongside the two functions above.

---

## 5. Future / non-blocking

None of the following is required to clear the EOL runtimes. They are recorded here so the context is not lost.

### 5.1 Retire the `serve_dscouk` Lambda in favour of S3-only hosting?

**Probably not — but understand why before deciding.** `serve_dscouk` exists as a *demonstration*: the README states the site's goal is to show "the same page served by different methods", and the `/lambda` vs `/s3` split is the demo. Deleting the Lambda path would delete the point of the site. The Lambda is not there because it is the best way to serve static files; it is there because it is the exhibit.

That said, the current shape is doing unnecessary work: CloudFront's **default** cache behaviour points at the API Gateway/Lambda origin, so the Lambda handles traffic that isn't part of the demo. A worthwhile, low-risk cleanup is to **repoint `default_cache_behavior` at the S3 origin** and leave `/lambda*` on the Lambda. That keeps the demo intact, cuts Lambda invocations to the pages that are actually demonstrating Lambda, and shrinks the blast radius of the next runtime EOL. It would also let the `dscouk-lambda-dev` origin and the `/pr*/pr*/lambda*` behaviour be re-examined.

If the demo is ever retired, the full removal is: delete `terraform/lambda.tf` + `terraform/api.tf`, drop the two API Gateway origins and the `/lambda*` behaviours from `core.tf`, drop `grunt exec:zip_lambda_dscouk` from `Gruntfile.js` and `.circleci/config.yml`, and drop the `lambda` Grunt target and `src/templates/lambda-thissite.tpl`.

### 5.2 The empty stub files

`terraform/cloudfront.tf` and `terraform/s3.tf` are both **0 bytes**. The real CloudFront and S3 configuration lives in `terraform/core/core.tf`. These stubs are actively misleading — they suggest the root module owns CloudFront and S3, which sent this review looking in the wrong place first.

**Recommendation:** delete both. If they are meant as placeholders for a future split, replace them with a one-line comment pointing at `terraform/core/core.tf` instead. This is a zero-risk change but should **not** be bundled with the runtime fix — keep that diff to one line per file.

### 5.3 Toolchain modernisation

Not blocking, but it is the root cause of §3.2 being a question at all:

- Terraform 0.10.6 → current (0.10 → 0.11 → 0.12 syntax migration is the painful step; the `"${...}"` interpolation everywhere and `config {}` blocks in `terraform/main.tf:22` are 0.11-era syntax).
- Pin the AWS provider version explicitly once on a Terraform version that supports it, and commit a lock file.
- `.circleci/images/Dockerfile`: `circleci/node:7.10` and python2 `pip install awscli` are both long dead; the base image is unlikely to still be pullable.
- `origin_ssl_protocols = ["TLSv1"]` on both API Gateway origins (`core.tf:265`, `core.tf:277`) is CloudFront-to-origin only, but TLS 1.0 should be raised to `["TLSv1.2"]`.
- Add a calendar reminder for **30 Apr 2027** (`nodejs22.x`) if you take the conservative edge option in §2.2.

---

## Appendix: reference dates

| Runtime | Status | Deprecation | Update blocked |
| --- | --- | --- | --- |
| `python3.6` | deprecated | 18 Jul 2022 | 29 Aug 2022 |
| `nodejs6.10` | deprecated | 12 Aug 2019 | 12 Aug 2019 |
| `python3.8` (other projects) | deprecated | 14 Oct 2024 | 3 Mar 2027 |
| `nodejs20.x` | deprecated | 30 Apr 2026 | 3 Mar 2027 |
| **`nodejs22.x`** | **supported** | 30 Apr 2027 | 1 Jul 2027 |
| `nodejs24.x` | supported (no callback handlers) | 30 Apr 2028 | 1 Jul 2028 |
| `python3.12` | supported | 31 Oct 2028 | 10 Jan 2029 |
| **`python3.13`** | **supported** | 30 Jun 2029 | 31 Aug 2029 |
| `python3.14` | supported | 30 Jun 2029 | 31 Aug 2029 |

Sources: [AWS Lambda runtimes](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html), [Restrictions on Lambda@Edge](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-at-edge-function-restrictions.html), [Node.js 24 runtime now available in AWS Lambda](https://aws.amazon.com/blogs/compute/node-js-24-runtime-now-available-in-aws-lambda/).
