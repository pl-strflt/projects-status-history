❗ The project is now deprecated as it uses [deprecated ProjectNext API](https://github.blog/changelog/2022-06-23-the-new-github-issues-june-23rd-update/). Its' functionality was ported to a [TS action](https://github.com/galargh/.github/blob/d3061a425cd373878e4f0320b344671955aef3c8/scripts/src/actions/shared/update-status-history.ts).

# What is Status History?

The workflow available in this repository help maintaining the following fields on a GitHub project:
- `Status History`: a list of past statuses an item was assigne
- `Status Timestamp`: a timestamp from when the last `Status` change was performed
- `Status Date`: a date when the last `Status` change was performed

I advise GitHub project admins to set up the update workflow to run on schedule. Personally, I have it set up to run every hour but the frequency should be adjusted according to the granularity of the updates the admins care about.

## Prerequisites

### GitHub Token

You need to create a GitHub token with:
- `admin:org` permission for writing to the project

### Project Status History, Timetamp and Date Fields

Unfortunately, it is not yet possible to automate creation of the project fields.

For `Status History`, `Status Timestamp` and `Status Date` as `NAME`:
1. Navigate to your project.
1. Click `➕ New Field`.
1. Name the field `NAME`.
1. Set the type to `📅 Date` for `NAME` = `Status Date` and to `🔤 Text` otherwise.
1. Click `Save`.

## How to update Status History?

You can either run the script from your console or set up and run a GitHub Actions workflow.

Both methods expect the following inputs:
- `OWNER`: the name of the user or the organisation where the project resides
- `PROJECT_NAME`: the name of the project

### Console

1. Install [GitHub CLI](https://cli.github.com/).
1. [Authenticate with GitHub](https://cli.github.com/manual/gh_auth_login) by running `gh auth login` (e.g. with the `GITHUB_TOKEN` you created).
1. Clone this repository  by running `gh repo clone pl-strflt/projects-status-history`.
1. Perform the update by running `./projects-status-history/.github/scripts/update.sh 'OWNER' 'PROJECT_NAME'`.

### GitHub Actions

This is an example of an update workflow that you can create in a repository of your choosing:
```
name: Update Status History
on:
  schedule:
    - cron:  '15 * * * *'
jobs:
  update:
    uses: pl-strflt/projects-status-history/.github/workflows/update_reusable.yml@main
    with:
      owner: OWNER
      project_name: PROJECT_NAME
    secrets:
      token: GITHUB_TOKEN
```

## How does it work?

To analyse the procedure in detail, I advise you to look at the [code](.github/scripts/update.sh) directly.
