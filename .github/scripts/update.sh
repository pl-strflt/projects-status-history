#!/bin/bash

set -e
set -u
set -o pipefail

echo "::group::Parsing inputs"
owner="$1"
echo "owner=${owner}"
project_name="$2"
echo "project_name=${project_name}"
timestamp="${3:-$(date -u +"%Y-%m-%d %H:%M")}"
echo "timestamp=${timestamp}"
echo "::endgroup::"

echo "::group::Checking the type of the owner"
type="$(gh api "users/${owner}" --jq '.type' | tr '[:upper:]' '[:lower:]')"
echo "type=${type}"
echo "::endgroup::"

echo "::group::Retrieving project"
project="$(gh api graphql -f query='query($login: String!, $project_name: String!, $endCursor: String) {
  '"$type"'(login: $login) {
    projectsNext(first: 1, query: $project_name) {
      nodes {
        id
        fields(first: 100) {
          nodes {
            id
            name
            settings
          }
        }
        items(first: 100, after: $endCursor) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            id
            fieldValues(first: 100) {
              nodes {
                value
                projectField {
                  id
                }
              }
            }
          }
        }
      }
    }
  }
}' -f login="${owner}" -f project_name="${project_name}" --jq '.data.'"$type"'.projectsNext.nodes[0]' --paginate | jq -nc '[inputs] | .[0] + {"items":{"nodes":(map(.items.nodes) | add)}}')"
echo "project=$(jq '.id' <<< "${project}")"
echo "::endgroup::"

echo "::group::Retrieving information about project"
project_id="$(jq -r '.id' <<< "${project}")"
echo "project_id=${project_id}"
project_status_field="$(jq -c '.fields.nodes | map(select(.name == "Status")) | .[0]' <<< "${project}")"
echo "project_status_field=$(jq -r '.id' <<< "${project_status_field}")"
project_status_field_id="$(jq -r '.id' <<< "${project_status_field}")"
echo "project_status_field_id=${project_status_field_id}"
project_status_field_settings="$(jq -r '.settings' <<< "${project_status_field}")"
echo "project_status_field_settings=${project_status_field_settings}"
project_status_history_field="$(jq -c '.fields.nodes | map(select(.name == "Status History")) | .[0]' <<< "${project}")"
echo "project_status_history_field=$(jq -r '.id' <<< "${project_status_history_field}")"
project_status_history_field_id="$(jq -r '.id' <<< "${project_status_history_field}")"
echo "project_status_history_field_id=${project_status_history_field_id}"
project_status_timestamp_field="$(jq -c '.fields.nodes | map(select(.name == "Status Timestamp")) | .[0]' <<< "${project}")"
echo "project_status_timestamp_field=$(jq -r '.id' <<< "${project_status_timestamp_field}")"
project_status_timestamp_field_id="$(jq -r '.id' <<< "${project_status_timestamp_field}")"
echo "project_status_timestamp_field_id=${project_status_timestamp_field_id}"
echo "::endgroup::"

echo "::group::Processing project items"
while read project_item_id; do
  if [[ -z "$project_item_id" ]]; then
    continue
  fi
  echo "project_item_id=${project_item_id}"
  project_item="$(jq -c '.items.nodes | map(select(.id == $id)) | .[0]' --arg id "${project_item_id}" <<< "${project}")"
  echo "project_item=$(jq -r '.id' <<< "$project_item")"
  echo "$project_item"
  project_item_status_history_field_value="$(jq -r '.fieldValues.nodes | map(select(.projectField.id == $id)) | .[0].value // "[]"' --arg id "${project_status_history_field_id}" <<< "${project_item}")"
  echo "project_item_status_history_field_value=${project_item_status_history_field_value}"
  project_item_status_field_value="$(jq -r '.fieldValues.nodes | map(select(.projectField.id == $id)) | .[0].value // ""' --arg id "${project_status_field_id}" <<< "${project_item}")"
  echo "project_item_status_field_value=${project_item_status_field_value}"
  project_item_status_field_value_name="$(jq -r '.options | map(select(.id == $id)) | .[0].name // ""' --arg id "${project_item_status_field_value}"  <<< "${project_status_field_settings}")"
  echo "project_item_status_field_value_name=${project_item_status_field_value_name}"
  if [[ "$(jq -r '.[0] // null' <<< "${project_item_status_history_field_value}")" == "${project_item_status_field_value_name}" ]]; then
    continue
  fi
  project_item_status_history_field_value="$(jq -c '[$status] + .[:1]' --arg status "${project_item_status_field_value_name}" <<< "${project_item_status_history_field_value}")"
  echo "project_item_status_history_field_value=${project_item_status_history_field_value}"
  > /dev/null gh api graphql -f query='mutation($project_id: ID!, $project_item_id: ID!, $project_status_history_field_id: ID!, $project_item_status_history_field_value: String!) {
    updateProjectNextItemField(input: {
      projectId: $project_id,
      itemId: $project_item_id,
      fieldId: $project_status_history_field_id,
      value: $project_item_status_history_field_value,
    }) {
      projectNextItem {
        id
      }
    }
  }' -f project_id="${project_id}" -f project_item_id="${project_item_id}" -f project_status_history_field_id="${project_status_history_field_id}" -f project_item_status_history_field_value="${project_item_status_history_field_value}"
  > /dev/null gh api graphql -f query='mutation($project_id: ID!, $project_item_id: ID!, $project_status_timestamp_field_id: ID!, $timestamp: String!) {
    updateProjectNextItemField(input: {
      projectId: $project_id,
      itemId: $project_item_id,
      fieldId: $project_status_timestamp_field_id,
      value: $timestamp,
    }) {
      projectNextItem {
        id
      }
    }
  }' -f project_id="${project_id}" -f project_item_id="${project_item_id}" -f project_status_timestamp_field_id="${project_status_timestamp_field_id}" -f timestamp="${timestamp}"
done <<< "$(jq -r '.items.nodes[].id' <<< "$project")"
echo "::endgroup"
