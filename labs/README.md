# Blog labs

Reproducible validations for published posts. One folder per post, named after the post's permalink slug.

Each lab has:

- `README.md` — what the post claims, which claims are unverified, how to run the lab, and the screenshot checklist.
- `lab.env.example` — copy to `lab.env` (gitignored) and fill in.
- `scripts/NN-*.sh` — run in order. `90-teardown.sh` always last.
- Terraform stacks where the post uses them.
- `results/` (gitignored) — raw command output captured by the scripts, used to update the post.

Screenshots go to `assets/images/postsImages/` using the existing naming convention (`<PREFIX>_<NN>.png`) and are embedded as:

```html
<img src="/assets/images/postsImages/OCI_TFState_01.png" class="alignnone">
```

This folder is excluded from the Jekyll build (`_config.yml`). State files, tfvars, keys and results are gitignored.

| Post | Lab | Status |
|---|---|---|
| [Terraform OCI Backend: Securing State in Object Storage](/oci-terraform-backend-object-storage/) | [oci-terraform-backend-object-storage](oci-terraform-backend-object-storage/) | run 2026-11-11 — 2 corrections needed |
