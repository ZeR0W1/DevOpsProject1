"""Secret-safe diagnostic filters for project lifecycle API calls."""


def github_api_diagnostic(status, operation="access"):
    """Classify a GitHub API status without exposing response content."""
    status = int(status or 0)
    if status == 401:
        return (
            "the lifecycle token is invalid, expired, or revoked; rerun bash "
            "setup.sh to replace it"
        )
    if status == 403:
        return (
            f"the token identity is valid but GitHub {operation} is denied; grant "
            "the required fine-grained repository permission and review organization policy"
        )
    if status == 404:
        return (
            "the selected repository, webhook, or delivery was not found or is not "
            "available to this token; verify setup repository selection and token access"
        )
    if status == 422:
        return (
            f"GitHub rejected the {operation} request as invalid; verify the reviewed "
            "request inputs and current GitHub resource state"
        )
    return (
        "GitHub could not be reached or returned an unexpected response; verify "
        "controller DNS/network access and GitHub API availability"
    )


class FilterModule:
    """Expose project diagnostic filters to Ansible."""

    def filters(self):
        return {"github_api_diagnostic": github_api_diagnostic}