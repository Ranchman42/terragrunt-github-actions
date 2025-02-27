#!/bin/bash

function terragruntApply {
  # Gather the output of `terragrunt apply`.
  echo "apply: info: applying Terragrunt configuration in ${tfWorkingDir}"
  applyOutput=$(${tfBinary} apply -auto-approve -input=false ${*} 2>&1)
  applyExitCode=${?}
  applyCommentStatus="Failed"

  # If the first apply fails, then try again, this is needed because the terraform python module (terraform-aws-modules/lambda/aws) we use has a bug that prevents it from working the first apply usually.
  if [ ${applyExitCode} -eq 1 ]; then
    echo "${applyOutput}"
    echo "apply: info: failed first run apply, trying again Terragrunt configuration in ${tfWorkingDir}"
    applyOutput=$(${tfBinary} apply -auto-approve -input=false ${*} 2>&1)
    applyExitCode=${?}
    applyCommentStatus="Failed"
  fi

  # Exit code of 0 indicates success. Print the output and exit.
  if [ ${applyExitCode} -eq 0 ]; then
    echo "apply: info: successfully applied Terragrunt configuration in ${tfWorkingDir}"
    echo "${applyOutput}"
    echo
    applyCommentStatus="Success"
  fi



  # Exit code of !0 indicates failure.
  if [ ${applyExitCode} -ne 0 ]; then
    echo "apply: error: failed to apply Terragrunt configuration in ${tfWorkingDir}"
    echo "${applyOutput}"
    echo
  fi

  # Comment on the pull request if necessary.
  if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${tfComment}" == "1" ]; then
    applyCommentWrapper="#### \`${tfBinary} apply\` ${applyCommentStatus}
<details><summary>Show Output</summary>

\`\`\`
${applyOutput}
\`\`\`

</details>

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tfWorkingDir}\`, Workspace: \`${tfWorkspace}\`*"

    applyCommentWrapper=$(stripColors "${applyCommentWrapper}")
    echo "apply: info: creating JSON"
    applyPayload=$(echo "${applyCommentWrapper}" | jq -R --slurp '{body: .}')
    applyCommentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
    echo "apply: info: commenting on the pull request"
    echo "${applyPayload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${applyCommentsURL}" > /dev/null
  fi

  exit ${applyExitCode}
}
