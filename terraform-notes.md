# Terraform Notes — Day 1

My own notes from learning Terraform. Written in simple words so I can read it again later.

---

## Part 1 — What is Terraform?

Terraform is a program. I write text files that describe what I want in AWS.
Then Terraform talks to AWS and builds it.

I already know CloudFormation. Terraform does the same job.
The difference: CloudFormation uses YAML, Terraform uses HCL (its own language).
And Terraform can also manage Azure, GitHub, and other services. CloudFormation is only AWS.

### The loop I repeat forever

```
1. Write .tf files          (say what I want)
2. terraform init           (download the AWS plugin) - only once per folder
3. terraform plan           (preview - nothing changes yet)
4. terraform apply          (really build it)
5. terraform destroy        (delete everything)
```

Important: `plan` is safe. It only shows me what would happen. Nothing is created.
Only `apply` and `destroy` change real things in AWS.

---

## Part 2 — My project files

My folder is `C:\Users\p250825\projects\aws-static-pipeline`

```
aws-static-pipeline/
├── versions.tf          <- rules: which Terraform, which provider, which region
├── s3.tf                <- the S3 bucket for my website
├── cloudfront.tf        <- CloudFront + OAC + bucket policy
├── backend.tf           <- where to save the state file
├── checklist.md         <- my progress tracker
├── site/
│   └── index.html       <- my website content (NOT managed by Terraform)
└── bootstrap/           <- a SEPARATE small project
    └── main.tf          <- creates the bucket that stores state files
```

**Important rule:** Terraform reads ALL `.tf` files in one folder together, as if they were one big file.
The file names do not matter to Terraform. `s3.tf`, `main.tf`, `banana.tf` — all the same.
I split them by topic only to help myself read them.

**Also important:** Terraform does NOT look inside subfolders.
So `bootstrap/` is a completely separate project. It has its own state, its own everything.

---

## Part 3 — Each file explained

### versions.tf — the rules file

```hcl
terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Owner     = "p250825"
      Project   = "aws-static-pipeline"
      ManagedBy = "terraform"
    }
  }
}
```

**What it does:** Sets the rules for this project. No AWS resources here.

**Line by line:**

| Line | What it means | Why I need it |
|---|---|---|
| `required_version = ">= 1.11"` | Refuse to run if Terraform is older than 1.11 | Old versions may not understand my code. This stops confusing errors. |
| `required_providers { aws = ... }` | I need the AWS plugin | Terraform alone does not know how to talk to AWS. It needs a plugin, called a **provider**. |
| `source = "hashicorp/aws"` | The plugin is published by HashiCorp | There are other AWS providers. This says which one. |
| `version = "~> 6.0"` | Use version 6.x, but never 7.x | `~>` means "allow small updates, block big ones". Version 7 might work differently and break my code. |
| `provider "aws" { region = ... }` | Configure the plugin: use Tokyo | Every resource I write goes to Tokyo unless I say otherwise. |
| `default_tags` | Put these 3 tags on every resource automatically | I cannot see the bill in this company account. Tags let me (and other people) find what I created. |

**Why I wrote it:** Without `required_providers`, `terraform init` does not know what to download.
Without `provider "aws" { region }`, Terraform does not know which region to build in.

---

### s3.tf — my first resource

```hcl
resource "aws_s3_bucket" "site" {
  bucket = "p250825-static-site"
}
```

**What it does:** Creates one S3 bucket. This is where my website files live.

**Line by line:**

`resource` — the keyword meaning "I want Terraform to create and manage something".

`"aws_s3_bucket"` — the TYPE of thing. This exact word comes from the AWS provider documentation.
I cannot invent it. If I type it wrong, Terraform says "unknown resource type".

`"site"` — a nickname *I* choose. AWS never sees this. It is only used inside my `.tf` files,
so other resources can point to this one. For example: `aws_s3_bucket.site.arn`.

`bucket = "p250825-static-site"` — the real name AWS will use.
S3 bucket names must be unique in the whole world, across all AWS accounts.
That is why I put my employee ID in front.

**Why so short?** Because a bucket does not need much. AWS fills in the rest with defaults.
Later, if I want versioning or encryption, those are SEPARATE resources (see bootstrap/main.tf).
This is different from CloudFormation, where they are all properties inside one block.

---

### backend.tf — where the state file lives

```hcl
terraform {
  backend "s3" {
    bucket       = "p250825-tf-state"
    key          = "site/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

**First I must understand: what is the state file?**

When Terraform creates something, it writes down what it made in a file called `terraform.tfstate`.
This file is Terraform's **memory**.

Inside it: the bucket name, its ARN, its region, its tags, its encryption setting — everything.
Terraform asked AWS "what does this bucket look like?" and saved the full answer.

**Why the state file matters:**

Terraform knows nothing except what is in that file.
- If the file says the bucket exists → Terraform will not create it again.
- If the file is gone → Terraform thinks nothing exists, and tries to build everything again.

I tested this. I moved the file away and ran `plan`. Terraform wanted to create the bucket again.

**So why move the state file to S3?**

Three problems with keeping it on my laptop:

1. **One laptop = one point of failure.** If my disk dies or I delete the file, Terraform forgets
   everything it built. The resources are still in AWS, but Terraform cannot see them anymore.

2. **Nobody else can work on it.** A coworker running Terraform would have no state file.
   They would try to create everything again.

3. **Two people at the same time can break it.** If two `apply` commands write to the file
   at the same moment, the file gets corrupted. Local files have no protection against this.

**Line by line:**

| Line | What it means |
|---|---|
| `backend "s3"` | Store the state in S3, not on my laptop |
| `bucket = "p250825-tf-state"` | Which bucket (the one I made in `bootstrap/`) |
| `key = "site/terraform.tfstate"` | The path INSIDE the bucket. Like a file path. If I had a second project it would use a different key, e.g. `network/terraform.tfstate` |
| `region = "ap-northeast-1"` | Which region the bucket is in. Careful: `ap-northeast-1a` is an Availability Zone, NOT a region. I made this mistake. |
| `encrypt = true` | Encrypt the state file. State can contain passwords in plain text. |
| `use_lockfile = true` | Turn on locking. While one `apply` runs, nobody else can run at the same time. |

**How I moved it:**

```powershell
terraform init -migrate-state
```

`backend.tf` alone does NOT move anything. It only says WHERE to store state from now on.
The `-migrate-state` flag is what actually copies the old local file into S3.

Nothing about my AWS resources changed. Only the location of the memory changed.

---

### bootstrap/main.tf — the chicken and egg problem

**The problem:**

My main project needs a bucket to store its state.
But if I create that bucket with the same project... where does THAT state go?

**The answer:** a small separate project. It creates only the state bucket.
It runs once. Its own state stays on my laptop, and that is fine, because it manages nothing else.

```hcl
resource "aws_s3_bucket" "tf_state" {
  bucket = "p250825-tf-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**Four resources, not one.** This is important and different from CloudFormation.

In CloudFormation, one `AWS::S3::Bucket` holds versioning, encryption, and public access
as properties inside it. In Terraform, they are four separate resources that all point at the same bucket.

**Why each one:**

| Resource | Why |
|---|---|
| `aws_s3_bucket` | The bucket itself |
| `lifecycle { prevent_destroy = true }` | A safety lock. If I run `terraform destroy` by accident, Terraform REFUSES to delete this bucket. It holds all my memory. Losing it is very bad. |
| `aws_s3_bucket_versioning` | Keep old copies of the state file. If state gets corrupted, I can go back to yesterday's version. This is my undo button. |
| `aws_s3_bucket_server_side_encryption_configuration` | Encrypt at rest. State files can contain secrets in plain text. |
| `aws_s3_bucket_public_access_block` | Make it impossible to accidentally make this bucket public. |

**Notice:** `bucket = aws_s3_bucket.tf_state.id`

This is a **reference**. It means "use the ID of the bucket I defined above".
I do not type the bucket name again. If I change the name in one place, everything follows.

References also tell Terraform the ORDER. It knows it must create the bucket first,
then attach versioning. I never say "do this before that" — the references do it for me.

---

### cloudfront.tf — four things that connect together

This file is the most complex one. It has 3 resources plus 1 output.

#### Resource 1 — Origin Access Control (OAC)

```hcl
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "p250825-site-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
```

**The problem it solves:**

My bucket is private. Block Public Access is ON. Nobody on the internet can read it.
But CloudFront needs to read `index.html` to serve it to visitors.

**The answer:** OAC gives CloudFront an identity. CloudFront **signs** every request to S3
using AWS credentials, proving "I am CloudFront distribution E1ABC...".
S3 checks that signature against the bucket policy and allows it.

| Line | What it means |
|---|---|
| `origin_access_control_origin_type = "s3"` | The origin is an S3 bucket (not a load balancer, etc.) |
| `signing_behavior = "always"` | Sign every request, no exceptions |
| `signing_protocol = "sigv4"` | Use AWS Signature Version 4, the current standard |

Note: there is an older way called OAI (Origin Access Identity). It still works but is legacy.
OAC is the current method. They are NOT interchangeable.

#### Resource 2 — the CloudFront distribution

```hcl
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
    origin_id                = "s3-origin"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
```

**What CloudFront is:** a CDN. It copies my files to servers all over the world.
A visitor in Osaka gets the file from a nearby server, not from Tokyo. Faster, and cheaper.

**The `origin` block — where CloudFront gets the files from:**

| Line | What it means | Why it matters |
|---|---|---|
| `domain_name = aws_s3_bucket.site.bucket_regional_domain_name` | The bucket's REST endpoint | There are two kinds of S3 endpoint. The REST endpoint (`bucket.s3.region.amazonaws.com`) works with OAC. The WEBSITE endpoint (`bucket.s3-website-region.amazonaws.com`) does NOT support OAC and has no HTTPS. I must use the REST one. |
| `origin_access_control_id = ...` | Connect the OAC I made above | Without this, CloudFront does not sign requests, and S3 denies everything with 403 |
| `origin_id = "s3-origin"` | A label I choose for this origin | Used below in `target_origin_id`. Both strings must match exactly. |

**`default_root_object = "index.html"`**

When someone visits `https://myurl.cloudfront.net/` with no filename, CloudFront asks S3 for
`index.html`. Without this line, CloudFront asks S3 for an empty key, and S3 returns 403
(not 404 — S3 will not confirm a key does not exist to a caller who is not authorized to list).

This is the number one cause of "403 on `/` but 200 on `/index.html`".

**Important limit:** this only works at the root. `/blog/` will still fail.
Fixing that needs a CloudFront Function or an `index.html` in every folder.

**The `default_cache_behavior` block — how CloudFront handles requests:**

| Line | What it means |
|---|---|
| `allowed_methods = ["GET", "HEAD"]` | Only allow read requests. My site is static — no uploads, no deletes. Allowing POST/PUT/DELETE would be pointless and a bigger attack surface. |
| `cached_methods = ["GET", "HEAD"]` | Which of those to cache |
| `target_origin_id = "s3-origin"` | Send these requests to that origin. MUST match `origin_id` above. |
| `viewer_protocol_policy = "redirect-to-https"` | If someone uses http://, redirect them to https:// |
| `forwarded_values { query_string = false }` | Ignore `?something=x` when deciding what to cache. My static files do not care about query strings, so this improves the cache hit rate. |
| `cookies { forward = "none" }` | Do not pass cookies to S3. S3 does not use them. |

**The last two blocks:**

`restrictions { geo_restriction { restriction_type = "none" } }` — do not block any country.
This block is REQUIRED even when I want no restriction. Terraform will error without it.

`viewer_certificate { cloudfront_default_certificate = true }` — use CloudFront's own
HTTPS certificate, which covers `*.cloudfront.net`. I get HTTPS for free with no work.

If I wanted my own domain like `www.mysite.com`, I would need:
an ACM certificate **in us-east-1** (CloudFront only reads certs from that region, no exceptions),
plus an `aliases` list, plus DNS records. I do not have a domain, so I skip all of that.

#### Resource 3 — the bucket policy

```hcl
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontOAC"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.site.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
          }
        }
      }
    ]
  })
}
```

**What it does:** The OAC lets CloudFront *ask*. The bucket policy is what lets it *succeed*.
Both are needed. OAC without a matching policy = 403.

**`jsonencode({ ... })`** — a Terraform function. I write the policy in HCL style,
and Terraform converts it to JSON. Easier than writing raw JSON with escaped quotes.

| Line | What it means | Why |
|---|---|---|
| `Version = "2012-10-17"` | The IAM policy language version | Always this exact date. It is not a date I choose. It is the version identifier of the policy language. |
| `Sid` | A name for this statement | Optional. Helps when reading logs. |
| `Effect = "Allow"` | Allow, not Deny | |
| `Principal = { Service = "cloudfront.amazonaws.com" }` | WHO is allowed | The CloudFront service itself |
| `Action = "s3:GetObject"` | WHAT they can do | Only read objects. Not list, not write, not delete. |
| `Resource = "${aws_s3_bucket.site.arn}/*"` | WHICH objects | The `/*` matters. Without it, this would mean the bucket itself (for listing), not the objects inside. |
| `Condition` with `AWS:SourceArn` | WHICH CloudFront | See below. This is important. |

**About the Condition — I tested this:**

I removed the Condition and the site still worked. Why?

Because the Condition does not control whether CloudFront **can** access.
It controls **which** CloudFront distributions can access.

Without it, the policy says "any CloudFront distribution, in any AWS account, can read my bucket".
A stranger could create their own distribution, point it at my bucket
(the domain name is easy to guess from the bucket name), and serve my files.

My own distribution still worked because the Principal still matched.

**Lesson: a Condition makes a policy narrower. Removing one makes it MORE permissive, not less.**

For a public website the risk is small. For private data it would be a leak.

#### The output

```hcl
output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.site.domain_name}"
}
```

**What it does:** prints a value after `apply`, so I do not have to hunt for it in the console.

`${...}` is string interpolation — put the value of that expression inside the text.

I can read it any time with:
```powershell
terraform output cloudfront_url
```

---

## Part 4 — How the pieces connect

```
aws_s3_bucket.site
      │
      │ (its regional domain name and ARN are used by...)
      ▼
aws_cloudfront_origin_access_control.site
      │
      │ (its id is used by...)
      ▼
aws_cloudfront_distribution.site
      │
      │ (its ARN is used by...)
      ▼
aws_s3_bucket_policy.site  ──── grants access back to the distribution
```

**Terraform works out this order by itself.** I never write "create X before Y".
When I write `aws_s3_bucket.site.arn` inside another resource, Terraform sees the reference
and knows the bucket must exist first.

This is called an **implicit dependency**. It is one of the best things about Terraform.

---

## Part 5 — What actually happens when a visitor loads my site

1. Visitor types `https://dxxxx.cloudfront.net`
2. DNS resolves to the nearest CloudFront edge location
3. TLS handshake happens **at the edge**, using CloudFront's default certificate
4. CloudFront checks its cache. If the file is there (cache hit) → send it, done.
5. If not (cache miss) → CloudFront needs to fetch from the origin
6. Because `default_root_object = "index.html"`, the request for `/` becomes a request for `index.html`
7. CloudFront signs the request with SigV4, using its OAC identity
8. The request goes to the S3 REST endpoint
9. S3 checks the bucket policy: is the Principal `cloudfront.amazonaws.com`? Is the SourceArn my distribution? Is the Action `s3:GetObject`?
10. Yes to all → S3 returns the file
11. CloudFront caches it at the edge and sends it to the visitor
12. The next visitor in the same region gets it from cache, and S3 is never contacted

**Block Public Access stays ON the whole time.** No public access is ever needed.

---

## Part 6 — Commands I used

| Command | What it does | Safe? |
|---|---|---|
| `terraform init` | Download the provider plugin. Run once per folder. | Yes |
| `terraform init -migrate-state` | Move existing state to a new backend | Careful — but it asks first |
| `terraform plan` | Preview changes. Nothing happens in AWS. | Yes, always |
| `terraform apply` | Really build it. Asks me to type `yes`. | No — this changes real things |
| `terraform destroy` | Delete everything in this folder's state | No — very dangerous |
| `terraform output <name>` | Print an output value | Yes |
| `terraform fmt` | Auto-fix indentation in my .tf files | Yes |
| `terraform validate` | Check syntax without contacting AWS | Yes |

**How to read a plan:**

```
Plan: 3 to add, 0 to change, 0 to destroy.
```

- `+` = will be created
- `~` = will be changed in place
- `-` = will be DESTROYED
- `-/+` = will be destroyed and recreated (dangerous — can cause downtime)

**I must read the "to destroy" number every single time before typing yes.**
This is the habit that stops me from deleting a production database by accident.

---

## Part 7 — Mistakes I made today

| Mistake | What happened | Lesson |
|---|---|---|
| Typed `sed` in PowerShell | Command not found | `sed` is Linux. PowerShell is a different language. |
| Typed `$env:USERPROFILE` in bash | Command not found | Same thing in reverse. Check which window I am in: `PS C:\>` is PowerShell, `user@pc:~$` is Linux. |
| `region = "ap-northeast-1a"` | Terraform error: Missing region value | `ap-northeast-1a` is an Availability Zone. The region is `ap-northeast-1`. |
| `Out-File` broke the .tf file | "Invalid multi-line string" errors | PowerShell wrote the wrong text encoding. Better to edit files in the Kiro editor. |
| Copied `aws_s3_bucket.b` from the docs | Reference to a resource that does not exist | Doc examples use their own names. I must change them to MY names (`site`). |
| Copied `aliases` from the docs | Would need a domain and a certificate I do not have | Do not copy blindly. Read what each line does first. |
| Extra `}` when pasting the Condition back | Syntax error | Count the braces. Or use `terraform fmt` to spot bad structure. |

---

## Part 8 — Words I need to know

| Word | Meaning |
|---|---|
| **Provider** | A plugin that lets Terraform talk to a service (AWS, Azure, GitHub) |
| **Resource** | One thing Terraform creates and manages (a bucket, a distribution) |
| **State** | Terraform's memory of what it built. A JSON file. |
| **Backend** | Where the state file is stored (local laptop, or S3) |
| **Reference** | Pointing at another resource, like `aws_s3_bucket.site.arn` |
| **Implicit dependency** | Terraform working out the build order from references |
| **Output** | A value Terraform prints after apply |
| **HCL** | HashiCorp Configuration Language — the syntax of .tf files |
| **OAC** | Origin Access Control — lets CloudFront read a private S3 bucket |
| **ARN** | Amazon Resource Name — the unique ID of any AWS resource |
| **Origin** | Where CloudFront fetches files from |
| **Edge location** | A CloudFront server near the visitor |
| **Cache invalidation** | Telling CloudFront to forget its cached copy |

---

## Part 9 — What I built today

```
Visitor
   │ HTTPS
   ▼
CloudFront distribution  (public, has free TLS certificate)
   │ signed request (SigV4, via OAC)
   ▼
S3 bucket p250825-static-site  (PRIVATE, Block Public Access ON)
   └── index.html

Separately:
S3 bucket p250825-tf-state  (private, versioned, encrypted)
   └── site/terraform.tfstate   <- Terraform's memory
```

**Cost:** close to zero. A few MB in S3 is fractions of a cent.
CloudFront's free tier covers 1 TB out and 10 million requests per month.
Realistically $0.00 to $0.50 per month.

**Careful:** I cannot see the bill in this company account. So I must check for
expensive leftovers myself. NAT Gateway is about $45/month. ALB is about $18/month.
EKS control plane is about $73/month. None of those exist yet, but they will in later weeks.

---

## Part 10 — Next steps

- [ ] Run `terraform apply` to restore the Condition in the bucket policy (I removed it while testing)
- [ ] Test `https://<my-url>/nonexistent.html` and see what error S3 gives, and why
- [ ] Create the GitHub OIDC provider and a deploy role scoped to one branch
- [ ] Write `.github/workflows/deploy.yml` so a `git push` deploys the site
- [ ] Start `failures.md` and write down every error from today
- [ ] `terraform destroy` at the end, and confirm nothing is left except the state bucket
